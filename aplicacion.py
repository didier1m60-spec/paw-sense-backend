from fastapi import FastAPI, HTTPException, Depends, status
from fastapi.security import OAuth2PasswordBearer
from pydantic import BaseModel, EmailStr
from typing import List, Optional
import datetime
import jwt
import os
import bcrypt
from sqlalchemy import create_engine, Column, Integer, String, ForeignKey, DateTime
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker, Session, relationship

# Configuración de base de datos
DATABASE_URL = os.getenv("DATABASE_URL")
engine = create_engine(DATABASE_URL)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()

# Seguridad
SECRET_KEY = "paw_sense_secret_key_change_me"
ALGORITHM = "HS256"
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="auth/login")

# --- MODELOS DE BASE DE DATOS (SQLAlchemy) ---
class UserDB(Base):
    __tablename__ = "users"
    id = Column(Integer, primary_key=True, index=True)
    email = Column(String, unique=True, index=True, nullable=False)
    hashed_password = Column(String, nullable=False)
    created_at = Column(DateTime, default=datetime.datetime.utcnow)
    pets = relationship("PetDB", back_populates="owner")

class PetDB(Base):
    __tablename__ = "pets"
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    name = Column(String, nullable=False)
    breed = Column(String)
    age = Column(Integer)
    created_at = Column(DateTime, default=datetime.datetime.utcnow)
    owner = relationship("UserDB", back_populates="pets")

# --- ESQUEMAS DE ENTRADA/SALIDA (Pydantic) ---
class UserRegister(BaseModel):
    email: EmailStr
    password: str

class UserLogin(BaseModel):
    email: EmailStr
    password: str

class Token(BaseModel):
    access_token: str
    token_type: str

class PetCreate(BaseModel):
    name: str
    breed: Optional[str] = None
    age: Optional[int] = None

class PetResponse(BaseModel):
    id: int
    name: str
    breed: Optional[str]
    age: Optional[int]

    class Config:
        from_attributes = True

# --- FUNCIONES DE AYUDA (Encriptación directa con bcrypt) ---
def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

def hash_password(password: str) -> str:
    pwd_bytes = password.encode('utf-8')
    salt = bcrypt.gensalt()
    hashed = bcrypt.hashpw(pwd_bytes, salt)
    return hashed.decode('utf-8')

def verify_password(plain_password: str, hashed_password: str) -> bool:
    password_bytes = plain_password.encode('utf-8')
    hashed_bytes = hashed_password.encode('utf-8')
    return bcrypt.checkpw(password_bytes, hashed_bytes)

def create_access_token(data: dict) -> str:
    to_encode = data.copy()
    expire = datetime.datetime.utcnow() + datetime.timedelta(hours=24)
    to_encode.update({"exp": expire})
    return jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)

def get_current_user(token: str = Depends(oauth2_scheme), db: Session = Depends(get_db)):
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        email: str = payload.get("sub")
        if email is None:
            raise HTTPException(status_code=401, detail="Token inválido")
    except jwt.PyJWTError:
        raise HTTPException(status_code=401, detail="Token inválido")
    
    user = db.query(UserDB).filter(UserDB.email == email).first()
    if user is None:
        raise HTTPException(status_code=401, detail="Usuario no encontrado")
    return user

# --- APLICACIÓN FASTAPI ---
app = FastAPI(title="Paw-Sense AI Service")

@app.get("/")
def home():
    return {"status": "Servidor de Paw-Sense AI activo"}

# 1. Registro de usuario
@app.post("/auth/register", status_code=status.HTTP_201_CREATED)
def register(user: UserRegister, db: Session = Depends(get_db)):
    db_user = db.query(UserDB).filter(UserDB.email == user.email).first()
    if db_user:
        raise HTTPException(status_code=400, detail="El correo ya está registrado")
    
    new_user = UserDB(
        email=user.email,
        hashed_password=hash_password(user.password)
    )
    db.add(new_user)
    db.commit()
    return {"message": "Usuario registrado exitosamente"}

# 2. Inicio de sesión (Login)
@app.post("/auth/login", response_model=Token)
def login(user: UserLogin, db: Session = Depends(get_db)):
    db_user = db.query(UserDB).filter(UserDB.email == user.email).first()
    if not db_user or not verify_password(user.password, db_user.hashed_password):
        raise HTTPException(status_code=400, detail="Credenciales incorrectas")
    
    access_token = create_access_token(data={"sub": db_user.email})
    return {"access_token": access_token, "token_type": "bearer"}

# 3. Registrar una nueva mascota
@app.post("/pets", response_model=PetResponse, status_code=status.HTTP_201_CREATED)
def create_pet(pet: PetCreate, current_user: UserDB = Depends(current_user), db: Session = Depends(get_db)):
    new_pet = PetDB(
        user_id=current_user.id,
        name=pet.name,
        breed=pet.breed,
        age=pet.age
    )
    db.add(new_pet)
    db.commit()
    db.refresh(new_pet)
    return new_pet

# 4. Obtener la lista de mascotas del usuario logueado
@app.get("/pets", response_model=List[PetResponse])
def get_user_pets(current_user: UserDB = Depends(get_current_user), db: Session = Depends(get_db)):
    pets = db.query(PetDB).filter(PetDB.user_id == current_user.id).all()
    return pets