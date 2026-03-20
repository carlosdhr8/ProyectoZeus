import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class PaseadoresTab extends StatefulWidget {
  final Map userData;
  final List mascotas;

  const PaseadoresTab({
    super.key,
    required this.userData,
    required this.mascotas,
  });

  @override
  State<PaseadoresTab> createState() => _PaseadoresTabState();
}

class _PaseadoresTabState extends State<PaseadoresTab> {
  bool get _esAdmin => widget.userData['es_admin'] ?? false;

  Future<void> _asignarPaseadorDialog(int petId) async {
    try {
      final response = await http.get(Uri.parse("http://18.223.214.78:8000/get_all_walkers"));
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
                    onChanged: (val) => setStateDialog(() => selectedPaseadorId = val),
                  ),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar")),
                    ElevatedButton(
                      onPressed: selectedPaseadorId == null
                          ? null
                          : () async {
                              try {
                                final assignRes = await http.post(
                                  Uri.parse("http://18.223.214.78:8000/assign_walker"),
                                  headers: {"Content-Type": "application/json"},
                                  body: jsonEncode({"pet_id": petId, "paseador_id": selectedPaseadorId}),
                                );

                                if (assignRes.statusCode == 200) {
                                  var pSelected = paseadores.firstWhere((p) => p['id'].toString() == selectedPaseadorId.toString());
                                  setState(() {
                                    int idx = widget.mascotas.indexWhere((m) => m['id'] == petId);
                                    if (idx != -1) {
                                      widget.mascotas[idx]['paseador'] = {
                                        "id": pSelected['id'],
                                        "nombre": pSelected['nombre'],
                                        "experiencia": pSelected['experiencia'] ?? "",
                                        "biografia": pSelected['biografia'] ?? "",
                                      };
                                    }
                                  });
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: const Text("¡Paseador asignado con éxito!"),
                                      backgroundColor: Theme.of(context).colorScheme.primary,
                                    ),
                                  );
                                } else {
                                  var errorData = jsonDecode(assignRes.body);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text("Error: ${errorData['detail']}"), backgroundColor: Theme.of(context).colorScheme.error),
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error de conexión: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.mascotas.isEmpty) {
      return const Center(child: Text("No hay mascotas registradas."));
    }
    return ListView.builder(
      itemCount: widget.mascotas.length,
      itemBuilder: (context, index) {
        var pet = widget.mascotas[index];
        var paseador = pet['paseador'];

        return Card(
          margin: const EdgeInsets.all(10),
          elevation: 3,
          child: Padding(
            padding: const EdgeInsets.all(15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Mascota: ${pet['nombre']}", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const Divider(),
                if (paseador != null) ...[
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const CircleAvatar(child: Icon(Icons.person)),
                    title: Text("Paseador: ${paseador['nombre']}", style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Experiencia: ${paseador['experiencia'] ?? 'N/A'}"),
                        Text("Biografía: ${paseador['biografia'] ?? 'N/A'}"),
                      ],
                    ),
                  ),
                ] else ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Text(
                      "Paseador aun no asignado",
                      style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 16, fontWeight: FontWeight.bold),
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
}
