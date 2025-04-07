import 'package:flutter/material.dart';
import 'app_original.dart' show WelcomeScreen; // Importa WelcomeScreen


void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Meu App Medicamentos',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const WelcomeScreen(), // Usa a WelcomeScreen como home
    );
  }
}