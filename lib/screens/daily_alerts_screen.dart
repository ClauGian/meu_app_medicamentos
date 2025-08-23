import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import '../notification_service.dart';
import 'medication_alert_screen.dart';
import 'dart:ui';

class DailyAlertsScreen extends StatefulWidget {
  final Database database;
  final NotificationService notificationService;

  const DailyAlertsScreen({
    super.key,
    required this.database,
    required this.notificationService,
  });

  @override
  DailyAlertsScreenState createState() => DailyAlertsScreenState();
}

class DailyAlertsScreenState extends State<DailyAlertsScreen> {
  Future<Map<String, List<Map<String, dynamic>>>> _getGroupedDailyAlerts() async {
    final startTime = DateTime.now();
    try {
      final medications = await widget.database.query(
        'medications',
        where: 'horarios IS NOT NULL AND horarios != ? AND (isContinuous = ? OR startDate <= ?)',
        whereArgs: ['', 1, DateTime.now().toIso8601String()],
      );
      print('DEBUG: Medicamentos buscados: $medications');

      final Map<String, List<Map<String, dynamic>>> grouped = {};

      for (var med in medications) {
        final horariosStr = med['horarios'] as String? ?? '';
        if (horariosStr.trim().isEmpty) continue;

        final horarios = horariosStr.split(',').map((h) => h.trim()).toList();
        final startDate = DateTime.parse(med['startDate'] as String);
        final isContinuous = (med['isContinuous'] as int?) == 1;

        if (isContinuous || startDate.isBefore(DateTime.now())) {
          for (var horario in horarios) {
            grouped.putIfAbsent(horario, () => []).add(med);
          }
        }
      }

      final sortedKeys = grouped.keys.toList()..sort();
      final Map<String, List<Map<String, dynamic>>> sortedGrouped = {
        for (var key in sortedKeys) key: grouped[key]!
      };

      print('DEBUG: Tempo de _getGroupedDailyAlerts: ${DateTime.now().difference(startTime).inMilliseconds}ms');
      return sortedGrouped;
    } catch (e, stackTrace) {
      print('DEBUG: Erro em _getGroupedDailyAlerts: $e');
      print('DEBUG: StackTrace: $stackTrace');
      return {};
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFCCCCCC),
        elevation: 0,
        centerTitle: true,
        toolbarHeight: 110,
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
                  color: const Color(0xFFEFEFEF),
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
                        

                        return GestureDetector(
                          onTap: () {
                            final rootIsolateToken = RootIsolateToken.instance;
                            if (rootIsolateToken == null) {
                              print('DEBUG: ERRO: RootIsolateToken.instance retornou null em daily_alerts_screen.dart');
                              throw Exception('RootIsolateToken.instance retornou null. Verifique a versão do Flutter ou o contexto da aplicação.');
                            }
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => MedicationAlertScreen(
                                  horario: horario,
                                  medicationIds: [id],
                                  database: widget.database,
                                  notificationService: widget.notificationService,
                                  rootIsolateToken: rootIsolateToken,
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
                                color: Color.fromRGBO(0, 105, 148, 1),
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
}