import 'package:flutter/material.dart';
import 'welcome_screen.dart'; // Apenas a tela de boas-vindas por enquanto

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Meu App de Medicamentos',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const WelcomeScreen(), // Tela inicial direta, sem rotas por agora
    );
  }
}