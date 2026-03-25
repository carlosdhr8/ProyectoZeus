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
                  return Container(
                    color: Colors.amber[700],
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
                    child: Row(
                      children: [
                        const Icon(Icons.directions_walk, color: Colors.white),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            "CAMINATA EN CURSO",
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ),
                        TextButton(
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
                          child: const Text("VER", style: TextStyle(color: Colors.white, decoration: TextDecoration.underline)),
                        )
                      ],
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
