import 'package:flutter/material.dart';
import 'screens/login_page.dart'; // Importante importar el archivo

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Zeus App',
      theme: ThemeData(primarySwatch: Colors.green),
      home: const LoginPage(), // Aquí llamamos a la página separada
    );
  }
}