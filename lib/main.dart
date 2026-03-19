import 'package:flutter/material.dart';
import 'screens/login_page.dart';

// PALETA DE COLORES
const Color zeusGreen = Color(0xFF166948); // Verde Zeus (Primario)
const Color zeusYellow = Color(0xFFFDE056); // Amarillo Zeus (Acento)
const Color zeusBackground = Color(0xFFF9F6ED); // Crema claro
const Color zeusTextDark = Color(0xFF1E211F); // Texto oscuro suave
const Color zeusTextLight = Color(0xFF5A635C); // Texto secundario

final ThemeData zeusPetTheme = ThemeData(
  useMaterial3: true,
  scaffoldBackgroundColor: zeusBackground,
  colorScheme: ColorScheme.fromSeed(
    seedColor: zeusGreen,
    primary: zeusGreen,
    secondary: zeusYellow,
    surface: Colors.white,
    error: const Color(0xFFD32F2F),
    onPrimary: Colors.white,
    onSecondary: zeusTextDark,
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: zeusGreen,
    foregroundColor: Colors.white,
    centerTitle: true,
    elevation: 0,
    scrolledUnderElevation: 2,
    iconTheme: IconThemeData(color: Colors.white),
    titleTextStyle: TextStyle(
      fontSize: 22,
      fontWeight: FontWeight.w600,
      color: Colors.white,
      letterSpacing: 0.5,
    ),
  ),
  cardTheme: CardThemeData(
    color: Colors.white,
    elevation: 3,
    shadowColor: zeusGreen.withOpacity(0.15),
    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: BorderSide(color: zeusGreen.withOpacity(0.1), width: 1),
    ),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: zeusGreen,
      foregroundColor: Colors.white,
      elevation: 2,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      textStyle: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
      ),
    ),
  ),
  textTheme: const TextTheme(
    displayLarge: TextStyle(color: zeusTextDark, fontWeight: FontWeight.bold),
    titleLarge: TextStyle(color: zeusTextDark, fontWeight: FontWeight.w700),
    titleMedium: TextStyle(color: zeusTextDark, fontWeight: FontWeight.w600),
    bodyLarge: TextStyle(color: zeusTextDark, fontSize: 16),
    bodyMedium: TextStyle(color: zeusTextLight, fontSize: 14),
    labelLarge: TextStyle(color: zeusGreen, fontWeight: FontWeight.w600),
  ),
  tabBarTheme: const TabBarThemeData(
    labelColor: zeusYellow,
    unselectedLabelColor: Colors.white70,
    indicatorColor: zeusYellow,
    indicatorSize: TabBarIndicatorSize.tab,
  ),
  iconTheme: const IconThemeData(color: zeusGreen),
);

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Zeus App',
      theme: zeusPetTheme,
      home: const LoginPage(),
    );
  }
}
