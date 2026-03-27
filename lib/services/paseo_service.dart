import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:http/http.dart' as http;

class PaseoService {
  static final PaseoService _instance = PaseoService._internal();
  factory PaseoService() => _instance;
  PaseoService._internal();

  WebSocketChannel? _channel;
  StreamSubscription<Position>? _positionStream;
  Timer? _heartbeatTimer;
  String? _currentServerUrl;
  Map? _activePaseoData;
  bool _isTransmitting = false;

  final StreamController<bool> _statusController =
      StreamController<bool>.broadcast();
  Stream<bool> get statusStream => _statusController.stream;

  bool get isTransmitting => _isTransmitting;
  Map? get activePaseoData => _activePaseoData;

  void startPaseo(Map paseoData, String serverUrl) async {
    if (_isTransmitting) return;

    _activePaseoData = paseoData;

    // Conectar WebSocket
    final rawId = (paseoData['id_paseo'] ?? paseoData['id']).toString();
    final cleanId = rawId.replaceAll('#', '').trim();
    final url = '$serverUrl/ws/paseo/$cleanId'.replaceAll('#', '').trim();

    _currentServerUrl = serverUrl;
    _channel = WebSocketChannel.connect(Uri.parse(url));

    // Iniciar GPS
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    // Enviar posición inicial
    try {
      Position current = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      _enviarCoordenadas(current);
    } catch (e) {
      debugPrint("Error GPS inicial: $e");
    }

    // Eliminado el stream por movimiento para usar solo el temporizador de 30s
    /*
    _positionStream = Geolocator.getPositionStream(locationSettings: locationSettings).listen((Position position) {
      _enviarCoordenadas(position);
    });
    */

    // Lógica única: Envío de ubicación cada 30 segundos (Pedido por usuario)
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (timer) async {
      try {
        Position current = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
        _enviarCoordenadas(current);
      } catch (e) {
        debugPrint("Error en heartbeat GPS: $e");
      }
    });

    _isTransmitting = true;
    _statusController.add(true);
  }

  void _enviarCoordenadas(Position position) {
    if (_channel != null) {
      final data = {
        "lat": position.latitude,
        "lng": position.longitude,
        "timestamp": DateTime.now().toIso8601String(),
        "status": "active",
      };
      _channel!.sink.add(jsonEncode(data));
    }
  }

  Future<bool> updatePaseoStatus(int paseoId, String nuevoEstado) async {
    if (_currentServerUrl == null) return false;
    final baseUrl = _currentServerUrl!
        .replaceAll('ws://', 'http://')
        .replaceAll('wss://', 'https://');
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/update_paseo_status'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "id_paseo": paseoId,
          "nuevo_estado": nuevoEstado,
        }),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint("Error actualizando estado del paseo: $e");
      return false;
    }
  }

  void stopPaseo() {
    _positionStream?.cancel();
    _heartbeatTimer?.cancel();
    _channel?.sink.close();
    _isTransmitting = false;
    _activePaseoData = null;
    _statusController.add(false);
  }
}
