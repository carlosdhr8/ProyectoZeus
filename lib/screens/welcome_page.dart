import 'package:flutter/material.dart';
import 'tabs/mascotas_tab.dart';
import 'tabs/paseadores_tab.dart';
import 'tabs/perfil_tab.dart';

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
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text("Bienvenido, ${widget.userData['nombre']}"),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.pets), text: "Mascotas"),
              Tab(icon: Icon(Icons.directions_walk), text: "Paseador"),
              Tab(icon: Icon(Icons.person), text: "Perfil"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            MascotasTab(
              userData: widget.userData,
              mascotas: _listaMascotas,
            ),
            PaseadoresTab(
              userData: widget.userData,
              mascotas: _listaMascotas,
            ),
            PerfilTab(
              userData: widget.userData,
            ),
          ],
        ),
      ),
    );
  }
}
