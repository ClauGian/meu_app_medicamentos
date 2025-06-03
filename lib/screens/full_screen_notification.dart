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

class FullScreenNotificationState extends State<FullScreenNotification> with SingleTickerProviderStateMixin {
  AnimationController? _animationController;
  Animation<double>? _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(_animationController!);
    _animationController!.forward();

    if (widget.audioPlayer != null) {
      try {
        widget.audioPlayer!.setSource(AssetSource('sounds/alarm.mp3'));
        widget.audioPlayer!.setVolume(1.0);
        widget.audioPlayer!.setReleaseMode(ReleaseMode.loop);
        widget.audioPlayer!.resume();
        print('DEBUG: Som do alarme iniciado');
      } catch (e) {
        print('DEBUG: Erro ao iniciar som do alarme: $e');
      }
    }
  }

  @override
  void dispose() {
    if (widget.audioPlayer != null) {
      try {
        widget.audioPlayer!.stop();
        print('DEBUG: Som do alarme parado no dispose');
      } catch (e) {
        print('DEBUG: Erro ao parar som do alarme: $e');
      }
    }
    _animationController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromRGBO(224, 245, 224, 1),
      body: FadeTransition(
        opacity: _fadeAnimation!,
        child: Container(
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
                      try {
                        await widget.audioPlayer!.stop();
                        print('DEBUG: Som do alarme parado ao clicar em Ver');
                      } catch (e) {
                        print('DEBUG: Erro ao parar som do alarme: $e');
                      }
                    }
                    widget.onClose?.call();
                    try {
                      await Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => MedicationAlertScreen(
                            horario: widget.horario,
                            medicationIds: widget.medicationIds,
                            database: widget.database,
                          ),
                        ),
                      );
                    } catch (e) {
                      print('DEBUG: Erro ao navegar para MedicationAlertScreen: $e');
                    }
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
      ),
    );
  }
}