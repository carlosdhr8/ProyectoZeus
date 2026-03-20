import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:table_calendar/table_calendar.dart';

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
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Text(
                      "Paseador aun no asignado",
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
                if (_esAdmin) ...[
                  const SizedBox(height: 10),
                  Center(
                    child: Column(
                      children: [
                        ElevatedButton.icon(
                          icon: const Icon(Icons.assignment_ind),
                          label: const Text("Asignar/Cambiar Paseador"),
                          onPressed: () => _asignarPaseadorDialog(pet['id']),
                        ),
                        if (paseador != null) ...[
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            icon: const Icon(Icons.calendar_month),
                            label: const Text("Ver Agenda del Paseador"),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(
                                color: Theme.of(context).colorScheme.primary,
                                width: 2,
                              ),
                              foregroundColor: Theme.of(
                                context,
                              ).colorScheme.primary,
                            ),
                            onPressed: () {
                              showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                shape: const RoundedRectangleBorder(
                                  borderRadius: BorderRadius.vertical(
                                    top: Radius.circular(20),
                                  ),
                                ),
                                builder: (ctx) => SizedBox(
                                  height:
                                      MediaQuery.of(context).size.height * 0.8,
                                  child: PaseadorAgendaSheet(
                                    paseadorId: int.parse(
                                      paseador['id'].toString(),
                                    ),
                                    paseadorNombre: paseador['nombre']
                                        .toString(),
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ],
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

class PaseadorAgendaSheet extends StatefulWidget {
  final int paseadorId;
  final String paseadorNombre;

  const PaseadorAgendaSheet({
    super.key,
    required this.paseadorId,
    required this.paseadorNombre,
  });

  @override
  State<PaseadorAgendaSheet> createState() => _PaseadorAgendaSheetState();
}

class _PaseadorAgendaSheetState extends State<PaseadorAgendaSheet> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<DateTime, List<dynamic>> _eventosPaseador = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _cargarAgenda();
  }

  Future<void> _cargarAgenda() async {
    setState(() => _isLoading = true);
    try {
      final res = await http.get(
        Uri.parse(
          "http://18.223.214.78:8000/paseador_agenda/${widget.paseadorId}/${_focusedDay.year}/${_focusedDay.month}",
        ),
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final paseos = data['paseos'] as List? ?? [];
        Map<DateTime, List<dynamic>> nuevosEventos = {};
        for (var p in paseos) {
          DateTime fp = DateTime.parse(p['fecha_paseo'].toString());
          DateTime fc = DateTime.utc(fp.year, fp.month, fp.day);
          if (nuevosEventos[fc] == null) nuevosEventos[fc] = [];
          nuevosEventos[fc]!.add(p);
        }
        if (!mounted) return;
        setState(() {
          _eventosPaseador = nuevosEventos;
          _isLoading = false;
        });
      } else {
        if (!mounted) return;
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error del servidor: ${res.body}")),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error al cargar agenda: $e")));
    }
  }

  List<dynamic> _getEventos(DateTime dia) {
    return _eventosPaseador[DateTime.utc(dia.year, dia.month, dia.day)] ?? [];
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            "Agenda de ${widget.paseadorNombre}",
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ),
        TableCalendar(
          locale: 'es_ES',
          firstDay: DateTime.utc(2025, 1, 1),
          lastDay: DateTime.utc(2030, 12, 31),
          focusedDay: _focusedDay,
          selectedDayPredicate: (d) => isSameDay(_selectedDay, d),
          onDaySelected: (s, f) {
            setState(() {
              _selectedDay = s;
              _focusedDay = f;
            });
          },
          onPageChanged: (f) {
            _focusedDay = f;
            _cargarAgenda();
          },
          eventLoader: _getEventos,
          calendarStyle: const CalendarStyle(markersMaxCount: 0),
          headerStyle: const HeaderStyle(formatButtonVisible: false),
          calendarBuilders: CalendarBuilders(
            defaultBuilder: (context, day, focusedDay) {
              final evs = _getEventos(day);
              if (evs.isNotEmpty) {
                final color = Theme.of(context).colorScheme.primary;
                return Container(
                  margin: const EdgeInsets.all(6),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: color, width: 1.5),
                  ),
                  child: Text(
                    '${day.day}',
                    style: TextStyle(fontWeight: FontWeight.bold, color: color),
                  ),
                );
              }
              return null;
            },
            todayBuilder: (context, day, focusedDay) {
              final evs = _getEventos(day);
              final color = Theme.of(context).colorScheme.primary;
              if (evs.isNotEmpty) {
                return Container(
                  margin: const EdgeInsets.all(6),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: color, width: 2),
                  ),
                  child: Text(
                    '${day.day}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                );
              }
              return null;
            },
          ),
        ),
        const Divider(),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _getEventos(_selectedDay ?? _focusedDay).isEmpty
              ? const Center(child: Text("El paseador está libre este día"))
              : ListView(
                  children: _getEventos(_selectedDay ?? _focusedDay).map((ev) {
                    return ListTile(
                      leading: const Icon(Icons.pets, color: Colors.green),
                      title: Text(
                        "${ev['hora_inicio']} - ${ev['hora_fin']}",
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        "Mascota: ${ev['nombre_mascota']}\nDueño: ${ev['nombre_dueno'] ?? 'Anónimo'}",
                      ),
                    );
                  }).toList(),
                ),
        ),
      ],
    );
  }
}
