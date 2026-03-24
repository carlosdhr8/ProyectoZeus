import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'welcome_page.dart';
import 'register_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;

  Future<void> _login() async {
    setState(() { _isLoading = true; });
    
    // Cambia esta IP por la de tu PC si usas tablet física
    const String url = "http://18.223.214.78:8000/login";

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "email": _emailController.text,
          "password": _passwordController.text,
        }),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        if (!mounted) return;

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => WelcomePage(
              userData: data['user_data'],
              mascotas: data['mascotas'],
            ),
          ),
        );
      } else {
        _mostrarMensaje("Credenciales incorrectas ⚡");
      }
    } catch (e) {
      _mostrarMensaje("Error de conexión con el servidor");
    } finally {
      if (mounted) setState(() { _isLoading = false; });
    }
  }

  void _mostrarMensaje(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje), backgroundColor: Theme.of(context).colorScheme.error),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo o Icono Principal Fuerte
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFF1E211F), width: 3),
                      boxShadow: const [
                        BoxShadow(color: Color(0xFF1E211F), offset: Offset(4, 4)),
                      ],
                    ),
                    child: Icon(Icons.bolt, size: 80, color: Theme.of(context).colorScheme.secondary),
                  ),
                  const SizedBox(height: 24),
                  
                  // Título Fuerte
                  Text(
                    "ZEUSPET",
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                      color: Theme.of(context).colorScheme.primary,
                      shadows: const [
                        Shadow(color: Color(0xFF1E211F), offset: Offset(2, 2)),
                      ],
                    ),
                  ),
                  Text(
                    "BIENESTAR CANINO",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                      color: Theme.of(context).colorScheme.secondary,
                      shadows: const [
                        Shadow(color: Color(0xFF1E211F), offset: Offset(1, 1)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),

                  // Campos de Texto con "Fuerza" estilo cómic
                  TextFormField(
                    controller: _emailController,
                    decoration: InputDecoration(
                      labelText: 'CORREO ELECTRÓNICO',
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
                      prefixIcon: Icon(Icons.email, color: Theme.of(context).colorScheme.primary),
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'CONTRASEÑA',
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
                      prefixIcon: Icon(Icons.lock, color: Theme.of(context).colorScheme.primary),
                    ),
                  ),
                  const SizedBox(height: 35),

                  // Botón de Ingreso Estilo Zeus
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
                          onPressed: () {
                            if (_formKey.currentState!.validate()) _login();
                          },
                          child: const FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text('INGRESAR AL OLIMPO', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 25),
                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const RegisterPage()),
                          );
                        },
                        child: Text(
                          "¿Eres nuevo? Regístrate aquí", 
                          style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 15)
                        ),
                      ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}