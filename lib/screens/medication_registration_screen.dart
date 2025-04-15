import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart'; // Para CupertinoPicker
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:sqflite/sqflite.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as path; // Para path.join
import 'medication_list_screen.dart';
import 'package:flutter/services.dart';
import 'package:scroll_to_index/scroll_to_index.dart';
import 'package:dropdown_button2/dropdown_button2.dart';


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
  final TextEditingController _typeController = TextEditingController();
  final TextEditingController _instructionsController = TextEditingController();
  final FocusNode _nameFocusNode = FocusNode(); // Adicionado aqui
  final FocusNode _stockFocusNode = FocusNode();
  final FocusNode _dosageFocusNode = FocusNode();
  final FocusNode _startDateFocusNode = FocusNode();
  final FocusNode _firstTimeFocusNode = FocusNode();
  final FocusNode _secondTimeFocusNode = FocusNode();
  final FocusNode _thirdTimeFocusNode = FocusNode();
  final FocusNode _fourthTimeFocusNode = FocusNode();
  final FocusNode _typeFocusNode = FocusNode();
  final FocusNode _instructionsFocusNode = FocusNode();    
  final GlobalKey _dropdownKey = GlobalKey();
  final scrollDirection = Axis.vertical;
  final scrollController = AutoScrollController();  
  final FocusNode _usageFocusNode = FocusNode();
  final GlobalKey _typeDropdownTagKey = GlobalKey();
  final GlobalKey _frequencyDropdownTagKey = GlobalKey();
  final GlobalKey _typeKey = GlobalKey(); // ← nova chave para o campo Tipo
  final GlobalKey _usageKey = GlobalKey();



  String? _type;
  bool _isContinuous = false;
  File? _image;
  bool _showPhotoOption = false;
  final ImagePicker _picker = ImagePicker();
  int? _frequency;
  List<TextEditingController> _timeControllers = [TextEditingController()];
  Future<Database>? _databaseFuture;

  void _checkDuplicateMedicationOnNameFieldExit() async {
    if (!mounted) return;

    final database = await _databaseFuture;
    if (database == null) return;

    final List<Map<String, dynamic>> existingMedications = await database.query('medications');

    String normalizeName(String name) {
      return name.replaceAll(' ', '').toLowerCase();
    }

    final newNameNormalized = normalizeName(_nameController.text);

    final bool alreadyExists = existingMedications.any((med) {
      final existingName = med['name'] as String? ?? '';
      return normalizeName(existingName) == newNameNormalized;
    });

    if (alreadyExists) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Medicamento já cadastrado"),
          content: const Text("Este nome já foi adicionado. Escolha outro ou edite o existente."),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                // Volta o foco para o campo do nome
                FocusScope.of(context).requestFocus(_nameFocusNode);
              },
              child: const Text("OK"),
            ),
          ],
        ),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    print("Chamando _initDatabase");
    _databaseFuture = _initDatabase();
    
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
      _timeControllers.clear();
      _timeControllers.addAll(
        times.isNotEmpty
            ? times.map((time) => TextEditingController(text: time)).toList()
            : [TextEditingController()],
      );
    } else {
      _timeControllers.add(TextEditingController());
    }

    // Foco inicial com atraso maior
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          print("Forçando foco no nome após renderização");
          try {
            scrollController.jumpTo(0.0);
            print("Rolagem inicial resetada");
          } catch (e) {
            print("Erro ao resetar rolagem: $e");
          }
          _nameFocusNode.requestFocus();
          print("Teclado solicitado para Nome do Medicamento");
        }
      });
    });

    _nameFocusNode.addListener(() {
      if (!_nameFocusNode.hasFocus) {
        _checkDuplicateMedicationOnNameFieldExit();
      }
    });

    _checkUserAge();
    print("initState concluído");
  }

  @override
  void dispose() {
    // FocusNodes
    _nameFocusNode.dispose();
    _stockFocusNode.dispose();
    _typeFocusNode.dispose();
    _dosageFocusNode.dispose();
    _instructionsFocusNode.dispose();
    _firstTimeFocusNode.dispose();
    _secondTimeFocusNode.dispose();
    _thirdTimeFocusNode.dispose();
    _fourthTimeFocusNode.dispose();
    _startDateFocusNode.dispose();
    _typeController.dispose();
    _instructionsController.dispose();

    _nameController.dispose();
    _stockController.dispose();
    _dosageController.dispose();
    _startDateController.dispose();

    // Lista de horários
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
                        scrollController: FixedExtentScrollController(initialItem: 8),
                        children: List.generate(
                          24,
                          (index) => Center(
                            child: Text(
                              index.toString().padLeft(2, '0'),
                              style: const TextStyle(fontSize: 28),
                            ),
                          ),
                        ),
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
                        scrollController: FixedExtentScrollController(initialItem: 0),
                        children: List.generate(
                          60,
                          (index) => Center(
                            child: Text(
                              index.toString().padLeft(2, '0'),
                              style: const TextStyle(fontSize: 28),
                            ),
                          ),
                        ),
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

  String normalizeName(String name) {
    return name.replaceAll(RegExp(r'\s+'), '').toLowerCase();
  }

  void _showFieldError(String message, FocusNode focusNode) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message, style: const TextStyle(fontSize: 20))),
    );
    FocusScope.of(context).requestFocus(focusNode);
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message, style: const TextStyle(fontSize: 20))),
    );
  }

  Future<void> _saveMedication() async {
    print("Iniciando _saveMedication");
    // Verificação de campos obrigatórios
    if (_nameController.text.trim().isEmpty) {
      _showFieldError("Preencha o nome do medicamento.", _nameFocusNode);
      return;
    }
    if (_stockController.text.trim().isEmpty) {
      _showFieldError("Preencha a quantidade total.", _stockFocusNode);
      return;
    }
    if (_dosageController.text.trim().isEmpty) {
      _showFieldError("Preencha a dosagem por dia.", _dosageFocusNode);
      return;
    }
    if (_startDateController.text.trim().isEmpty) {
      _showFieldError("Selecione a data de início.", _startDateFocusNode);
      return;
    }
    if (_type == null) {
      _showSnack("Selecione o tipo do medicamento.");
      return;
    }
    if (_frequency == null || _frequency == 0) {
      _showSnack("Selecione o modo de usar.");
      return;
    }
    if (_timeControllers.any((c) => c.text.trim().isEmpty)) {
      _showSnack("Preencha todos os horários de uso.");
      return;
    }


    try {
      print("Esperando o _databaseFuture");
      final database = await _databaseFuture;
      // Verificação de medicamento duplicado
      if (!mounted) return;

      if (database == null) {
        print("Erro: _databaseFuture retornou null (durante verificação de duplicidade)");
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Erro: Banco de dados não inicializado")),
        );
        return;
      }

      final List<Map<String, dynamic>> existingMedications = await database.query('medications');


      // Função de normalização (remove espaços e ignora maiúsculas/minúsculas)
      String normalizeName(String name) {
        return name.replaceAll(' ', '').toLowerCase();
      }

      final newNameNormalized = normalizeName(_nameController.text);

      final bool alreadyExists = existingMedications.any((med) {
        final existingName = med['name'] ?? '';
        return normalizeName(existingName) == newNameNormalized;
      });

      if (alreadyExists) {
        print("Medicamento já cadastrado");
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("Aviso"),
            content: const Text("Medicamento já cadastrado."),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("OK"),
              ),
            ],
          ),
        );
        return; // Interrompe o salvamento
      }

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
          body: LayoutBuilder(
            builder: (context, constraints) {
              return ListView(
                controller: scrollController,
                padding: const EdgeInsets.only(left: 16.0, top: 46.0, right: 16.0, bottom: 200.0),
                children: [
                  _buildTextField(_nameController, "Nome do Medicamento", centerText: false, focusNode: _nameFocusNode, autofocus: true),
                  const SizedBox(height: 20),
                  _buildTextField(_stockController, "Quantidade Total", keyboardType: TextInputType.number, focusNode: _stockFocusNode),
                  const SizedBox(height: 20),
                  _buildTypeDropdown(),
                  const SizedBox(height: 20),
                  _buildTextField(_dosageController, "Dosagem (por dia)", keyboardType: TextInputType.numberWithOptions(decimal: true), focusNode: _dosageFocusNode),
                  const SizedBox(height: 2),
                  _buildFrequencyDropdown(),
                  const SizedBox(height: 20),
                  ..._timeControllers.asMap().entries.map((entry) {
                    int index = entry.key;
                    TextEditingController controller = entry.value;
                    FocusNode? focusNode;
                    if (index == 0) {
                      focusNode = _firstTimeFocusNode;
                    } else if (index == 1) {
                      focusNode = _secondTimeFocusNode;
                    } else if (index == 2) {
                      focusNode = _thirdTimeFocusNode;
                    } else if (index == 3) {
                      focusNode = _fourthTimeFocusNode;
                    }
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10.0),
                      child: _buildTimeField(controller, "${index + 1}° Horário", index, focusNode: focusNode),
                    );
                  }).toList(),
                  const SizedBox(height: 20),
                  AutoScrollTag(
                    key: GlobalKey(),
                    controller: scrollController,
                    index: 11 + _timeControllers.length,
                    highlightColor: Colors.transparent,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Uso Contínuo",
                          style: TextStyle(color: Color.fromRGBO(0, 85, 128, 1), fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        Switch(
                          value: _isContinuous,
                          onChanged: (value) => setState(() => _isContinuous = value),
                          activeColor: const Color.fromRGBO(0, 105, 148, 1),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  AutoScrollTag(
                    key: GlobalKey(),
                    controller: scrollController,
                    index: 11 + _timeControllers.length + 1,
                    highlightColor: Colors.transparent,
                    child: GestureDetector(
                      onTap: () async {
                        await _selectDate(context);
                        try {
                          await scrollController.scrollToIndex(
                            11 + _timeControllers.length + 2,
                            preferPosition: AutoScrollPosition.begin,
                            duration: const Duration(milliseconds: 200),
                          );
                          print("Rolou para o campo Tirar Foto (índice ${11 + _timeControllers.length + 2})");
                        } catch (e) {
                          print("Erro ao rolar pro campo Tirar Foto: $e");
                        }
                      },
                      child: _buildTextField(
                        _startDateController,
                        "Data de Início",
                        focusNode: _startDateFocusNode,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  AutoScrollTag(
                    key: GlobalKey(),
                    controller: scrollController,
                    index: 11 + _timeControllers.length + 2,
                    highlightColor: Colors.transparent,
                    child: _showPhotoOption ? _buildPhotoSection() : Container(),
                  ),
                  const SizedBox(height: 20),
                  AutoScrollTag(
                    key: GlobalKey(),
                    controller: scrollController,
                    index: 11 + _timeControllers.length + 3,
                    highlightColor: Colors.transparent,
                    child: _buildSaveButton(),
                  ),
                  const SizedBox(height: 20),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label, {
    TextInputType keyboardType = TextInputType.text,
    bool centerText = true,
    FocusNode? focusNode,
    bool autofocus = false,
  }) {
    final isNameField = label == "Nome do Medicamento";
    final isStockField = label == "Quantidade Total";

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
          keyboardType: label == "Quantidade Total" ? TextInputType.number : keyboardType,
          inputFormatters: label == "Quantidade Total" ? [FilteringTextInputFormatter.digitsOnly] : null,
          textAlign: centerText ? TextAlign.center : TextAlign.left,
          textCapitalization: label == "Nome do Medicamento" ? TextCapitalization.words : TextCapitalization.none,
          readOnly: label == "Data de Início",
          onTap: label == "Data de Início" ? () => _selectDate(context) : null,
          focusNode: focusNode,
          autofocus: autofocus,
          onSubmitted: (_) {
            if (label == "Nome do Medicamento") {
              FocusScope.of(context).requestFocus(_stockFocusNode);
            } else if (label == "Quantidade Total") {
              FocusScope.of(context).requestFocus(_typeFocusNode);
            } else if (label == "Tipo") {
              FocusScope.of(context).requestFocus(_dosageFocusNode);
            } else if (label == "Dosagem (por dia)") {
              FocusScope.of(context).requestFocus(_instructionsFocusNode);
            } else if (label == "Modo de Usar") {
              FocusScope.of(context).requestFocus(_firstTimeFocusNode);
            } else if (label == "1° Horário") {
              FocusScope.of(context).requestFocus(_secondTimeFocusNode);
            } else if (label == "2° Horário") {
              FocusScope.of(context).requestFocus(_startDateFocusNode);
            } else if (label == "3° Horário") {
              FocusScope.of(context).requestFocus(_startDateFocusNode);
            }
          },
          decoration: InputDecoration(
            labelText: label == "Nome do Medicamento"
                ? "Insira o nome"
                : label == "Quantidade Total"
                    ? "Insira a quantidade total"
                    : label == "Dosagem (por dia)"
                        ? "Insira a quantidade diária"
                        : label == "Data de Início"
                            ? "Selecione a data"
                            : "Insira a data",
            labelStyle: const TextStyle(fontSize: 20, color: Color.fromRGBO(0, 85, 128, 1)),
            floatingLabelBehavior: FloatingLabelBehavior.never,
            filled: true,
            fillColor: Colors.grey[200],
            border: OutlineInputBorder(
              borderSide: BorderSide(
                color: label == "Data de Início" ? Color.fromRGBO(85, 170, 85, 1) : Colors.grey,
                width: label == "Data de Início" ? 5.0 : 2.0,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(
                color: label == "Data de Início" ? Color.fromRGBO(85, 170, 85, 1) : Colors.grey,
                width: label == "Data de Início" ? 5.0 : 2.0,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Color.fromRGBO(85, 170, 85, 1), width: 5.0),
            ),
          ),
          style: const TextStyle(fontSize: 24),
        ),
      ],
    );
  }

  Widget _buildTypeDropdown() {
    const List<String> medicationTypes = ["Comprimidos", "Cápsulas", "Gotas", "Xarope", "Injeção"];

    return Focus(
      focusNode: _typeFocusNode,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Tipo do Medicamento",
            style: TextStyle(
              color: Color.fromRGBO(0, 85, 128, 1),
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          AutoScrollTag(
            key: _typeDropdownTagKey,
            controller: scrollController,
            index: 3,
            highlightColor: Colors.transparent,
            child: Container(
              key: _typeKey, // ← importante!
              decoration: BoxDecoration(
                color: Colors.grey[200],
                border: Border.all(
                  color: _typeFocusNode.hasFocus ? const Color.fromRGBO(85, 170, 85, 1) : Colors.transparent,
                  width: 5.0,
                ),
                borderRadius: BorderRadius.circular(4.0),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 16.0),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton2<String>(
                    key: _dropdownKey,
                    value: medicationTypes.contains(_type) ? _type : null,
                    isExpanded: true,
                    hint: const Text(
                      "Selecione o tipo",
                      style: TextStyle(
                        fontSize: 20,
                        color: Color.fromRGBO(0, 85, 128, 1),
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                    items: medicationTypes.map((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(
                          value,
                          style: const TextStyle(fontSize: 20),
                        ),
                      );
                    }).toList(),
                    onMenuStateChange: (isOpen) async {
                      if (isOpen) {
                        print("Menu do dropdown de Tipo está abrindo...");

                        // Aguarda o layout ser renderizado
                        await Future.delayed(const Duration(milliseconds: 50));

                        try {
                          final box = _typeKey.currentContext!.findRenderObject() as RenderBox;
                          final position = box.localToGlobal(Offset.zero);
                          final screenHeight = MediaQuery.of(context).size.height;

                          final bottomMargin = 340.0; // espaço para mostrar o dropdown confortavelmente

                          final distanceToBottom = screenHeight - position.dy;

                          if (distanceToBottom < bottomMargin) {
                            final scrollOffset = bottomMargin - distanceToBottom;
                            final newOffset = scrollController.offset + scrollOffset;
                            await scrollController.animateTo(
                              newOffset,
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                            );
                            print("Rolagem ajustada em $scrollOffset pixels");
                          }
                        } catch (e) {
                          print("Erro ao ajustar rolagem dinâmica: $e");
                        }
                      }
                    },
                    onChanged: (String? newValue) async {
                      setState(() {
                        _type = newValue;
                      });
                      print("Selecionou tipo: $newValue");

                      await Future.delayed(const Duration(milliseconds: 150));
                      await scrollController.scrollToIndex(
                        5,
                        preferPosition: AutoScrollPosition.begin,
                        duration: const Duration(milliseconds: 200),
                      );
                      print("Rolou para o campo de dosagem (índice 5)");

                      FocusScope.of(context).requestFocus(_dosageFocusNode);
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFrequencyDropdown() {
    return Focus(
      focusNode: _usageFocusNode,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Modo de Usar",
            style: TextStyle(
              color: Color.fromRGBO(0, 85, 128, 1),
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          AutoScrollTag(
            key: _frequencyDropdownTagKey,
            controller: scrollController,
            index: 9,
            highlightColor: Colors.transparent,
            child: Container(
              key: _usageKey,
              width: double.infinity,
              constraints: const BoxConstraints(minHeight: 75),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                border: Border.all(
                  color: _usageFocusNode.hasFocus ? const Color.fromRGBO(85, 170, 85, 1) : Colors.transparent,
                  width: 5.0,
                ),
                borderRadius: BorderRadius.circular(4.0),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 1.0),
              child: DropdownButtonHideUnderline(
                child: DropdownButton2<int>(
                  value: _frequency,
                  isExpanded: true,
                  hint: const Text(
                    "Selecione",
                    style: TextStyle(
                      fontSize: 20,
                      color: Color.fromRGBO(0, 85, 128, 1),
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                  customButton: const Padding(
                    padding: EdgeInsets.only(right: 12.0),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Icon(
                        Icons.arrow_drop_down,
                        size: 30,
                        color: Color.fromRGBO(0, 85, 128, 1),
                      ),
                    ),
                  ),
                  dropdownStyleData: DropdownStyleData(
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                    ),
                    maxHeight: 250,
                    offset: const Offset(0, 9), // Ajuste fino: 9 pixels pra baixo
                    elevation: 0,
                  ),
                  items: List.generate(5, (index) => index + 1).map((int value) {
                    return DropdownMenuItem<int>(
                      value: value,
                      child: Text(
                        "$value x por dia",
                        style: const TextStyle(fontSize: 20),
                      ),
                    );
                  }).toList(),
                  onMenuStateChange: (isOpen) async {
                    if (isOpen) {
                      await Future.delayed(const Duration(milliseconds: 75)); // Manter atraso
                      try {
                        final box = _usageKey.currentContext!.findRenderObject() as RenderBox;
                        final position = box.localToGlobal(Offset.zero);
                        final screenHeight = MediaQuery.of(context).size.height;
                        final bottomMargin = 320.0; // Manter margem
                        final distanceToBottom = screenHeight - position.dy;
                        if (distanceToBottom < bottomMargin) {
                          final scrollOffset = bottomMargin - distanceToBottom;
                          final newOffset = scrollController.offset + scrollOffset;
                          await scrollController.animateTo(
                            newOffset,
                            duration: const Duration(milliseconds: 120), // Manter duração
                            curve: Curves.easeInOut,
                          );
                        }
                      } catch (e) {
                        print("Erro ao ajustar rolagem: $e");
                      }
                    }
                  },
                  onChanged: (int? newValue) async {
                    if (newValue != null) {
                      setState(() {
                        _frequency = newValue;
                        _updateTimeFields(_frequency);
                      });
                      await Future.delayed(const Duration(milliseconds: 150));
                      await scrollController.scrollToIndex(
                        11,
                        preferPosition: AutoScrollPosition.begin,
                        duration: const Duration(milliseconds: 200),
                      );
                      FocusScope.of(context).requestFocus(_firstTimeFocusNode);
                    }
                  }
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildTimeField(TextEditingController controller, String label, int index, {FocusNode? focusNode}) {
    final List<FocusNode> timeFocusNodes = [
      _firstTimeFocusNode,
      _secondTimeFocusNode,
      _thirdTimeFocusNode,
      _fourthTimeFocusNode,
    ];
    
    return AutoScrollTag(
      key: GlobalKey(),
      controller: scrollController,
      index: 11 + index,
      highlightColor: Colors.transparent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: Color.fromRGBO(0, 85, 128, 1), fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 1),
          TextField(
            controller: controller,
            focusNode: timeFocusNodes[index],
            readOnly: true,
            textAlign: TextAlign.left,
            decoration: InputDecoration(
              hintText: "Selecione",
              hintStyle: const TextStyle(fontSize: 20, color: Color.fromRGBO(0, 85, 128, 1)),
              filled: true,
              fillColor: Colors.grey[200],
              enabledBorder: const OutlineInputBorder(
                borderSide: BorderSide(color: Colors.transparent, width: 5.0),
              ),
              focusedBorder: const OutlineInputBorder(
                borderSide: BorderSide(color: Color.fromRGBO(85, 170, 85, 1), width: 5.0),
              ),
            ),
            style: const TextStyle(fontSize: 24),
            onTap: () async {
              await _selectTime(context, index);
              if (index < _timeControllers.length - 1) {
                try {
                  await scrollController.scrollToIndex(
                    11 + index + 1,
                    preferPosition: AutoScrollPosition.begin,
                    duration: const Duration(milliseconds: 200),
                  );
                  print("Rolou para o horário ${index + 2} (índice ${11 + index + 1})");
                  FocusScope.of(context).requestFocus(timeFocusNodes[index + 1]);
                } catch (e) {
                  print("Erro ao rolar pro próximo horário: $e");
                }
              } else {
                try {
                  await scrollController.scrollToIndex(
                    11 + _timeControllers.length,
                    preferPosition: AutoScrollPosition.begin,
                    duration: const Duration(milliseconds: 200),
                  );
                  print("Rolou para o campo Uso Contínuo (índice ${11 + _timeControllers.length})");
                } catch (e) {
                  print("Erro ao rolar pro campo Uso Contínuo: $e");
                }
              }
            },
          ),
        ],
      ),
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