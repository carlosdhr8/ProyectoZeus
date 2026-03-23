import 'package:flutter/material.dart';
import 'tabs/mascotas_tab.dart';
import 'tabs/paseadores_tab.dart';
import 'tabs/perfil_tab.dart';
import 'tabs/calendario_tab.dart';

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
        body: TabBarView(
          children: misVistas,
        ),
      ),
    );
  }
}
