import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'dart:io';
import '../notification_service.dart'; // Importar o NotificationService

class MedicationAlertScreen extends StatefulWidget {
  final String horario;
  final List<String> medicationIds;
  final Database database;

  const MedicationAlertScreen({
    super.key,
    required this.horario,
    required this.medicationIds,
    required this.database,
  });

  @override
  MedicationAlertScreenState createState() => MedicationAlertScreenState();
}

class MedicationAlertScreenState extends State<MedicationAlertScreen> {
  final NotificationService notificationService = NotificationService();
  List<Map<String, dynamic>> medications = [];
  List<bool> isTaken = [];
  List<bool> isSkipped = []; // Novo estado para indicar se o medicamento foi pulado

  @override
  void initState() {
    super.initState();
    _fetchMedications();
  }

  Future<void> _fetchMedications() async {
    final List<Map<String, dynamic>> meds = [];
    for (var id in widget.medicationIds) {
      final result = await widget.database.query(
        'medications',
        where: 'id = ?',
        whereArgs: [id],
      );
      if (result.isNotEmpty) {
        meds.add(result[0]);
      }
    }
    setState(() {
      medications = meds;
      isTaken = List<bool>.filled(meds.length, false);
      isSkipped = List<bool>.filled(meds.length, false);
    });
  }

  void _checkAndCloseIfDone() {
    // Verifica se todos os medicamentos foram processados (tomados, adiados ou pulados)
    bool allProcessed = true;
    for (int i = 0; i < medications.length; i++) {
      if (!isTaken[i] && !isSkipped[i] && medications[i].isNotEmpty) {
        allProcessed = false;
        break;
      }
    }
    if (allProcessed && mounted) {
      Navigator.pop(context);
    }
  }

  Future<void> _handleTake(int index) async {
    final medication = Map<String, dynamic>.from(medications[index]);
    final quantidadeTotal = medication['quantidade'] as int;
    final dosagemDiaria = medication['dosagem_diaria'] as int;
    final horarios = (medication['horarios'] as String).split(',');
    final dosePorAlarme = dosagemDiaria ~/ horarios.length;
    final novaQuantidade = quantidadeTotal - dosePorAlarme;

    await widget.database.update(
      'medications',
      {'quantidade': novaQuantidade},
      where: 'id = ?',
      whereArgs: [medication['id']],
    );
    print('DEBUG: Nova quantidade após atualização: $novaQuantidade');

    if (novaQuantidade <= dosagemDiaria * 2) {
      await notificationService.showNotification(
        id: 999,
        title: 'Estoque Baixo',
        body: 'Restam poucos comprimidos de ${medication['nome']}. Reabasteça!',
        sound: 'alarm',
        payload: '',
      );
    }

    setState(() {
      medications[index] = medication..['quantidade'] = novaQuantidade;
      isTaken[index] = true;
    });

    _checkAndCloseIfDone();
  }

  void _showDelayOptions(int index, BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Adiar Alarme"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text("15 minutos"),
              onTap: () => _handleDelay(index, context, 15),
            ),
            ListTile(
              title: const Text("30 minutos"),
              onTap: () => _handleDelay(index, context, 30),
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

  Future<void> _handleDelay(int index, BuildContext context, int minutes) async {
    final remainingIds = <String>[];
    for (int i = 0; i < medications.length; i++) {
      if (i != index && !isTaken[i] && !isSkipped[i]) {
        remainingIds.add(medications[i]['id'].toString());
      }
    }

    final now = DateTime.now();
    final newTime = now.add(Duration(minutes: minutes));

    // Agenda uma nova notificação com os IDs restantes
    if (remainingIds.isNotEmpty) {
      final payload = '${widget.horario}|${remainingIds.join(',')}';
      await notificationService.scheduleNotification(
        id: DateTime.now().millisecondsSinceEpoch % 10000,
        title: 'Alerta de Medicamento: ${widget.horario}',
        body: 'Você tem ${remainingIds.length} medicamentos para tomar',
        payload: payload,
        sound: 'alarm',
        scheduledTime: newTime,
      );
    }

    setState(() {
      medications[index] = <String, dynamic>{}; // Remove o medicamento da lista
      Navigator.pop(context); // Fecha o diálogo
      _checkAndCloseIfDone();
    });
  }

  Future<void> _handleSkip(int index) async {
    final medication = Map<String, dynamic>.from(medications[index]);
    final skipCount = (medication['skip_count'] as int) + 1;
    await widget.database.update(
      'medications',
      {'skip_count': skipCount},
      where: 'id = ?',
      whereArgs: [medication['id']],
    );

    // Verifica se há um cuidador_id válido (não nulo e não zero)
    if (medication['cuidador_id'] != null && medication['cuidador_id'] != 0 && skipCount >= 2) {
      await notificationService.showNotification(
        id: 1000,
        title: 'Aviso ao Cuidador',
        body: 'Usuário pulou ${medication['nome']} 2 vezes!',
        sound: 'alarm',
        payload: '',
      );
      // TODO: Implementar notificação ao cuidador via Firebase (quando configurado)
    }

    setState(() {
      medications[index] = medication..['skip_count'] = skipCount;
      isSkipped[index] = true;
    });

    _checkAndCloseIfDone();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F0F0),
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
              Expanded(
                child: ListView.builder(
                  itemCount: medications.length,
                  itemBuilder: (context, index) {
                    final med = medications[index];
                    if (med.isEmpty) return const SizedBox.shrink(); // Esconde medicamentos adiados

                    final nome = med['nome'] as String;
                    final fotoPath = med['foto_embalagem'] as String? ?? '';
                    final dosagemDiaria = med['dosagem_diaria'] as int;
                    final horarios = (med['horarios'] as String).split(',');
                    final dosePorAlarme = dosagemDiaria ~/ horarios.length;
                    final doseFormatada = dosePorAlarme.toString();

                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.black45),
                        borderRadius: BorderRadius.circular(8),
                        color: const Color(0xFFEFEFEF),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Medicamento: $nome",
                            style: const TextStyle(fontSize: 18),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "Tomar: $doseFormatada comprimido(s)",
                            style: const TextStyle(fontSize: 18),
                          ),
                          const SizedBox(height: 16),
                          if (fotoPath.isNotEmpty)
                            Image.file(
                              File(fotoPath),
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
                                  backgroundColor: isTaken[index] ? Colors.grey : const Color(0xFF4CAF50),
                                ),
                                onPressed: isTaken[index] ? null : () => _handleTake(index),
                                child: const Text("Tomar"),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF2196F3),
                                ),
                                onPressed: () => _showDelayOptions(index, context),
                                child: const Text("Adiar"),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isSkipped[index] ? Colors.grey : Colors.red,
                                ),
                                onPressed: isSkipped[index] ? null : () => _handleSkip(index),
                                child: const Text("Pular"),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromRGBO(0, 105, 148, 1),
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                ),
                child: const Text(
                  "Fechar",
                  style: TextStyle(fontSize: 18, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}