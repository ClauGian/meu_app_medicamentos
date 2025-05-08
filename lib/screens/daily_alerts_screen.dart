import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'medication_alert_screen.dart';

class DailyAlertsScreen extends StatelessWidget {
  final Database database;

  const DailyAlertsScreen({super.key, required this.database});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFCCCCCC),
        elevation: 0,
        centerTitle: true,
        toolbarHeight: 110, // Altura aumentada para acomodar as duas linhas
        title: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "Alertas",
              style: TextStyle(
                color: Color.fromRGBO(0, 105, 148, 1),
                fontSize: 36,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              "do Dia",
              style: TextStyle(
                color: Color.fromRGBO(85, 170, 85, 1),
                fontSize: 36,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
      backgroundColor: const Color(0xFFCCCCCC),
      body: FutureBuilder<Map<String, List<Map<String, dynamic>>>>(
        future: _getGroupedDailyAlerts(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('Nenhum alerta para hoje'));
          }

          final groupedAlerts = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.all(12),
            children: groupedAlerts.entries.map((entry) {
              final horario = entry.key;
              final medicamentos = entry.value;

              return Container(
                margin: const EdgeInsets.only(bottom: 30),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.black45),
                  borderRadius: BorderRadius.circular(8),
                  color: const Color(0xFFEFEFEF), // Fundo cinza claro
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        horario,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...medicamentos.map((med) {
                        final nome = med['nome'] as String;
                        final dosagemDiaria = med['dosagem_diaria'] as int;
                        final horarios = (med['horarios'] as String).split(',');
                        final dosePorAlarme = dosagemDiaria / horarios.length;
                        final doseFormatada = dosePorAlarme % 1 == 0
                            ? dosePorAlarme.toInt().toString()
                            : dosePorAlarme.toString();
                        final id = med['id'].toString();
                        final fotoPath = med['foto_embalagem'] as String? ?? '';

                        return GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => MedicationAlertScreen(
                                  horario: horario,
                                  medicationIds: [id], // Passa uma lista com o ID único
                                  database: database,
                                ),
                              ),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Text(
                              '• $nome  –  $doseFormatada  comprimido(s)',
                              style: const TextStyle(
                                fontSize: 18,
                                color: Color.fromRGBO(0, 105, 148, 1), // Azul escuro
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }

  Future<Map<String, List<Map<String, dynamic>>>> _getGroupedDailyAlerts() async {
    final medications = await database.query('medications');
    final today = DateTime.now();
    final Map<String, List<Map<String, dynamic>>> grouped = {};

    for (var med in medications) {
      final horariosStr = med['horarios'] as String;
      if (horariosStr.trim().isEmpty) continue;

      final horarios = horariosStr.split(',');
      final startDate = DateTime.parse(med['startDate'] as String);
      final isContinuous = med['isContinuous'] as int == 1;

      if (isContinuous || startDate.isBefore(today)) {
        for (var h in horarios) {
          final horario = h.trim();
          grouped.putIfAbsent(horario, () => []).add(med);
        }
      }
    }

    // Ordena os horários
    final sortedKeys = grouped.keys.toList()..sort((a, b) => a.compareTo(b));
    final Map<String, List<Map<String, dynamic>>> sortedGrouped = {
      for (var key in sortedKeys) key: grouped[key]!,
    };

    return sortedGrouped;
  }
}
