import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:audioplayers/audioplayers.dart';
import 'medication_alert_screen.dart';

class FullScreenNotification extends StatelessWidget {
  final String horario;
  final List<String> medicationIds;
  final Database database;
  final AudioPlayer? audioPlayer;

  FullScreenNotification({
    super.key,
    required this.horario,
    required this.medicationIds,
    required this.database,
    this.audioPlayer,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color.fromRGBO(204, 248, 204, 1),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Hora do Medicamento',
              style: TextStyle(
                fontSize: 40,
                fontWeight: FontWeight.bold,
                color: Color.fromRGBO(0, 105, 148, 1),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: () async {
                // Parar o som do alarme
                if (audioPlayer != null) {
                  await audioPlayer!.stop();
                  print('DEBUG: Som do alarme parado');
                }
                // Navegar para MedicationAlertScreen e remover a tela cheia
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => MedicationAlertScreen(
                      horario: horario,
                      medicationIds: medicationIds,
                      database: database,
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4CAF50),
                padding: const EdgeInsets.symmetric(horizontal: 60, vertical: 20),
              ),
              child: const Text(
                'Ver',
                style: TextStyle(fontSize: 24, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}