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
  // Se eliminó el ImagePicker ya que ya no se suben fotos desde aquí.

  bool get _esAdmin => widget.userData['es_admin'] ?? false;

  // Se eliminó _subirFotoPaseador ya que las fotos ahora vienen de la tabla Usuarios centralizada.

  Future<void> _asignarPaseadorDialog(int petId) async {
    try {
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
                                final assignRes = await http.post(
                                  Uri.parse(
                                    "http://18.223.214.78:8000/assign_walker",
                                  ),
                                  headers: {"Content-Type": "application/json"},
                                  body: jsonEncode({
                                    "pet_id": petId,
                                    "paseador_id": selectedPaseadorId,
                                  }),
                                );

                                if (assignRes.statusCode == 200) {
                                  var pSelected = paseadores.firstWhere(
                                    (p) =>
                                        p['id'].toString() ==
                                        selectedPaseadorId.toString(),
                                  );
                                  setState(() {
                                    int idx = widget.mascotas.indexWhere(
                                      (m) => m['id'] == petId,
                                    );
                                    if (idx != -1) {
                                      widget.mascotas[idx]['paseador'] = {
                                        "id": pSelected['id'],
                                        "nombre": pSelected['nombre'],
                                        "experiencia":
                                            pSelected['experiencia'] ?? "",
                                        "biografia":
                                            pSelected['biografia'] ?? "",
                                        "foto": pSelected['foto'],
                                      };
                                    }
                                  });
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: const Text(
                                        "¡Paseador asignado con éxito!",
                                      ),
                                      backgroundColor: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                    ),
                                  );
                                } else {
                                  var errorData = jsonDecode(assignRes.body);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        "Error: ${errorData['detail']}",
                                      ),
                                      backgroundColor: Theme.of(
                                        context,
                                      ).colorScheme.error,
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
    if (widget.mascotas.isEmpty) {
      return const Center(child: Text("No hay mascotas registradas."));
    }
    return ListView.builder(
      itemCount: widget.mascotas.length,
      itemBuilder: (context, index) {
        var pet = widget.mascotas[index];
        var paseador = pet['paseador'];

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: Theme.of(context).primaryColor, width: 2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header de la Mascota
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.pets, color: Colors.white, size: 24),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "Mascota: ${pet['nombre'].toString().toUpperCase()}",
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
              
              // Cuerpo del Paseador
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: paseador != null
                    ? Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.secondary.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(color: Theme.of(context).colorScheme.secondary.withOpacity(0.5), width: 1.5),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.directions_walk, color: Colors.brown, size: 28),
                                const SizedBox(width: 8),
                                const Text(
                                  "MI PASEADOR ASIGNADO",
                                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1.2, color: Colors.brown),
                                ),
                              ],
                            ),
                            const SizedBox(height: 15),
                            Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 4))
                                ],
                                border: Border.all(color: Theme.of(context).colorScheme.primary, width: 3),
                              ),
                              child: CircleAvatar(
                                radius: 55, // Mucho más grande que la mascota
                                backgroundColor: Colors.white,
                                backgroundImage: (paseador['foto'] != null && paseador['foto'].toString().trim().isNotEmpty)
                                    ? MemoryImage(base64Decode(paseador['foto']))
                                    : null,
                                child: (paseador['foto'] == null || paseador['foto'].toString().trim().isEmpty)
                                    ? Icon(Icons.person, color: Theme.of(context).colorScheme.primary, size: 36)
                                    : null,
                              ),
                            ),
                            const SizedBox(height: 15),
                            Text(
                              paseador['nombre'].toString().toUpperCase(),
                              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 22, color: Theme.of(context).colorScheme.primary),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 5),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.secondary,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                "Experiencia: ${paseador['experiencia'] ?? 'N/A'}",
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              "\"${paseador['biografia'] ?? 'El mejor paseador para tu mascota.'}\"",
                              style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 14, color: Colors.black54),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                    : Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.error.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(color: Theme.of(context).colorScheme.error, width: 1.5),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.warning_amber_rounded, size: 40, color: Theme.of(context).colorScheme.error),
                            const SizedBox(height: 10),
                            Text(
                              "PASEADOR AÚN NO ASIGNADO",
                              style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 15, fontWeight: FontWeight.bold),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
              ),

              if (_esAdmin) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: ElevatedButton.icon(
                    onPressed: () => _asignarPaseadorDialog(pet['id']),
                    icon: const Icon(Icons.assignment_ind),
                    label: const Text("ASIGNAR / CAMBIAR PASEADOR", style: TextStyle(fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      elevation: 2,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ],
          ),
        );
      },
    );
  }
}
