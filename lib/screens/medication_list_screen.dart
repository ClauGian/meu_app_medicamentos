import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'dart:io';
import 'medication_registration_screen.dart';
import 'home_screen.dart';
import '../notification_service.dart'; // Adicionado import
import 'package:intl/intl.dart';

class MedicationListScreen extends StatefulWidget {
  final Database database;
  final NotificationService notificationService; // Novo parâmetro

  const MedicationListScreen({
    super.key,
    required this.database,
    required this.notificationService,
  });

  @override
  State<MedicationListScreen> createState() => _MedicationListScreenState();
}

class _MedicationListScreenState extends State<MedicationListScreen> {
  List<Map<String, dynamic>> _medications = [];

  @override
  void initState() {
    super.initState();
    _loadMedications();
  }

  Future<void> _loadMedications() async {
    final List<Map<String, dynamic>> medications = await widget.database.query('medications');
    print('DEBUG: Medicamentos carregados em MedicationListScreen: $medications'); // Adicionado log
    setState(() {
      _medications = medications;
    });
  }

  void _confirmDelete(BuildContext context, int id, String name) {
    showDialog(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text("Confirmar Exclusão", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        content: Text("Deseja excluir o medicamento '$name'?", style: const TextStyle(fontSize: 20)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancelar", style: TextStyle(fontSize: 20, color: Color.fromRGBO(0, 105, 148, 1))),
          ),
          TextButton(
            onPressed: () async {
              await widget.database.delete('medications', where: 'id = ?', whereArgs: [id]);
              Navigator.pop(context);
              _loadMedications();
            },
            child: const Text("Excluir", style: TextStyle(fontSize: 20, color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showImageDialog(BuildContext context, String imagePath) {
    showDialog(
      context: context,
      builder: (BuildContext context) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.file(
              File(imagePath),
              fit: BoxFit.contain,
              height: MediaQuery.of(context).size.height * 0.5,
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Fechar", style: TextStyle(fontSize: 20, color: Color.fromRGBO(0, 105, 148, 1))),
            ),
          ],
        ),
      ),
    );
  }

  void _showReporQuantidadeDialog(dynamic id) {
    TextEditingController _quantidadeController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: const Text(
            'Repor Quantidade',
            style: TextStyle(color: Color.fromRGBO(0, 105, 148, 1)),
          ),
          content: TextField(
            controller: _quantidadeController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Quantos adquiriu',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              child: const Text('Cancelar', style: TextStyle(color: Colors.red)),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Color.fromRGBO(85, 170, 85, 1),
                foregroundColor: Colors.white,
              ),
              child: const Text('Salvar'),
              onPressed: () {
                String novaQuantidade = _quantidadeController.text;
                if (novaQuantidade.isNotEmpty) {
                  _reporQuantidade(id, int.parse(novaQuantidade));
                }
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _reporQuantidade(dynamic id, int novaQuantidade) async {
    final List<Map<String, dynamic>> result = await widget.database.query(
      'medications',
      columns: ['quantidade'],
      where: 'id = ?',
      whereArgs: [id],
    );
    int quantidadeAtual = result.isNotEmpty ? (result[0]['quantidade'] as int? ?? 0) : 0;
    int quantidadeTotal = quantidadeAtual + novaQuantidade;
    await widget.database.update(
      'medications',
      {'quantidade': quantidadeTotal},
      where: 'id = ?',
      whereArgs: [id],
    );
    _loadMedications();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (context) => HomeScreen(
                database: widget.database,
                notificationService: widget.notificationService, // Adicionado
              ),
            ),
            (route) => false,
          );
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFCCCCCC),
        appBar: AppBar(
          toolbarHeight: 100.0,
          backgroundColor: const Color(0xFFCCCCCC),
          title: const Padding(
            padding: EdgeInsets.only(top: 20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "Medicamentos",
                  style: TextStyle(
                    color: Color.fromRGBO(0, 105, 148, 1),
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  "Cadastrados",
                  style: TextStyle(
                    color: Color.fromRGBO(85, 170, 85, 1),
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          centerTitle: true,
          leading: Padding(
            padding: const EdgeInsets.only(top: 20.0),
            child: IconButton(
              icon: const Icon(
                Icons.arrow_back,
                color: Color.fromRGBO(0, 105, 148, 1),
                size: 42,
              ),
              onPressed: () {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(
                    builder: (context) => HomeScreen(
                      database: widget.database,
                      notificationService: widget.notificationService, // Adicionado
                    ),
                  ),
                  (route) => false,
                );
              },
            ),
          ),
        ),
        body: SafeArea(
          child: _medications.isEmpty
              ? const Center(
                  child: Text(
                    "Nenhum medicamento cadastrado.",
                    style: TextStyle(fontSize: 20, color: Colors.blue, fontWeight: FontWeight.bold),
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 16.0),
                  child: ListView.builder(
                    itemCount: _medications.length,
                    itemBuilder: (context, index) {
                      final med = _medications[index];
                      final imagePath = med['foto_embalagem'] as String?;
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 8.0),
                        elevation: 0,
                        child: ClipRect(
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border.all(width: 2.0, color: Colors.black),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: [
                                Container(
                                  width: double.infinity,
                                  height: 50.0,
                                  padding: EdgeInsets.zero,
                                  decoration: BoxDecoration(
                                    color: Colors.grey[400],
                                    border: Border(
                                      bottom: BorderSide(width: 2.0, color: Colors.black),
                                    ),
                                  ),
                                  child: Center(
                                    child: Text(
                                      med['nome']?.toString() ?? 'Nome não informado',
                                      style: TextStyle(
                                        fontSize: 30,
                                        color: Colors.blue[900],
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox.shrink(),
                                ConstrainedBox(
                                  constraints: BoxConstraints.tightFor(
                                    width: MediaQuery.of(context).size.width - 8.0,
                                  ),
                                  child: DataTable(
                                    columnSpacing: 4.0,
                                    dividerThickness: 1.0,
                                    dataRowMinHeight: 48.0,
                                    dataRowMaxHeight: 48.0,
                                    decoration: const BoxDecoration(),
                                    horizontalMargin: 0,
                                    columns: const [
                                      DataColumn(label: Text('')),
                                      DataColumn(
                                        label: SizedBox(
                                          width: 140.0,
                                          child: Text(''),
                                        ),
                                      ),
                                    ],
                                    rows: [
                                      DataRow(cells: [
                                        DataCell(
                                          Container(
                                            width: 160.0,
                                            padding: const EdgeInsets.only(left: 4.0),
                                            child: Text(
                                              'Quantidade:',
                                              style: TextStyle(
                                                fontSize: 16,
                                                color: Colors.blue[900],
                                                fontWeight: FontWeight.bold,
                                              ),
                                              softWrap: true,
                                              textAlign: TextAlign.left,
                                            ),
                                          ),
                                        ),
                                        DataCell(
                                          Center(
                                            child: SizedBox(
                                              width: 140.0,
                                              child: Text(
                                                med['quantidade']?.toString() ?? '0',
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  color: Colors.blue[900],
                                                  fontWeight: FontWeight.bold,
                                                ),
                                                softWrap: true,
                                                textAlign: TextAlign.center,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ]),
                                      DataRow(cells: [
                                        DataCell(
                                          Container(
                                            width: 160.0,
                                            padding: const EdgeInsets.only(left: 4.0),
                                            child: Text(
                                              'Tipo:',
                                              style: TextStyle(
                                                fontSize: 16,
                                                color: Colors.blue[900],
                                                fontWeight: FontWeight.bold,
                                              ),
                                              softWrap: true,
                                              textAlign: TextAlign.left,
                                            ),
                                          ),
                                        ),
                                        DataCell(
                                          Center(
                                            child: SizedBox(
                                              width: 140.0,
                                              child: Text(
                                                med['tipo_medicamento']?.toString() ?? 'Não especificado',
                                                style: TextStyle(fontSize: 16, color: Colors.blue[900]),
                                                softWrap: true,
                                                textAlign: TextAlign.center,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ]),
                                      DataRow(cells: [
                                        DataCell(
                                          Container(
                                            width: 160.0,
                                            padding: const EdgeInsets.only(left: 4.0),
                                            child: Text(
                                              'Dosagem ao dia:',
                                              style: TextStyle(
                                                fontSize: 16,
                                                color: Colors.blue[900],
                                                fontWeight: FontWeight.bold,
                                              ),
                                              softWrap: true,
                                              textAlign: TextAlign.left,
                                            ),
                                          ),
                                        ),
                                        DataCell(
                                          Center(
                                            child: SizedBox(
                                              width: 140.0,
                                              child: Text(
                                                med['dosagem_diaria']?.toString() ?? 'Não informada',
                                                style: TextStyle(fontSize: 16, color: Colors.blue[900]),
                                                softWrap: true,
                                                textAlign: TextAlign.center,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ]),
                                      DataRow(cells: [
                                        DataCell(
                                          Container(
                                            width: 160.0,
                                            padding: const EdgeInsets.only(left: 4.0),
                                            child: Text(
                                              'Modo de usar',
                                              style: TextStyle(
                                                fontSize: 16,
                                                color: Colors.blue[900],
                                                fontWeight: FontWeight.bold,
                                              ),
                                              softWrap: true,
                                              textAlign: TextAlign.left,
                                            ),
                                          ),
                                        ),
                                        DataCell(
                                          Center(
                                            child: SizedBox(
                                              width: 140.0,
                                              child: Text(
                                                med['frequencia']?.toString() ?? 'Não informado',
                                                style: TextStyle(fontSize: 16, color: Colors.blue[900]),
                                                softWrap: true,
                                                textAlign: TextAlign.center,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ]),
                                      DataRow(cells: [
                                        DataCell(
                                          Container(
                                            width: 160.0,
                                            padding: const EdgeInsets.only(left: 4.0),
                                            child: Text(
                                              'Horários:',
                                              style: TextStyle(
                                                fontSize: 16,
                                                color: Colors.blue[900],
                                                fontWeight: FontWeight.bold,
                                              ),
                                              softWrap: true,
                                              textAlign: TextAlign.left,
                                            ),
                                          ),
                                        ),
                                        DataCell(
                                          Center(
                                            child: Container(
                                              width: 140.0,
                                              alignment: Alignment.center,
                                              child: Text(
                                                med['horarios']?.toString() ?? 'Não informado',
                                                style: TextStyle(fontSize: 14, color: Colors.blue[900]),
                                                softWrap: true,
                                                maxLines: null,
                                                textAlign: TextAlign.center,
                                                overflow: TextOverflow.visible,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ]),
                                      DataRow(cells: [
                                        DataCell(
                                          Container(
                                            width: 160.0,
                                            padding: const EdgeInsets.only(left: 4.0),
                                            child: Text(
                                              'Início:',
                                              style: TextStyle(
                                                fontSize: 16,
                                                color: Colors.blue[900],
                                                fontWeight: FontWeight.bold,
                                              ),
                                              softWrap: true,
                                              textAlign: TextAlign.left,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ),
                                        DataCell(
                                          Center(
                                            child: SizedBox(
                                              width: 140.0,
                                              child: Text(
                                                med['startDate'] != null
                                                    ? DateFormat('dd/MM/yyyy')
                                                        .format(DateFormat('yyyy-MM-dd').parse(med['startDate']))
                                                    : 'Não informado',
                                                style: TextStyle(fontSize: 16, color: Colors.blue[900]),
                                                softWrap: true,
                                                textAlign: TextAlign.center,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ]),
                                      DataRow(cells: [
                                        DataCell(
                                          Container(
                                            width: 160.0,
                                            padding: const EdgeInsets.only(left: 4.0),
                                            child: Text(
                                              'Contínuo:',
                                              style: TextStyle(
                                                fontSize: 16,
                                                color: Colors.blue[900],
                                                fontWeight: FontWeight.bold,
                                              ),
                                              softWrap: true,
                                              textAlign: TextAlign.left,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ),
                                        DataCell(
                                          Center(
                                            child: SizedBox(
                                              width: 140.0,
                                              child: Text(
                                                med['isContinuous'] == 1 ? 'Sim' : 'Não',
                                                style: TextStyle(fontSize: 16, color: Colors.blue[900]),
                                                softWrap: true,
                                                textAlign: TextAlign.center,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ]),
                                      DataRow(cells: [
                                        DataCell(
                                          Container(
                                            width: 160.0,
                                            padding: const EdgeInsets.only(left: 4.0),
                                            child: Text(
                                              'Foto:',
                                              style: TextStyle(
                                                fontSize: 16,
                                                color: Colors.blue[900],
                                                fontWeight: FontWeight.bold,
                                              ),
                                              softWrap: true,
                                              textAlign: TextAlign.left,
                                            ),
                                          ),
                                        ),
                                        DataCell(
                                          imagePath != null && imagePath.isNotEmpty && File(imagePath).existsSync()
                                              ? GestureDetector(
                                                  onTap: () => _showImageDialog(context, imagePath),
                                                  child: Center(
                                                    child: Image.file(
                                                      File(imagePath),
                                                      width: 50,
                                                      height: 50,
                                                      fit: BoxFit.cover,
                                                    ),
                                                  ),
                                                )
                                              : const Center(
                                                  child: Icon(
                                                    Icons.image_not_supported,
                                                    size: 50,
                                                    color: Colors.grey,
                                                  ),
                                                ),
                                        ),
                                      ]),
                                    ],
                                    headingRowHeight: 0,
                                    dataRowColor: WidgetStateProperty.all(Colors.transparent),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                                  child: Column(
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                        children: [
                                          ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: const Color.fromRGBO(0, 105, 148, 1),
                                              foregroundColor: Colors.white,
                                              minimumSize: const Size(120, 50),
                                            ),
                                            onPressed: () {
                                              final adjustedMed = Map<String, dynamic>.from(med);
                                              adjustedMed['id'] = med['id']?.toString();
                                              adjustedMed['quantidade'] = med['quantidade']?.toString();
                                              adjustedMed['dosagem_diaria'] = med['dosagem_diaria']?.toString();
                                              adjustedMed['frequencia'] = med['frequencia']?.toString();
                                              adjustedMed['isContinuous'] = med['isContinuous']?.toString();
                                              adjustedMed['horarios'] = med['horarios']?.toString() ?? '';
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (context) => MedicationRegistrationScreen(
                                                    database: widget.database,
                                                    medication: adjustedMed,
                                                    notificationService: widget.notificationService,
                                                  ),
                                                ),
                                              ).then((_) => _loadMedications());
                                            },
                                            child: const Text('Alterar', style: TextStyle(fontSize: 16)),
                                          ),
                                          ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.red,
                                              foregroundColor: Colors.white,
                                              minimumSize: const Size(120, 50),
                                            ),
                                            onPressed: () => _confirmDelete(context, med['id'], med['nome']?.toString() ?? ''),
                                            child: const Text('Excluir', style: TextStyle(fontSize: 16)),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8.0),
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color.fromRGBO(85, 170, 85, 1),
                                          foregroundColor: Colors.white,
                                          minimumSize: const Size(180, 50),
                                        ),
                                        onPressed: () {
                                          _showReporQuantidadeDialog(med['id']);
                                        },
                                        child: const Text(
                                          'Repor Quantidade',
                                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
        ),
      ),
    );
  }
}