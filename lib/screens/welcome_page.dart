import 'package:flutter/material.dart';
import '../services/paseo_service.dart';
import '../screens/paseo_activo_screen.dart';
import 'tabs/mascotas_tab.dart';
import 'tabs/paseadores_tab.dart';
import 'tabs/perfil_tab.dart';
import 'tabs/calendario_tab.dart';
import 'tabs/admin_roles_tab.dart';

class WelcomePage extends StatefulWidget {
  final Map userData;
  final List mascotas;

  const WelcomePage({
    super.key,
    required this.userData,
    required this.mascotas,
  });

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  late List _listaMascotas;

  @override
  void initState() {
    super.initState();
    _listaMascotas = List.from(widget.mascotas);
  }

  @override
  Widget build(BuildContext context) {
    bool esPaseador = widget.userData['es_paseador'] ?? false;

    List<Tab> misTabs = [
      const Tab(icon: Icon(Icons.pets), text: "Mascotas"),
      const Tab(icon: Icon(Icons.calendar_month), text: "Calendario"),
    ];
    List<Widget> misVistas = [
      MascotasTab(userData: widget.userData, mascotas: _listaMascotas),
      CalendarioTab(userData: widget.userData, mascotas: _listaMascotas),
    ];

    if (!esPaseador) {
      misTabs.add(const Tab(icon: Icon(Icons.directions_walk), text: "Paseador"));
      misVistas.add(PaseadoresTab(userData: widget.userData, mascotas: _listaMascotas));
    }

    if (widget.userData['es_admin'] == true) {
      misTabs.add(const Tab(icon: Icon(Icons.admin_panel_settings), text: "Roles"));
      misVistas.add(AdminRolesTab(userData: widget.userData));
    }

    misTabs.add(const Tab(icon: Icon(Icons.person), text: "Perfil"));
    misVistas.add(PerfilTab(userData: widget.userData));

    return DefaultTabController(
      length: misTabs.length,
      child: Scaffold(
        appBar: AppBar(
          title: Text("Bienvenido, ${widget.userData['nombre']}"),
          bottom: TabBar(
            isScrollable: true,
            tabs: misTabs,
          ),
        ),
        body: Column(
          children: [
            // Indicador de Paseo en curso (solo para paseadores)
            StreamBuilder<bool>(
              stream: PaseoService().statusStream,
              initialData: PaseoService().isTransmitting,
              builder: (context, snapshot) {
                if (snapshot.data == true) {
                  return Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF001F3F), // Navy Zeus
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: const Color(0xFFD4AF37), width: 2), // Gold
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      child: Row(
                        children: [
                          const Icon(Icons.directions_walk, color: Color(0xFFD4AF37), size: 28),
                          const SizedBox(width: 15),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "PASEO ACTIVO",
                                  style: TextStyle(
                                    color: Colors.white, 
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                                Text(
                                  "Transmitiendo GPS en vivo...",
                                  style: TextStyle(color: Colors.white70, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          ElevatedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => PaseoActivoScreen(
                                    paseoData: PaseoService().activePaseoData!,
                                    serverUrl: 'ws://18.223.214.78:8000',
                                  ),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFD4AF37),
                              foregroundColor: const Color(0xFF001F3F),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              padding: const EdgeInsets.symmetric(horizontal: 20),
                            ),
                            child: const Text("IR A PASEO", style: TextStyle(fontWeight: FontWeight.bold)),
                          )
                        ],
                      ),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
            Expanded(
              child: TabBarView(
                children: misVistas,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
