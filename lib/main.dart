import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

void main() {
  runApp(const PawSenseApp());
}

class PawSenseApp extends StatelessWidget {
  const PawSenseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Paw-Sense AI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.deepOrange,
        useMaterial3: true,
      ),
      home: const LoginScreen(),
    );
  }
}

// ==========================================
// 1. PANTALLA DE INICIO DE SESIÓN (LOGIN)
// ==========================================
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _storage = const FlutterSecureStorage();
  bool _isLoading = false;

  final String _loginUrl = "https://paw-sense-backend.onrender.com/auth/login";

  Future<void> _login() async {
    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse(_loginUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "email": _emailController.text.trim(),
          "password": _passwordController.text.trim(),
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final token = data['access_token'];

        // Guardamos el token JWT de forma segura
        await _storage.write(key: 'jwt_token', value: token);

        if (!mounted) return;
        // Navegamos al selector de perros
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const PetsScreen()),
        );
      } else {
        _showError("Correo o contraseña incorrectos.");
      }
    } catch (e) {
      _showError("Error de conexión con el servidor.");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Paw-Sense AI - Login'), centerTitle: true),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.pets, size: 80, color: Colors.deepOrange),
            const SizedBox(height: 20),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'Correo electrónico', border: OutlineInputBorder()),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 15),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(labelText: 'Contraseña', border: OutlineInputBorder()),
              obscureText: true,
            ),
            const SizedBox(height: 25),
            _isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: _login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepOrange,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(50),
                    ),
                    child: const Text('Iniciar Sesión', style: TextStyle(fontSize: 18)),
                  ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 2. PANTALLA DE SELECCIÓN DE MASCOTAS
// ==========================================
class PetsScreen extends StatefulWidget {
  const PetsScreen({super.key});

  @override
  State<PetsScreen> createState() => _PetsScreenState();
}

class _PetsScreenState extends State<PetsScreen> {
  final _storage = const FlutterSecureStorage();
  final String _petsUrl = "https://paw-sense-backend.onrender.com/pets";
  late Future<List<dynamic>> _petsFuture;

  @override
  void initState() {
    super.initState();
    _petsFuture = _fetchPets();
  }

  Future<List<dynamic>> _fetchPets() async {
    try {
      final token = await _storage.read(key: 'jwt_token');
      final response = await http.get(
        Uri.parse(_petsUrl),
        headers: {
          "Accept": "application/json",
          "Authorization": "Bearer $token",
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Selecciona tu Perro'), centerTitle: true),
      body: FutureBuilder<List<dynamic>>(
        future: _petsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No hay mascotas registradas o error al cargar.'));
          }

          final pets = snapshot.data!;

          return ListView.builder(
            itemCount: pets.length,
            itemBuilder: (context, index) {
              final pet = pets[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  leading: const Icon(Icons.pets, size: 40, color: Colors.deepOrange),
                  title: Text(pet['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('Raza: ${pet['breed']} | Edad: ${pet['age']} años'),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => HomeScreen(selectedPetName: pet['name']),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// ==========================================
// 3. PANTALLA DE MONITOREO Y TELEMETRÍA
// ==========================================
class HomeScreen extends StatefulWidget {
  final String selectedPetName;
  const HomeScreen({super.key, required this.selectedPetName});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isAlertActive = false;
  late String _statusMessage;
  bool _isLoading = false;
  final _storage = const FlutterSecureStorage();

  // URL del endpoint de predicción en Render
  final String _predictUrl = "https://paw-sense-backend.onrender.com/predict";

  @override
  void initState() {
    super.initState();
    _statusMessage = "Monitoreando a ${widget.selectedPetName}...";
  }

  Future<void> _sendTelemetryToAI(double ax, double ay, double az, double gx, double gy, double gz, int bpm) async {
    setState(() => _isLoading = true);

    try {
      final token = await _storage.read(key: 'jwt_token');
      
      final response = await http.post(
        Uri.parse(_predictUrl),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: jsonEncode({
          "pet_name": widget.selectedPetName,
          "ax": ax, "ay": ay, "az": az,
          "gx": gx, "gy": gy, "gz": gz,
          "bpm": bpm
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _isAlertActive = data['evacuation_alert'] ?? false;
          _statusMessage = data['message'] ?? "Respuesta recibida exitosamente";
        });
      } else {
        setState(() {
          _statusMessage = "Error en respuesta del servidor (${response.statusCode})";
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = "Error de conexión con el servidor IA.";
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Monitoreo: ${widget.selectedPetName}'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(
              _isAlertActive ? Icons.warning_amber_rounded : Icons.pets,
              size: 110,
              color: _isAlertActive ? Colors.red : Colors.green,
            ),
            const SizedBox(height: 25),
            Text(
              _statusMessage,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: _isAlertActive ? Colors.red : Colors.black87,
              ),
            ),
            const SizedBox(height: 40),
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else ...[
              ElevatedButton.icon(
                onPressed: () => _sendTelemetryToAI(6.0, 1.0, 1.0, 0.2, 0.1, 2.0, 85),
                icon: const Icon(Icons.warning),
                label: const Text('Simular Patrón de Evacuación'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepOrange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                ),
              ),
              const SizedBox(height: 15),
              OutlinedButton.icon(
                onPressed: () => _sendTelemetryToAI(1.0, 1.0, 1.0, 0.1, 0.1, 0.1, 80),
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('Simular Estado Normal'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}