import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'dart:io';
import '../notification_service.dart';
import 'dart:async';
import 'package:flutter/services.dart';

// Movido para o nível superior
class FetchMedicationsParams {
  final List<String> medicationIds;
  final String horario;
  final Database database;
  final RootIsolateToken rootIsolateToken; // Adicionado

  FetchMedicationsParams(this.medicationIds, this.horario, this.database, this.rootIsolateToken);
}

class MedicationAlertScreen extends StatefulWidget {
  final String horario;
  final List<String> medicationIds;
  final Database database;
  final NotificationService notificationService;
  final RootIsolateToken rootIsolateToken; // Adicionado

  MedicationAlertScreen({
    super.key,
    required this.horario,
    required this.medicationIds,
    required this.database,
    required this.notificationService,
    required this.rootIsolateToken, // Adicionado
  }) {
    print('DEBUG: Construindo MedicationAlertScreen com horario=$horario, medicationIds=$medicationIds');
    if (medicationIds.isEmpty) {
      print('DEBUG: AVISO: medicationIds está vazio ao construir MedicationAlertScreen');
    }
  }

  @override
  MedicationAlertScreenState createState() => MedicationAlertScreenState();
}

class MedicationAlertScreenState extends State<MedicationAlertScreen> {
  List<Map<String, dynamic>> medications = [];
  List<bool> isTaken = [];
  List<bool> isSkipped = [];
  bool isLoading = true;

  static final List<Map<String, dynamic>> _pendingDelays = [];
  static Timer? _delayTimer;

  @override
  void initState() {
    super.initState();
    _fetchMedications();
  }


  static Future<List<Map<String, dynamic>>> _fetchMedicationsInIsolate(FetchMedicationsParams params) async {
    final startTime = DateTime.now();
    try {
      BackgroundIsolateBinaryMessenger.ensureInitialized(params.rootIsolateToken);
      print('DEBUG: BackgroundIsolateBinaryMessenger inicializado no Isolate');

      print('DEBUG: medicationIds recebidos no Isolate: ${params.medicationIds}');
      print('DEBUG: Tipo de medicationIds no Isolate: ${params.medicationIds.runtimeType}');

      List<Map<String, dynamic>> result;
      if (params.medicationIds.isEmpty) {
        print('DEBUG: Lista de medicationIds vazia, verificando medicamentos para o horário ${params.horario}');
        result = await params.database.query(
          'medications',
          where: 'horarios LIKE ?',
          whereArgs: ['%${params.horario}%'],
        );
        print('DEBUG: Medicamentos encontrados para horário ${params.horario}: $result');
      } else {
        final List<int> intMedicationIds = params.medicationIds.where((id) {
          try {
            int.parse(id);
            return true;
          } catch (e) {
            print('DEBUG: ID inválido ignorado: $id');
            return false;
          }
        }).map((id) {
          print('DEBUG: Convertendo ID no Isolate: $id');
          return int.parse(id);
        }).toList();
        print('DEBUG: IDs convertidos para inteiros no Isolate: $intMedicationIds');

        if (intMedicationIds.isEmpty) {
          print('DEBUG: Nenhum ID de medicamento válido, retornando lista vazia');
          return [];
        }

        result = await params.database.query(
          'medications',
          columns: ['id', 'nome', 'quantidade', 'dosagem_diaria', 'horarios', 'foto_embalagem', 'cuidador_id', 'skip_count'],
          where: 'id IN (${intMedicationIds.map((_) => '?').join(',')})',
          whereArgs: intMedicationIds,
        );
      }

      print('DEBUG: Medicamentos buscados no Isolate: $result');
      print('DEBUG: Tempo de _fetchMedicationsInIsolate: ${DateTime.now().difference(startTime).inMilliseconds}ms');
      return result;
    } catch (e, stackTrace) {
      print('DEBUG: Erro ao buscar medicamentos no Isolate: $e');
      print('DEBUG: StackTrace: $stackTrace');
      print('DEBUG: Tempo de _fetchMedicationsInIsolate (com erro): ${DateTime.now().difference(startTime).inMilliseconds}ms');
      return [];
    }
  }



  Future<void> _fetchMedications() async {
    final startTime = DateTime.now();
    try {
      final rootIsolateToken = RootIsolateToken.instance;
      if (rootIsolateToken == null) {
        throw Exception('RootIsolateToken.instance() retornou null. Verifique a versão do Flutter ou o contexto da aplicação.');
      }
      final params = FetchMedicationsParams(widget.medicationIds, widget.horario, widget.database, widget.rootIsolateToken);
      final result = await compute(_fetchMedicationsInIsolate, params);

      setState(() {
        medications = result;
        isTaken = List<bool>.filled(result.length, false);
        isSkipped = List<bool>.filled(result.length, false);
        isLoading = false;
      });
      print('DEBUG: _fetchMedications concluído, tempo total: ${DateTime.now().difference(startTime).inMilliseconds}ms');
    } catch (e, stackTrace) {
      print('DEBUG: Erro ao executar _fetchMedications no Isolate: $e');
      print('DEBUG: StackTrace: $stackTrace');
      setState(() {
        isLoading = false;
      });
    }
  }



  void _checkAndCloseIfDone() {
    bool allProcessed = true;
    for (int i = 0; i < medications.length; i++) {
      if (medications[i].isNotEmpty) {
        allProcessed = false;
        break;
      }
    }
    print('DEBUG: Medicamentos restantes: ${medications.length}');
    if (allProcessed && mounted) {
      print('DEBUG: Todos os medicamentos processados, fechando MedicationAlertScreen');
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
      await widget.notificationService.showNotification(
        id: 999,
        title: 'Estoque Baixo',
        body: 'Restam poucos comprimidos de ${medication['nome']}. Reabasteça!',
        sound: 'alarm',
        payload: '',
      );
    }

    setState(() {
      medications[index] = <String, dynamic>{};
      isTaken[index] = true;
      _checkAndCloseIfDone();
    });
  }

  Future<void> _handleDelay(int index, BuildContext context) async {
    final medicationId = medications[index]['id'].toString();
    final now = DateTime.now();

    _pendingDelays.add({
      'medicationId': medicationId,
      'horario': widget.horario,
      'timestamp': now,
    });

    _delayTimer?.cancel();

    _delayTimer = Timer(Duration(seconds: 10), () async {
      final recentDelays = _pendingDelays.where((delay) {
        return now.difference(delay['timestamp'] as DateTime).inSeconds <= 10;
      }).toList();

      final medicationIds = recentDelays
          .map((delay) => delay['medicationId'] as String)
          .toSet()
          .toList();

      if (medicationIds.isNotEmpty) {
        final newTime = DateTime.now().add(Duration(minutes: 15)); // 🔹 Delay de 15 minutos
        final payload = '${widget.horario}|${medicationIds.join(',')}';
        final notificationId = DateTime.now().millisecondsSinceEpoch % 10000;

        try {
          await widget.notificationService.scheduleNotification(
            id: notificationId,
            title: 'Alerta de Medicamento: ${widget.horario}',
            body: 'Você tem ${medicationIds.length} medicamentos adiados para tomar',
            payload: payload,
            sound: 'malta', // 🔹 Alterado de 'alarm' para 'malta'
            scheduledTime: newTime,
          );
          print('DEBUG: Notificação unificada agendada para ${medicationIds.length} medicamentos: $medicationIds');
          
          setState(() {
            medications.removeWhere((m) => medicationIds.contains(m['id'].toString()));
            _checkAndCloseIfDone();
          });
        } catch (e) {
          print('DEBUG: Erro ao agendar notificação unificada: $e');
        }
      }

      _pendingDelays.clear();
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
    print('DEBUG: Medicamento ${medication['nome']} pulado. Novo skip_count: $skipCount');

    final cuidadorId = medication['cuidador_id'];
    if (cuidadorId != null && cuidadorId.toString().isNotEmpty && cuidadorId.toString() != '0' && skipCount == 2) {
      print('DEBUG: Enviando notificação ao cuidador - Usuário pulou ${medication['nome']} 2 vezes (cuidador_id: $cuidadorId)');
      await widget.database.update(
        'medications',
        {'skip_count': 0},
        where: 'id = ?',
        whereArgs: [medication['id']],
      );
      print('DEBUG: skip_count resetado para 0 para o medicamento ${medication['nome']}');
    } else {
      print('DEBUG: Notificação ao cuidador não enviada - cuidador_id: $cuidadorId, skip_count: $skipCount');
    }

    setState(() {
      medications[index] = <String, dynamic>{};
      isSkipped[index] = true;
      _checkAndCloseIfDone();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F0F0),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year} - ${widget.horario}",
                      style: const TextStyle(color: Color.fromRGBO(0, 105, 148, 1), fontSize: 30, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: medications.isEmpty
                          ? const Center(child: Text('Nenhum medicamento encontrado', style: TextStyle(fontSize: 20)))
                          : ListView.builder(
                              itemCount: medications.length,
                              itemBuilder: (context, index) {
                                final med = medications[index];
                                if (med.isEmpty) return const SizedBox.shrink();

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
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      Text(
                                        nome,
                                        style: const TextStyle(
                                          color: Color.fromRGBO(0, 105, 148, 1),
                                          fontSize: 36,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        "Tomar: $doseFormatada comprimido(s)",
                                        style: const TextStyle(fontSize: 20),
                                      ),
                                      const SizedBox(height: 16),
                                      if (fotoPath.isNotEmpty)
                                        GestureDetector(
                                          onTap: () {
                                            showDialog(
                                              context: context,
                                              builder: (context) => Dialog(
                                                child: Column(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Image.file(
                                                      File(fotoPath),
                                                      width: MediaQuery.of(context).size.width * 0.8,
                                                      fit: BoxFit.contain,
                                                    ),
                                                    TextButton(
                                                      onPressed: () => Navigator.pop(context),
                                                      child: const Text("Fechar"),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            );
                                          },
                                          child: Image.file(
                                            File(fotoPath),
                                            width: 100,
                                            height: 100,
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                      const SizedBox(height: 24),
                                      Column(
                                        children: [
                                          ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: isTaken[index] ? Colors.grey : const Color(0xFF4CAF50),
                                              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                                              textStyle: const TextStyle(fontSize: 20),
                                            ),
                                            onPressed: isTaken[index] || isSkipped[index]
                                                ? null
                                                : () {
                                                    showDialog(
                                                      context: context,
                                                      barrierDismissible: false,
                                                      builder: (context) => Center(
                                                        child: Container(
                                                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                                          decoration: BoxDecoration(
                                                            color: const Color(0xFF006994),
                                                            borderRadius: BorderRadius.circular(8),
                                                          ),
                                                          child: Text(
                                                            'Tomou o medicamento ${med['nome']}',
                                                            style: const TextStyle(color: Colors.white, fontSize: 20),
                                                          ),
                                                        ),
                                                      ),
                                                    );
                                                    Future.delayed(const Duration(seconds: 5), () {
                                                      if (Navigator.of(context).canPop()) {
                                                        Navigator.of(context).pop();
                                                      }
                                                    });
                                                    _handleTake(index);
                                                  },
                                            child: const Text("Tomar"),
                                          ),
                                          const SizedBox(height: 16),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Expanded(
                                                child: ElevatedButton(
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: const Color(0xFF2196F3),
                                                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                                                    textStyle: const TextStyle(fontSize: 20),
                                                  ),
                                                  onPressed: isTaken[index] || isSkipped[index]
                                                      ? null
                                                      : () {
                                                          showDialog(
                                                            context: context,
                                                            barrierDismissible: false,
                                                            builder: (context) => Center(
                                                              child: Container(
                                                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                                                decoration: BoxDecoration(
                                                                  color: const Color(0xFF006994),
                                                                  borderRadius: BorderRadius.circular(8),
                                                                ),
                                                                child: Text(
                                                                  'Medicamento ${med['nome']} adiado para daqui 15 minutos',
                                                                  style: TextStyle(color: Colors.white, fontSize: 20),
                                                                ),
                                                              ),
                                                            ),
                                                          );
                                                          Future.delayed(const Duration(seconds: 5), () {
                                                            if (Navigator.of(context).canPop()) {
                                                              Navigator.of(context).pop();
                                                            }
                                                          });
                                                          _handleDelay(index, context);
                                                        },
                                                  child: const Text("Adiar"),
                                                ),
                                              ),
                                              const SizedBox(width: 16),
                                              Expanded(
                                                child: ElevatedButton(
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: isSkipped[index] ? Colors.grey : Colors.red,
                                                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                                                    textStyle: const TextStyle(fontSize: 20),
                                                  ),
                                                  onPressed: isTaken[index] || isSkipped[index]
                                                      ? null
                                                      : () {
                                                            showDialog(
                                                              context: context,
                                                              barrierDismissible: false,
                                                              builder: (context) => Center(
                                                                child: Container(
                                                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                                                  decoration: BoxDecoration(
                                                                    color: const Color(0xFF006994),
                                                                    borderRadius: BorderRadius.circular(8),
                                                                  ),
                                                                  child: Text(
                                                                    'Medicamento ${med['nome']} pulado',
                                                                    style: const TextStyle(color: Colors.white, fontSize: 20),
                                                                  ),
                                                                ),
                                                              ),
                                                            );
                                                            Future.delayed(const Duration(seconds: 5), () {
                                                              if (Navigator.of(context).canPop()) {
                                                                Navigator.of(context).pop();
                                                              }
                                                            });
                                                            _handleSkip(index);
                                                          },
                                                  child: const Text("Pular"),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}