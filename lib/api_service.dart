import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiService {
  // URL base de tu backend desplegado en Render
  static const String baseUrl = 'https://paw-sense-backend.onrender.com';
  
  // Instancia para guardar el token de forma segura
  final _storage = const FlutterSecureStorage();

  // 1. Método de Iniciar Sesión (Login)
  Future<bool> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final token = data['access_token'];
        
        // Guardamos el token JWT de forma segura en el celular
        await _storage.write(key: 'jwt_token', value: token);
        return true;
      }
      return false;
    } catch (e) {
      print('Error en login: $e');
      return false;
    }
  }

  // 2. Método para Obtener las Mascotas del Usuario
  Future<List<dynamic>> getPets() async {
    try {
      // Recuperamos el token guardado
      final token = await _storage.read(key: 'jwt_token');

      final response = await http.get(
        Uri.parse('$baseUrl/pets'),
        headers: {
          'accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return [];
    } catch (e) {
      print('Error al obtener mascotas: $e');
      return [];
    }
  }

  // 3. Método para Cerrar Sesión
  Future<void> logout() async {
    await _storage.delete(key: 'jwt_token');
  }
}