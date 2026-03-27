import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:http/http.dart' as http;

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
  List<LatLng> _routePoints = [];
  bool _isLoadingHistory = true;

  @override
  void initState() {
    super.initState();
    _fetchHistory();
    _conectarWebSocket();
  }

  Future<void> _fetchHistory() async {
    setState(() {
      _routePoints = [];
      _isLoadingHistory = true;
    });
    
    final rawId = (widget.paseoData['id_paseo'] ?? widget.paseoData['id']).toString();
    final cleanId = rawId.replaceAll('#', '').trim();
    final baseUrl = widget.serverUrl.replaceAll('ws://', 'http://').replaceAll('wss://', 'https://');
    
    try {
      final response = await http.get(Uri.parse('$baseUrl/get_location_history/$cleanId'));
      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        if (data.isNotEmpty) {
          final List<LatLng> points = data.map((e) => LatLng(e['lat'], e['lng'])).toList();
          setState(() {
            _routePoints = points;
            _currentWalkerPosition = points.last;
            _isLoadingHistory = false;
          });
          Future.delayed(const Duration(milliseconds: 500), () {
             if (mounted) _mapController.move(points.last, 16.0);
          });
        } else {
          setState(() => _isLoadingHistory = false);
        }
      }
    } catch (e) {
      debugPrint("Error cargando historial: $e");
      setState(() => _isLoadingHistory = false);
    }
  }

  void _conectarWebSocket() {
    final rawId = (widget.paseoData['id_paseo'] ?? widget.paseoData['id']).toString();
    final cleanId = rawId.replaceAll('#', '').trim();
    final url = '${widget.serverUrl}/ws/paseo/$cleanId'.replaceAll('#', '').trim();
    
    _channel = WebSocketChannel.connect(Uri.parse(url));

    _channel!.stream.listen((message) {
      if (!mounted) return;
      try {
        final data = jsonDecode(message);
        if (data['lat'] != null && data['lng'] != null) {
          final newMarker = LatLng(data['lat'], data['lng']);
          setState(() {
            _currentWalkerPosition = newMarker;
            _routePoints.add(newMarker);
          });
          _mapController.move(newMarker, 16.0); 
        }
      } catch (e) {
        debugPrint("Error procesando mensaje WS: $e");
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
      body: _isLoadingHistory
          ? const Center(child: CircularProgressIndicator())
          : (_currentWalkerPosition == null && _routePoints.isEmpty)
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 20),
                      Text("Esperando que el paseador inicie el recorrido...",
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                )
              : FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _currentWalkerPosition ?? const LatLng(0, 0),
                    initialZoom: 16.0,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
                      subdomains: const ['a', 'b', 'c', 'd'],
                      userAgentPackageName: 'com.zeus.pet_care_app',
                  ),
                    MarkerLayer(
                      markers: _routePoints.asMap().entries.where((entry) {
                        return entry.key % 2 == 0;
                    }).map((entry) {
                        return Marker(
                          point: entry.value,
                          width: 35,
                          height: 35,
                          child: Icon(
                            Icons.pets,
                            size: 24,
                            color: Theme.of(context).colorScheme.primary, 
                          ),
                        );
                    }).toList(),
                  ),
                  if (_currentWalkerPosition != null)
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
