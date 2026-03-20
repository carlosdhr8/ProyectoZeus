import 'package:flutter/material.dart';
import '../login_page.dart';

class PerfilTab extends StatelessWidget {
  final Map userData;

  const PerfilTab({super.key, required this.userData});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const CircleAvatar(radius: 50, child: Icon(Icons.person, size: 50)),
          const SizedBox(height: 20),
          ListTile(
            leading: const Icon(Icons.badge),
            title: const Text("Nombre"),
            subtitle: Text(userData['nombre'] ?? "N/A"),
          ),
          ListTile(
            leading: const Icon(Icons.email),
            title: const Text("Email"),
            subtitle: Text(userData['email'] ?? "N/A"),
          ),
          ListTile(
            leading: const Icon(Icons.cake),
            title: const Text("Edad"),
            subtitle: Text(userData['edad']?.toString() ?? "N/A"),
          ),
          ListTile(
            leading: const Icon(Icons.location_on),
            title: const Text("Lugar de Residencia"),
            subtitle: Text(userData['residencia'] ?? "N/A"),
          ),
          const Spacer(),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
              side: BorderSide(color: Theme.of(context).colorScheme.error, width: 1.5),
              minimumSize: const Size.fromHeight(50),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => const LoginPage()),
              (route) => false,
            ),
            icon: const Icon(Icons.logout),
            label: const Text("Cerrar Sesión"),
          ),
        ],
      ),
    );
  }
}
