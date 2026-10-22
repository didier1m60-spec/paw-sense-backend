import 'package:flutter/material.dart';
import 'api_service.dart';

class PetsScreen extends StatefulWidget {
  const PetsScreen({super.key});

  @override
  State<PetsScreen> createState() => _PetsScreenState();
}

class _PetsScreenState extends State<PetsScreen> {
  final _apiService = ApiService();
  late Future<List<dynamic>> _petsFuture;

  @override
  void initState() {
    super.initState();
    _petsFuture = _apiService.getPets();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Selecciona tu Perro a Monitorear')),
      body: FutureBuilder<List<dynamic>>(
        future: _petsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No hay mascotas registradas.'));
          }

          final pets = snapshot.data!;

          return ListView.builder(
            itemCount: pets.length,
            itemBuilder: (context, index) {
              final pet = pets[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  leading: const Icon(Icons.pets, size: 40, color: Colors.blue),
                  title: Text(pet['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('Raza: ${pet['breed']} | Edad: ${pet['age']} años'),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () {
                    // Acción al seleccionar un perro específico para monitorear
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Monitoreando a ${pet['name']}')),
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