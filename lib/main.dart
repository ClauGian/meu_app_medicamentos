import 'package:flutter/material.dart';
import 'screens/welcome_screen.dart';
import 'notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized(); // Garante que o Flutter está inicializado
  await NotificationService().init(); // Inicializa o sistema de notificações
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MediAlerta', // Ajustado para o nome do app
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: const Color(0xFFF0F0F0), // Cinza claro, conforme usamos antes
      ),
      home: const WelcomeScreen(),
    );
  }
}