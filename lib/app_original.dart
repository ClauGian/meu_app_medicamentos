import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';
import 'screens/medication_registration_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: const WelcomeScreen(),
    );
  }
}

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFCCCCCC),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 40),
              RichText(
                text: const TextSpan(
                  children: [
                    TextSpan(
                      text: 'Medi',
                      style: TextStyle(
                        color: Color.fromRGBO(0, 105, 148, 1),
                        fontSize: 56,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextSpan(
                      text: 'Alerta',
                      style: TextStyle(
                        color: Color.fromRGBO(85, 170, 85, 1),
                        fontSize: 56,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
              Image.asset(
                'assets/imagem_senhora.png',
                height: MediaQuery.of(context).size.height * 0.40,
              ),
              const SizedBox(height: 30),
              const Text(
                'Seu remédio na hora certa.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color.fromRGBO(0, 85, 128, 1),
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 60),
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const HomeScreen()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromRGBO(0, 105, 148, 1),
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                ),
                child: const Text(
                  "Começar",
                  style: TextStyle(fontSize: 24, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFCCCCCC),
      appBar: AppBar(
        title: Padding(
          padding: const EdgeInsets.only(top: 20.0, left: 16.0),
          child: RichText(
            text: const TextSpan(
              children: [
                TextSpan(
                  text: 'Medi',
                  style: TextStyle(
                    color: Color.fromRGBO(0, 105, 148, 1),
                    fontSize: 42,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextSpan(
                  text: 'Alerta',
                  style: TextStyle(
                    color: Color.fromRGBO(85, 170, 85, 1),
                    fontSize: 42,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
        backgroundColor: const Color(0xFFCCCCCC),
        elevation: 0,
        leading: Builder(
          builder: (context) => Padding(
            padding: const EdgeInsets.only(top: 10.0, left: 16.0),
            child: IconButton(
              icon: const Icon(Icons.menu, size: 42),
              color: const Color.fromRGBO(0, 105, 148, 1),
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
          ),
        ),
      ),
      drawer: Drawer(
        child: ListView(
          padding: const EdgeInsets.only(top: 40.0, left: 16.0),
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(
                color: Color.fromRGBO(0, 105, 148, 1),
              ),
              child: RichText(
                text: const TextSpan(
                  children: [
                    TextSpan(
                      text: 'Medi',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextSpan(
                      text: 'Alerta',
                      style: TextStyle(
                        color: Color.fromRGBO(85, 170, 85, 1),
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            ListTile(
              title: const Text(
                'Meu Cadastro',
                style: TextStyle(
                  color: Color.fromRGBO(0, 85, 128, 1),
                  fontSize: 20,
                ),
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const UserRegistrationScreen()),
                );
              },
            ),
            ListTile(
              title: const Text(
                'Cadastrar Cuidador',
                style: TextStyle(
                  color: Color.fromRGBO(0, 85, 128, 1),
                  fontSize: 20,
                ),
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const CaregiverRegistrationScreen()),
                );
              },
            ),
            ListTile(
              title: const Text(
                'Cadastrar Medicamentos',
                style: TextStyle(
                  color: Color.fromRGBO(0, 85, 128, 1),
                  fontSize: 20,
                ),
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const MedicationRegistrationScreen()),
                );
              },
            ),
            ListTile(
              title: const Text(
                'Lista de Medicamentos',
                style: TextStyle(
                  color: Color.fromRGBO(0, 85, 128, 1),
                  fontSize: 20,
                ),
              ),
              onTap: () async {
                final database = await getDatabase();
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => MedicationListScreen(database: database)),
                );
              },
            ),
            ListTile(
              title: const Text(
                'Alertas',
                style: TextStyle(
                  color: Color.fromRGBO(0, 85, 128, 1),
                  fontSize: 20,
                ),
              ),
              onTap: () {},
            ),
          ],
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 40),
              RichText(
                textAlign: TextAlign.center,
                text: const TextSpan(
                  children: [
                    TextSpan(
                      text: 'Bem-vindo ao ',
                      style: TextStyle(
                        color: Color.fromRGBO(0, 105, 148, 1),
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        height: 1.5,
                      ),
                    ),
                    TextSpan(
                      text: 'Medi',
                      style: TextStyle(
                        color: Color.fromRGBO(0, 105, 148, 1),
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        height: 1.5,
                      ),
                    ),
                    TextSpan(
                      text: 'Alerta!',
                      style: TextStyle(
                        color: Color.fromRGBO(85, 170, 85, 1),
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 80),
              ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromRGBO(0, 105, 148, 1),
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                ),
                child: const Text(
                  'Ver Alertas do Dia',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Função auxiliar para obter o banco de dados (será usada no MedicationListScreen)
  Future<Database> getDatabase() async {
    return await openDatabase(
      path.join(await getDatabasesPath(), 'medications.db'),
      onCreate: (db, version) {
        return db.execute(
          'CREATE TABLE medications(id INTEGER PRIMARY KEY, name TEXT, stock TEXT, type TEXT, dosage TEXT, frequency INTEGER, times TEXT, startDate TEXT, isContinuous INTEGER, imagePath TEXT)',
        );
      },
      version: 1,
    );
  }
}

class UserRegistrationScreen extends StatefulWidget {
  const UserRegistrationScreen({super.key});

  @override
  _UserRegistrationScreenState createState() => _UserRegistrationScreenState();
}

class _UserRegistrationScreenState extends State<UserRegistrationScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _dateController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _validateAndSave() {
    String name = _nameController.text.trim();
    String date = _dateController.text.replaceAll('/', '');
    String phone = _phoneController.text.replaceAll(RegExp(r'[^0-9]'), '');

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Por favor, preencha o Nome.',
            style: TextStyle(fontSize: 20),
          ),
        ),
      );
      return;
    }

    if (date.length != 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'A Data de Nascimento deve ter o formato dd/mm/aaaa (8 dígitos).',
            style: TextStyle(fontSize: 20),
          ),
        ),
      );
      return;
    }

    if (phone.length != 11) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'O Telefone deve ter 11 dígitos (ex.: (XX) XXXXX-XXXX).',
            style: TextStyle(fontSize: 20),
          ),
        ),
      );
      return;
    }

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        flexibleSpace: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.only(top: 20.0),
              child: RichText(
                text: const TextSpan(
                  children: [
                    TextSpan(
                      text: 'Meu ',
                      style: TextStyle(
                        color: Color.fromRGBO(0, 105, 148, 1),
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextSpan(
                      text: 'Cadastro',
                      style: TextStyle(
                        color: Color.fromRGBO(85, 170, 85, 1),
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        backgroundColor: const Color(0xFFCCCCCC),
        elevation: 0,
        leading: Builder(
          builder: (context) => Padding(
            padding: const EdgeInsets.only(top: 20.0, left: 16.0),
            child: IconButton(
              icon: const Icon(Icons.arrow_back, size: 42),
              color: const Color.fromRGBO(0, 105, 148, 1),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ),
        toolbarHeight: 100,
      ),
      backgroundColor: const Color(0xFFCCCCCC),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              const SizedBox(height: 30),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Nome',
                  border: OutlineInputBorder(),
                  labelStyle: TextStyle(
                    color: Color.fromRGBO(0, 85, 128, 1),
                    fontSize: 20,
                  ),
                  filled: true,
                  fillColor: Colors.grey,
                ),
                style: const TextStyle(fontSize: 24),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _dateController,
                decoration: const InputDecoration(
                  labelText: 'Data de Nascimento (dd/mm/aaaa)',
                  border: OutlineInputBorder(),
                  labelStyle: TextStyle(
                    color: Color.fromRGBO(0, 85, 128, 1),
                    fontSize: 20,
                  ),
                  filled: true,
                  fillColor: Colors.grey,
                ),
                style: const TextStyle(fontSize: 24),
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(8),
                  _DateInputFormatter(),
                ],
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: 'Telefone',
                  border: OutlineInputBorder(),
                  labelStyle: TextStyle(
                    color: Color.fromRGBO(0, 85, 128, 1),
                    fontSize: 20,
                  ),
                  filled: true,
                  fillColor: Colors.grey,
                ),
                style: const TextStyle(fontSize: 24),
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(11),
                  _PhoneInputFormatter(),
                ],
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'E-mail (opcional)',
                  border: OutlineInputBorder(),
                  labelStyle: TextStyle(
                    color: Color.fromRGBO(0, 85, 128, 1),
                    fontSize: 20,
                  ),
                  filled: true,
                  fillColor: Colors.grey,
                ),
                style: const TextStyle(fontSize: 24),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 80),
              ElevatedButton(
                onPressed: _validateAndSave,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromRGBO(0, 105, 148, 1),
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                ),
                child: const Text(
                  'Salvar',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _DateInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    String text = newValue.text;
    if (text.length > 8) {
      return oldValue;
    }
    String formatted = '';
    for (int i = 0; i < text.length; i++) {
      if (i == 2 || i == 4) {
        formatted += '/';
      }
      formatted += text[i];
    }
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class _PhoneInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    String text = newValue.text;
    if (text.length > 11) {
      return oldValue;
    }
    String formatted = '';
    for (int i = 0; i < text.length; i++) {
      if (i == 0) formatted += '(';
      if (i == 2) formatted += ') ';
      if (i == 7) formatted += '-';
      formatted += text[i];
    }
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class CaregiverRegistrationScreen extends StatefulWidget {
  const CaregiverRegistrationScreen({super.key});

  @override
  _CaregiverRegistrationScreenState createState() => _CaregiverRegistrationScreenState();
}

class _CaregiverRegistrationScreenState extends State<CaregiverRegistrationScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _relationController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _relationController.dispose();
    super.dispose();
  }

  void _validateAndSave() {
    String name = _nameController.text.trim();
    String phone = _phoneController.text.replaceAll(RegExp(r'[^0-9]'), '');

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Por favor, preencha o Nome.',
            style: TextStyle(fontSize: 20),
          ),
        ),
      );
      return;
    }

    if (phone.length != 11) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'O Telefone deve ter 11 dígitos (ex.: (XX) XXXXX-XXXX).',
            style: TextStyle(fontSize: 20),
          ),
        ),
      );
      return;
    }

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        flexibleSpace: const SafeArea(
          child: Center(
            child: Padding(
              padding: EdgeInsets.only(top: 20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Cadastrar',
                    style: TextStyle(
                      color: Color.fromRGBO(0, 105, 148, 1),
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Cuidador',
                    style: TextStyle(
                      color: Color.fromRGBO(85, 170, 85, 1),
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        backgroundColor: const Color(0xFFCCCCCC),
        elevation: 0,
        leading: Builder(
          builder: (context) => Padding(
            padding: const EdgeInsets.only(top: 10.0, left: 16.0),
            child: IconButton(
              icon: const Icon(Icons.arrow_back, size: 42),
              color: const Color.fromRGBO(0, 105, 148, 1),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ),
        toolbarHeight: 140,
      ),
      backgroundColor: const Color(0xFFCCCCCC),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              const SizedBox(height: 50),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Nome',
                  border: OutlineInputBorder(),
                  labelStyle: TextStyle(
                    color: Color.fromRGBO(0, 85, 128, 1),
                    fontSize: 20,
                  ),
                  filled: true,
                  fillColor: Colors.grey,
                ),
                style: const TextStyle(fontSize: 24),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: 'Telefone',
                  border: OutlineInputBorder(),
                  labelStyle: TextStyle(
                    color: Color.fromRGBO(0, 85, 128, 1),
                    fontSize: 20,
                  ),
                  filled: true,
                  fillColor: Colors.grey,
                ),
                style: const TextStyle(fontSize: 24),
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(11),
                  _PhoneInputFormatter(),
                ],
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _relationController,
                decoration: const InputDecoration(
                  labelText: 'Relação com o Usuário (opcional)',
                  border: OutlineInputBorder(),
                  labelStyle: TextStyle(
                    color: Color.fromRGBO(0, 85, 128, 1),
                    fontSize: 20,
                  ),
                  filled: true,
                  fillColor: Colors.grey,
                ),
                style: const TextStyle(fontSize: 24),
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 80),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[600],
                      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                    ),
                    child: const Text(
                      'Pular',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                      ),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: _validateAndSave,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color.fromRGBO(0, 105, 148, 1),
                      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                    ),
                    child: const Text(
                      'Salvar',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}


class MedicationListScreen extends StatefulWidget {
  final Database database;

  const MedicationListScreen({required this.database, super.key});

  @override
  _MedicationListScreenState createState() => _MedicationListScreenState();
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