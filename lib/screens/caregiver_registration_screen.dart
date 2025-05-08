import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:flutter/services.dart';
import '../utils/formatters.dart';

class CaregiverRegistrationScreen extends StatefulWidget {
  final Database database;

  const CaregiverRegistrationScreen({super.key, required this.database});

  @override
  CaregiverRegistrationScreenState createState() => CaregiverRegistrationScreenState();
}

class CaregiverRegistrationScreenState extends State<CaregiverRegistrationScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _relationController = TextEditingController();
  bool _isEditing = false; // Controla se os campos são editáveis

  @override
  void initState() {
    super.initState();
    _loadCaregiver(); // Carregar dados do cuidador ao iniciar
    // Verificar se há cuidador para decidir o estado inicial
    widget.database.query('caregivers', limit: 1).then((result) {
      setState(() {
        _isEditing = result.isEmpty; // Habilitar edição se não houver cuidador
      });
      print('DEBUG: Modo de edição inicial: $_isEditing');
    });
  }

  Future<void> _loadCaregiver() async {
    try {
      final result = await widget.database.query(
        'caregivers',
        limit: 1, // Garante que buscamos apenas um cuidador
      );
      if (result.isNotEmpty) {
        final caregiver = result.first;
        _nameController.text = caregiver['name'] as String? ?? '';
        _phoneController.text = caregiver['phone'] as String? ?? '';
        print('DEBUG: Dados do cuidador carregados: $caregiver');
      } else {
        print('DEBUG: Nenhum cuidador encontrado.');
      }
    } catch (e) {
      print('DEBUG: Erro ao carregar cuidador: $e');
    }
  }

  void _toggleEditing() {
    setState(() {
      _isEditing = !_isEditing; // Alternar entre editável e readonly
    });
    print('DEBUG: Modo de edição: $_isEditing');
  }

  void _validateAndSave() async {
    if (!_isEditing) return; // Impedir salvamento se não estiver em modo de edição

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

    try {
      final existing = await widget.database.query('caregivers', limit: 1);
      if (existing.isEmpty) {
        // Inserir novo cuidador
        int id = await widget.database.insert(
          'caregivers',
          {'name': name, 'phone': phone},
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        print('DEBUG: Cuidador salvo com ID: $id');
      } else {
        // Atualizar cuidador existente
        await widget.database.update(
          'caregivers',
          {'name': name, 'phone': phone},
          where: 'id = ?',
          whereArgs: [existing.first['id']],
        );
        print('DEBUG: Cuidador atualizado: ID ${existing.first['id']}');
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Cuidador salvo com sucesso!',
            style: TextStyle(fontSize: 20),
          ),
          duration: Duration(seconds: 2),
        ),
      );
      setState(() {
        _isEditing = false; // Voltar para readonly após salvar
      });
      await Future.delayed(const Duration(seconds: 2));
      Navigator.pop(context);
    } catch (e) {
      print('DEBUG: Erro ao salvar cuidador: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Erro ao salvar o cuidador.',
            style: TextStyle(fontSize: 20),
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _relationController.dispose();
    super.dispose();
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
                enabled: _isEditing, // Campo editável apenas se _isEditing for true
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
                  PhoneInputFormatter(),
                ],
                enabled: _isEditing,
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
                enabled: _isEditing,
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
                    onPressed: _isEditing ? _validateAndSave : _toggleEditing,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color.fromRGBO(0, 105, 148, 1),
                      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                    ),
                    child: Text(
                      _isEditing ? 'Salvar' : 'Alterar',
                      style: const TextStyle(
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