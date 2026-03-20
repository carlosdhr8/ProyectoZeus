import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:image_picker/image_picker.dart';

class MascotasTab extends StatefulWidget {
  final Map userData;
  final List mascotas;

  const MascotasTab({
    super.key,
    required this.userData,
    required this.mascotas,
  });

  @override
  State<MascotasTab> createState() => _MascotasTabState();
}

class _MascotasTabState extends State<MascotasTab> {
  final ImagePicker _picker = ImagePicker();

  bool get _esAdmin => widget.userData['es_admin'] ?? false;
  String get _userEmail => widget.userData['email'] ?? "";

  Future<void> _subirFotoMascota(int petId) async {
    try {
      final XFile? imagen = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 50,
      );

      if (imagen == null) return;

      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Subiendo imagen...")));

      var request = http.MultipartRequest(
        'POST',
        Uri.parse('http://18.223.214.78:8000/upload-pet-photo/$petId'),
      );

      request.files.add(await http.MultipartFile.fromPath('file', imagen.path));

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final bytes = await imagen.readAsBytes();
        String base64Image = base64Encode(bytes);

        setState(() {
          int idx = widget.mascotas.indexWhere((m) => m['id'] == petId);
          if (idx != -1) {
            widget.mascotas[idx]['foto'] = base64Image;
          }
        });

        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("¡Foto actualizada!"),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
      } else {
        throw Exception("Error ${response.statusCode}: ${response.body}");
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error: $e"),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  Future<void> _cambiarPlanUsuario(int petId, String planActual) async {
    String? planSeleccionado = planActual;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Asignar Plan (Modo Admin)"),
        content: DropdownButtonFormField<String>(
          value: ['Sin Plan', 'Basico', 'Intermedio', 'Avanzado'].contains(planSeleccionado)
              ? planSeleccionado
              : 'Sin Plan',
          items: ['Sin Plan', 'Basico', 'Intermedio', 'Avanzado']
              .map((p) => DropdownMenuItem(value: p, child: Text(p)))
              .toList(),
          onChanged: (val) => planSeleccionado = val,
          decoration: const InputDecoration(labelText: "Selecciona el plan"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            onPressed: () async {
              final response = await http.post(
                Uri.parse("http://18.223.214.78:8000/update_plan"),
                headers: {"Content-Type": "application/json"},
                body: jsonEncode({"pet_id": petId, "tipo_plan": planSeleccionado}),
              );
              if (response.statusCode == 200) {
                setState(() {
                  int idx = widget.mascotas.indexWhere((m) => m['id'] == petId);
                  if (idx != -1) {
                    widget.mascotas[idx]['plan_mascota'] = planSeleccionado;
                  }
                });
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Plan $planSeleccionado asignado exitosamente")),
                );
              }
            },
            child: const Text("Confirmar"),
          ),
        ],
      ),
    );
  }

  Future<void> _agregarMascotaDialog() async {
    TextEditingController nombreCtrl = TextEditingController();
    TextEditingController razaCtrl = TextEditingController();
    TextEditingController tamanoCtrl = TextEditingController();
    TextEditingController pesoCtrl = TextEditingController();
    TextEditingController edadCtrl = TextEditingController();
    TextEditingController descCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Registrar Nueva Mascota"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nombreCtrl, decoration: const InputDecoration(labelText: "Nombre")),
              TextField(controller: razaCtrl, decoration: const InputDecoration(labelText: "Raza")),
              TextField(controller: tamanoCtrl, decoration: const InputDecoration(labelText: "Tamaño (Pequeño/Mediano/Grande)")),
              TextField(controller: pesoCtrl, decoration: const InputDecoration(labelText: "Peso (kg)"), keyboardType: TextInputType.number),
              TextField(controller: edadCtrl, decoration: const InputDecoration(labelText: "Edad"), keyboardType: TextInputType.number),
              TextField(controller: descCtrl, decoration: const InputDecoration(labelText: "Breve Descripción"), maxLines: 2),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar")),
          ElevatedButton(
            onPressed: () async {
              if (nombreCtrl.text.isEmpty) return;
              Map<String, dynamic> petData = {
                "nombre": nombreCtrl.text,
                "raza": razaCtrl.text,
                "tamano": tamanoCtrl.text,
                "peso": double.tryParse(pesoCtrl.text) ?? 0.0,
                "descripcion": descCtrl.text,
                "edad": int.tryParse(edadCtrl.text) ?? 0,
                "usuario_email": _userEmail,
              };
              try {
                final response = await http.post(
                  Uri.parse("http://18.223.214.78:8000/add_pet"),
                  headers: {"Content-Type": "application/json"},
                  body: jsonEncode(petData),
                );
                if (response.statusCode == 200) {
                  final responseData = jsonDecode(response.body);
                  int newId = responseData['new_id'];
                  setState(() {
                    widget.mascotas.add({
                      ...petData,
                      "id": newId,
                      "plan_mascota": "Sin Plan",
                      "foto": null,
                      "paseador": null,
                      "dueno": widget.userData['nombre'],
                    });
                  });
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text("¡Mascota registrada con éxito!"),
                      backgroundColor: Theme.of(context).colorScheme.primary,
                    ),
                  );
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
              }
            },
            child: const Text("Guardar"),
          ),
        ],
      ),
    );
  }

  Future<void> _borrarMascota(int petId, String petNombre) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Eliminar Mascota", style: TextStyle(color: Theme.of(context).colorScheme.error)),
        content: Text("¿Estás seguro de que deseas borrar a $petNombre? Esta acción no se puede deshacer."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () async {
              try {
                final response = await http.delete(Uri.parse("http://18.223.214.78:8000/delete_pet/$petId"));
                if (response.statusCode == 200) {
                  setState(() {
                    widget.mascotas.removeWhere((m) => m['id'] == petId);
                  });
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text("Mascota eliminada del sistema"),
                      backgroundColor: Theme.of(context).colorScheme.primary,
                    ),
                  );
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
              }
            },
            child: const Text("Eliminar"),
          ),
        ],
      ),
    );
  }

  Future<void> _editarMascota(Map pet) async {
    TextEditingController nombreCtrl = TextEditingController(text: pet['nombre'] ?? "");
    TextEditingController razaCtrl = TextEditingController(text: pet['raza'] ?? "");
    TextEditingController tamanoCtrl = TextEditingController(text: pet['tamano'] ?? "");
    TextEditingController pesoCtrl = TextEditingController(text: (pet['peso'] ?? 0).toString());
    TextEditingController edadCtrl = TextEditingController(text: (pet['edad'] ?? 0).toString());
    TextEditingController descCtrl = TextEditingController(text: pet['descripcion'] ?? "");

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_esAdmin ? "Admin: Editar Datos" : "Editar mi Mascota"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nombreCtrl, decoration: const InputDecoration(labelText: "Nombre")),
              TextField(controller: razaCtrl, decoration: const InputDecoration(labelText: "Raza")),
              TextField(controller: tamanoCtrl, decoration: const InputDecoration(labelText: "Tamaño")),
              TextField(controller: pesoCtrl, decoration: const InputDecoration(labelText: "Peso (kg)"), keyboardType: TextInputType.number),
              TextField(controller: edadCtrl, decoration: const InputDecoration(labelText: "Edad"), keyboardType: TextInputType.number),
              TextField(controller: descCtrl, decoration: const InputDecoration(labelText: "Descripción"), maxLines: 2),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cerrar")),
          ElevatedButton(
            onPressed: () async {
              Map<String, dynamic> updateData = {
                "id": pet['id'],
                "nombre": nombreCtrl.text,
                "raza": razaCtrl.text,
                "tamano": tamanoCtrl.text,
                "peso": double.tryParse(pesoCtrl.text) ?? 0.0,
                "descripcion": descCtrl.text,
                "edad": int.tryParse(edadCtrl.text) ?? 0,
              };
              try {
                final response = await http.post(
                  Uri.parse("http://18.223.214.78:8000/update_pet"),
                  headers: {"Content-Type": "application/json"},
                  body: jsonEncode(updateData),
                );
                if (response.statusCode == 200) {
                  setState(() {
                    int idx = widget.mascotas.indexWhere((m) => m['id'] == pet['id']);
                    if (idx != -1) widget.mascotas[idx].addAll(updateData);
                  });
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text("Datos actualizados", style: TextStyle(color: Colors.white)),
                      backgroundColor: Theme.of(context).colorScheme.primary,
                    ),
                  );
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
              }
            },
            child: const Text("Guardar"),
          ),
        ],
      ),
    );
  }

  Widget _zeusTag(String titulo, String desc, BuildContext context, {bool isHighlight = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: isHighlight ? Theme.of(context).colorScheme.secondary : Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1E211F), width: 1.5),
        boxShadow: const [BoxShadow(color: Color(0xFF1E211F), offset: Offset(2, 2))],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            titulo.toUpperCase(),
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 0.5),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          Text(
            desc,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: isHighlight ? const Color(0xFF1E211F) : Theme.of(context).colorScheme.primary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (!_esAdmin)
          Padding(
            padding: const EdgeInsets.all(10.0),
            child: ElevatedButton.icon(
              onPressed: _agregarMascotaDialog,
              icon: Icon(Icons.add, color: Theme.of(context).colorScheme.onSecondary),
              label: Text("Agregar Nueva Mascota", style: TextStyle(color: Theme.of(context).colorScheme.onSecondary)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.secondary,
                minimumSize: const Size.fromHeight(50),
                elevation: 4,
              ),
            ),
          ),
        Expanded(
          child: widget.mascotas.isEmpty
              ? const Center(child: Text("No hay mascotas registradas."))
              : ListView.builder(
                  itemCount: widget.mascotas.length,
                  itemBuilder: (context, index) {
                    var pet = widget.mascotas[index];
                    bool hasFoto = pet['foto'] != null && pet['foto'].toString().trim().isNotEmpty;
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFF1E211F), width: 2.5),
                        boxShadow: const [BoxShadow(color: Color(0xFF1E211F), offset: Offset(4, 4))],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: Column(
                          children: [
                            Container(
                              color: Theme.of(context).colorScheme.primary,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                              child: Row(
                                children: [
                                  GestureDetector(
                                    onTap: () => _subirFotoMascota(pet['id']),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(color: Theme.of(context).colorScheme.secondary, width: 3),
                                      ),
                                      child: CircleAvatar(
                                        radius: 35,
                                        backgroundColor: Colors.white24,
                                        backgroundImage: hasFoto ? MemoryImage(base64Decode(pet['foto'])) : null,
                                        child: !hasFoto ? const Icon(Icons.add_a_photo, color: Colors.white70) : null,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(pet['nombre'].toString().toUpperCase(),
                                            style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 1)),
                                        Text("${pet['raza']} • ${pet['edad']} años",
                                            style: TextStyle(color: Theme.of(context).colorScheme.secondary, fontSize: 14, fontWeight: FontWeight.w600)),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    children: [
                                      if (_esAdmin)
                                        IconButton(
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                          icon: const Icon(Icons.delete_forever, color: Colors.white70),
                                          onPressed: () => _borrarMascota(pet['id'], pet['nombre']),
                                        ),
                                      if (_esAdmin) const SizedBox(height: 10),
                                      IconButton(
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        icon: const Icon(Icons.edit_square, color: Colors.white),
                                        onPressed: () => _editarMascota(pet),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(child: _zeusTag("Tamaño", pet['tamano'] ?? "N/A", context)),
                                      const SizedBox(width: 8),
                                      Expanded(child: _zeusTag("Peso", "${pet['peso']} kg", context)),
                                      const SizedBox(width: 8),
                                      Expanded(child: _zeusTag("Plan", pet['plan_mascota'] ?? "Sin Plan", context, isHighlight: true)),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  if (_esAdmin) ...[
                                    Row(
                                      children: [
                                        const Icon(Icons.person, size: 18, color: Colors.grey),
                                        const SizedBox(width: 6),
                                        Text("Dueño: ${pet['dueno']}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                  ],
                                  Text("\"${pet['descripcion'] ?? 'Sin descripción disponible'}\"",
                                      style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.black54)),
                                  if (_esAdmin) ...[
                                    const SizedBox(height: 16),
                                    SizedBox(
                                      width: double.infinity,
                                      child: OutlinedButton(
                                        onPressed: () => _cambiarPlanUsuario(pet['id'], pet['plan_mascota'] ?? "Sin Plan"),
                                        style: OutlinedButton.styleFrom(
                                          side: BorderSide(color: Theme.of(context).colorScheme.primary, width: 2),
                                          foregroundColor: Theme.of(context).colorScheme.primary,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        ),
                                        child: const Text("CAMBIAR PLAN", style: TextStyle(fontWeight: FontWeight.bold)),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
