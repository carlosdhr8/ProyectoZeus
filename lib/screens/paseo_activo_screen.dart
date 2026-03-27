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

  @override
  void initState() {
    super.initState();
    _currentEstado = widget.paseoData['estado'] ?? 'Pendiente';
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

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: _paseoService.statusStream,
      initialData: _paseoService.isTransmitting,
      builder: (context, snapshot) {
        bool isTransmitting = snapshot.data ?? false;
        
        return Scaffold(
          appBar: AppBar(title: Text("Paseo: ${widget.paseoData['nombre_mascota'] ?? 'Mascota'}")),
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isTransmitting ? Icons.gps_fixed : Icons.gps_not_fixed,
                  size: 100,
                  color: isTransmitting ? Theme.of(context).colorScheme.primary : Colors.grey,
                ),
                const SizedBox(height: 20),
                Text(
                  isTransmitting ? "Transmitiendo Ubicación en Vivo" : "GPS Inactivo (Pausa)",
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
        );
      }
    );
  }
}
