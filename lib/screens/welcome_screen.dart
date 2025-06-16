import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'home_screen.dart';
import 'notification_service.dart'; // Adicionada importação
import 'daily_alerts_screen.dart';

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
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MediAlerta'),
        backgroundColor: const Color.fromRGBO(85, 170, 85, 1),
        centerTitle: true,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/logo.png',
              height: 150,
            ),
            const SizedBox(height: 20),
            const Text(
              'Bem-vindo ao MediAlerta!',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 40),
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
                backgroundColor: const Color.fromRGBO(85, 170, 85, 1),
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
              ),
              child: const Text(
                'Gerenciar Medicamentos',
                style: TextStyle(fontSize: 24, color: Colors.white),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                try {
                  // Verificar se os medicamentos de teste já existem
                  final existingMeds = await widget.database.query(
                    'medications',
                    where: 'nome = ?',
                    whereArgs: ['Teste Medicamento 1'],
                  );
                  if (existingMeds.isEmpty) {
                    await widget.database.insert('medications', {
                      'nome': 'Teste Medicamento 1',
                      'quantidade': 30,
                      'dosagem_diaria': 2,
                      'horarios': '08:00,20:00',
                      'tipo_medicamento': 'Comprimido',
                      'frequencia': 'Diária',
                      'startDate': '2025-06-16',
                      'isContinuous': 1,
                      'skip_count': 0,
                    });
                    await widget.database.insert('medications', {
                      'nome': 'Teste Medicamento 2',
                      'quantidade': 20,
                      'dosagem_diaria': 1,
                      'horarios': '08:00',
                      'tipo_medicamento': 'Cápsula',
                      'frequencia': 'Diária',
                      'startDate': '2025-06-16',
                      'isContinuous': 1,
                      'skip_count': 0,
                    });
                    print("DEBUG: Medicamentos de teste inseridos com sucesso.");
                  } else {
                    print("DEBUG: Medicamentos de teste já existem, pulando inserção.");
                  }

                  // Usar IDs fixos para teste
                  final List<String> medicationIds = ['1', '2']; // IDs gerados pelo AUTOINCREMENT
                  final payload = '08:00|${medicationIds.join(',')}';
                  print('DEBUG: Payload gerado: $payload');

                  if (medicationIds.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Nenhum medicamento configurado para teste!')),
                    );
                    return;
                  }

                  final notificationId = DateTime.now().millisecondsSinceEpoch % 10000;

                  await widget.notificationService.cancelAllNotifications();

                  print('DEBUG: Aguardando 10 segundos antes de disparar a notificação');
                  await Future.delayed(const Duration(seconds: 10));
                  print('DEBUG: Disparando notificação após atraso');

                  await widget.notificationService.showNotification(
                    id: notificationId,
                    title: 'Hora do Medicamento',
                    body: 'Toque para ver os medicamentos',
                    sound: 'alarm',
                    payload: payload,
                  );

                  final pendingNotifications = await widget.notificationService.getPendingNotifications();
                  print('DEBUG: Notificações pendentes imediatamente após agendamento: ${pendingNotifications.length}');
                  for (var notification in pendingNotifications) {
                    print('DEBUG: Pendente - ID: ${notification.id}, Title: ${notification.title}, Payload: ${notification.payload}');
                  }

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Teste iniciado: notificação agendada para 10 segundos!')),
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
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => DailyAlertsScreen(
                      database: widget.database,
                      notificationService: widget.notificationService,
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromRGBO(85, 170, 85, 1),
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
              ),
              child: const Text(
                'Alertas Diários',
                style: TextStyle(fontSize: 24, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}