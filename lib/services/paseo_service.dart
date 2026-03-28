import 'dart:async';
import 'dart:convert';
import 'dart:io';
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
  static const int maxRetries = 15;

  final StreamController<bool> _statusController =
      StreamController<bool>.broadcast();
  Stream<bool> get statusStream => _statusController.stream;

  final StreamController<ConnectionStatus> _connectionController =
      StreamController<ConnectionStatus>.broadcast();
  Stream<ConnectionStatus> get connectionStream => _connectionController.stream;

  bool get isTransmitting => _isTransmitting;
  Map? get activePaseoData => _activePaseoData;

  /// Inicia el proceso de paseo y activa el hilo de transmisión
  void startPaseo(Map paseoData, String serverUrl) async {
    if (_isTransmitting) return;

    _activePaseoData = paseoData;
    _currentServerUrl = serverUrl;
    _isManualStop = false;
    _retryCount = 0;

    _initWebSocket();

    // Configuración de GPS
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
    } catch (e) {
      debugPrint("Error permisos GPS: $e");
    }

    // Timer de latido (Heartbeat) - Cada 30 segundos
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (
      timer,
    ) async {
      if (_isTransmitting && !_isManualStop) {
        _enviarPosicionActual();
      }
    });

    _isTransmitting = true;
    _statusController.add(true);
  }

  /// Inicialización protegida del WebSocketChannel
  /// Inicialización protegida del WebSocketChannel
  Future<void> _initWebSocket() async {
    // 1. Agrega 'async' aquí
    if (_isManualStop || _activePaseoData == null || _currentServerUrl == null)
      return;

    _cleanupResources();

    final rawId = (_activePaseoData!['id_paseo'] ?? _activePaseoData!['id'])
        .toString();
    final cleanId = rawId.replaceAll('#', '').trim();
    final url = '$_currentServerUrl/ws/paseo/$cleanId'
        .replaceAll('#', '')
        .trim();

    debugPrint("WS: Intentando conectar a $url...");

    try {
      _channel = WebSocketChannel.connect(Uri.parse(url));

      // 2. 🔥 LA SOLUCIÓN AL CRASH 🔥
      // Esto obliga a Dart a esperar a que el túnel realmente se abra.
      // Si no hay red (errno 101), esto fallará y saltará directo al 'catch' de abajo.
      await _channel!.ready;

      _channelSubscription = _channel!.stream.listen(
        (message) {
          _retryCount = 0;
          _connectionController.add(ConnectionStatus.connected);
        },
        onError: (error) {
          debugPrint("WS error atrapado en stream: $error");
          _handleConnectionLoss();
        },
        onDone: () {
          debugPrint("WS canal completado (onDone)");
          _handleConnectionLoss();
        },
        cancelOnError: true,
      );

      _connectionController.add(ConnectionStatus.connected);
    } catch (e) {
      // 3. Ahora este catch atrapará el SocketException (errno = 101) sin cerrar la app
      debugPrint("WS crash durante conexión o pérdida de red inicial: $e");
      _handleConnectionLoss();
    }
  }

  /// Mecanismo de reintentos con retraso
  void _handleConnectionLoss() {
    if (_isManualStop) return;
    _cleanupResources();

    if (_retryCount < maxRetries) {
      _retryCount++;
      _connectionController.add(ConnectionStatus.retrying);
      debugPrint("WS: Reintentando en 5 segundos... (Intento $_retryCount)");

      _retryTimer?.cancel();
      _retryTimer = Timer(const Duration(seconds: 5), () {
        if (!_isManualStop) _initWebSocket();
      });
    } else {
      _connectionController.add(ConnectionStatus.disconnected);
      debugPrint("WS: Límite de reintentos alcanzado.");
    }
  }

  /// Método SEGURO para enviar datos (safeSend)
  void _safeSend(dynamic data) {
    if (_isManualStop || !_isTransmitting || _channel == null) return;

    try {
      _channel!.sink.add(data);
    } catch (e) {
      debugPrint("WS: Fallo en safeSend: $e");
      _handleConnectionLoss();
    }
  }

  Future<void> _enviarPosicionActual() async {
    try {
      Position current = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      final data = {
        "lat": current.latitude,
        "lng": current.longitude,
        "timestamp": DateTime.now().toIso8601String(),
        "status": "active",
      };

      _safeSend(jsonEncode(data));
    } catch (e) {
      debugPrint("Error obteniendo posición GPS: $e");
    }
  }

  void _cleanupResources() {
    try {
      _channelSubscription?.cancel();
      _channelSubscription = null;
      _channel?.sink.close();
      _channel = null;
    } catch (e) {
      debugPrint("Error limpiando WS: $e");
    }
  }

  Future<bool> updatePaseoStatus(int paseoId, String nuevoEstado) async {
    if (_currentServerUrl == null) return false;
    final baseUrl = _currentServerUrl!
        .replaceAll('ws://', 'http://')
        .replaceAll('wss://', 'https://');
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/update_paseo_status'),
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({
              "id_paseo": paseoId,
              "nuevo_estado": nuevoEstado,
            }),
          )
          .timeout(const Duration(seconds: 10));
      return response.statusCode == 200;
    } catch (e) {
      debugPrint("Error actualizando estado del paseo: $e");
      return false;
    }
  }

  void stopPaseo() {
    _isManualStop = true;
    _isTransmitting = false;
    _retryCount = 0;

    _heartbeatTimer?.cancel();
    _retryTimer?.cancel();
    _cleanupResources();

    _activePaseoData = null;
    _statusController.add(false);
    _connectionController.add(ConnectionStatus.disconnected);
  }
}
