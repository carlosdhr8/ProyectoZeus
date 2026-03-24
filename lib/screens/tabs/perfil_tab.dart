import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import '../login_page.dart';

class PerfilTab extends StatefulWidget {
  final Map userData;

  const PerfilTab({super.key, required this.userData});

  @override
  State<PerfilTab> createState() => _PerfilTabState();
}

class _PerfilTabState extends State<PerfilTab> {
  final ImagePicker _picker = ImagePicker();

  Future<void> _subirFotoUsuario() async {
    ImageSource? sourceSeleccionado;
    
    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (BuildContext ctx) {
        return SafeArea(
          child: Wrap(
            children: [
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text("Seleccionar foto de perfil", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Galería de Fotos'),
                onTap: () { sourceSeleccionado = ImageSource.gallery; Navigator.pop(ctx); },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Tomar Foto (Cámara)'),
                onTap: () { sourceSeleccionado = ImageSource.camera; Navigator.pop(ctx); },
              ),
            ],
          ),
        );
      },
    );

    if (sourceSeleccionado == null) return;

    try {
      final XFile? imagen = await _picker.pickImage(
        source: sourceSeleccionado!,
        imageQuality: 60,
      );

      if (imagen == null) return;

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Subiendo imagen de perfil...")));

      String userEmail = widget.userData['email'];

      var request = http.MultipartRequest(
        'POST',
        Uri.parse('http://18.223.214.78:8000/upload-user-photo/$userEmail'),
      );

      request.files.add(await http.MultipartFile.fromPath('file', imagen.path));

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (!mounted) return;
      
      if (response.statusCode == 200) {
        final bytes = await imagen.readAsBytes();
        String base64Image = base64Encode(bytes);

        setState(() {
          widget.userData['foto'] = base64Image;
        });

        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("¡Foto de perfil actualizada!"),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
      } else {
        throw Exception("Error ${response.statusCode}: ${response.body}");
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error: $e"),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  Future<void> _editarInfoPaseador(BuildContext context) async {
    final expController = TextEditingController(text: widget.userData['walker_info']?['experiencia'] ?? "");
    final bioController = TextEditingController(text: widget.userData['walker_info']?['biografia'] ?? "");

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Editar Información de Paseador"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: expController,
                decoration: const InputDecoration(labelText: "Experiencia (ej: 3 años)"),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: bioController,
                maxLines: 4,
                decoration: const InputDecoration(labelText: "Biografía"),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar")),
          ElevatedButton(
            onPressed: () async {
              try {
                final res = await http.post(
                  Uri.parse("http://18.223.214.78:8000/update_walker_info"),
                  headers: {"Content-Type": "application/json"},
                  body: jsonEncode({
                    "usuario_id": widget.userData['id'],
                    "experiencia": expController.text,
                    "biografia": bioController.text,
                  }),
                );
                if (res.statusCode == 200) {
                  setState(() {
                    widget.userData['walker_info']['experiencia'] = expController.text;
                    widget.userData['walker_info']['biografia'] = bioController.text;
                  });
                  if (context.mounted) Navigator.pop(context);
                }
              } catch (e) {
                debugPrint("Error updating walker info: $e");
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
    var userData = widget.userData;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
          GestureDetector(
            onTap: _subirFotoUsuario,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 4))
                ],
                border: Border.all(color: Theme.of(context).colorScheme.primary, width: 3),
              ),
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  CircleAvatar(
                    radius: 65,
                    backgroundColor: Colors.white,
                    backgroundImage: (userData['foto'] != null && userData['foto'].toString().trim().isNotEmpty)
                        ? MemoryImage(base64Decode(userData['foto']))
                        : null,
                    child: (userData['foto'] == null || userData['foto'].toString().trim().isEmpty)
                        ? Icon(Icons.person, color: Theme.of(context).colorScheme.primary, size: 60)
                        : null,
                  ),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.secondary,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                  ),
                ],
              ),
            ),
          ),
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
          if (userData['es_paseador'] == true) ...[
            const Divider(),
            ListTile(
              leading: const Icon(Icons.history_edu),
              title: const Text("Experiencia"),
              subtitle: Text(userData['walker_info']?['experiencia'] ?? "Sin experiencia cargada"),
              trailing: IconButton(
                icon: const Icon(Icons.edit, size: 20),
                onPressed: () => _editarInfoPaseador(context),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.description),
              title: const Text("Mi Biografía"),
              subtitle: Text(
                userData['walker_info']?['biografia'] ?? "Sin biografía",
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: IconButton(
                icon: const Icon(Icons.edit, size: 20),
                onPressed: () => _editarInfoPaseador(context),
              ),
            ),
          ],
            const SizedBox(height: 30),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
                side: BorderSide(
                  color: Theme.of(context).colorScheme.error,
                  width: 1.5,
                ),
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
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
      ),
    );
  }
}
