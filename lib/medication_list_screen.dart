import 'dart:io';
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'medication_registration_screen.dart';


class MedicationListScreen extends StatefulWidget {
  final Database database;

  const MedicationListScreen({required this.database, super.key});

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
              _loadMedications(); // Atualiza a lista após exclusão
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFCCCCCC),
        title: const Text("Medicamentos Cadastrados", style: TextStyle(color: Color.fromRGBO(0, 105, 148, 1), fontSize: 28, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color.fromRGBO(0, 105, 148, 1), size: 42),
          onPressed: () {
            Navigator.pop(context);
            Navigator.push(context, MaterialPageRoute(builder: (context) => MedicationRegistrationScreen()));
          },
        ),
      ),
      body: _medications.isEmpty
          ? const Center(child: Text("Nenhum medicamento cadastrado.", style: TextStyle(fontSize: 20)))
          : ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: _medications.length,
              itemBuilder: (context, index) {
                final med = _medications[index];
                final imagePath = med['imagePath'] as String?;
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(med['name'], style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                            ),
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit, color: Color.fromRGBO(0, 105, 148, 1), size: 40),
                                  onPressed: () {
                                    Navigator.pop(context);
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => MedicationRegistrationScreen(medication: med),
                                      ),
                                    );
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red, size: 50),
                                  onPressed: () => _confirmDelete(context, med['id'], med['name']),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Quantidade Total: ${med['stock']}", style: const TextStyle(fontSize: 18)),
                            Text("Tipo: ${med['type']}", style: const TextStyle(fontSize: 18)),
                            Text("Dosagem: ${med['dosage']}", style: const TextStyle(fontSize: 18)),
                            Text("Modo de Usar: ${med['frequency']} x por dia", style: const TextStyle(fontSize: 18)),
                            Text("Horários: ${med['times']}", style: const TextStyle(fontSize: 18)),
                            Text("Início: ${med['startDate']}", style: const TextStyle(fontSize: 18)),
                            Text("Contínuo: ${med['isContinuous'] == 1 ? 'Sim' : 'Não'}", style: const TextStyle(fontSize: 18)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        imagePath != null && File(imagePath).existsSync()
                            ? GestureDetector(
                                onTap: () => _showImageDialog(context, imagePath),
                                child: Image.file(
                                  File(imagePath),
                                  width: 50,
                                  height: 50,
                                  fit: BoxFit.cover,
                                ),
                              )
                            : const Icon(Icons.image_not_supported, size: 50, color: Colors.grey),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}