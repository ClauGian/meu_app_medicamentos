import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:flutter/services.dart';
import '../utils/formatters.dart';

class UserRegistrationScreen extends StatefulWidget {
  final Database database;

  const UserRegistrationScreen({super.key, required this.database});

  @override
  _UserRegistrationScreenState createState() => _UserRegistrationScreenState();
}

class _UserRegistrationScreenState extends State<UserRegistrationScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _loadUser();
    widget.database.query('users', limit: 1).then((result) {
      setState(() {
        _isEditing = result.isEmpty;
      });
      print('DEBUG: Modo de edição inicial: $_isEditing');
    });
  }

  Future<void> _loadUser() async {
    try {
      final result = await widget.database.query(
        'users',
        limit: 1,
      );
      if (result.isNotEmpty) {
        final user = result.first;
        _nameController.text = user['name'] as String? ?? '';
        _phoneController.text = user['phone'] as String? ?? '';
        _dateController.text = user['date'] as String? ?? '';
        print('DEBUG: Dados do usuário carregados: $user');
      } else {
        print('DEBUG: Nenhum usuário encontrado.');
      }
    } catch (e) {
      print('DEBUG: Erro ao carregar usuário: $e');
    }
  }

  void _toggleEditing() {
    setState(() {
      _isEditing = !_isEditing;
    });
    print('DEBUG: Modo de edição: $_isEditing');
  }

  void _validateAndSave() async {
    if (!_isEditing) return;

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
            'A Data de Nascimento deve ter o formato dd/mm/aaaa.',
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
      final existing = await widget.database.query('users', limit: 1);
      if (existing.isEmpty) {
        int id = await widget.database.insert(
          'users',
          {'name': name, 'phone': phone, 'date': date},
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        print('DEBUG: Usuário salvo com ID: $id');
      } else {
        await widget.database.update(
          'users',
          {'name': name, 'phone': phone, 'date': date},
          where: 'id = ?',
          whereArgs: [existing.first['id']],
        );
        print('DEBUG: Usuário atualizado: ID ${existing.first['id']}');
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Usuário salvo com sucesso!',
            style: TextStyle(fontSize: 20),
          ),
          duration: Duration(seconds: 2),
        ),
      );
      setState(() {
        _isEditing = false;
      });
      await Future.delayed(const Duration(seconds: 2));
      Navigator.pop(context);
    } catch (e) {
      print('DEBUG: Erro ao salvar usuário: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Erro ao salvar o usuário.',
            style: TextStyle(fontSize: 20),
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _dateController.dispose();
    _phoneController.dispose();
    super.dispose();
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
                  fillColor: Colors.white,
                ),
                style: const TextStyle(fontSize: 24),
                textCapitalization: TextCapitalization.words,
                enabled: _isEditing,
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
                  fillColor: Colors.white,
                ),
                style: const TextStyle(fontSize: 24),
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(8),
                  DateInputFormatter(),
                ],
                enabled: _isEditing,
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
                  fillColor: Colors.white,
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
              const SizedBox(height: 80),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
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