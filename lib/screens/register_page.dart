import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _passCtrl = TextEditingController();
  final TextEditingController _nombreCtrl = TextEditingController();
  final TextEditingController _residenciaCtrl = TextEditingController();
  final TextEditingController _edadCtrl = TextEditingController();
  bool _isLoading = false;

  Future<void> _registrar() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    // Usamos la misma IP de tu servidor
    const String url = "http://18.223.214.78:8000/register";

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "email": _emailCtrl.text,
          "password": _passCtrl.text,
          "nombre_completo": _nombreCtrl.text,
          "edad": int.parse(_edadCtrl.text),
          "lugar_residencia": _residenciaCtrl.text,
        }),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("¡Bienvenido al Olimpo! Ya puedes iniciar sesión."), backgroundColor: Colors.green),
        );
        Navigator.pop(context); // Volver al Login
      } else {
        final error = jsonDecode(response.body);
        _mostrarMensaje(error['detail'] ?? "Error al registrar");
      }
    } catch (e) {
      _mostrarMensaje("Error de conexión con el servidor");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _mostrarMensaje(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje), backgroundColor: Colors.redAccent),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.green[500],
      appBar: AppBar(title: const Text("Únete a Zeus App")),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(25),
          child: Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    const Icon(Icons.person_add, size: 50, color: Colors.green),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _nombreCtrl,
                      decoration: const InputDecoration(labelText: "Nombre Completo", prefixIcon: Icon(Icons.person)),
                      validator: (v) => v!.isEmpty ? "Campo requerido" : null,
                    ),
                    TextFormField(
                      controller: _emailCtrl,
                      decoration: const InputDecoration(labelText: "Correo Electrónico", prefixIcon: Icon(Icons.email)),
                      validator: (v) => v!.contains("@") ? null : "Email inválido",
                    ),
                    TextFormField(
                      controller: _passCtrl,
                      decoration: const InputDecoration(labelText: "Contraseña", prefixIcon: Icon(Icons.lock)),
                      obscureText: true,
                      validator: (v) => v!.length < 4 ? "Mínimo 4 caracteres" : null,
                    ),
                    TextFormField(
                      controller: _edadCtrl,
                      decoration: const InputDecoration(labelText: "Edad", prefixIcon: Icon(Icons.cake)),
                      keyboardType: TextInputType.number,
                    ),
                    TextFormField(
                      controller: _residenciaCtrl,
                      decoration: const InputDecoration(labelText: "Lugar de Residencia", prefixIcon: Icon(Icons.map)),
                    ),
                    const SizedBox(height: 30),
                    _isLoading 
                      ? const CircularProgressIndicator()
                      : ElevatedButton(
                          style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                          onPressed: _registrar, 
                          child: const Text("Crear Cuenta"),
                        ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}