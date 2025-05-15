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
    // Iniciar e tocar o som do alarme
    if (widget.audioPlayer != null) {
      try {
        widget.audioPlayer!.setSource(AssetSource('sounds/alarm.mp3'));
        widget.audioPlayer!.play(AssetSource('sounds/alarm.mp3'));
        print('DEBUG: Som do alarme iniciado');
      } catch (e) {
        print('DEBUG: Erro ao iniciar som do alarme: $e');
      }
    }
  }

  @override
  void dispose() {
    if (widget.audioPlayer != null) {
      widget.audioPlayer!.stop();
      print('DEBUG: Som do alarme parado no dispose');
    }
    widget.onClose?.call();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromRGBO(224, 245, 224, 1),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color.fromRGBO(0, 105, 148, 1),
              Color.fromRGBO(173, 216, 230, 1),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.alarm_on_rounded,
                color: Colors.white,
                size: 100,
              ),
              const SizedBox(height: 20),
              const Text(
                'Hora do Medicamento',
                style: TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  shadows: [
                    Shadow(
                      offset: Offset(2, 2),
                      blurRadius: 4,
                      color: Colors.black38,
                    ),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: () async {
                  if (widget.audioPlayer != null) {
                    await widget.audioPlayer!.stop();
                    print('DEBUG: Som do alarme parado ao clicar em Ver');
                  }
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
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color.fromRGBO(0, 105, 148, 1),
                  padding: const EdgeInsets.symmetric(horizontal: 60, vertical: 20),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  elevation: 8,
                  shadowColor: Colors.black45,
                ),
                child: const Text(
                  'Ver',
                  style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}