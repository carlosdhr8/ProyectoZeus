import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../paseo_activo_screen.dart';
import '../mapa_en_vivo_screen.dart';

class CalendarioTab extends StatefulWidget {
  final Map userData;
  final List mascotas;

  const CalendarioTab({
    super.key,
    required this.userData,
    required this.mascotas,
  });

  @override
  State<CalendarioTab> createState() => _CalendarioTabState();
}

class _CalendarioTabState extends State<CalendarioTab> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<DateTime, List<dynamic>> _eventosMascota = {};
  String? _selectedValue; // e.g., 'pet_1' or 'walker_2'
  List<dynamic> _paseadores = [];
  List<dynamic> _planesActivos = [];

  bool get _esAdmin => widget.userData['es_admin'] ?? false;
  bool get _esPaseador => widget.userData['rol'] == 'paseador' || (widget.userData['es_paseador'] ?? false);
  String get _adminEmail => widget.userData['email'] ?? "";

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    if (_esPaseador) {
      _selectedValue = "walker_${widget.userData['walker_id']}";
      _cargarPaseos();
    } else if (widget.mascotas.isNotEmpty) {
      _selectedValue = "pet_${widget.mascotas.first['id']}";
      _cargarPaseos();
    }
    if (_esAdmin) {
      _cargarPaseadores();
    }
    _cargarPlanes();
  }

  Future<void> _cargarPlanes() async {
    try {
      final res = await http.get(
        Uri.parse("http://18.223.214.78:8000/get_planes"),
      );
      if (res.statusCode == 200) {
        if (!mounted) return;
        setState(() {
          _planesActivos = jsonDecode(res.body);
        });
      }
    } catch (e) {
      // ignorar
    }
  }

  Future<void> _cargarPaseadores() async {
    try {
      final res = await http.get(
        Uri.parse("http://18.223.214.78:8000/get_all_walkers"),
      );
      if (res.statusCode == 200) {
        if (!mounted) return;
        setState(() {
          _paseadores = jsonDecode(res.body);
        });
      }
    } catch (e) {
      // ignore silently
    }
  }

  Future<void> _cargarPaseos() async {
    if (_selectedValue == null) return;
    try {
      String url = "";
      if (_selectedValue!.startsWith("pet_")) {
        var petId = _selectedValue!.substring(4);
        url =
            "http://18.223.214.78:8000/mis_paseos/$petId/${_focusedDay.year}/${_focusedDay.month}";
      } else if (_selectedValue!.startsWith("walker_")) {
        var walkerId = _selectedValue!.substring(7);
        url =
            "http://18.223.214.78:8000/paseador_agenda/$walkerId/${_focusedDay.year}/${_focusedDay.month}";
      }
      if (url.isEmpty) return;

      final res = await http.get(Uri.parse(url));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final paseos = data['paseos'] as List? ?? []; // Prevención de nulo
        Map<DateTime, List<dynamic>> nuevosEventos = {};
        for (var p in paseos) {
          DateTime fechaParseada = DateTime.parse(p['fecha_paseo'].toString());
          DateTime fechaClave = DateTime.utc(
            fechaParseada.year,
            fechaParseada.month,
            fechaParseada.day,
          );
          if (nuevosEventos[fechaClave] == null) nuevosEventos[fechaClave] = [];
          nuevosEventos[fechaClave]!.add(p);
        }
        setState(() {
          _eventosMascota = nuevosEventos;
        });
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Error del Servidor: ${res.statusCode} - ${res.body}",
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error Interno (Flutter): $e")));
    }
  }

  List<dynamic> _obtenerEventosDelDia(DateTime dia) {
    DateTime fechaNormalizada = DateTime.utc(dia.year, dia.month, dia.day);
    return _eventosMascota[fechaNormalizada] ?? [];
  }

  int get _paseosUsados {
    int count = 0;
    _eventosMascota.values.forEach((lista) => count += lista.length);
    return count;
  }

  int get _limitePaseos {
    if (_selectedValue == null || !_selectedValue!.startsWith("pet_")) return 0;
    var petId = int.tryParse(_selectedValue!.substring(4));
    // Si no encuentra la mascota, retorna un Map vacío en vez de un Set {} que tumba la app
    var pet = widget.mascotas.firstWhere(
      (p) => p['id'] == petId,
      orElse: () => <String, dynamic>{},
    );
    String planName = (pet['plan_mascota'] ?? "")
        .toString()
        .toLowerCase()
        .trim();
    if (planName == 'sin plan' || planName.isEmpty) return 0;

    for (var p in _planesActivos) {
      if (p['nombre'].toString().toLowerCase().trim() == planName) {
        return p['limite_horas'] as int;
      }
    }
    return 0;
  }

  Future<void> _asignarNuevoPaseo() async {
    DateTime? fechaElegida = await showDatePicker(
      context: context,
      initialDate: _focusedDay,
      firstDate: DateTime.now(),
      lastDate: DateTime(2030),
    );
    if (fechaElegida == null) return;

    if (!mounted) return;
    TimeOfDay? horaInicio = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 9, minute: 0),
    );
    if (horaInicio == null) return;

    if (!mounted) return;
    TimeOfDay? horaFin = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: horaInicio.hour + 1,
        minute: horaInicio.minute,
      ),
    );
    if (horaFin == null) return;

    if (_selectedValue == null || !_selectedValue!.startsWith("pet_")) return;
    var petId = int.tryParse(_selectedValue!.substring(4));
    var pet = widget.mascotas.firstWhere(
      (p) => p['id'] == petId,
      orElse: () => <String, dynamic>{},
    );
    if (pet['paseador'] == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Esta mascota no tiene un paseador asignado."),
        ),
      );
      return;
    }
    var paseadorId = pet['paseador']['id'];

    try {
      final res = await http.post(
        Uri.parse("http://18.223.214.78:8000/asignar_paseo"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "pet_id": petId,
          "paseador_id": paseadorId,
          "fecha": fechaElegida.toIso8601String().split('T')[0],
          "hora_inicio":
              "${horaInicio.hour.toString().padLeft(2, '0')}:${horaInicio.minute.toString().padLeft(2, '0')}:00",
          "hora_fin":
              "${horaFin.hour.toString().padLeft(2, '0')}:${horaFin.minute.toString().padLeft(2, '0')}:00",
          "admin_email": _adminEmail,
          "es_admin": _esAdmin,
        }),
      );

      if (!mounted) return;
      if (res.statusCode == 200) {
        _cargarPaseos();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Paseo asignado con éxito")),
        );
      } else {
        var err = jsonDecode(res.body);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: ${err['detail']}")));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Excepción subiendo paseo: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.mascotas.isEmpty)
      return const Center(child: Text("Sin mascotas registradas"));

    return Column(
      children: [
        if (!_esPaseador)
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: DropdownButton<dynamic>(
              value: _selectedValue,
              isExpanded: true,
              items: [
                ...widget.mascotas
                    .map(
                      (m) => DropdownMenuItem<dynamic>(
                        value: "pet_${m['id']}",
                        child: Text("Mascota: ${m['nombre']} - ${m['raza']}"),
                      ),
                    )
                    .toList(),
                if (_esAdmin)
                  ..._paseadores
                      .map(
                        (p) => DropdownMenuItem<dynamic>(
                          value: "walker_${p['id']}",
                          child: Text("Paseador: ${p['nombre']}"),
                        ),
                      )
                      .toList(),
              ],
              onChanged: (v) {
                if (v != null) {
                  setState(() => _selectedValue = v.toString());
                  _cargarPaseos();
                }
              },
            ),
          ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.info_outline,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  _esAdmin
                      ? "Modo Admin: Agendando paseos"
                      : _esPaseador
                      ? "Modo Paseador: Viendo paseos asignados"
                      : "Plan de paseos usado: $_paseosUsados de $_limitePaseos horas en el mes",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
        TableCalendar(
          locale: 'es_ES',
          firstDay: DateTime.utc(2025, 1, 1),
          lastDay: DateTime.utc(2030, 12, 31),
          focusedDay: _focusedDay,
          selectedDayPredicate: (dia) => isSameDay(_selectedDay, dia),
          onDaySelected: (s, f) {
            setState(() {
              _selectedDay = s;
              _focusedDay = f;
            });
          },
          onPageChanged: (f) {
            _focusedDay = f;
            _cargarPaseos();
          },
          eventLoader: _obtenerEventosDelDia,
          calendarStyle: CalendarStyle(
            markerDecoration: BoxDecoration(
              color: Theme.of(context).colorScheme.secondary,
              shape: BoxShape.circle,
            ),
            markersMaxCount: 4,
          ),
          headerStyle: const HeaderStyle(formatButtonVisible: false),
          calendarBuilders: CalendarBuilders(
            defaultBuilder: (context, day, focusedDay) {
              final eventos = _obtenerEventosDelDia(day);
              if (eventos.isNotEmpty) {
                final color = Theme.of(context).colorScheme.primary;
                return Container(
                  margin: const EdgeInsets.all(6.0),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8.0),
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
              final eventos = _obtenerEventosDelDia(day);
              if (eventos.isNotEmpty) {
                final color = Theme.of(context).colorScheme.primary;
                return Container(
                  margin: const EdgeInsets.all(6.0),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.40),
                    borderRadius: BorderRadius.circular(8.0),
                    border: Border.all(color: color, width: 2.0),
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
          child: ListView(
            children: _obtenerEventosDelDia(_selectedDay ?? _focusedDay).map((
              evento,
            ) {
              bool isWalker = _selectedValue?.startsWith("walker_") ?? false;
              return ListTile(
                leading: const Icon(Icons.pets, color: Colors.green),
                title: Text(
                  isWalker
                      ? "Mascota: ${evento['nombre_mascota']}"
                      : "Paseador: ${evento['nombre_paseador'] ?? 'No asignado'}",
                ),
                subtitle: Text(
                  "Hora: ${evento['hora_inicio']} - ${evento['hora_fin']}" +
                      (isWalker
                          ? "\nDueño: ${evento['nombre_dueno'] ?? 'Anónimo'}"
                          : ""),
                ),
                trailing: ElevatedButton.icon(
                  onPressed: () {
                    final DateTime fechaPaseo = DateTime.parse(evento['fecha_paseo'].toString());
                    final DateTime hoy = DateTime.now();
                    final bool esHabilitadoPaseador = isSameDay(fechaPaseo, hoy);
                    final int diasDiferencia = hoy.difference(fechaPaseo).inDays;
                    final bool expiroHistorial = diasDiferencia > 7;

                    try {
                      if (_esPaseador) {
                        if (!esHabilitadoPaseador) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Solo puedes iniciar paseos programados para hoy."))
                          );
                          return;
                        }
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => PaseoActivoScreen(
                              paseoData: evento as Map<String, dynamic>,
                              serverUrl: 'ws://18.223.214.78:8000',
                            ),
                          ),
                        ).catchError((e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text("Error al abrir pantalla paseador: $e"))
                          );
                        });
                      } else {
                        if (expiroHistorial) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("El historial de ubicación de este paseo ha expirado (máximo 7 días)."))
                          );
                          return;
                        }
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => MapaEnVivoScreen(
                              paseoData: evento as Map<String, dynamic>,
                              serverUrl: 'ws://18.223.214.78:8000',
                            ),
                          ),
                        ).catchError((e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text("Error al abrir mapa: $e"))
                          );
                        });
                      }
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("Error de navegación: $e"))
                      );
                    }
                  },
                  icon: Icon(_esPaseador ? Icons.play_arrow : Icons.map, size: 18),
                  label: Text(_esPaseador ? "INICIAR" : "VER MAPA"),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                    textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        if (_esAdmin &&
            _selectedValue != null &&
            _selectedValue!.startsWith("pet_"))
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton.icon(
                onPressed: _asignarNuevoPaseo,
                icon: const Icon(Icons.add_alarm),
                label: const Text(
                  "ASIGNAR NUEVO PASEO",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
