import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'home_screen.dart';
import '../notification_service.dart';


class WelcomeScreen extends StatefulWidget {
  final Database database;
  final NotificationService notificationService;

  const WelcomeScreen({
    super.key,
    required this.database,
    required this.notificationService,
  });

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  bool _isScheduling = false;

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
                errorBuilder: (context, error, stackTrace) {
                  print('DEBUG: Erro ao carregar asset: $error');
                  return const Icon(
                    Icons.error,
                    size: 150,
                    color: Colors.red,
                  );
                },
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
                    MaterialPageRoute(
                      builder: (context) => HomeScreen(
                        database: widget.database,
                        notificationService: widget.notificationService,
                      ),
                    ),
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
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () async {
                  if (_isScheduling) {
                    print('DEBUG: Agendamento em andamento, ignorando clique');
                    return;
                  }
                  _isScheduling = true;
                  try {
                    // 🔹 Cancelar todas as notificações pendentes
                    await widget.notificationService.cancelAllNotifications();
                    print('DEBUG: Todas as notificações pendentes canceladas antes do teste');

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Teste iniciado: notificação agendada para daqui 10 segundos!'),
                      ),
                    );

                    final medications = await widget.database.query(
                      'medications',
                      where: 'horarios LIKE ?',
                      whereArgs: ['%08:00%'],
                    );
                    print('DEBUG: Medicamentos carregados do banco: $medications');
                    if (medications.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Nenhum medicamento encontrado para 08:00!'),
                        ),
                      );
                      _isScheduling = false;
                      return;
                    }

                    final medicationIds = medications.map((med) => med['id'].toString()).toList();
                    final payload = '08:00|${medicationIds.join(',')}';
                    print('DEBUG: Payload gerado: $payload');

                    final timestamp = DateTime.now().millisecondsSinceEpoch;
                    final notificationId = (timestamp.hashCode ^ payload.hashCode).abs() % 1000000;

                    await widget.notificationService.scheduleNotification(
                      id: notificationId,
                      title: 'Alerta de Medicamento',
                      body: 'Você tem ${medicationIds.length} medicamentos para tomar',
                      payload: payload,
                      scheduledTime: DateTime.now().add(Duration(seconds: 10)),
                      sound: 'malta',
                    );

                    print('DEBUG: Notificação agendada para daqui 10 segundos');
                  } catch (e) {
                    print('DEBUG: Erro ao agendar notificação: $e');
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Erro ao agendar notificação: $e')),
                    );
                  } finally {
                    _isScheduling = false;
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