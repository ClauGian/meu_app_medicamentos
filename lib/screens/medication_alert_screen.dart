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

  @override
  void initState() {
    super.initState();
    widget.notificationService.stopAlarmSound(); // Parar o som do alarme
    print('DEBUG: stopAlarmSound chamado ao iniciar MedicationAlertScreen');
    _fetchMedications();
  }


  void _handleSkip(int index) {
    setState(() {
      final updatedMedications = List<Map<String, dynamic>>.from(medications);
      updatedMedications[index] = {}; // 🔥 Remove o item visualmente
      medications = updatedMedications;

      isSkipped[index] = true;
    });
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
          columns: ['id', 'nome', 'quantidade', 'tipo_medicamento', 'dosagem_diaria', 'horarios', 'foto_embalagem', 'skip_count'],
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
      
      // Limpar initialRouteData no Android ANTES de navegar
      _clearInitialRouteData();
      
      // Usar addPostFrameCallback para navegação segura
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          // Navegar direto para Home (não WelcomeScreen!)
          Navigator.of(context).pushNamedAndRemoveUntil(
            '/home',
            (route) => false,
          );
        }
      });
    }
  }


  Future<void> _clearInitialRouteData() async {
    try {
      const platform = MethodChannel('com.claudinei.medialerta/navigation');
      await platform.invokeMethod('clearInitialRouteData');
      print('DEBUG: initialRouteData limpo no Android');
    } catch (e) {
      print('DEBUG: Erro ao limpar initialRouteData: $e');
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
      // CORREÇÃO: Criar uma CÓPIA mutável da lista antes de modificar
      final updatedMedications = List<Map<String, dynamic>>.from(medications);
      updatedMedications[index] = <String, dynamic>{};
      medications = updatedMedications;
      
      isTaken[index] = true;
      // _checkAndCloseIfDone() REMOVIDO - agora é chamado no botão após o dialog
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
                    const SizedBox(height: 40), // <-- Espaçamento maior no topo
                    Text(
                      "${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year} - ${widget.horario}",
                      style: const TextStyle(
                        color: Color.fromRGBO(0, 105, 148, 1),
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: medications.isEmpty
                          ? const Center(
                              child: Text(
                                'Nenhum medicamento encontrado',
                                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                              ),
                            )
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
                                        "Tomar: $doseFormatada ${med['tipo_medicamento'] ?? ''}",
                                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
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
                                                      child: const Text("Fechar", style: TextStyle(fontWeight: FontWeight.bold)),
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

                                      // --- BOTÕES ---
                                      Column(
                                        children: [
                                          SizedBox(
                                            width: 230,
                                            child: ElevatedButton(
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: const Color(0xFF006994),
                                                padding: const EdgeInsets.symmetric(vertical: 18),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(30), // 🔸 bordas arredondadas
                                                ),
                                                textStyle: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                                              ),
                                              onPressed: isTaken[index] || isSkipped[index]
                                                  ? null
                                                  : () async {
                                                      // Primeiro executar _handleTake
                                                      await _handleTake(index);
                                                      
                                                      // Só mostrar o dialog se o widget ainda estiver montado
                                                      if (!mounted) return;
                                                      
                                                      // Mostrar dialog
                                                      showDialog(
                                                        context: context,
                                                        barrierDismissible: false,
                                                        builder: (context) => Align(
                                                          alignment: Alignment.center,
                                                          child: Container(
                                                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                                            decoration: BoxDecoration(
                                                              color: Color(0xFF006994),
                                                              borderRadius: BorderRadius.circular(8),
                                                            ),
                                                            child: Text(
                                                              'Tomou o medicamento ${med['nome']}',
                                                              textAlign: TextAlign.center, // 🔥 AQUI está a correção
                                                              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                                                            ),
                                                          ),
                                                        ),
                                                      );
                                                      
                                                      // Aguardar 3 segundos e fechar dialog
                                                      await Future.delayed(const Duration(seconds: 3));
                                                      
                                                      if (mounted && Navigator.of(context).canPop()) {
                                                        Navigator.of(context).pop();
                                                      }
                                                      
                                                      // Só DEPOIS verificar se deve fechar a tela
                                                      if (mounted) {
                                                        _checkAndCloseIfDone();
                                                      }
                                                    },
                                              child: const Text("Tomar", style: TextStyle(color: Colors.white)),
                                            ),
                                          ),
                                          const SizedBox(height: 16),

                                          SizedBox(
                                            width: 230,
                                            child: ElevatedButton(
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: const Color(0xFF55AA55),
                                                padding: const EdgeInsets.symmetric(vertical: 18),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(30), 
                                                ),
                                                textStyle: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                                              ),
                                              onPressed: isTaken[index] || isSkipped[index]
                                                  ? null
                                                  : () {
                                                      // 1️⃣ Primeiro executa o skip (como no botão TOMAR)
                                                      _handleSkip(index);

                                                      // 2️⃣ Mostra o diálogo
                                                      showDialog(
                                                        context: context,
                                                        barrierDismissible: false,
                                                        builder: (context) => Align(
                                                          alignment: Alignment.center,
                                                          child: Container(
                                                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                                            decoration: BoxDecoration(
                                                              color: const Color(0xFF006994),
                                                              borderRadius: BorderRadius.circular(8),
                                                            ),
                                                            child: Text(
                                                              'Medicamento ${med['nome']} pulado',
                                                              textAlign: TextAlign.center,
                                                              style: const TextStyle(
                                                                color: Colors.white, 
                                                                fontSize: 20, 
                                                                fontWeight: FontWeight.bold,
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                      );

                                                      // 3️⃣ Aguarda os 3 segundos
                                                      Future.delayed(const Duration(seconds: 3), () {
                                                        if (Navigator.of(context).canPop()) {
                                                          Navigator.of(context).pop();
                                                        }

                                                        // 4️⃣ Agora fecha a tela corretamente
                                                        if (mounted) {
                                                          _checkAndCloseIfDone();
                                                        }
                                                      });
                                                    },
                                              child: const Text(
                                                "Pular",
                                                style: TextStyle(color: Colors.white),
                                              ),
                                            ),
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