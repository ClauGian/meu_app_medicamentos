import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

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

class MedicationRegistrationScreen extends StatefulWidget {
  final Map<String, dynamic>? medication; // Parâmetro opcional pra edição

  const MedicationRegistrationScreen({super.key, this.medication});

  @override
  _MedicationRegistrationScreenState createState() => _MedicationRegistrationScreenState();
}

class _MedicationRegistrationScreenState extends State<MedicationRegistrationScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _stockController = TextEditingController();
  final TextEditingController _dosageController = TextEditingController();
  final TextEditingController _startDateController = TextEditingController();
  final FocusNode _nameFocusNode = FocusNode(); // Adicionado aqui
  String? _type;
  bool _isContinuous = false;
  File? _image;
  bool _showPhotoOption = false;
  final ImagePicker _picker = ImagePicker();
  int? _frequency;
  List<TextEditingController> _timeControllers = [TextEditingController()];
  Future<Database>? _databaseFuture;

  @override
  void initState() {
    super.initState();
    print("Iniciando initState");
    _checkUserAge();
    _startDateController.text = DateFormat('dd/MM/yyyy').format(DateTime.now());
    if (widget.medication != null) {
      print("Preenchendo campos para edição");
      _nameController.text = widget.medication!['name'] ?? '';
      _stockController.text = widget.medication!['stock'] ?? '';
      _type = widget.medication!['type'];
      _dosageController.text = widget.medication!['dosage'] ?? '';
      _frequency = widget.medication!['frequency'];
      _isContinuous = widget.medication!['isContinuous'] == 1;
      _image = widget.medication!['imagePath'] != null ? File(widget.medication!['imagePath']) : null;
      final times = (widget.medication!['times'] as String?)?.split(',') ?? [];
      _timeControllers = times.isNotEmpty
          ? times.map((time) => TextEditingController(text: time)).toList()
          : [TextEditingController()];
    }
    print("Chamando _initDatabase");
    _databaseFuture = _initDatabase();
    print("initState concluído");
  }

  @override
  void dispose() {
    _nameFocusNode.dispose(); // Libera o FocusNode ao destruir o widget
    _nameController.dispose();
    _stockController.dispose();
    _dosageController.dispose();
    _startDateController.dispose();
    _timeControllers.forEach((controller) => controller.dispose());
    super.dispose();
  }

  void _checkUserAge() {
    const birthDate = "1960-04-01"; // Substituir por dado real depois
    final age = DateTime.now().difference(DateTime.parse(birthDate)).inDays ~/ 365;
    setState(() {
      _showPhotoOption = age >= 60;
    });
  }

  Future<Database> _initDatabase() async {
    try {
      print("Iniciando _initDatabase");
      final dbPath = await getDatabasesPath();
      print("Caminho do banco de dados: $dbPath");
      final fullPath = path.join(dbPath, 'medications.db');
      print("Caminho completo: $fullPath");
      final database = await openDatabase(
        fullPath,
        onCreate: (db, version) {
          print("Criando tabela medications");
          return db.execute(
            'CREATE TABLE medications(id INTEGER PRIMARY KEY, name TEXT, stock TEXT, type TEXT, dosage TEXT, frequency INTEGER, times TEXT, startDate TEXT, isContinuous INTEGER, imagePath TEXT)',
          );
        },
        version: 1,
      );
      print("Banco de dados inicializado com sucesso");
      return database;
    } catch (e, stackTrace) {
      print("Erro ao inicializar o banco de dados: $e");
      print("Stack trace: $stackTrace");
      rethrow; // Relança pra depuração
    }
  }

  Future<void> _pickImage() async {
    final XFile? pickedImage = await _picker.pickImage(source: ImageSource.camera);
    if (pickedImage != null) {
      setState(() {
        _image = File(pickedImage.path);
      });
    }
  }

  Future<void> _selectTime(BuildContext context, int index) async {
    int selectedHour = 8;
    int selectedMinute = 0;

    await showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Container(
          height: 350,
          child: Column(
            children: [
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 100,
                      child: CupertinoPicker(
                        itemExtent: 60.0,
                        onSelectedItemChanged: (int value) {
                          selectedHour = value;
                        },
                        children: List.generate(24, (index) => Center(child: Text("${index.toString().padLeft(2, '0')}", style: const TextStyle(fontSize: 28)))),
                        scrollController: FixedExtentScrollController(initialItem: 8),
                      ),
                    ),
                    const SizedBox(width: 20),
                    SizedBox(
                      width: 100,
                      child: CupertinoPicker(
                        itemExtent: 60.0,
                        onSelectedItemChanged: (int value) {
                          selectedMinute = value;
                        },
                        children: List.generate(60, (index) => Center(child: Text("${index.toString().padLeft(2, '0')}", style: const TextStyle(fontSize: 28)))),
                        scrollController: FixedExtentScrollController(initialItem: 0),
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    _timeControllers[index].text = "${selectedHour.toString().padLeft(2, '0')}:${selectedMinute.toString().padLeft(2, '0')}";
                  });
                  Navigator.pop(context);
                },
                child: const Text("OK", style: TextStyle(fontSize: 20, color: Color.fromRGBO(0, 105, 148, 1))),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime initialDate = DateTime.now();
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color.fromRGBO(0, 105, 148, 1),
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate != null) {
      setState(() {
        _startDateController.text = DateFormat('dd/MM/yyyy').format(pickedDate);
      });
    }
  }

  void _updateTimeFields(int? newFrequency) {
    if (newFrequency != null) {
      setState(() {
        _frequency = newFrequency;
        _timeControllers = List.generate(newFrequency, (index) => TextEditingController());
      });
    }
  }

  bool _validateFields() {
    print("Iniciando validação"); // Log para debug
    List<String> errors = [];

    if (_nameController.text.isEmpty) {
      errors.add("Nome do Medicamento não preenchido");
    }
    if (_stockController.text.isEmpty) {
      errors.add("Quantidade Total não preenchida");
    }
    if (_type == null) {
      errors.add("Tipo do Medicamento não selecionado");
    }
    if (_dosageController.text.isEmpty) {
      errors.add("Dosagem não preenchida");
    }
    if (_frequency == null) {
      errors.add("Modo de Usar não selecionado");
    }
    if (_timeControllers.any((controller) => controller.text.isEmpty)) {
      errors.add("Um ou mais horários não preenchidos");
    }
    if (_startDateController.text.isEmpty) {
      errors.add("Data de Início não preenchida");
    }

    if (errors.isNotEmpty) {
      print("Erros encontrados: $errors"); // Log para debug
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            errors.join('\n'),
            style: const TextStyle(fontSize: 20),
          ),
          duration: Duration(seconds: errors.length > 1 ? 4 : 3),
        ),
      );
      return false;
    }

    if (_timeControllers.length != _frequency) {
      print("Inconsistência nos horários: ${_timeControllers.length} != $_frequency"); // Log para debug
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Preencha todos os horários conforme o Modo de Usar!", style: TextStyle(fontSize: 20))),
      );
      return false;
    }

    print("Validação OK"); // Log para debug
    return true;
  }

  void _clearFields() {
    _nameController.clear();
    _stockController.clear();
    _dosageController.clear();
    _startDateController.text = DateFormat('dd/MM/yyyy').format(DateTime.now());
    setState(() {
      _type = null;
      _isContinuous = false;
      _image = null;
      _frequency = null;
      _timeControllers = [TextEditingController()];
    });
    FocusScope.of(context).requestFocus(_nameFocusNode); // Move o foco para o campo Nome
  }

  Future<void> _saveMedication() async {
    print("Iniciando _saveMedication");
    if (!_validateFields()) {
      print("Validação falhou");
      return;
    }

    try {
      print("Esperando o _databaseFuture");
      final database = await _databaseFuture;
      if (database == null) {
        print("Erro: _databaseFuture retornou null");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Erro: Banco de dados não inicializado", style: TextStyle(fontSize: 20))),
        );
        return;
      }
      print("Tentando salvar no banco de dados");
      await database.insert(
        'medications',
        {
          'name': _nameController.text,
          'stock': _stockController.text,
          'type': _type,
          'dosage': _dosageController.text,
          'frequency': _frequency,
          'times': _timeControllers.map((c) => c.text).join(','),
          'startDate': _startDateController.text,
          'isContinuous': _isContinuous ? 1 : 0,
          'imagePath': _image?.path,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      print("Medicamento salvo com sucesso");
      _showPostSaveOptions();
    } catch (e) {
      print("Erro ao salvar no banco de dados: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erro ao salvar: $e", style: const TextStyle(fontSize: 20))),
      );
    }
  }

  void _showPostSaveOptions() {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text(
          "Medicamento salvo com sucesso!",
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          "O que você gostaria de fazer?",
          style: TextStyle(fontSize: 20),
        ),  
        actions: [
          TextButton(
            onPressed: () {
              print("Clicou em Cadastrar Novo");
              Navigator.pop(dialogContext);
              _clearFields();
              print("Foco solicitado para Nome do Medicamento");
              FocusScope.of(context).requestFocus(_nameFocusNode);
            },
            child: const Text(
              "Cadastrar Novo",
              style: TextStyle(color: Color.fromRGBO(0, 105, 148, 1), fontSize: 20),
            ),
          ),
          TextButton(
            onPressed: () async {
              print("Esperando _databaseFuture para Ver Cadastrados");
              final database = await _databaseFuture;
              if (database == null) {
                print("Erro: _databaseFuture retornou null");
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Erro: Banco de dados não inicializado", style: TextStyle(fontSize: 20))),
                );
                Navigator.pop(dialogContext);
                return;
              }
              Navigator.pop(dialogContext);
              Navigator.push(context, MaterialPageRoute(builder: (context) => MedicationListScreen(database: database)));
            },
            child: const Text(
              "Ver Cadastrados",
              style: TextStyle(color: Color.fromRGBO(0, 105, 148, 1), fontSize: 20),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Database>(
      future: _databaseFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(child: Text("Erro ao carregar o banco de dados: ${snapshot.error}")),
          );
        }
        // Banco de dados está pronto, prossegue com a tela normal
        return Scaffold(
          backgroundColor: const Color(0xFFCCCCCC),
          appBar: AppBar(
            backgroundColor: const Color(0xFFCCCCCC),
            toolbarHeight: 140,
            leading: Padding(
              padding: const EdgeInsets.only(top: 20.0, left: 16.0),
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Color.fromRGBO(0, 105, 148, 1), size: 42),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            title: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text("Cadastrar", style: TextStyle(color: Color.fromRGBO(0, 105, 148, 1), fontSize: 36, fontWeight: FontWeight.bold)),
                Text("Medicamento", style: TextStyle(color: Color.fromRGBO(85, 170, 85, 1), fontSize: 36, fontWeight: FontWeight.bold)),
              ],
            ),
            centerTitle: true,
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 30),
                _buildTextField(_nameController, "Nome do Medicamento", centerText: false),
                const SizedBox(height: 20),
                _buildTextField(_stockController, "Quantidade Total", keyboardType: TextInputType.number),
                const SizedBox(height: 20),
                _buildTypeDropdown(),
                const SizedBox(height: 20),
                _buildTextField(_dosageController, "Dosagem (por dia)", keyboardType: TextInputType.numberWithOptions(decimal: true)),
                const SizedBox(height: 20),
                _buildFrequencyDropdown(),
                const SizedBox(height: 20),
                ..._timeControllers.asMap().entries.map((entry) {
                  int index = entry.key;
                  TextEditingController controller = entry.value;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10.0),
                    child: _buildTimeField(controller, "${index + 1}° Horário", index),
                  );
                }).toList(),
                const SizedBox(height: 20),
                _buildContinuousSwitch(),
                const SizedBox(height: 20),
                _buildTextField(_startDateController, "Data de Início"),
                const SizedBox(height: 20),
                if (_showPhotoOption) _buildPhotoSection(),
                const SizedBox(height: 20),
                _buildSaveButton(),
                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, {TextInputType keyboardType = TextInputType.text, bool centerText = true}) {
    final FocusNode focusNode = label == "Nome do Medicamento" ? _nameFocusNode : FocusNode(); // Usa o FocusNode específico para o nome
    bool hasFocus = false;

    return StatefulBuilder(
      builder: (BuildContext context, StateSetter setState) {
        focusNode.addListener(() {
          if (focusNode.hasFocus && !hasFocus) {
            setState(() {
              hasFocus = true;
            });
          }
        });

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(color: Color.fromRGBO(0, 85, 128, 1), fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            TextField(
              controller: controller,
              keyboardType: keyboardType,
              textAlign: centerText ? TextAlign.center : TextAlign.left,
              textCapitalization: label == "Nome do Medicamento" ? TextCapitalization.words : TextCapitalization.none,
              readOnly: label == "Data de Início",
              onTap: label == "Data de Início" ? () => _selectDate(context) : null,
              focusNode: focusNode,
              decoration: InputDecoration(
                hintText: hasFocus ? null : null,
                labelText: label == "Nome do Medicamento" ? "Insira o nome" :
                          label == "Quantidade Total" ? "Insira a quantidade total" :
                          label == "Dosagem (por dia)" ? "Insira a quantidade diária" :
                          "Insira a data",
                labelStyle: const TextStyle(fontSize: 20, color: Color.fromRGBO(0, 85, 128, 1)),
                floatingLabelBehavior: FloatingLabelBehavior.never,
                filled: true,
                fillColor: Colors.grey[200],
                border: const OutlineInputBorder(borderSide: BorderSide(color: Colors.grey, width: 2.0)),
              ),
              style: const TextStyle(fontSize: 24),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTypeDropdown() {
    const List<String> _medicationTypes = ["Comprimidos", "Cápsulas", "Xarope", "Injeção"]; // Ajustado pra plural
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Tipo do Medicamento",
          style: TextStyle(color: Color.fromRGBO(0, 85, 128, 1), fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Container(
          height: 70.0,
          decoration: BoxDecoration(
            color: Colors.grey[200],
            border: Border.all(color: Colors.grey, width: 2.0),
            borderRadius: BorderRadius.circular(4.0),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _medicationTypes.contains(_type) ? _type : null, // Só usa _type se estiver na lista
                hint: const Text(
                  "Selecione o tipo",
                  style: TextStyle(
                    fontSize: 20,
                    color: Color.fromRGBO(0, 85, 128, 1),
                    fontWeight: FontWeight.normal,
                  ),
                ),
                isExpanded: true,
                alignment: Alignment.centerLeft,
                items: _medicationTypes.map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(
                      value,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.normal),
                    ),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  setState(() {
                    _type = newValue;
                  });
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
  class MedicationRegistrationScreen extends StatefulWidget {
  Widget _buildFrequencyDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Modo de Usar",
          style: TextStyle(color: Color.fromRGBO(0, 85, 128, 1), fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Container(
          height: 70.0,
          decoration: BoxDecoration(
            color: Colors.grey[200],
            border: Border.all(color: Colors.grey, width: 2.0),
            borderRadius: BorderRadius.circular(4.0),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0), // Espaço simétrico
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: _frequency,
                hint: const Text(
                  "Selecione",
                  style: TextStyle(
                    fontSize: 20,
                    color: Color.fromRGBO(0, 85, 128, 1),
                    fontWeight: FontWeight.normal,
                  ),
                ),
                isExpanded: true,
                icon: const Icon(Icons.arrow_drop_down, size: 30, color: Color.fromRGBO(0, 85, 128, 1)), // Personaliza a seta
                items: List.generate(5, (index) => index + 1).map((int value) {
                  return DropdownMenuItem<int>(
                    value: value,
                    child: Text(
                      "$value x por dia",
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.normal),
                    ),
                  );
                }).toList(),
                onChanged: (int? newValue) {
                  setState(() {
                    _frequency = newValue;
                    _updateTimeFields(newValue ?? 1);
                  });
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTimeField(TextEditingController controller, String label, int index) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Color.fromRGBO(0, 85, 128, 1), fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          readOnly: true,
          textAlign: TextAlign.left,
          decoration: const InputDecoration(
            hintText: "Selecione",
            hintStyle: TextStyle(fontSize: 20, color: Color.fromRGBO(0, 85, 128, 1)),
            filled: true,
            fillColor: Colors.grey,
            border: OutlineInputBorder(borderSide: BorderSide(color: Colors.grey, width: 2.0)),
          ),
          style: const TextStyle(fontSize: 24),
          onTap: () => _selectTime(context, index),
        ),
      ],
    );
  }

  Widget _buildContinuousSwitch() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          "Uso Contínuo?",
          style: TextStyle(color: Color.fromRGBO(0, 85, 128, 1), fontSize: 20, fontWeight: FontWeight.bold),
        ),
        Switch(
          value: _isContinuous,
          onChanged: (value) => setState(() => _isContinuous = value),
          activeColor: const Color.fromRGBO(0, 105, 148, 1),
        ),
      ],
    );
  }

  Widget _buildPhotoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Fotografar Embalagem (recomendado para facilitar a identificação)",
          style: TextStyle(color: Color.fromRGBO(0, 85, 128, 1), fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        _image == null
            ? ElevatedButton.icon(
                onPressed: () => _pickImage(),
                icon: const Icon(Icons.camera_alt, color: Colors.white),
                label: const Text("Tirar Foto", style: TextStyle(color: Colors.white, fontSize: 24)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromRGBO(0, 105, 148, 1),
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                ),
              )
            : Row(
                children: [
                  Image.file(_image!, height: 100, width: 100, fit: BoxFit.cover),
                  const SizedBox(width: 10),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.red, size: 30),
                    onPressed: () => setState(() => _image = null),
                  ),
                ],
              ),
      ],
    );
  }

  Widget _buildSaveButton() {
    return Center(
      child: Builder(
        builder: (BuildContext context) {
          return ElevatedButton(
            onPressed: () {
              print("Botão Salvar clicado"); // Log para debug
              _saveMedication();
            },
            child: const Text("Salvar", style: TextStyle(color: Colors.white, fontSize: 24)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color.fromRGBO(0, 105, 148, 1),
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
            ),
          );
        },
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