import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:http/http.dart' as http;

enum ConnectionStatus { connected, retrying, disconnected }

class PaseoService {
  static final PaseoService _instance = PaseoService._internal();
  factory PaseoService() => _instance;
  PaseoService._internal();

  WebSocketChannel? _channel;
  StreamSubscription? _channelSubscription;
  Timer? _heartbeatTimer;
  Timer? _retryTimer;
  String? _currentServerUrl;
  Map? _activePaseoData;
  bool _isTransmitting = false;
  bool _isManualStop = false;
  int _retryCount = 0;
  static const int maxRetries = 15; // 75 segundos (5s * 15)

  final StreamController<bool> _statusController = StreamController<bool>.broadcast();
  Stream<bool> get statusStream => _statusController.stream;

  final StreamController<ConnectionStatus> _connectionController = StreamController<ConnectionStatus>.broadcast();
  Stream<ConnectionStatus> get connectionStream => _connectionController.stream;

  bool get isTransmitting => _isTransmitting;
  Map? get activePaseoData => _activePaseoData;

  void startPaseo(Map paseoData, String serverUrl) async {
    if (_isTransmitting) return;

    try {
      _activePaseoData = paseoData;
      _currentServerUrl = serverUrl;
      _isManualStop = false;
      _retryCount = 0;

      // Iniciar WebSocket de forma segura
      _connectWebSocket();

      // Iniciar GPS con manejo de errores total
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      // Heartbeat garantizado
      _heartbeatTimer?.cancel();
      _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (timer) async {
        if (_isTransmitting && !_isManualStop) {
          try {
            Position current = await Geolocator.getCurrentPosition(
              desiredAccuracy: LocationAccuracy.high,
              timeLimit: const Duration(seconds: 10),
            );
            _enviarCoordenadas(current);
          } catch (e) {
            debugPrint("Error en heartbeat GPS: $e");
          }
        }
      });

      _isTransmitting = true;
      _statusController.add(true);
    } catch (e) {
      debugPrint("Error crítico en startPaseo: $e");
      stopPaseo();
    }
  }

  void _connectWebSocket() {
    if (_isManualStop || _activePaseoData == null || _currentServerUrl == null) return;
    
    _retryTimer?.cancel();
    
    try {
      // Limpiar canal previo antes de abrir uno nuevo
      _cleanupChannel();

      final rawId = (_activePaseoData!['id_paseo'] ?? _activePaseoData!['id']).toString();
      final cleanId = rawId.replaceAll('#', '').trim();
      final url = '$_currentServerUrl/ws/paseo/$cleanId'.replaceAll('#', '').trim();

      debugPrint("Conectando WebSocket a $url... (Intento $_retryCount)");
      
      _channel = WebSocketChannel.connect(Uri.parse(url));
      
      // El listen debe estar envuelto en try-catch por si arroja error inmediato
      _channelSubscription = _channel!.stream.listen(
        (message) {
          _retryCount = 0; 
          _connectionController.add(ConnectionStatus.connected);
        },
        onDone: () {
          debugPrint("WS: Canal cerrado.");
          _handleDisconnection();
        },
        onError: (error) {
          debugPrint("WS: Error en flujo: $error");
          _handleDisconnection();
        },
        cancelOnError: true,
      );
      
      _connectionController.add(ConnectionStatus.connected);
    } catch (e, stack) {
      debugPrint("ERROR de conexión WebSocket: $e");
      debugPrint(stack.toString());
      _handleDisconnection();
    }
  }

  void _handleDisconnection() {
    if (_isManualStop) return;

    _cleanupChannel();

    if (_retryCount < maxRetries) {
      _retryCount++;
      _connectionController.add(ConnectionStatus.retrying);
      _retryTimer?.cancel();
      _retryTimer = Timer(const Duration(seconds: 5), () {
        if (!_isManualStop) _connectWebSocket();
      });
    } else {
      _connectionController.add(ConnectionStatus.disconnected);
      debugPrint("Falla persistente: Límite de reintentos alcanzado.");
    }
  }

  void _cleanupChannel() {
    try {
      _channelSubscription?.cancel();
      _channelSubscription = null;
      _channel?.sink.close();
      _channel = null;
    } catch (e) {
      debugPrint("Error limpiando canal: $e");
    }
  }

  void _enviarCoordenadas(Position position) {
    if (_isManualStop || !_isTransmitting) return;
    
    // Si no hay canal o no está listo, evitamos intentar enviar
    if (_channel != null) {
      final data = {
        "lat": position.latitude,
        "lng": position.longitude,
        "timestamp": DateTime.now().toIso8601String(),
        "status": "active",
      };
      try {
        _channel!.sink.add(jsonEncode(data));
      } catch (e) {
        debugPrint("Fallo al enviar a sink: $e");
        // El stream listener detectará la caída pronto.
      }
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
      ).timeout(const Duration(seconds: 10));
      return response.statusCode == 200;
    } catch (e) {
      debugPrint("Error actualizando estado: $e");
      return false;
    }
  }

  void stopPaseo() {
    _isManualStop = true;
    _isTransmitting = false;
    _retryCount = 0;
    
    _heartbeatTimer?.cancel();
    _retryTimer?.cancel();
    _cleanupChannel();
    
    _activePaseoData = null;
    _statusController.add(false);
    _connectionController.add(ConnectionStatus.disconnected);
  }
}
