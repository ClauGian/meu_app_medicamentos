import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'package:sqflite/sqflite.dart';
import '../notification_service.dart';

class WelcomeScreen extends StatelessWidget {
  final Database database;
  final NotificationService notificationService;

  const WelcomeScreen({
    super.key,
    required this.database,
    required this.notificationService,
  });

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
                    final medications = await database.query(
                      'medications',
                      where: 'horarios LIKE ?',
                      whereArgs: ['%08:00%'],
                    );
                    print('DEBUG: Medicamentos carregados do banco: $medications');
                    if (medications.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Nenhum medicamento encontrado para 08:00!')),
                      );
                      return;
                    }

                    final medicationIds = medications.map((med) => med['id'].toString()).toList();
                    final payload = '08:00|${medicationIds.join(',')}';
                    print('DEBUG: Payload gerado: $payload');

                    final notificationId = DateTime.now().millisecondsSinceEpoch % 10000;

                    await notificationService.cancelAllNotifications();

                    // Testar com showNotification em vez de scheduleNotification
                    await notificationService.showNotification(
                      id: notificationId,
                      title: 'Hora do Medicamento',
                      body: 'Toque para ver os medicamentos',
                      sound: 'alarm', 
                      payload: payload,
                    );

                    final pendingNotifications = await notificationService.getPendingNotifications();
                    print('DEBUG: Notificações pendentes imediatamente após agendamento: ${pendingNotifications.length}');
                    for (var notification in pendingNotifications) {
                      print('DEBUG: Pendente - ID: ${notification.id}, Title: ${notification.title}, Payload: ${notification.payload}');
                    }

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Teste iniciado: notificação exibida!')),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Erro: $e')),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromRGBO(85, 170, 85, 1),
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                ),
                child: const Text(
                  'Testar Notificação',
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