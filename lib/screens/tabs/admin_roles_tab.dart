import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class AdminRolesTab extends StatefulWidget {
  final Map userData;

  const AdminRolesTab({super.key, required this.userData});

  @override
  State<AdminRolesTab> createState() => _AdminRolesTabState();
}

class _AdminRolesTabState extends State<AdminRolesTab> {
  List<dynamic> _usuarios = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  Future<void> _fetchUsers() async {
    setState(() => _isLoading = true);
    try {
      final res = await http.get(Uri.parse("http://18.223.214.78:8000/get_all_users"));
      if (!mounted) return;
      if (res.statusCode == 200) {
        setState(() {
          _usuarios = jsonDecode(res.body);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching users: $e");
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateRole(int userId, String nuevoRol) async {
    try {
      final res = await http.post(
        Uri.parse("http://18.223.214.78:8000/update_user_role"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"user_id": userId, "nuevo_rol": nuevoRol}),
      );

      if (!mounted) return;
      if (res.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Rol actualizado a $nuevoRol")),
        );
        _fetchUsers(); // Recargamos para ver cambios
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error actualizando rol: $e")),
      );
    }
  }

  Future<void> _reseteoPasswordDialog(BuildContext context, dynamic user) async {
    final passwordController = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Restablecer Password: ${user['nombre']}"),
        content: TextField(
          controller: passwordController,
          decoration: const InputDecoration(labelText: "Nueva Contraseña"),
          obscureText: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar")),
          ElevatedButton(
            onPressed: () async {
              if (passwordController.text.isEmpty) return;
              try {
                final res = await http.post(
                  Uri.parse("http://18.223.214.78:8000/reset_password"),
                  headers: {"Content-Type": "application/json"},
                  body: jsonEncode({
                    "user_id": user['id'],
                    "new_password": passwordController.text,
                    "admin_id": widget.userData['id'],
                  }),
                );
                if (!mounted) return;
                if (res.statusCode == 200) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Contraseña actualizada")));
                  Navigator.pop(ctx);
                }
              } catch (e) {
                debugPrint("Error resetting password: $e");
              }
            },
            child: const Text("Asignar"),
          ),
        ],
      ),
    );
  }

  Future<void> _editarInfoPaseador(BuildContext context, dynamic user) async {
    final expController = TextEditingController(text: user['walker_info']?['experiencia'] ?? "");
    final bioController = TextEditingController(text: user['walker_info']?['biografia'] ?? "");

    await showDialog(
      context: context,
      builder: (contextDialog) => AlertDialog(
        title: Text("Editar Info: ${user['nombre']}"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: expController,
              decoration: const InputDecoration(labelText: "Experiencia"),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: bioController,
              maxLines: 3,
              decoration: const InputDecoration(labelText: "Biografía"),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(contextDialog), child: const Text("Cancelar")),
          ElevatedButton(
            onPressed: () async {
              try {
                final res = await http.post(
                  Uri.parse("http://18.223.214.78:8000/update_walker_info"),
                  headers: {"Content-Type": "application/json"},
                  body: jsonEncode({
                    "usuario_id": user['id'],
                    "experiencia": expController.text,
                    "biografia": bioController.text,
                  }),
                );
                if (!mounted) return;
                if (res.statusCode == 200) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Info actualizada")));
                  Navigator.pop(contextDialog);
                  _fetchUsers();
                }
              } catch (e) {
                debugPrint("Error: $e");
              }
            },
            child: const Text("Guardar"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _fetchUsers,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _usuarios.length,
        itemBuilder: (context, index) {
          final user = _usuarios[index];
          String rol = user['rol'] ?? 'usuario';


          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: const Color(0xFF1E211F), width: 2),
              boxShadow: const [
                BoxShadow(color: Color(0xFF1E211F), offset: Offset(4, 4))
              ],
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              leading: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Theme.of(context).colorScheme.primary, width: 2),
                ),
                child: CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.grey[200],
                  backgroundImage: user['has_foto'] == true 
                    ? NetworkImage("http://18.223.214.78:8000/user_photo/${user['id']}") 
                    : null,
                  child: user['has_foto'] != true ? const Icon(Icons.person, color: Colors.grey) : null,
                ),
              ),
              title: Text(
                user['nombre'].toString().toUpperCase(),
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(user['email'], style: const TextStyle(fontSize: 12)),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: _getRoleColor(rol).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _getRoleColor(rol)),
                    ),
                    child: Text(
                      rol.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: _getRoleColor(rol),
                      ),
                    ),
                  ),
                ],
              ),
              trailing: PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                onSelected: (value) {
                  if (value == 'edit_info') {
                    _editarInfoPaseador(context, user);
                  } else if (value == 'reset_pw') {
                    _reseteoPasswordDialog(context, user);
                  } else {
                    _updateRole(user['id'], value);
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'admin', child: Text("Hacer Admin")),
                  const PopupMenuItem(value: 'paseador', child: Text("Hacer Paseador")),
                  const PopupMenuItem(value: 'usuario', child: Text("Hacer Usuario Normal")),
                  const PopupMenuDivider(),
                  const PopupMenuItem(value: 'reset_pw', child: Row(
                    children: [
                      Icon(Icons.lock_reset, size: 18),
                      SizedBox(width: 8),
                      Text("Restablecer Password"),
                    ],
                  )),
                  if (user['rol'] == 'paseador') ...[
                    const PopupMenuDivider(),
                    const PopupMenuItem(value: 'edit_info', child: Row(
                      children: [
                        Icon(Icons.edit, size: 18),
                        SizedBox(width: 8),
                        Text("Editar Info de Paseador"),
                      ],
                    )),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Color _getRoleColor(String rol) {
    switch (rol.toLowerCase()) {
      case 'admin':
        return Colors.redAccent;
      case 'paseador':
        return Colors.blueAccent;
      default:
        return Colors.green;
    }
  }
}
