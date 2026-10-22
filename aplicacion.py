from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

app = FastAPI(title="Paw-Sense AI Service")

# Habilitar CORS para que el navegador permita la conexión
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

class TelemetryData(BaseModel):
    ax: float
    ay: float
    az: float
    gx: float
    gy: float
    gz: float
    bpm: int

@app.get("/")
def home():
    return {"status": "Servidor de Paw-Sense AI activo"}

@app.post("/predict")
async def predict_behavior(data: TelemetryData):
    needs_to_evacuate = data.ax > 5.0 and data.gz > 1.5
    
    return {
        "evacuation_alert": needs_to_evacuate,
        "confidence": 0.92 if needs_to_evacuate else 0.10,
        "message": "¡Atención! Tu mascota necesita ir al baño ahora." if needs_to_evacuate else "Comportamiento normal detectado."
    }

@app.post("/chatbot")
async def chatbot_advice(query: str):
    return {
        "response": "Recuerda premiar a tu mascota inmediatamente después de evacuar en el lugar correcto."
    }
