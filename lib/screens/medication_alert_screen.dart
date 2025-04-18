import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:sqflite/sqflite.dart';
import 'dart:io';
import '../notification_service.dart'; // Importar o NotificationService

class MedicationAlertScreen extends StatefulWidget {
  final String medicationId;
  final String nome;
  final String dose;
  final String fotoPath;
  final String horario;
  final Database database;

  const MedicationAlertScreen({
    Key? key,
    required this.medicationId,
    required this.nome,
    required this.dose,
    required this.fotoPath,
    required this.horario,
    required this.database,
  }) : super(key: key);

  @override
  _MedicationAlertScreenState createState() => _MedicationAlertScreenState();
}

class _MedicationAlertScreenState extends State<MedicationAlertScreen> {
  final NotificationService notificationService = NotificationService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F0F0), // Cinza claro
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year} - ${widget.horario}",
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Text(
                "Medicamento: ${widget.nome}",
                style: const TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 8),
              Text(
                "Tomar: ${widget.dose}",
                style: const TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 16),
              if (widget.fotoPath.isNotEmpty)
                Image.file(
                  File(widget.fotoPath),
                  width: 100,
                  height: 100,
                  fit: BoxFit.cover,
                ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4CAF50), // Verde
                    ),
                    onPressed: () => _handleTake(context),
                    child: const Text("Tomar"),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2196F3), // Azul
                    ),
                    onPressed: () => _showDelayOptions(context),
                    child: const Text("Adiar"),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                    ),
                    onPressed: () => _handleSkip(context),
                    child: const Text("Pular"),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleTake(BuildContext context) async {
    final medication = await widget.database.query(
      'medications',
      where: 'id = ?',
      whereArgs: [widget.medicationId],
    );
    if (medication.isNotEmpty) {
      final quantidadeTotal = medication[0]['quantidade_total'] as int;
      final dosagemDiaria = medication[0]['dosagem_diaria'] as int;
      final horarios = (medication[0]['horarios'] as String).split(',');
      final dosePorAlarme = dosagemDiaria / horarios.length;

      final novaQuantidade = quantidadeTotal - dosePorAlarme;
      await widget.database.update(
        'medications',
        {'quantidade_total': novaQuantidade},
        where: 'id = ?',
        whereArgs: [widget.medicationId],
      );

      if (novaQuantidade <= dosagemDiaria * 2) {
        await notificationService.showNotification(
          id: 999,
          title: 'Estoque Baixo',
          body: 'Restam poucos comprimidos de ${widget.nome}. Reabasteça!',
          sound: 'alarm',
          payload: '',
        );
      }
    }

    Navigator.pop(context);
  }

  void _showDelayOptions(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Adiar Alarme"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text("15 minutos"),
              onTap: () => _handleDelay(context, 15),
            ),
            ListTile(
              title: const Text("30 minutos"),
              onTap: () => _handleDelay(context, 30),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancelar"),
          ),
        ],
      ),
    );
  }

  Future<void> _handleDelay(BuildContext context, int minutes) async {
    final now = DateTime.now();
    final newTime = now.add(Duration(minutes: minutes));

    await notificationService.scheduleNotification(
      id: widget.medicationId.hashCode,
      title: 'Lembrete: ${widget.nome}',
      body: 'Tomar: ${widget.dose}',
      sound: 'alarm',
      payload: widget.medicationId,
      scheduledTime: newTime,
    );

    Navigator.pop(context);
    Navigator.pop(context);
  }

  Future<void> _handleSkip(BuildContext context) async {
    final medication = await widget.database.query(
      'medications',
      where: 'id = ?',
      whereArgs: [widget.medicationId],
    );
    if (medication.isNotEmpty) {
      final skipCount = (medication[0]['skip_count'] as int) + 1;
      await widget.database.update(
        'medications',
        {'skip_count': skipCount},
        where: 'id = ?',
        whereArgs: [widget.medicationId],
      );

      if (medication[0]['cuidador_id'] != null && skipCount >= 2) {
        await notificationService.showNotification(
          id: 1000,
          title: 'Aviso ao Cuidador',
          body: 'Usuário pulou ${widget.nome} 2 vezes!',
          sound: 'alarm',
          payload: '',
        );
        // TODO: Implementar notificação ao cuidador via Firebase
        // Exemplo: await FirebaseFirestore.instance.collection('notifications').add({...});
      }
    }

    Navigator.pop(context);
  }
}