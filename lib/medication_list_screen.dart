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

  Future<void> _deleteMedication(int id) async {
    await widget.database.delete('medications', where: 'id = ?', whereArgs: [id]);
    _loadMedications();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color.fromRGBO(0, 85, 128, 1),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Lista de Medicamentos",
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage("assets/images/background_image.jpg"),
            fit: BoxFit.cover,
          ),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => MedicationRegistrationScreen(database: widget.database), // Passa o database
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromRGBO(0, 85, 128, 1),
                  minimumSize: const Size(double.infinity, 50),
                ),
                child: const Text(
                  "Cadastrar Novo Medicamento",
                  style: TextStyle(fontSize: 20, color: Colors.white),
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: _medications.length,
                itemBuilder: (context, index) {
                  final med = _medications[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: ListTile(
                      leading: med['photoPath'] != null
                          ? Image.file(File(med['photoPath']), width: 50, height: 50, fit: BoxFit.cover)
                          : const Icon(Icons.medication, size: 50),
                      title: Text(med['name']),
                      subtitle: Text(
                        'Estoque: ${med['stock']} | Tipo: ${med['type']} | Dosagem: ${med['dosage']}',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => MedicationRegistrationScreen(
                                    database: widget.database, // Passa o database
                                    medication: med,
                                  ),
                                ),
                              );
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete),
                            onPressed: () => _deleteMedication(med['id']),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}