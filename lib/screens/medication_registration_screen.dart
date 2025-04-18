import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:sqflite/sqflite.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as path;
import 'package:flutter/services.dart';
import 'package:scroll_to_index/scroll_to_index.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import '../notification_service.dart';
import 'medication_list_screen.dart';

class MedicationRegistrationScreen extends StatefulWidget {
  final Map<String, dynamic>? medication;

  const MedicationRegistrationScreen({super.key, this.medication});

  @override
  State<MedicationRegistrationScreen> createState() => _MedicationRegistrationScreenState();
}

class _MedicationRegistrationScreenState extends State<MedicationRegistrationScreen> {
  // Controladores de texto
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _stockController = TextEditingController();
  final TextEditingController _dosageController = TextEditingController();
  final TextEditingController _startDateController = TextEditingController();
  List<TextEditingController> _timeControllers = [TextEditingController()];

  // FocusNodes
  final FocusNode _nameFocusNode = FocusNode();
  final FocusNode _stockFocusNode = FocusNode();
  final FocusNode _typeFocusNode = FocusNode();
  final FocusNode _dosageFocusNode = FocusNode();
  final FocusNode _firstTimeFocusNode = FocusNode();
  final FocusNode _secondTimeFocusNode = FocusNode();
  final FocusNode _thirdTimeFocusNode = FocusNode();
  final FocusNode _fourthTimeFocusNode = FocusNode();
  final FocusNode _fifthTimeFocusNode = FocusNode();
  final FocusNode _startDateFocusNode = FocusNode();
  final FocusNode _usageFocusNode = FocusNode();

  // Scroll controller
  final AutoScrollController _scrollController = AutoScrollController();

  // Chaves para AutoScrollTag e campos
  final GlobalKey _typeKey = GlobalKey();
  final GlobalKey _usageKey = GlobalKey();
  final GlobalKey _nameKey = GlobalKey();
  final GlobalKey _stockKey = GlobalKey();
  final GlobalKey _dosageKey = GlobalKey();  
  final GlobalKey _firstTimeKey = GlobalKey();
  final GlobalKey _secondTimeKey = GlobalKey();
  final GlobalKey _thirdTimeKey = GlobalKey();
  final GlobalKey _fourthTimeKey = GlobalKey();
  final GlobalKey _startDateKey = GlobalKey();

  // Outros estados
  String? _type;
  int? _frequency;
  bool _isContinuous = false;
  File? _image;
  bool _showPhotoOption = false;
  Future<Database>? _databaseFuture;

  // Picker para foto
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _databaseFuture = _initDatabase();
    _startDateController.text = DateFormat('dd/MM/yyyy').format(DateTime.now());

    if (widget.medication != null) {
      _fillFieldsForEditing();
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          _scrollController.jumpTo(0.0);
          _nameFocusNode.requestFocus();
        }
      });
    });

    _nameFocusNode.addListener(() {
      if (!_nameFocusNode.hasFocus) {
        _checkDuplicateMedicationOnNameFieldExit();
      }
    });

    _checkUserAge();
  }

  @override
  void dispose() {
    _nameFocusNode.dispose();
    _stockFocusNode.dispose();
    _typeFocusNode.dispose();
    _dosageFocusNode.dispose();
    _firstTimeFocusNode.dispose();
    _secondTimeFocusNode.dispose();
    _thirdTimeFocusNode.dispose();
    _fourthTimeFocusNode.dispose();
    _fifthTimeFocusNode.dispose();
    _startDateFocusNode.dispose();
    _usageFocusNode.dispose();

    _nameController.dispose();
    _stockController.dispose();
    _dosageController.dispose();
    _startDateController.dispose();
    _timeControllers.forEach((controller) => controller.dispose());

    super.dispose();
  }

  void _fillFieldsForEditing() {
    _nameController.text = widget.medication!['nome'] ?? '';
    _stockController.text = widget.medication!['quantidade_total']?.toString() ?? '';
    _type = widget.medication!['tipo_medicamento'];
    _dosageController.text = widget.medication!['dosagem_diaria']?.toString() ?? '';
    _frequency = widget.medication!['frequency'] ?? (widget.medication!['horarios'] as String?)?.split(',')?.length;
    _isContinuous = widget.medication!['isContinuous'] == 1;
    _image = widget.medication!['foto_embalagem'] != null ? File(widget.medication!['foto_embalagem']) : null;

    final times = (widget.medication!['horarios'] as String?)?.split(',') ?? [];
    _timeControllers.clear();
    _timeControllers.addAll(
      times.isNotEmpty
          ? times.map((time) => TextEditingController(text: time)).toList()
          : [TextEditingController()],
    );
  }

  void _checkUserAge() {
    const birthDate = "1960-04-01"; // Substituir por data real
    final age = DateTime.now().difference(DateTime.parse(birthDate)).inDays ~/ 365;
    setState(() {
      _showPhotoOption = age >= 60;
    });
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final fullPath = path.join(dbPath, 'medications.db');

    return await openDatabase(
      fullPath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute(
          'CREATE TABLE medications(id TEXT PRIMARY KEY, nome TEXT, quantidade_total INTEGER, dosagem_diaria INTEGER, tipo_medicamento TEXT, horarios TEXT, startDate TEXT, isContinuous INTEGER, foto_embalagem TEXT, skip_count INTEGER, cuidador_id TEXT)',
        );
        await db.execute(
          'CREATE TABLE users(id INTEGER PRIMARY KEY, name TEXT, phone TEXT)',
        );
        await db.execute(
          'CREATE TABLE caregivers(id INTEGER PRIMARY KEY, name TEXT, phone TEXT)',
        );
      },
    );
  }

  Future<void> _scrollToField(GlobalKey key) async {
    try {
      final context = key.currentContext;
      if (context != null) {
        final RenderBox box = context.findRenderObject() as RenderBox;
        final position = box.localToGlobal(Offset.zero).dy;
        final screenHeight = MediaQuery.of(context).size.height;
        final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
        final targetScrollOffset = position - (screenHeight - keyboardHeight) / 2 + box.size.height / 2;

        print("Scrolling to key: $key, targetOffset: $targetScrollOffset");
        await _scrollController.animateTo(
          targetScrollOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    } catch (e) {
      print("Erro ao centralizar campo: $e");
    }
  }

  void _checkDuplicateMedicationOnNameFieldExit() async {
    if (!mounted) return;
    final database = await _databaseFuture;
    if (database == null) return;

    final List<Map<String, dynamic>> existingMedications = await database.query('medications');
    final newNameNormalized = _normalizeName(_nameController.text);

    final bool alreadyExists = existingMedications.any((med) {
      final existingName = med['nome'] as String? ?? '';
      return _normalizeName(existingName) == newNameNormalized && med['id'] != widget.medication?['id'];
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
                FocusScope.of(context).requestFocus(_nameFocusNode);
              },
              child: const Text("OK"),
            ),
          ],
        ),
      );
    }
  }

  String _normalizeName(String name) {
    return name.replaceAll(RegExp(r'\s+'), '').toLowerCase();
  }

  InputDecoration getInputDecoration(String hintText, {bool isDateField = false}) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(fontSize: 20, color: Color.fromRGBO(0, 85, 128, 1)),
      filled: true,
      fillColor: Colors.grey[200],
      enabledBorder: const OutlineInputBorder(
        borderSide: BorderSide(color: Colors.grey, width: 1.0),
      ),
      focusedBorder: const OutlineInputBorder(
        borderSide: BorderSide(color: Color.fromRGBO(85, 170, 85, 1), width: 5.0),
      ),
    );
  }

  BoxDecoration getDropdownDecoration({required bool hasFocus}) {
    return BoxDecoration(
      color: Colors.grey[200],
      border: Border.all(
        color: hasFocus ? const Color.fromRGBO(85, 170, 85, 1) : Colors.grey,
        width: hasFocus ? 5.0 : 1.0,
      ),
      borderRadius: BorderRadius.circular(4.0),
    );
  }

  TextStyle getLabelStyle() {
    return const TextStyle(
      color: Color.fromRGBO(0, 85, 128, 1),
      fontSize: 20,
      fontWeight: FontWeight.bold,
    );
  }

  ButtonStyle getButtonStyle() {
    return ElevatedButton.styleFrom(
      backgroundColor: const Color.fromRGBO(0, 105, 148, 1),
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
    );
  }

  Future<void> _selectTime(BuildContext context, int index) async {
    int selectedHour = 8;
    int selectedMinute = 0;

    await showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SizedBox(
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
                        onSelectedItemChanged: (int value) => selectedHour = value,
                        scrollController: FixedExtentScrollController(initialItem: 8),
                        children: List.generate(
                          24,
                          (index) => Center(
                            child: Text(index.toString().padLeft(2, '0'), style: const TextStyle(fontSize: 28)),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 20),
                    SizedBox(
                      width: 100,
                      child: CupertinoPicker(
                        itemExtent: 60.0,
                        onSelectedItemChanged: (int value) => selectedMinute = value,
                        scrollController: FixedExtentScrollController(initialItem: 0),
                        children: List.generate(
                          60,
                          (index) => Center(
                            child: Text(index.toString().padLeft(2, '0'), style: const TextStyle(fontSize: 28)),
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

  Future<void> _pickImage() async {
    final XFile? pickedImage = await _picker.pickImage(source: ImageSource.camera);
    if (pickedImage != null) {
      setState(() {
        _image = File(pickedImage.path);
      });
    }
  }

  bool _validateFields() {
    List<String> errors = [];

    if (_nameController.text.isEmpty) errors.add("Nome do Medicamento não preenchido.");
    if (_stockController.text.isEmpty) errors.add("Quantidade Total não preenchida.");
    if (!RegExp(r'^\d+$').hasMatch(_stockController.text)) errors.add("Quantidade Total deve ser um número.");
    if (_type == null) errors.add("Tipo do Medicamento não selecionado.");
    if (_dosageController.text.isEmpty) errors.add("Dosagem não preenchida.");
    if (!RegExp(r'^\d+$').hasMatch(_dosageController.text)) errors.add("Dosagem deve ser um número.");
    if (_frequency == null) errors.add("Modo de Usar não selecionado.");
    if (_timeControllers.any((controller) => controller.text.isEmpty)) errors.add("Horário de uso não preenchido.");
    if (_startDateController.text.isEmpty) errors.add("Data de Início não preenchida.");

    if (errors.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errors.join('\n'), style: const TextStyle(fontSize: 20)),
          duration: Duration(seconds: errors.length > 1 ? 4 : 3),
        ),
      );
      return false;
    }

    if (_timeControllers.length != _frequency) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Preencha todos os horários conforme o Modo de Usar!", style: TextStyle(fontSize: 20))),
      );
      return false;
    }

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

    FocusScope.of(context).requestFocus(_nameFocusNode);
  }

  Future<void> _saveMedication() async {
    if (!_validateFields()) return;

    try {
      final database = await _databaseFuture;
      if (database == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Erro: Banco de dados não inicializado", style: TextStyle(fontSize: 20))),
        );
        return;
      }

      final medicationId = widget.medication != null ? widget.medication!['id'] : 'med_${DateTime.now().millisecondsSinceEpoch}';
      final medicationData = {
        'id': medicationId,
        'nome': _nameController.text,
        'quantidade_total': int.parse(_stockController.text),
        'dosagem_diaria': int.parse(_dosageController.text),
        'tipo_medicamento': _type,
        'horarios': _timeControllers.map((c) => c.text).join(','),
        'startDate': DateFormat('yyyy-MM-dd').format(DateFormat('dd/MM/yyyy').parse(_startDateController.text)),
        'isContinuous': _isContinuous ? 1 : 0,
        'foto_embalagem': _image?.path ?? '',
        'skip_count': widget.medication?['skip_count'] ?? 0,
        'cuidador_id': widget.medication?['cuidador_id'] ?? '',
      };

      // Verificação de duplicidade
      final List<Map<String, dynamic>> existingMedications = await database.query('medications');
      final newNameNormalized = _normalizeName(_nameController.text);
      final bool alreadyExists = existingMedications.any((med) {
        final existingName = med['nome'] ?? '';
        return _normalizeName(existingName) == newNameNormalized && med['id'] != medicationId;
      });

      if (alreadyExists) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("Medicamento já cadastrado"),
            content: const Text("Este medicamento já existe. Escolha outro nome ou edite o existente."),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("OK"),
              ),
            ],
          ),
        );
        return;
      }

      // Inserção ou atualização no banco
      if (widget.medication != null) {
        await database.update(
          'medications',
          medicationData,
          where: 'id = ?',
          whereArgs: [medicationId],
        );
      } else {
        await database.insert(
          'medications',
          medicationData,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      // Agendar notificações
      final notificationService = NotificationService();
      final horarios = _timeControllers.map((c) => c.text).toList();
      final startDate = DateFormat('dd/MM/yyyy').parse(_startDateController.text);
      for (int i = 0; i < horarios.length; i++) {
        final timeParts = horarios[i].split(':');
        final scheduledTime = DateTime(
          startDate.year,
          startDate.month,
          startDate.day,
          int.parse(timeParts[0]),
          int.parse(timeParts[1]),
        );
        await notificationService.scheduleNotification(
          id: (medicationId.hashCode + i) % 1000000,
          title: 'Hora de tomar ${_nameController.text}',
          body: 'Dose: ${_dosageController.text} às ${horarios[i]}',
          sound: 'alarm',
          payload: medicationId,
          scheduledTime: scheduledTime,
        );
      }

      _showPostSaveOptions();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erro ao salvar: $e", style: const TextStyle(fontSize: 20))),
      );
    }
  }

  void _showPostSaveOptions() {
    showDialog(
      context: context,
      builder: (BuildContext context) => AlertDialog(
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
              Navigator.pop(context);
              _clearFields();
            },
            child: const Text(
              "Cadastrar Novo",
              style: TextStyle(color: Color.fromRGBO(0, 105, 148, 1), fontSize: 20),
            ),
          ),
          TextButton(
            onPressed: () async {
              final database = await _databaseFuture;
              if (database != null) {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => MedicationListScreen(database: database)),
                );
              }
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

        return Scaffold(
          backgroundColor: const Color(0xFFCCCCCC),
          appBar: _buildAppBar(),
          body: _buildFormBody(),
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
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
    );
  }

  Widget _buildFormBody() {
    return ListView(
      controller: _scrollController,
      padding: const EdgeInsets.all(20.0),
      children: [
        _buildTextField(
          controller: _nameController,
          label: "Nome do Medicamento",
          focusNode: _nameFocusNode,
          autofocus: true,
          keyTag: _nameKey,
          textStyle: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          onSubmitted: (_) {
            FocusScope.of(context).requestFocus(_stockFocusNode);
            _scrollToField(_stockKey);
          },
        ),
        const SizedBox(height: 20),
        _buildTextField(
          controller: _stockController,
          label: "Quantidade Total",
          focusNode: _stockFocusNode,
          keyboardType: TextInputType.number,
          textStyle: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
          keyTag: _stockKey,
          onSubmitted: (_) {
            FocusScope.of(context).requestFocus(_typeFocusNode);
            _scrollToField(_typeKey);
          },
        ),
        const SizedBox(height: 20),
        _buildTypeDropdown(),
        const SizedBox(height: 20),
        _buildTextField(
          controller: _dosageController,
          label: "Dosagem (por dia)",
          focusNode: _dosageFocusNode,
          keyboardType: TextInputType.number,
          textStyle: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
          keyTag: _dosageKey,
          onSubmitted: (_) {
            FocusScope.of(context).requestFocus(_usageFocusNode);
            _scrollToField(_usageKey);
          },
        ),
        const SizedBox(height: 20),
        _buildFrequencyDropdown(),
        const SizedBox(height: 20),
        ..._buildTimeFields(),
        const SizedBox(height: 20),
        _buildContinuousUsageSwitch(),
        const SizedBox(height: 20),
        _buildDateField(),
        const SizedBox(height: 20),
        _buildPhotoSection(),
        const SizedBox(height: 20),
        _buildSaveButton(),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    FocusNode? focusNode,
    TextInputType keyboardType = TextInputType.text,
    bool autofocus = false,
    GlobalKey? keyTag,
    TextStyle? textStyle,
    TextAlign textAlign = TextAlign.left,
    Function(String)? onSubmitted,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: getLabelStyle()),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          focusNode: focusNode,
          keyboardType: keyboardType,
          textAlign: textAlign,
          textCapitalization: TextCapitalization.sentences,
          autofocus: autofocus,
          decoration: getInputDecoration("Insira $label"),
          inputFormatters: keyboardType == TextInputType.number ? [FilteringTextInputFormatter.digitsOnly] : null,
          style: textStyle,
          onSubmitted: (value) {
            print("onSubmitted: $label");
            onSubmitted?.call(value);
          },
          onTap: () {
            print("onTap: $label");
            if (keyTag != null) _scrollToField(keyTag);
          },
        ),
      ],
    );
  }

  Widget _buildTypeDropdown() {
    const List<String> medicationTypes = ["Comprimidos", "Cápsulas", "Gotas", "Xarope", "Injeção"];
    final GlobalKey key = GlobalKey();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Tipo do Medicamento", style: getLabelStyle()),
        const SizedBox(height: 4),
        Container(
          key: key,
          decoration: getDropdownDecoration(hasFocus: _typeFocusNode.hasFocus),
          padding: const EdgeInsets.symmetric(horizontal: 12.0),
          child: DropdownButtonHideUnderline(
            child: DropdownButton2<String>(
              isExpanded: true,
              hint: const Text(
                "Selecione o tipo",
                style: TextStyle(fontSize: 24),
                textAlign: TextAlign.center,
              ),
              items: medicationTypes.map((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(
                    value,
                    style: const TextStyle(fontSize: 24),
                    textAlign: TextAlign.center,
                  ),
                );
              }).toList(),
              value: _type,
              onChanged: (String? newValue) {
                setState(() {
                  _type = newValue;
                });
                _scrollToField(key);
                FocusScope.of(context).requestFocus(_dosageFocusNode);
              },
              customButton: Container(
                height: 50,
                alignment: Alignment.center,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        _type ?? "Selecione o tipo",
                        style: const TextStyle(fontSize: 24),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const Icon(
                      Icons.arrow_drop_down,
                      color: Color.fromRGBO(0, 85, 128, 1),
                      size: 30,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFrequencyDropdown() {
    final GlobalKey key = GlobalKey();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Modo de Usar", style: getLabelStyle()),
        const SizedBox(height: 4),
        Container(
          key: key,
          decoration: getDropdownDecoration(hasFocus: _usageFocusNode.hasFocus),
          padding: const EdgeInsets.symmetric(horizontal: 12.0),
          child: DropdownButtonHideUnderline(
            child: DropdownButton2<int>(
              isExpanded: true,
              hint: const Text(
                "Selecione",
                style: TextStyle(fontSize: 24),
                textAlign: TextAlign.center,
              ),
              items: List.generate(5, (index) => index + 1).map((int value) {
                return DropdownMenuItem<int>(
                  value: value,
                  child: Text(
                    "$value x por dia",
                    style: const TextStyle(fontSize: 24),
                    textAlign: TextAlign.center,
                  ),
                );
              }).toList(),
              value: _frequency,
              onChanged: (int? newValue) {
                if (newValue != null) {
                  setState(() {
                    _frequency = newValue;
                    _timeControllers = List.generate(newValue, (_) => TextEditingController());
                  });
                  _scrollToField(key);
                  FocusScope.of(context).requestFocus(_firstTimeFocusNode);
                }
              },
              customButton: Container(
                height: 50,
                alignment: Alignment.center,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        _frequency != null ? "$_frequency x por dia" : "Selecione",
                        style: const TextStyle(fontSize: 24),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const Icon(
                      Icons.arrow_drop_down,
                      color: Color.fromRGBO(0, 85, 128, 1),
                      size: 30,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildTimeFields() {
    final List<FocusNode> timeFocusNodes = [
      _firstTimeFocusNode,
      _secondTimeFocusNode,
      _thirdTimeFocusNode,
      _fourthTimeFocusNode,
      _fifthTimeFocusNode,
    ];

    return List.generate(_timeControllers.length, (index) {
      final GlobalKey key = GlobalKey();
      return Padding(
        padding: const EdgeInsets.only(bottom: 10.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("${index + 1}° Horário", style: getLabelStyle()),
            const SizedBox(height: 4),
            TextField(
              controller: _timeControllers[index],
              focusNode: index < timeFocusNodes.length ? timeFocusNodes[index] : null,
              readOnly: true,
              decoration: getInputDecoration("Selecione o horário"),
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
              onTap: () async {
                print("onTap: Horário ${index + 1}");
                await _selectTime(context, index);
                print("selectTime concluído: Horário ${index + 1}");
                _scrollToField(key);
                if (index < _timeControllers.length - 1) {
                  if (!timeFocusNodes[index + 1].hasFocus) {
                    print("Movendo foco para Horário ${index + 2}");
                    FocusScope.of(context).requestFocus(timeFocusNodes[index + 1]);
                  }
                } else {
                  if (!_startDateFocusNode.hasFocus) {
                    print("Movendo foco para Data de Início");
                    FocusScope.of(context).requestFocus(_startDateFocusNode);
                  }
                }
              },
              key: key,
            ),
          ],
        ),
      );
    });
  }

  Widget _buildContinuousUsageSwitch() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text("Uso Contínuo", style: getLabelStyle()),
        Switch(
          value: _isContinuous,
          onChanged: (value) => setState(() => _isContinuous = value),
          activeColor: const Color.fromRGBO(0, 105, 148, 1),
        ),
      ],
    );
  }

  Widget _buildDateField() {
    final GlobalKey key = GlobalKey();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Data de Início", style: getLabelStyle()),
        const SizedBox(height: 4),
        TextField(
          controller: _startDateController,
          focusNode: _startDateFocusNode,
          readOnly: true,
          decoration: getInputDecoration("Selecione a data"),
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
          onTap: () async {
            print("onTap: Data de Início");
            await _selectDate(context);
            print("selectDate concluído");
            _scrollToField(key);
            print("Fechando teclado");
            FocusScope.of(context).unfocus();
          },
          key: key,
        ),
      ],
    );
  }

  Widget _buildPhotoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Fotografar Embalagem", style: getLabelStyle()),
        const SizedBox(height: 10),
        _image == null
            ? ElevatedButton.icon(
                onPressed: _pickImage,
                icon: const Icon(Icons.camera_alt, color: Colors.white),
                label: const Text("Tirar Foto", style: TextStyle(color: Colors.white, fontSize: 24)),
                style: getButtonStyle(),
              )
            : Row(
                children: [
                  Image.file(_image!, height: 100, width: 100, fit: BoxFit.cover),
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
      child: ElevatedButton(
        onPressed: _saveMedication,
        child: const Text("Salvar", style: TextStyle(color: Colors.white, fontSize: 24)),
        style: getButtonStyle(),
      ),
    );
  }
}