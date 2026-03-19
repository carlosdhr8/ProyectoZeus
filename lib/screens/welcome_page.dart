import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'login_page.dart';

class WelcomePage extends StatefulWidget {
  final Map userData;
  final List mascotas;

  const WelcomePage({
    super.key,
    required this.userData,
    required this.mascotas,
  });

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  late List _listaMascotas;
  late String _planActual;
  final ImagePicker _picker = ImagePicker();

  bool get _esAdmin => widget.userData['es_admin'] ?? false;
  String get _userEmail => widget.userData['email'] ?? "";

  @override
  void initState() {
    super.initState();
    _listaMascotas = List.from(widget.mascotas);
    _planActual = widget.userData['tipo_plan'] ?? "Sin Plan";
  }

  // --- FUNCIÓN DE SUBIR FOTO (CORREGIDA) ---
  Future<void> _subirFotoMascota(int petId) async {
    try {
      final XFile? imagen = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 50,
      );

      if (imagen == null) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Subiendo imagen...")));

      var request = http.MultipartRequest(
        'POST',
        Uri.parse('http://18.223.214.78:8000/upload-pet-photo/$petId'),
      );

      request.files.add(await http.MultipartFile.fromPath('file', imagen.path));

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        // CORRECCIÓN: Convertir la imagen seleccionada a base64 para mostrarla de inmediato
        final bytes = await imagen.readAsBytes();
        String base64Image = base64Encode(bytes);

        setState(() {
          int idx = _listaMascotas.indexWhere((m) => m['id'] == petId);
          if (idx != -1) {
            _listaMascotas[idx]['foto'] = base64Image;
          }
        });

        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("¡Foto actualizada!"),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        throw Exception("Error ${response.statusCode}: ${response.body}");
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
      );
    }
  }

  // --- FUNCIÓN DE CAMBIAR PLAN ---
  Future<void> _cambiarPlanUsuario(int petId, String planActual) async {
    String? planSeleccionado = planActual;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Asignar Plan (Modo Admin)"),
        content: DropdownButtonFormField<String>(
          value:
              [
                'Sin Plan',
                'Basico',
                'Intermedio',
                'Avanzado',
              ].contains(planSeleccionado)
              ? planSeleccionado
              : 'Sin Plan',
          items: [
            'Sin Plan',
            'Basico',
            'Intermedio',
            'Avanzado',
          ].map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
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
                body: jsonEncode({
                  "pet_id": petId,
                  "tipo_plan": planSeleccionado,
                }),
              );
              if (response.statusCode == 200) {
                setState(() {
                  int idx = _listaMascotas.indexWhere((m) => m['id'] == petId);
                  if (idx != -1) {
                    _listaMascotas[idx]['plan_mascota'] = planSeleccionado;
                  }
                });
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      "Plan $planSeleccionado asignado exitosamente",
                    ),
                  ),
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
              TextField(
                controller: nombreCtrl,
                decoration: const InputDecoration(labelText: "Nombre"),
              ),
              TextField(
                controller: razaCtrl,
                decoration: const InputDecoration(labelText: "Raza"),
              ),
              TextField(
                controller: tamanoCtrl,
                decoration: const InputDecoration(
                  labelText: "Tamaño (Pequeño/Mediano/Grande)",
                ),
              ),
              TextField(
                controller: pesoCtrl,
                decoration: const InputDecoration(labelText: "Peso (kg)"),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: edadCtrl,
                decoration: const InputDecoration(labelText: "Edad"),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: descCtrl,
                decoration: const InputDecoration(
                  labelText: "Breve Descripción",
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nombreCtrl.text.isEmpty) return; // Validación simple

              Map<String, dynamic> petData = {
                "nombre": nombreCtrl.text,
                "raza": razaCtrl.text,
                "tamano": tamanoCtrl.text,
                "peso": double.tryParse(pesoCtrl.text) ?? 0.0,
                "descripcion": descCtrl.text,
                "edad": int.tryParse(edadCtrl.text) ?? 0,
                "usuario_email":
                    _userEmail, // Enviamos el correo del dueño logueado
              };

              try {
                final response = await http.post(
                  Uri.parse("http://18.223.214.78:8000/add_pet"),
                  headers: {"Content-Type": "application/json"},
                  body: jsonEncode(petData),
                );

                if (response.statusCode == 200) {
                  final responseData = jsonDecode(response.body);
                  int newId =
                      responseData['new_id']; // Recibimos el ID desde SQL

                  setState(() {
                    _listaMascotas.add({
                      ...petData,
                      "id": newId,
                      "plan_mascota": "Sin Plan",
                      "foto": null,
                      "paseador": null,
                      "dueno": widget.userData['nombre'], // Para la UI
                    });
                  });

                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("¡Mascota registrada con éxito!"),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text("Error: $e")));
              }
            },
            child: const Text("Guardar"),
          ),
        ],
      ),
    );
  }

  // --- NUEVO: FUNCIÓN ELIMINAR MASCOTA (Solo Admin) ---
  Future<void> _borrarMascota(int petId, String petNombre) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          "Eliminar Mascota",
          style: TextStyle(color: Colors.red),
        ),
        content: Text(
          "¿Estás seguro de que deseas borrar a $petNombre? Esta acción no se puede deshacer.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              try {
                final response = await http.delete(
                  Uri.parse("http://18.223.214.78:8000/delete_pet/$petId"),
                );

                if (response.statusCode == 200) {
                  setState(() {
                    _listaMascotas.removeWhere((m) => m['id'] == petId);
                  });
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Mascota eliminada del sistema"),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                }
              } catch (e) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text("Error: $e")));
              }
            },
            child: const Text("Eliminar"),
          ),
        ],
      ),
    );
  }

  // --- FUNCIÓN DE EDITAR MASCOTA ---
  Future<void> _editarMascota(Map pet) async {
    TextEditingController nombreCtrl = TextEditingController(
      text: pet['nombre'] ?? "",
    );
    TextEditingController razaCtrl = TextEditingController(
      text: pet['raza'] ?? "",
    );
    TextEditingController tamanoCtrl = TextEditingController(
      text: pet['tamano'] ?? "",
    );
    TextEditingController pesoCtrl = TextEditingController(
      text: (pet['peso'] ?? 0).toString(),
    );
    TextEditingController edadCtrl = TextEditingController(
      text: (pet['edad'] ?? 0).toString(),
    );
    TextEditingController descCtrl = TextEditingController(
      text: pet['descripcion'] ?? "",
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_esAdmin ? "Admin: Editar Datos" : "Editar mi Mascota"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nombreCtrl,
                decoration: const InputDecoration(labelText: "Nombre"),
              ),
              TextField(
                controller: razaCtrl,
                decoration: const InputDecoration(labelText: "Raza"),
              ),
              TextField(
                controller: tamanoCtrl,
                decoration: const InputDecoration(labelText: "Tamaño"),
              ),
              TextField(
                controller: pesoCtrl,
                decoration: const InputDecoration(labelText: "Peso (kg)"),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: edadCtrl,
                decoration: const InputDecoration(labelText: "Edad"),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: descCtrl,
                decoration: const InputDecoration(labelText: "Descripción"),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cerrar"),
          ),
          ElevatedButton(
            onPressed: () async {
              Map<String, dynamic> updateData = {
                "id": pet['id'],
                "nombre": nombreCtrl.text,
                "raza": razaCtrl.text,
                "tamano": tamanoCtrl.text,
                "peso":
                    double.tryParse(pesoCtrl.text) ??
                    0.0, // Coincide con UpdatePetRequest
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
                    int idx = _listaMascotas.indexWhere(
                      (m) => m['id'] == pet['id'],
                    );
                    if (idx != -1) {
                      _listaMascotas[idx].addAll(updateData);
                    }
                  });
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        "Datos actualizados",
                        style: TextStyle(color: Colors.white),
                      ),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text("Error: $e")));
              }
            },
            child: const Text("Guardar"),
          ),
        ],
      ),
    );
  }

  // --- FUNCIÓN ASIGNAR PASEADOR (CORREGIDA) ---
  Future<void> _asignarPaseadorDialog(int petId) async {
    try {
      // 1. Obtener la lista de paseadores
      final response = await http.get(
        Uri.parse("http://18.223.214.78:8000/get_all_walkers"),
      );

      if (response.statusCode == 200) {
        List paseadores = jsonDecode(response.body);
        int? selectedPaseadorId;

        if (!mounted) return;

        await showDialog(
          context: context,
          builder: (context) {
            return StatefulBuilder(
              builder: (context, setStateDialog) {
                return AlertDialog(
                  title: const Text("Asignar Paseador"),
                  content: DropdownButtonFormField<int>(
                    value: selectedPaseadorId,
                    hint: const Text("Seleccione un paseador"),
                    isExpanded: true,
                    items: paseadores.map((p) {
                      return DropdownMenuItem<int>(
                        value: int.parse(p['id'].toString()),
                        child: Text(p['nombre'].toString()),
                      );
                    }).toList(),
                    onChanged: (val) =>
                        setStateDialog(() => selectedPaseadorId = val),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("Cancelar"),
                    ),
                    ElevatedButton(
                      onPressed: selectedPaseadorId == null
                          ? null
                          : () async {
                              try {
                                // Enviamos la petición al endpoint
                                final assignRes = await http.post(
                                  Uri.parse(
                                    "http://18.223.214.78:8000/assign_walker",
                                  ), // Asegúrate que la IP sea correcta
                                  headers: {"Content-Type": "application/json"},
                                  body: jsonEncode({
                                    "pet_id": petId,
                                    "paseador_id": selectedPaseadorId,
                                  }),
                                );

                                if (assignRes.statusCode == 200) {
                                  // Buscamos los datos del paseador seleccionado para actualizar la UI localmente
                                  var pSelected = paseadores.firstWhere(
                                    (p) =>
                                        p['id'].toString() ==
                                        selectedPaseadorId.toString(),
                                  );

                                  setState(() {
                                    int idx = _listaMascotas.indexWhere(
                                      (m) => m['id'] == petId,
                                    );
                                    if (idx != -1) {
                                      _listaMascotas[idx]['paseador'] = {
                                        "id": pSelected['id'],
                                        "nombre": pSelected['nombre'],
                                        "experiencia":
                                            pSelected['experiencia'] ?? "",
                                        "biografia":
                                            pSelected['biografia'] ?? "",
                                      };
                                    }
                                  });

                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        "¡Paseador asignado con éxito!",
                                      ),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                } else {
                                  // Aquí verás el error detallado si el backend falla
                                  var errorData = jsonDecode(assignRes.body);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        "Error: ${errorData['detail']}",
                                      ),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              } catch (e) {
                                print("Error en POST: $e");
                              }
                            },
                      child: const Text("Guardar"),
                    ),
                  ],
                );
              },
            );
          },
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error de conexión: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text("Bienvenido, ${widget.userData['nombre']}"),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.pets), text: "Mascotas"),
              Tab(icon: Icon(Icons.directions_walk), text: "Paseador"),
              Tab(icon: Icon(Icons.person), text: "Perfil"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildMascotasTab(),
            _buildPaseadoresTab(),
            _buildPerfilTab(context),
          ],
        ),
      ),
    );
  }

  Widget _buildMascotasTab() {
    return Column(
      children: [
        // BOTÓN AGREGAR (Visible solo si NO es admin)
        if (!_esAdmin)
          Padding(
            padding: const EdgeInsets.all(10.0),
            child: ElevatedButton.icon(
              onPressed: _agregarMascotaDialog,
              icon: const Icon(Icons.add),
              label: const Text("Agregar Nueva Mascota"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[700],
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(45),
              ),
            ),
          ),

        // LISTA DE MASCOTAS
        Expanded(
          child: _listaMascotas.isEmpty
              ? const Center(child: Text("No hay mascotas registradas."))
              : ListView.builder(
                  itemCount: _listaMascotas.length,
                  itemBuilder: (context, index) {
                    var pet = _listaMascotas[index];
                    bool hasFoto =
                        pet['foto'] != null &&
                        pet['foto'].toString().trim().isNotEmpty;

                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          children: [
                            ListTile(
                              leading: GestureDetector(
                                onTap: () => _subirFotoMascota(pet['id']),
                                child: CircleAvatar(
                                  radius: 30,
                                  backgroundColor: Colors.grey.shade300,
                                  backgroundImage: hasFoto
                                      ? MemoryImage(base64Decode(pet['foto']))
                                      : null,
                                  child: !hasFoto
                                      ? const Icon(
                                          Icons.camera_alt,
                                          color: Colors.white,
                                        )
                                      : null,
                                ),
                              ),
                              title: Text(
                                pet['nombre'],
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Text(
                                "${pet['raza']} - ${pet['edad']} años\nDueño: ${pet['dueno']}",
                              ),

                              // BOTONES DE ACCIÓN (Editar y Borrar)
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Botón Borrar (Visible solo si ES admin)
                                  if (_esAdmin)
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete,
                                        color: Colors.red,
                                      ),
                                      onPressed: () => _borrarMascota(
                                        pet['id'],
                                        pet['nombre'],
                                      ),
                                    ),
                                  // Botón Editar (Visible para todos)
                                  IconButton(
                                    icon: const Icon(
                                      Icons.edit,
                                      color: Colors.blue,
                                    ),
                                    onPressed: () => _editarMascota(pet),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                _infoCard("Tamaño", pet['tamano'] ?? "N/A"),
                                _infoCard("Peso", "${pet['peso']} kg"),
                                _infoCard(
                                  "Plan",
                                  pet['plan_mascota'] ?? "Sin Plan",
                                ),
                              ],
                            ),
                            Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                "Descripción: ${pet['descripcion'] ?? ''}",
                              ),
                            ),
                            if (_esAdmin)
                              Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: ElevatedButton(
                                  onPressed: () => _cambiarPlanUsuario(
                                    pet['id'],
                                    pet['plan_mascota'] ?? "Sin Plan",
                                  ),
                                  child: const Text("Cambiar Plan"),
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

  Widget _buildPaseadoresTab() {
    if (_listaMascotas.isEmpty) {
      return const Center(child: Text("No hay mascotas registradas."));
    }
    return ListView.builder(
      itemCount: _listaMascotas.length,
      itemBuilder: (context, index) {
        var pet = _listaMascotas[index];
        var paseador = pet['paseador'];

        return Card(
          margin: const EdgeInsets.all(10),
          elevation: 3,
          child: Padding(
            padding: const EdgeInsets.all(15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Mascota: ${pet['nombre']}",
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Divider(),
                if (paseador != null) ...[
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const CircleAvatar(child: Icon(Icons.person)),
                    title: Text(
                      "Paseador: ${paseador['nombre']}",
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Experiencia: ${paseador['experiencia'] ?? 'N/A'}",
                        ),
                        Text("Biografía: ${paseador['biografia'] ?? 'N/A'}"),
                      ],
                    ),
                  ),
                ] else ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    child: Text(
                      "Paseador aun no asignado",
                      style: TextStyle(
                        color: Colors.red,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
                if (_esAdmin) ...[
                  const SizedBox(height: 10),
                  Center(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.assignment_ind),
                      label: const Text("Asignar/Cambiar Paseador"),
                      onPressed: () => _asignarPaseadorDialog(pet['id']),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _infoCard(String titulo, String desc) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            Text(
              titulo,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
            const SizedBox(height: 4),
            Text(desc, style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildPerfilTab(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const CircleAvatar(radius: 50, child: Icon(Icons.person, size: 50)),
          const SizedBox(height: 20),
          ListTile(
            leading: const Icon(Icons.badge),
            title: const Text("Nombre"),
            subtitle: Text(widget.userData['nombre'] ?? "N/A"),
          ),
          ListTile(
            leading: const Icon(Icons.email),
            title: const Text("Email"),
            subtitle: Text(widget.userData['email'] ?? "N/A"),
          ),
          const Spacer(),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(50),
            ),
            onPressed: () => Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => const LoginPage()),
              (route) => false,
            ),
            icon: const Icon(Icons.logout),
            label: const Text("Cerrar Sesió"),
          ),
        ],
      ),
    );
  }
}
