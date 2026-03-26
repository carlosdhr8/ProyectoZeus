import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class PaseoService {
  static final PaseoService _instance = PaseoService._internal();
  factory PaseoService() => _instance;
  PaseoService._internal();

  WebSocketChannel? _channel;
  StreamSubscription<Position>? _positionStream;
  Timer? _heartbeatTimer;
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

    final locationSettings = AndroidSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5, // Mantener para actualizaciones por movimiento
      forceLocationManager: true, 
      foregroundNotificationConfig: const ForegroundNotificationConfig(
        notificationTitle: "Paseo en Curso",
        notificationText: "Zeus Pet App está rastreando el recorrido de la mascota.",
        notificationIcon: AndroidResource(name: 'launcher_icon'),
        enableWakeLock: true,
      ),
    );

    _positionStream = Geolocator.getPositionStream(locationSettings: locationSettings).listen((Position position) {
      _enviarCoordenadas(position);
    });

    // Nueva lógica: Heartbeat cada 30 segundos (Garantizado)
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

  void stopPaseo() {
    _positionStream?.cancel();
    _heartbeatTimer?.cancel();
    _channel?.sink.close();
    _isTransmitting = false;
    _activePaseoData = null;
    _statusController.add(false);
  }
}
