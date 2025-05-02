import 'package:flutter/material.dart';
import 'home_screen.dart'; // Vamos criar esse arquivo depois
import 'package:sqflite/sqflite.dart';
import 'package:medialerta/notification_service.dart';

class WelcomeScreen extends StatelessWidget {
  final Database database;

  const WelcomeScreen({super.key, required this.database});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFCCCCCC),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 40),
              RichText(
                text: const TextSpan(
                  children: [
                    TextSpan(
                      text: 'Medi',
                      style: TextStyle(
                        color: Color.fromRGBO(0, 105, 148, 1),
                        fontSize: 56,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextSpan(
                      text: 'Alerta',
                      style: TextStyle(
                        color: Color.fromRGBO(85, 170, 85, 1),
                        fontSize: 56,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
              Image.asset(
                'assets/imagem_senhora.png',
                height: MediaQuery.of(context).size.height * 0.40,
              ),
              const SizedBox(height: 30),
              const Text(
                'Seu remédio na hora certa.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color.fromRGBO(0, 85, 128, 1),
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 60),
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => HomeScreen(database: database)),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromRGBO(0, 105, 148, 1),
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                ),
                child: const Text(
                  "Começar",
                  style: TextStyle(fontSize: 24, color: Colors.white),
                ),
              ),
              const SizedBox(height: 20), // Espaço entre os botões
              ElevatedButton(
                onPressed: () async {
                  try {
                    // Busca o primeiro medicamento do banco
                    final medications = await database.query('medications', limit: 1);
                    if (medications.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Nenhum medicamento cadastrado!')),
                      );
                      return;
                    }
                    final medicationId = medications[0]['id'].toString();
                    
                    // Agenda a notificação com o ID do medicamento
                    await NotificationService().scheduleNotification(
                      id: 1,
                      title: 'Hora do Medicamento',
                      body: 'Medicamentos às 08:00',
                      sound: null,
                      payload: medicationId,
                      scheduledTime: DateTime.now().add(Duration(seconds: 5)),
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Notificação agendada para 5 segundos!')),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Erro ao agendar notificação: $e')),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromRGBO(85, 170, 85, 1),
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                ),
                child: const Text(
                  "Testar Notificação",
                  style: TextStyle(fontSize: 24, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}