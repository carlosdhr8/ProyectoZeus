import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'dart:async';

class PaseoActivoScreen extends StatefulWidget {
  final Map paseoData;
  final String serverUrl; 
  const PaseoActivoScreen({super.key, required this.paseoData, required this.serverUrl});

  @override
  State<PaseoActivoScreen> createState() => _PaseoActivoScreenState();
}

class _PaseoActivoScreenState extends State<PaseoActivoScreen> {
  WebSocketChannel? _channel;
  StreamSubscription<Position>? _positionStream;
  bool _isTransmitting = false;

  @override
  void initState() {
    super.initState();
    _conectarWebSocket();
  }

  void _conectarWebSocket() {
    final rawId = (widget.paseoData['id_paseo'] ?? widget.paseoData['id']).toString();
    final cleanId = rawId.replaceAll('#', '').trim();
    final url = '${widget.serverUrl}/ws/paseo/$cleanId'.replaceAll('#', '').trim();
    
    debugPrint("WS Conectando: $url");
    _channel = WebSocketChannel.connect(Uri.parse(url));
  }

  Future<void> _iniciarTransmision() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Servicios de GPS deshabilitados. Activa la ubicación en tu dispositivo.')));
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    if (permission == LocationPermission.deniedForever) return;

    setState(() => _isTransmitting = true);
    
    // 1. Enviar posición actual de inmediato al conectar
    try {
      Position current = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      _enviarCoordenadas(current);
    } catch (e) {
      debugPrint("Error obteniendo posición inicial: $e");
    }

    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5, // Enviar datos si se mueve 5 metros
    );

    _positionStream = Geolocator.getPositionStream(locationSettings: locationSettings).listen((Position position) {
      _enviarCoordenadas(position);
    });
  }

  void _enviarCoordenadas(Position position) {
    if (_channel != null) {
      final data = {
        "lat": position.latitude,
        "lng": position.longitude,
        "timestamp": DateTime.now().toIso8601String(),
        "status": "active"
      };
      _channel!.sink.add(jsonEncode(data));
    }
  }

  void _detenerTransmision() {
    _positionStream?.cancel();
    setState(() => _isTransmitting = false);
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _channel?.sink.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Paseo: ${widget.paseoData['nombre_mascota'] ?? 'Mascota'}")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _isTransmitting ? Icons.gps_fixed : Icons.gps_not_fixed,
              size: 100,
              color: _isTransmitting ? Theme.of(context).colorScheme.primary : Colors.grey,
            ),
            const SizedBox(height: 20),
            Text(
              _isTransmitting ? "Transmitiendo Ubicación en Vivo" : "GPS Inactivo",
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40.0),
              child: Text(
                _isTransmitting 
                  ? "El dueño y el administrador ahora pueden ver tu ubicación en tiempo real en el mapa." 
                  : "Presiona el botón para iniciar el recorrido.",
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: Colors.black54),
              ),
            ),
            const SizedBox(height: 50),
            ElevatedButton.icon(
              icon: Icon(_isTransmitting ? Icons.stop : Icons.play_arrow, color: Colors.white,),
              style: ElevatedButton.styleFrom(
                backgroundColor: _isTransmitting ? Colors.red : Theme.of(context).colorScheme.primary,
                minimumSize: const Size(220, 60),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
              onPressed: _isTransmitting ? _detenerTransmision : _iniciarTransmision,
              label: Text(_isTransmitting ? "FINALIZAR RECORRIDO" : "INICIAR RECORRIDO", style: const TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
