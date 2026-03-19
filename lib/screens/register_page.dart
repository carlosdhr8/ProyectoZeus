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
          SnackBar(
            content: const Text("¡Bienvenido al Olimpo! Ya puedes iniciar sesión.", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
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
      SnackBar(content: Text(mensaje, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)), backgroundColor: Theme.of(context).colorScheme.error),
    );
  }

  // Helper para crear TextFormFields estilo cómic/fuerte
  Widget _buildZeusField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isPassword = false,
    TextInputType type = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextFormField(
        controller: controller,
        obscureText: isPassword,
        keyboardType: type,
        validator: validator,
        decoration: InputDecoration(
          labelText: label.toUpperCase(),
          labelStyle: const TextStyle(fontWeight: FontWeight.bold),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF1E211F), width: 2),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF1E211F), width: 2),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 3),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Theme.of(context).colorScheme.error, width: 2),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Theme.of(context).colorScheme.error, width: 3),
          ),
          prefixIcon: Icon(icon, color: Theme.of(context).colorScheme.primary),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("ÚNETE AL OLIMPO", style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1)),
        backgroundColor: Theme.of(context).colorScheme.primary,
        centerTitle: true,
        elevation: 0,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.secondary,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF1E211F), width: 3),
              boxShadow: const [
                BoxShadow(color: Color(0xFF1E211F), offset: Offset(6, 6)),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(17),
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      // Icono / Encabezado
                      Container(
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFF1E211F), width: 3),
                        ),
                        child: Icon(Icons.person_add, size: 50, color: Theme.of(context).colorScheme.secondary),
                      ),
                      const SizedBox(height: 24),

                      _buildZeusField(
                        controller: _nombreCtrl,
                        label: "Nombre Completo",
                        icon: Icons.person,
                        validator: (v) => v!.isEmpty ? "Campo requerido" : null,
                      ),
                      _buildZeusField(
                        controller: _emailCtrl,
                        label: "Correo Electrónico",
                        icon: Icons.email,
                        validator: (v) => v!.contains("@") ? null : "Email inválido",
                      ),
                      _buildZeusField(
                        controller: _passCtrl,
                        label: "Contraseña",
                        icon: Icons.lock,
                        isPassword: true,
                        validator: (v) => v!.length < 4 ? "Mínimo 4 caracteres" : null,
                      ),
                      _buildZeusField(
                        controller: _edadCtrl,
                        label: "Edad",
                        icon: Icons.cake,
                        type: TextInputType.number,
                      ),
                      _buildZeusField(
                        controller: _residenciaCtrl,
                        label: "Lugar de Residencia",
                        icon: Icons.map,
                      ),
                      const SizedBox(height: 20),
                      
                      _isLoading 
                        ? CircularProgressIndicator(color: Theme.of(context).colorScheme.primary)
                        : Container(
                            width: double.infinity,
                            height: 55,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: const [
                                BoxShadow(color: Color(0xFF1E211F), offset: Offset(4, 4)),
                              ],
                            ),
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Theme.of(context).colorScheme.secondary,
                                foregroundColor: const Color(0xFF1E211F),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: const BorderSide(color: Color(0xFF1E211F), width: 2),
                                ),
                              ),
                              onPressed: _registrar,
                              child: const Text("CREAR CUENTA ZEUS", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1)),
                            ),
                          ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}