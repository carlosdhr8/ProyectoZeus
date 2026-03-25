import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class MapaEnVivoScreen extends StatefulWidget {
  final Map paseoData;
  final String serverUrl;
  const MapaEnVivoScreen({super.key, required this.paseoData, required this.serverUrl});

  @override
  State<MapaEnVivoScreen> createState() => _MapaEnVivoScreenState();
}

class _MapaEnVivoScreenState extends State<MapaEnVivoScreen> {
  WebSocketChannel? _channel;
  LatLng? _currentWalkerPosition;
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    final rawId = (widget.paseoData['id_paseo'] ?? widget.paseoData['id']).toString();
    final cleanId = rawId.replaceAll('#', '').trim();
    final url = '${widget.serverUrl}/ws/paseo/$cleanId'.replaceAll('#', '').trim();
    
    _channel = WebSocketChannel.connect(Uri.parse(url));

    _channel!.stream.listen((message) {
      final data = jsonDecode(message);
      if (data['lat'] != null && data['lng'] != null) {
        final newMarker = LatLng(data['lat'], data['lng']);
        setState(() {
          _currentWalkerPosition = newMarker;
        });
        _mapController.move(newMarker, 16.0); // Animar mapa a la nueva ubicacion
      }
    });
  }

  @override
  void dispose() {
    _channel?.sink.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Rastreando: ${widget.paseoData['nombre_mascota'] ?? 'Mascota'}")),
      body: _currentWalkerPosition == null
          ? const Center(
              child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 20),
                Text("Esperando que el paseador inicie el recorrido...", style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ))
          : FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _currentWalkerPosition!,
                initialZoom: 16.0,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.zeus.petapp',
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _currentWalkerPosition!,
                      width: 60,
                      height: 60,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: Theme.of(context).colorScheme.primary, width: 3),
                          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4, spreadRadius: 1)],
                        ),
                        child: Icon(Icons.pets, color: Theme.of(context).colorScheme.primary, size: 30),
                      ),
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}
