import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

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
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isAlertActive = false;
  String _statusMessage = "Monitoreando mascota...";
  bool _isLoading = false;

  // Direccion IP de la red Wi-Fi local de tu PC
  final String _apiUrl = "http://192.168.40.74:8000/predict";

  Future<void> _sendTelemetryToAI(double ax, double ay, double az, double gx, double gy, double gz, int bpm) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "ax": ax,
          "ay": ay,
          "az": az,
          "gx": gx,
          "gy": gy,
          "gz": gz,
          "bpm": bpm
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _isAlertActive = data['evacuation_alert'];
          _statusMessage = data['message'];
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
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Paw-Sense AI Dashboard'),
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