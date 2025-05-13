import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:audioplayers/audioplayers.dart';
import 'medication_alert_screen.dart';

class FullScreenNotification extends StatefulWidget {
  final String horario;
  final List<String> medicationIds;
  final Database database;
  final AudioPlayer? audioPlayer;
  final VoidCallback? onClose;

  const FullScreenNotification({
    super.key,
    required this.horario,
    required this.medicationIds,
    required this.database,
    this.audioPlayer,
    this.onClose,
  });

  @override
  FullScreenNotificationState createState() => FullScreenNotificationState();
}

class FullScreenNotificationState extends State<FullScreenNotification> {
  @override
  void initState() {
    super.initState();
    // Parar o som do alarme quando a tela abrir
    if (widget.audioPlayer != null) {
      widget.audioPlayer!.setReleaseMode(ReleaseMode.stop);
      widget.audioPlayer!.stop();
      print('DEBUG: Som do alarme parado ao abrir FullScreenNotification');
    }
  }

  @override
  void dispose() {
    // Chamar onClose ao fechar a tela
    widget.onClose?.call();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromRGBO(224, 245, 224, 1),
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
                // Parar o som do alarme (por segurança, caso initState falhe)
                if (widget.audioPlayer != null) {
                  await widget.audioPlayer!.stop();
                  print('DEBUG: Som do alarme parado ao clicar em Ver');
                }
                // Navegar para MedicationAlertScreen e remover a tela cheia
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => MedicationAlertScreen(
                      horario: widget.horario,
                      medicationIds: widget.medicationIds,
                      database: widget.database,
                    ),
                  ),
                );
                // Chamar onClose ao navegar
                widget.onClose?.call();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromRGBO(0, 105, 148, 1),
                padding: const EdgeInsets.symmetric(horizontal: 60, vertical: 20),
              ),
              child: const Text(
                'Ver',
                style: TextStyle(fontSize: 30, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}