import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import '../notification_service.dart';
import 'welcome_screen.dart';

class LoadingScreen extends StatefulWidget {
  final Database database;
  final NotificationService notificationService;

  const LoadingScreen({
    super.key,
    required this.database,
    required this.notificationService,
  });

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen> {
  @override
  void initState() {
    super.initState();
    print('DEBUG: LoadingScreen initState');
    
    // Aguardar 1 segundo e navegar para WelcomeScreen
    // (se tiver dados de notificação, o MethodChannel vai navegar antes)
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        print('DEBUG: LoadingScreen navegando para WelcomeScreen');
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => WelcomeScreen(
              database: widget.database,
              notificationService: widget.notificationService,
            ),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFFCCCCCC),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              color: Color.fromRGBO(0, 105, 148, 1),
            ),
            SizedBox(height: 20),
            Text(
              'Carregando...',
              style: TextStyle(
                color: Color.fromRGBO(0, 85, 128, 1),
                fontSize: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }
}