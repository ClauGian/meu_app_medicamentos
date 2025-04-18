import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'medication_alert_screen.dart';

class DailyAlertsScreen extends StatelessWidget {
  final Database database;

  const DailyAlertsScreen({Key? key, required this.database}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Alertas do Dia'),
        backgroundColor: const Color.fromRGBO(0, 105, 148, 1),
        foregroundColor: Colors.white,
      ),
      backgroundColor: const Color(0xFFCCCCCC),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _getDailyAlerts(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('Nenhum alerta para hoje'));
          }
          final alerts = snapshot.data!;
          return ListView.builder(
            itemCount: alerts.length,
            itemBuilder: (context, index) {
              final medication = alerts[index];
              final nome = medication['nome'] as String;
              final dosagemDiaria = medication['dosagem_diaria'] as int;
              final horarios = (medication['horarios'] as String).split(',');
              final dosePorAlarme = dosagemDiaria / horarios.length;
              final horario = horarios[0]; // Simplificado, ajustar conforme necessidade
              final id = medication['id'] as String;
              final fotoPath = medication['foto_embalagem'] as String? ?? '';
              return ListTile(
                title: Text(nome),
                subtitle: Text('Dose: $dosePorAlarme comprimido(s) | Horário: $horario'),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => MedicationAlertScreen(
                        medicationId: id,
                        nome: nome,
                        dose: '$dosePorAlarme comprimido(s)',
                        fotoPath: fotoPath,
                        horario: horario,
                        database: database,
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _getDailyAlerts() async {
    final medications = await database.query('medications');
    final today = DateTime.now();
    final dailyAlerts = <Map<String, dynamic>>[];
    for (var med in medications) {
      final horarios = (med['horarios'] as String).split(',');
      final startDate = DateTime.parse(med['startDate'] as String);
      final isContinuous = med['isContinuous'] as int == 1;
      // Simplificado: incluir medicamentos com horários e data válida
      if (horarios.isNotEmpty && (isContinuous || startDate.isBefore(today))) {
        dailyAlerts.add(med);
      }
    }
    return dailyAlerts;
  }
}