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
                  isTransmitting ? "Transmitiendo Ubicación en Vivo" : "GPS Inactivo",
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 50),
                ElevatedButton.icon(
                  icon: Icon(isTransmitting ? Icons.stop : Icons.play_arrow, color: Colors.white,),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isTransmitting ? Colors.red : Theme.of(context).colorScheme.primary,
                    minimumSize: const Size(220, 60),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  ),
                  onPressed: () {
                    if (isTransmitting) {
                      _paseoService.stopPaseo();
                    } else {
                      _paseoService.startPaseo(widget.paseoData, widget.serverUrl);
                    }
                  },
                  label: Text(
                    isTransmitting ? "FINALIZAR RECORRIDO" : "INICIAR RECORRIDO", 
                    style: const TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)
                  ),
                ),
              ],
            ),
          ),
        );
      }
    );
  }
}
