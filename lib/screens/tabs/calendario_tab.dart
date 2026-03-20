import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class CalendarioTab extends StatefulWidget {
  final Map userData;
  final List mascotas;

  const CalendarioTab({super.key, required this.userData, required this.mascotas});

  @override
  State<CalendarioTab> createState() => _CalendarioTabState();
}

class _CalendarioTabState extends State<CalendarioTab> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<DateTime, List<dynamic>> _eventosMascota = {};
  dynamic _selectedPetId; // Cambiado a dynamic para evitar errores de parseo con id enteros o strings

  bool get _esAdmin => widget.userData['es_admin'] ?? false;
  String get _adminEmail => widget.userData['email'] ?? "";

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    if (widget.mascotas.isNotEmpty) {
      _selectedPetId = widget.mascotas.first['id'];
      _cargarPaseos();
    }
  }

  Future<void> _cargarPaseos() async {
    if (_selectedPetId == null) return;
    try {
      final res = await http.get(Uri.parse("http://18.223.214.78:8000/mis_paseos/$_selectedPetId/${_focusedDay.year}/${_focusedDay.month}"));
      
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final paseos = data['paseos'] as List? ?? []; // Prevención de nulo
        Map<DateTime, List<dynamic>> nuevosEventos = {};
        for (var p in paseos) {
          DateTime fechaParseada = DateTime.parse(p['fecha_paseo'].toString());
          DateTime fechaClave = DateTime.utc(fechaParseada.year, fechaParseada.month, fechaParseada.day);
          if (nuevosEventos[fechaClave] == null) nuevosEventos[fechaClave] = [];
          nuevosEventos[fechaClave]!.add(p);
        }
        setState(() {
          _eventosMascota = nuevosEventos;
        });
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error del Servidor: ${res.statusCode} - ${res.body}")));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error Interno (Flutter): $e")));
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
    if (_selectedPetId == null) return 0;
    // Si no encuentra la mascota, retorna un Map vacío en vez de un Set {} que tumba la app
    var pet = widget.mascotas.firstWhere((p) => p['id'] == _selectedPetId, orElse: () => <String, dynamic>{});
    String plan = (pet['plan_mascota'] ?? "").toString().toLowerCase();
    if (plan.contains("basico") || plan.contains("básico")) return 8;
    if (plan.contains("intermedio")) return 16;
    if (plan.contains("avanzado") || plan.contains("full")) return 24;
    return 0;
  }

  Future<void> _asignarNuevoPaseo() async {
     DateTime? fechaElegida = await showDatePicker(context: context, initialDate: _focusedDay, firstDate: DateTime.now(), lastDate: DateTime(2030));
     if (fechaElegida == null) return;
     
     if (!mounted) return;
     TimeOfDay? horaInicio = await showTimePicker(context: context, initialTime: const TimeOfDay(hour: 9, minute: 0));
     if (horaInicio == null) return;
     
     if (!mounted) return;
     TimeOfDay? horaFin = await showTimePicker(context: context, initialTime: TimeOfDay(hour: horaInicio.hour + 1, minute: horaInicio.minute));
     if (horaFin == null) return;

     var pet = widget.mascotas.firstWhere((p) => p['id'] == _selectedPetId, orElse: () => <String, dynamic>{});
     if (pet['paseador'] == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Esta mascota no tiene un paseador asignado.")));
        return;
     }
     var paseadorId = pet['paseador']['id'];

     try {
       final res = await http.post(
         Uri.parse("http://18.223.214.78:8000/asignar_paseo"),
         headers: {"Content-Type": "application/json"},
         body: jsonEncode({
           "pet_id": _selectedPetId,
           "paseador_id": paseadorId,
           "fecha": fechaElegida.toIso8601String().split('T')[0],
           "hora_inicio": "${horaInicio.hour.toString().padLeft(2,'0')}:${horaInicio.minute.toString().padLeft(2,'0')}:00",
           "hora_fin": "${horaFin.hour.toString().padLeft(2,'0')}:${horaFin.minute.toString().padLeft(2,'0')}:00",
           "admin_email": _adminEmail,
           "es_admin": _esAdmin,
         })
       );
       
       if (!mounted) return;
       if (res.statusCode == 200) {
         _cargarPaseos();
         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Paseo asignado con éxito")));
       } else {
         var err = jsonDecode(res.body);
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: ${err['detail']}")));
       }
     } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Excepción subiendo paseo: $e")));
     }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.mascotas.isEmpty) return const Center(child: Text("Sin mascotas registradas"));

    return Column(
      children: [
        if (widget.mascotas.length > 1) 
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: DropdownButton<dynamic>(
              value: _selectedPetId,
              isExpanded: true,
              items: widget.mascotas.map((m) => DropdownMenuItem<dynamic>(value: m['id'], child: Text("Mascota: ${m['nombre']} - ${m['raza']}"))).toList(),
              onChanged: (v) {
                if (v != null) {
                  setState(() => _selectedPetId = v);
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
              Icon(Icons.info_outline, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  _esAdmin ? "Modo Admin: Agendando paseos" : "Plan de paseos usado: $_paseosUsados de $_limitePaseos horas en el mes",
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
            setState(() { _selectedDay = s; _focusedDay = f; });
          },
          onPageChanged: (f) {
            _focusedDay = f;
            _cargarPaseos();
          },
          eventLoader: _obtenerEventosDelDia,
          calendarStyle: CalendarStyle(
            markerDecoration: BoxDecoration(color: Theme.of(context).colorScheme.secondary, shape: BoxShape.circle),
            markersMaxCount: 4,
          ),
          headerStyle: const HeaderStyle(
            formatButtonVisible: false,
          ),
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
                  child: Text('${day.day}', style: TextStyle(fontWeight: FontWeight.bold, color: color)),
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
                  child: Text('${day.day}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                );
              }
              return null;
            },
          ),
        ),
        const Divider(),
        Expanded(
          child: ListView(
            children: _obtenerEventosDelDia(_selectedDay ?? _focusedDay).map((evento) {
              return ListTile(
                leading: const Icon(Icons.pets, color: Colors.green),
                title: Text("Paseador: ${evento['nombre_paseador'] ?? 'No asignado'}"),
                subtitle: Text("Hora: ${evento['hora_inicio']} - ${evento['hora_fin']}"),
              );
            }).toList(),
          ),
        ),
        if (_esAdmin)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton.icon(
              onPressed: _asignarNuevoPaseo,
              icon: const Icon(Icons.add_alarm),
              label: const Text("ASIGNAR NUEVO PASEO", style: TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
            ),
          ),
      ],
    );
  }
}
