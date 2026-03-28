import 'dart:async';
import 'package:flutter/material.dart';
import '../services/paseo_service.dart';

class PaseoActivoScreen extends StatefulWidget {
  final Map paseoData;
  final String serverUrl; 
  const PaseoActivoScreen({super.key, required this.paseoData, required this.serverUrl});

  @override
  State<PaseoActivoScreen> createState() => _PaseoActivoScreenState();
}

class _PaseoActivoScreenState extends State<PaseoActivoScreen> {
  final _paseoService = PaseoService();
  late String _currentEstado;
  StreamSubscription<ConnectionStatus>? _connectionSubs;
  bool _dialogVisible = false;

  @override
  void initState() {
    super.initState();
    _currentEstado = widget.paseoData['estado'] ?? 'Pendiente';
    
    // Escuchar cambios de conexión de forma segura fuera del build
    _connectionSubs = _paseoService.connectionStream.listen((status) {
      if (status == ConnectionStatus.disconnected && _paseoService.isTransmitting && !_dialogVisible) {
        _mostrarAlertaErrorConexion();
      }
    });
  }

  @override
  void dispose() {
    _connectionSubs?.cancel();
    super.dispose();
  }

  Future<void> _finalizarPaseo() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("¿Finalizar Paseo?"),
        content: const Text("Esta acción dará por concluido el paseo permanentemente."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("CANCELAR")),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("SÍ, FINALIZAR", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      final int paseoId = widget.paseoData['id_paseo'] ?? widget.paseoData['id'];
      await _paseoService.updatePaseoStatus(paseoId, 'Finalizado');
      _paseoService.stopPaseo();
      if (mounted) Navigator.pop(context);
    }
  }

  void _mostrarAlertaErrorConexion() {
    if (!mounted) return;
    _dialogVisible = true;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.red),
            SizedBox(width: 10),
            Text("Error de Conexión"),
          ],
        ),
        content: const Text(
          "No se pudo restablecer la conexión con el servidor después de varios intentos. "
          "Por favor, revisa tu conexión a internet o intenta reiniciar la transmisión manualmente.",
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              _dialogVisible = false;
              Navigator.pop(ctx);
            },
            child: const Text("ENTENDIDO"),
          ),
        ],
      ),
    ).then((_) => _dialogVisible = false);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: _paseoService.statusStream,
      initialData: _paseoService.isTransmitting,
      builder: (context, statusSnapshot) {
        bool isTransmitting = statusSnapshot.data ?? false;
        
        return StreamBuilder<ConnectionStatus>(
          stream: _paseoService.connectionStream,
          initialData: ConnectionStatus.connected,
          builder: (context, connSnapshot) {
            final connStatus = connSnapshot.data ?? ConnectionStatus.connected;
            
            return Scaffold(
              appBar: AppBar(title: Text("Paseo: ${widget.paseoData['nombre_mascota'] ?? 'Mascota'}")),
              body: Column(
                children: [
                  // Banner de estado de conexión
                  if (isTransmitting && connStatus == ConnectionStatus.retrying)
                    Container(
                      width: double.infinity,
                      color: Colors.orange,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 15,
                            height: 15,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          ),
                          SizedBox(width: 12),
                          Text(
                            "Conexión inestable. Reintentando...",
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  if (isTransmitting && connStatus == ConnectionStatus.disconnected)
                    Container(
                      width: double.infinity,
                      color: Colors.red,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: const Text(
                        "Sin conexión. Los puntos no se están guardando.",
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            !isTransmitting 
                                ? Icons.gps_not_fixed 
                                : (connStatus == ConnectionStatus.connected ? Icons.gps_fixed : Icons.signal_wifi_off),
                            size: 100,
                            color: !isTransmitting 
                                ? Colors.grey 
                                : (connStatus == ConnectionStatus.connected ? Theme.of(context).colorScheme.primary : (connStatus == ConnectionStatus.retrying ? Colors.orange : Colors.red)),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            isTransmitting 
                                ? (connStatus == ConnectionStatus.connected ? "Transmitiendo Ubicación en Vivo" : (connStatus == ConnectionStatus.retrying ? "Reconectando..." : "Desconectado"))
                                : "GPS Inactivo (Pausa)",
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 10),
                          if (_currentEstado == 'En Curso' && !isTransmitting)
                            const Text("Puedes reanudar la transmisión en cualquier momento.", style: TextStyle(color: Colors.grey)),
                          const SizedBox(height: 40),
                          ElevatedButton.icon(
                            icon: Icon(isTransmitting ? Icons.pause : Icons.play_arrow, color: Colors.white,),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isTransmitting ? Colors.orange : Theme.of(context).colorScheme.primary,
                              minimumSize: const Size(260, 60),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                            ),
                            onPressed: () async {
                              if (isTransmitting) {
                                _paseoService.stopPaseo();
                              } else {
                                if (_currentEstado == 'Pendiente') {
                                  final int paseoId = widget.paseoData['id_paseo'] ?? widget.paseoData['id'];
                                  await _paseoService.updatePaseoStatus(paseoId, 'En Curso');
                                  setState(() => _currentEstado = 'En Curso');
                                }
                                _paseoService.startPaseo(widget.paseoData, widget.serverUrl);
                              }
                            },
                            label: Text(
                              isTransmitting ? "PAUSAR TRANSMISIÓN" : (_currentEstado == 'Pendiente' ? "INICIAR RECORRIDO" : "REANUDAR TRANSMISIÓN"), 
                              style: const TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)
                            ),
                          ),
                          const SizedBox(height: 20),
                          OutlinedButton.icon(
                            icon: const Icon(Icons.check_circle_outline, color: Colors.red),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                              side: const BorderSide(color: Colors.red),
                              minimumSize: const Size(260, 50),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                            ),
                            onPressed: _finalizarPaseo,
                            label: const Text("FINALIZAR PASEO", style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      }
    );
  }
}
