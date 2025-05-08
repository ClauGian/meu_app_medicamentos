import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:sqflite/sqflite.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:scroll_to_index/scroll_to_index.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import '../notification_service.dart';
import 'medication_list_screen.dart';
import 'dart:async';
import 'package:medialerta/screens/home_screen.dart'; // Ajuste o caminho conforme sua estrutura

class MedicationRegistrationScreen extends StatefulWidget {
  final Database database;
  final Map<String, dynamic>? medication;

  const MedicationRegistrationScreen({super.key, required this.database, this.medication});

  @override
  State<MedicationRegistrationScreen> createState() => _MedicationRegistrationScreenState();
}

class _MedicationRegistrationScreenState extends State<MedicationRegistrationScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _stockController = TextEditingController();
  final TextEditingController _dosageController = TextEditingController();
  final TextEditingController _startDateController = TextEditingController();
  List<TextEditingController> _timeControllers = [];

  final FocusNode _nameFocusNode = FocusNode();
  final FocusNode _stockFocusNode = FocusNode();
  final FocusNode _typeFocusNode = FocusNode();
  final FocusNode _dosageFocusNode = FocusNode();
  final FocusNode _usageFocusNode = FocusNode();
  final FocusNode _continuousUseFocusNode = FocusNode();
  List<FocusNode> _timeFocusNodes = [];
  final FocusNode _startDateFocusNode = FocusNode();

  final GlobalKey _nameKey = GlobalKey();
  final GlobalKey _stockKey = GlobalKey();
  final GlobalKey _typeKey = GlobalKey();
  final GlobalKey _dosageKey = GlobalKey();
  final GlobalKey _usageKey = GlobalKey();
  List<GlobalKey> _timeKeys = [];
  final GlobalKey _startDateKey = GlobalKey();

  final AutoScrollController _scrollController = AutoScrollController();

  String? _type;
  String? _frequency;
  bool _isContinuous = false;
  File? _image; 
  bool _showPhotoOption = false; // ou o valor inicial apropriado 
  final ImagePicker _picker = ImagePicker();

  int _getDoseCount(String? frequency) {
    if (frequency == null) return 1;
    final number = int.tryParse(frequency.split('x')[0].trim());
    return number ?? 1;
  }

  void _customSetState(VoidCallback fn) {
    print("setState chamado");
    setState(fn);
  }

  @override
  void initState() {
    super.initState();
    
    _startDateController.text = DateFormat('dd/MM/yyyy').format(DateTime.now());

    if (widget.medication != null && widget.medication!['horarios'] != null) {
      String horariosStr = widget.medication!['horarios']!.toString();
      print('Horários recebidos em MedicationRegistrationScreen: $horariosStr');
      List<String> horariosList = horariosStr.isNotEmpty ? horariosStr.split(',') : [];
      _timeControllers = horariosList.isNotEmpty
          ? horariosList.map((time) => TextEditingController(text: time.trim())).toList()
          : List.generate(5, (_) => TextEditingController());
    } else {
      _timeControllers = List.generate(5, (_) => TextEditingController());
    }

    _timeFocusNodes = List.generate(5, (index) => FocusNode()..addListener(() {
          print("Time FocusNode [$index]: hasFocus=${_timeFocusNodes[index].hasFocus}");
        }));
    _timeKeys = List.generate(5, (_) => GlobalKey());

    _nameFocusNode.addListener(() {
      print("Name FocusNode: hasFocus=${_nameFocusNode.hasFocus}");
      if (!_nameFocusNode.hasFocus) {
        _checkDuplicateMedicationOnNameFieldExit();
      }
    });
    _stockFocusNode.addListener(() {
      print("Stock FocusNode: hasFocus=${_stockFocusNode.hasFocus}");
    });
    _typeFocusNode.addListener(() {
      print("Type FocusNode: hasFocus=${_typeFocusNode.hasFocus}");
    });
    _dosageFocusNode.addListener(() {
      print("Dosage FocusNode: hasFocus=${_dosageFocusNode.hasFocus}");
    });
    _usageFocusNode.addListener(() {
      print("Usage FocusNode: hasFocus=${_usageFocusNode.hasFocus}");
    });
    _startDateFocusNode.addListener(() {
      print("StartDate FocusNode: hasFocus=${_startDateFocusNode.hasFocus}");
      if (_startDateFocusNode.hasFocus) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToCenter(_startDateKey);
        });
      }
    });
    _continuousUseFocusNode.addListener(() {
      print("ContinuousUse FocusNode: hasFocus=${_continuousUseFocusNode.hasFocus}");
    });

    if (widget.medication != null) {
      _fillFieldsForEditing();
    }

    _checkUserAge();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0.0);
      }
      _nameFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _stockController.dispose();
    _dosageController.dispose();
    _startDateController.dispose();
    for (var controller in _timeControllers) {
      controller.dispose();
    }
    _nameFocusNode.dispose();
    _stockFocusNode.dispose();
    _typeFocusNode.dispose();
    _dosageFocusNode.dispose();
    _usageFocusNode.dispose();
    for (var node in _timeFocusNodes) {
      node.dispose();
    }
    _continuousUseFocusNode.dispose();
    _startDateFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _fillFieldsForEditing() {
    _nameController.text = widget.medication!['nome']?.toString() ?? '';
    _stockController.text = widget.medication!['quantidade']?.toString() ?? '';
    _type = widget.medication!['tipo_medicamento']?.toString();
    _dosageController.text = widget.medication!['dosagem_diaria']?.toString() ?? '';
    String horariosStr = widget.medication!['horarios']?.toString() ?? '';
    _frequency = widget.medication!['frequencia']?.toString() ?? 
        (horariosStr.isNotEmpty ? horariosStr.split(',').length.toString() : '');
    final isContinuousValue = widget.medication!['isContinuous'];
    _isContinuous = isContinuousValue == 1 || isContinuousValue == '1';
    final fotoEmbalagem = widget.medication!['foto_embalagem']?.toString();
    _image = fotoEmbalagem != null && fotoEmbalagem.isNotEmpty && File(fotoEmbalagem).existsSync()
        ? File(fotoEmbalagem)
        : null;

    List<String> times = horariosStr.isNotEmpty ? horariosStr.split(',') : [];
    _timeControllers.clear();
    if (times.isNotEmpty) {
      _timeControllers.addAll(times.map((time) => TextEditingController(text: time.trim())).toList());
    }
    // Preencher com controladores vazios até atingir 5, para consistência com a UI
    while (_timeControllers.length < 5) {
      _timeControllers.add(TextEditingController());
    }
  }

  void _checkUserAge() {
    const birthDate = "1960-04-01";
    final age = DateTime.now().difference(DateTime.parse(birthDate)).inDays ~/ 365;
    setState(() {
      _showPhotoOption = age >= 60;
    });
  }

  Future<void> _scrollToField(GlobalKey key) async {
    try {
      if (!_scrollController.hasClients) {
        print("❌ ScrollController não está vinculado, ignorando scroll para key: $key");
        return;
      }

      print("✅ Chamou _scrollToField para a key: $key");

      await Future.delayed(const Duration(milliseconds: 150));

      final context = key.currentContext;
      if (context != null) {
        final RenderBox box = context.findRenderObject() as RenderBox;
        final position = box.localToGlobal(Offset.zero).dy;
        final fieldHeight = box.size.height;
        final screenHeight = MediaQuery.of(context).size.height;
        final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
        final availableHeight = screenHeight - keyboardHeight;

        print("🧩 Dados atuais para o scroll:");
        print("- Posição Y do campo: $position");
        print("- Altura do campo: $fieldHeight");
        print("- Altura total da tela: $screenHeight");
        print("- Altura do teclado: $keyboardHeight");
        print("- Altura visível (sem teclado): $availableHeight");

        final targetOffset = _scrollController.offset + (position + fieldHeight / 2) - (availableHeight / 2);

        print("🎯 Tentando rolar até o offset: $targetOffset (máximo permitido: ${_scrollController.position.maxScrollExtent})");

        _scrollController.animateTo(
          targetOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      } else {
        print("⚠️ Contexto nulo para key: $key, ignorando scroll");
      }
    } catch (e) {
      print("🔥 Erro ao tentar centralizar campo: $e");
    }
  }

  void _scrollToCenter(GlobalKey key) {
    int retryCount = 0;
    const int maxRetries = 20;

    void tryScroll() {
      final context = key.currentContext;
      if (context != null) {
        final box = context.findRenderObject() as RenderBox;
        final position = box.localToGlobal(Offset.zero).dy;
        final height = box.size.height;
        final screenHeight = MediaQuery.of(context).size.height;
        final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
        final visibleHeight = screenHeight - keyboardHeight;

        print("🎯 Dados atuais para o scroll:");
        print("- Posição Y do campo: $position");
        print("- Altura do campo: $height");
        print("- Altura total da tela: $screenHeight");
        print("- Altura do teclado: $keyboardHeight");
        print("- Altura visível (sem teclado): $visibleHeight");

        final targetScrollOffset = _scrollController.offset + position - (visibleHeight / 2) + (height / 2);

        print("🎯 Contexto pronto! Scrollando para centralizar. Offset: $targetScrollOffset");

        _scrollController.animateTo(
          targetScrollOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      } else {
        retryCount++;
        if (retryCount <= maxRetries) {
          print("⏳ Contexto ainda nulo para ${key.toString()}, retry $retryCount...");
          Future.delayed(const Duration(milliseconds: 100), tryScroll);
        } else {
          print("⚠️ Máximo de tentativas de scroll atingido para ${key.toString()}");
        }
      }
    }

    tryScroll();
  }

  void _checkDuplicateMedicationOnNameFieldExit() async {
    print("Verificando duplicatas para nome: ${_nameController.text}");
    if (!mounted) return;
    final database = widget.database;
    print("Database em _checkDuplicateMedicationOnNameFieldExit: $database");

    final List<Map<String, dynamic>> existingMedications = await database.query('medications');
    final newNameNormalized = _normalizeName(_nameController.text);

    final bool alreadyExists = existingMedications.any((med) {
      final existingName = med['nome'] as String? ?? '';
      return _normalizeName(existingName) == newNameNormalized &&
          med['id'].toString() != widget.medication?['id']?.toString();
    });

    if (alreadyExists) {
      if (!mounted) return;
      print("Duplicata encontrada: $newNameNormalized");
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
    } else {
      print("Nenhuma duplicata encontrada para: $newNameNormalized");
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

  Future<void> _selectTime(BuildContext parentContext, int index) async {
    int selectedHour = 8;
    int selectedMinute = 0;

    await showModalBottomSheet(
      context: parentContext,
      builder: (BuildContext modalContext) {
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
                  Navigator.pop(modalContext);
                  final nextIndex = index + 1;
                  if (nextIndex < _timeFocusNodes.length) {
                    print("Movendo foco para Horário ${nextIndex + 1}");
                    FocusScope.of(parentContext).requestFocus(_timeFocusNodes[nextIndex]);
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (_timeKeys[nextIndex].currentContext != null) {
                        print("Iniciando scroll para Horário ${nextIndex + 1}");
                        _scrollToField(_timeKeys[nextIndex]);
                      } else {
                        print("Contexto nulo para _timeKeys[$nextIndex] após selecionar Horário ${index + 1}");
                      }
                    });
                  } else {
                    print("Movendo foco para Data de Início após Horário ${index + 1}");
                    FocusScope.of(parentContext).requestFocus(_startDateFocusNode);
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (_startDateKey.currentContext != null) {
                        print("Iniciando scroll para Data de Início após Horário ${index + 1}");
                        _scrollToField(_startDateKey);
                      } else {
                        print("Contexto nulo para _startDateKey após selecionar Horário ${index + 1}");
                      }
                    });
                  }
                },
                child: const Text("OK", style: TextStyle(fontSize: 20, color: Color.fromRGBO(0, 105, 148, 1))),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showCompactDatePicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        DateTime tempPickedDate = DateTime.now();

        return Container(
          height: 300,
          child: Column(
            children: [
              Expanded(
                child: CalendarDatePicker(
                  initialDate: DateTime.now(),
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                  onDateChanged: (DateTime newDate) {
                    tempPickedDate = newDate;
                  },
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromRGBO(0, 105, 148, 1),
                ),
                onPressed: () {
                  setState(() {
                    _startDateController.text = DateFormat('dd/MM/yyyy').format(tempPickedDate);
                  });
                  Navigator.pop(context);
                },
                child: const Text('Confirmar', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickImage() async {
    final XFile? pickedImage = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 50, // Reduz a qualidade para 50% (0 a 100)
    );
    if (pickedImage != null) {
      setState(() {
        _image = File(pickedImage.path);
      });
    }
  }

  bool _validateFields() {
    List<String> errors = [];

    if (_nameController.text.trim().isEmpty) {
      errors.add("Nome do Medicamento não preenchido.");
    }

    if (_stockController.text.trim().isEmpty) {
      errors.add("Quantidade não preenchida.");
    } else if (!RegExp(r'^\d+$').hasMatch(_stockController.text)) {
      errors.add("Quantidade deve ser um número válido.");
    }

    if (_type == null || _type!.trim().isEmpty) {
      errors.add("Tipo do Medicamento não selecionado.");
    }

    if (_dosageController.text.trim().isEmpty) {
      errors.add("Dosagem não preenchida.");
    } else if (!RegExp(r'^\d+$').hasMatch(_dosageController.text)) {
      errors.add("Dosagem deve ser um número válido.");
    }

    if (_frequency == null) {
      errors.add("Modo de Usar não selecionado.");
    }

    if (_startDateController.text.trim().isEmpty) {
      errors.add("Data de Início não preenchida.");
    } else {
      try {
        DateFormat('dd/MM/yyyy').parse(_startDateController.text);
      } catch (e) {
        errors.add("Data de Início inválida. Use o formato DD/MM/AAAA.");
      }
    }

    if (_frequency != null) {
      final doseCount = _getDoseCount(_frequency);
      if (doseCount == 0) {
        errors.add("Modo de Usar inválido.");
      } else if (_timeControllers.length < doseCount ||
          _timeControllers.take(doseCount).any((controller) => controller.text.trim().isEmpty)) {
        errors.add("Todos os horários devem ser preenchidos conforme o Modo de Usar.");
      } else {
        for (var i = 0; i < doseCount; i++) {
          final time = _timeControllers[i].text.trim();
          if (!RegExp(r'^\d{2}:\d{2}$').hasMatch(time)) {
            errors.add("Horário ${i + 1} inválido. Use o formato HH:MM.");
          } else {
            try {
              final parts = time.split(':');
              final hour = int.parse(parts[0]);
              final minute = int.parse(parts[1]);
              if (hour < 0 || hour > 23 || minute < 0 || minute > 59) {
                errors.add("Horário ${i + 1} fora do intervalo válido (00:00-23:59).");
              }
            } catch (e) {
              errors.add("Horário ${i + 1} inválido. Use números no formato HH:MM.");
            }
          }
        }
      }
    }

    if (errors.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errors.join('\n'), style: const TextStyle(fontSize: 20)),
          duration: Duration(seconds: errors.length > 1 ? 4 : 3),
        ),
      );
      return false;
    }

    return true;
  }

  void _clearFields() {
    print("clearFields: _timeControllers.length=${_timeControllers.length}, _timeFocusNodes.length=${_timeFocusNodes.length}, _timeKeys.length=${_timeKeys.length}");
    _customSetState(() {
      _nameController.clear();
      _stockController.clear();
      _dosageController.clear();
      _startDateController.text = DateFormat('dd/MM/yyyy').format(DateTime.now());
      _type = null;
      _isContinuous = false;
      _image = null;
      _frequency = null; // Pode mudar para "1x ao dia" se preferir
      final doseCount = _getDoseCount(_frequency) == 0 ? 1 : _getDoseCount(_frequency); // Garante pelo menos 1 elemento
      _timeControllers = List.generate(
        doseCount,
        (index) => TextEditingController(text: "00:00"),
      );
      _timeFocusNodes = List.generate(
        doseCount,
        (index) => FocusNode(),
      );
      _timeKeys = List.generate(
        doseCount,
        (index) => GlobalKey(),
      );
    });
    FocusScope.of(context).requestFocus(_nameFocusNode);
  }

  Future<void> _saveMedication() async {
    print("_timeControllers: ${_timeControllers.map((c) => c.text).toList()}");
    if (!_validateFields()) {
      print("Validação falhou");
      return;
    }

    try {
      final database = widget.database;
      print("Database: $database");

      final schema = await database.rawQuery('PRAGMA table_info(medications)');
      print("Esquema da tabela medications: $schema");

      final medicationData = {
        'nome': _nameController.text.trim(),
        'quantidade': int.parse(_stockController.text),
        'dosagem_diaria': int.parse(_dosageController.text),
        'tipo_medicamento': _type!.trim(),
        'frequencia': _frequency,
        'horarios': _timeControllers
            .map((c) => c.text.trim())
            .where((time) => time.isNotEmpty)
            .join(','),
        'startDate': DateFormat('yyyy-MM-dd').format(DateFormat('dd/MM/yyyy').parse(_startDateController.text)),
        'isContinuous': _isContinuous ? 1 : 0,
        'foto_embalagem': _image?.path ?? '',
        'skip_count': widget.medication?['skip_count'] ?? 0,
        'cuidador_id': widget.medication?['cuidador_id'] ?? '',
      };
      print('Horários salvos: ${medicationData['horarios']}');
      print("Dados do medicamento: $medicationData");

      final List<Map<String, dynamic>> existingMedications = await database.query('medications');
      final newNameNormalized = _normalizeName(_nameController.text);
      final bool alreadyExists = existingMedications.any((med) {
        final existingName = med['nome'] ?? '';
        return _normalizeName(existingName) == newNameNormalized &&
            (widget.medication == null || med['id'].toString() != widget.medication!['id'].toString());
      });

      if (alreadyExists) {
        print("Medicamento já cadastrado: $newNameNormalized");
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

      if (widget.medication != null) {
        print("Atualizando medicamento: ${widget.medication!['id']}");
        await database.update(
          'medications',
          medicationData,
          where: 'id = ?',
          whereArgs: [widget.medication!['id']],
        );
        print("Atualização concluída");
      } else {
        print("Inserindo novo medicamento");
        print("Instância do Database antes da inserção: $database");
        await database.insert(
          'medications',
          medicationData,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        print("Inserção concluída");
      }

      // Inicializar o NotificationService apenas se necessário
      final notificationService = NotificationService();
      // Não precisamos chamar init novamente, pois já foi inicializado em main.dart

      final horarios = _timeControllers
          .map((c) => c.text.trim())
          .where((time) => time.isNotEmpty)
          .toList();
      final startDate = DateFormat('dd/MM/yyyy').parse(_startDateController.text);
      for (int i = 0; i < horarios.length; i++) {
        final timeParts = horarios[i].split(':');
        DateTime scheduledTime = DateTime(
          startDate.year,
          startDate.month,
          startDate.day,
          int.parse(timeParts[0]),
          int.parse(timeParts[1]),
        );

        // Verificar se a data é passada, presente ou no mesmo dia
        final now = DateTime.now();
        if (scheduledTime.isBefore(now) ||
            scheduledTime.isAtSameMomentAs(now) ||
            (scheduledTime.year == now.year &&
                scheduledTime.month == now.month &&
                scheduledTime.day == now.day)) {
          // Avançar para o próximo dia
          scheduledTime = DateTime(
            startDate.year,
            startDate.month,
            startDate.day + 1, // Avançar um dia
            int.parse(timeParts[0]),
            int.parse(timeParts[1]),
          );
        }

        print("Agendando notificação $i: ${DateFormat('dd/MM/yyyy HH:mm').format(scheduledTime)}");
        await notificationService.scheduleNotification(
          id: (medicationData.hashCode + i) % 1000000,
          title: 'Hora de tomar ${_nameController.text}',
          body: 'Dose: ${_dosageController.text} às ${horarios[i]}',
          payload: _nameController.text, // Usar o ID do medicamento seria melhor
          scheduledTime: scheduledTime,
          sound: 'alarm',
        );
        print("Notificação $i agendada com sucesso");
      }

      print("Salvamento concluído, chamando _showPostSaveOptions");
      _showPostSaveOptions();
    } catch (e, stackTrace) {
      print("Erro ao salvar: $e\nStackTrace: $stackTrace");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erro ao salvar: $e", style: const TextStyle(fontSize: 20))),
      );
    }
  }

  void _showPostSaveOptions() {
    print("Exibindo janela de pós-salvamento");
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
              print("Clicou em Cadastrar Novo");
              Navigator.pop(context);
              _clearFields();
            },
            child: const Text(
              "Cadastrar Novo",
              style: TextStyle(color: Color.fromRGBO(0, 105, 148, 1), fontSize: 20),
            ),
          ),
          TextButton(
            onPressed: () {
              print("Clicou em Ver Cadastrados");
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => MedicationListScreen(database: widget.database)),
              );
            },
            child: const Text(
              "Ver Cadastrados",
              style: TextStyle(color: Color.fromRGBO(0, 105, 148, 1), fontSize: 20),
            ),
          ),
          TextButton(
            onPressed: () {
              print("Clicou em Voltar");
              Navigator.pop(context);
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => HomeScreen(database: widget.database)),
              );
            },
            child: const Text(
              "Voltar",
              style: TextStyle(color: Color.fromRGBO(0, 105, 148, 1), fontSize: 20),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    print("Build: MedicationRegistrationScreen reconstruído");
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: const Color(0xFFCCCCCC),
      appBar: _buildAppBar(),
      body: _buildFormBody(),
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
    return SingleChildScrollView(
      controller: _scrollController,
      padding: const EdgeInsets.all(20.0),
      child: Column(
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
            label: "Quantidade",
            focusNode: _stockFocusNode,
            keyboardType: TextInputType.number,
            textStyle: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
            keyTag: _stockKey,
            onSubmitted: (_) {
              print("onSubmitted: Quantidade - Iniciando");
              FocusScope.of(context).requestFocus(_typeFocusNode);
              print("onSubmitted: Quantidade - Foco solicitado para _typeFocusNode");

              WidgetsBinding.instance.addPostFrameCallback((_) {
                print("onSubmitted: Quantidade - Tentando scroll após nova frame");
                _scrollToField(_typeKey);
              });
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
              print("onSubmitted: Dosagem - Iniciando");
              FocusScope.of(context).requestFocus(_usageFocusNode);
              print("onSubmitted: Dosagem - Foco solicitado para _usageFocusNode");

              WidgetsBinding.instance.addPostFrameCallback((_) {
                print("onSubmitted: Dosagem - Tentando scroll após nova frame");
                _scrollToField(_usageKey);
              });
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
          const SizedBox(height: 100),
        ],
      ),
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
    return TypeDropdown(
      selectedType: _type,
      focusNode: _typeFocusNode,
      onChanged: (String? newValue) {
        print("onChanged: Atualizando _type para $newValue");
        _customSetState(() {
          _type = newValue;
        });
        FocusScope.of(context).requestFocus(_dosageFocusNode);

        WidgetsBinding.instance.addPostFrameCallback((_) {
          print("onChanged: Tipo - Tentando scroll para Dosagem após nova frame");
          _scrollToField(_dosageKey);
        });
      },
      scrollToField: _scrollToField,
      keyTag: _typeKey,
      scrollController: _scrollController,
    );
  }

  Widget _buildFrequencyDropdown() {
    return FrequencyDropdown(
      selectedFrequency: _frequency,
      focusNode: _usageFocusNode,
      onChanged: (String? newValue) {
        print("onChanged: Atualizando _frequency para $newValue");
        _customSetState(() {
          _frequency = newValue;
          // Calcula o novo doseCount
          final doseCount = _getDoseCount(newValue);
          // Redimensiona as listas
          _timeControllers = List.generate(
            doseCount,
            (index) => TextEditingController(text: "00:00"),
          );
          _timeFocusNodes = List.generate(
            doseCount,
            (index) => FocusNode(),
          );
          _timeKeys = List.generate(
            doseCount,
            (index) => GlobalKey(),
          );
        });
        // Mantém o comportamento original de foco e rolagem
        FocusScope.of(context).requestFocus(_timeFocusNodes.isNotEmpty ? _timeFocusNodes[0] : _continuousUseFocusNode ?? _startDateFocusNode);
        if (_timeFocusNodes.isNotEmpty && _timeKeys.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _scrollToField(_timeKeys[0]);
          });
        }
      },
      scrollToField: _scrollToField,
      keyTag: _usageKey,
      scrollController: _scrollController,
    );
  }

  List<Widget> _buildTimeFields() {
    final doseCount = _getDoseCount(_frequency);
    print("Building time fields: doseCount=$doseCount");

    // Ajustar _timeControllers, preservando valores existentes
    while (_timeControllers.length > doseCount) {
      _timeControllers.removeLast();
    }
    while (_timeControllers.length < doseCount) {
      _timeControllers.add(TextEditingController());
    }
    // Ajustar _timeFocusNodes
    while (_timeFocusNodes.length > doseCount) {
      _timeFocusNodes.removeLast();
    }
    while (_timeFocusNodes.length < doseCount) {
      _timeFocusNodes.add(FocusNode());
    }
    // Ajustar _timeKeys
    while (_timeKeys.length > doseCount) {
      _timeKeys.removeLast();
    }
    while (_timeKeys.length < doseCount) {
      _timeKeys.add(GlobalKey());
    }
    
    return List.generate(doseCount, (index) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 10.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("${index + 1}° Horário", style: getLabelStyle()),
            const SizedBox(height: 4),
            TextField(
              controller: _timeControllers[index],
              focusNode: _timeFocusNodes[index],
              key: _timeKeys[index],
              readOnly: true,
              decoration: getInputDecoration("Selecione o horário"),
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
              onTap: () async {
                print("onTap: Horário ${index + 1}");
                await _selectTime(context, index);
                print("selectTime concluído: Horário ${index + 1}");
                _scrollToField(_timeKeys[index]);
                if (index < doseCount - 1) {
                  print("Movendo foco para Horário ${index + 2}");
                  FocusScope.of(context).requestFocus(_timeFocusNodes[index + 1]);
                } else {
                  print("Movendo foco para Data de Início");
                  FocusScope.of(context).requestFocus(_startDateFocusNode);
                }
              },
              onSubmitted: (_) {
                print("onSubmitted: Horário ${index + 1}");
                if (index < doseCount - 1) {
                  print("Movendo foco para Horário ${index + 2}");
                  FocusScope.of(context).requestFocus(_timeFocusNodes[index + 1]);
                  _scrollToField(_timeKeys[index + 1]);
                } else {
                  print("Movendo foco para Data de Início");
                  FocusScope.of(context).requestFocus(_startDateFocusNode);
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _scrollToCenter(_startDateKey);
                  });
                }
              },
            ),
          ],
        ),
      );
    });
  }

  Widget _buildContinuousUsageSwitch() {
    return Focus(
      focusNode: _continuousUseFocusNode,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text("Uso Contínuo", style: getLabelStyle()),
          Switch(
            value: _isContinuous,
            onChanged: (value) => setState(() => _isContinuous = value),
            activeColor: const Color.fromRGBO(0, 105, 148, 1),
          ),
        ],
      ),
    );
  }

  Widget _buildDateField() {
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
          key: _startDateKey,
          onTap: () {
            print("onTap: Data de Início");
            _showCompactDatePicker(context);
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _scrollToCenter(_startDateKey);
            });
          },
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
            : ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width - 40, // Evitar overflow
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Image.file(
                        _image!,
                        height: 100,
                        width: 100,
                        fit: BoxFit.cover,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.red, size: 30),
                      onPressed: () => setState(() => _image = null),
                    ),
                  ],
                ),
              ),
      ],
    );
  }

  Widget _buildSaveButton() {
    return Center(
      child: ElevatedButton(
        onPressed: _saveMedication,
        style: getButtonStyle(),
        child: const Text("Salvar", style: TextStyle(color: Colors.white, fontSize: 24)),
      ),
    );
  }
}

class TypeDropdown extends StatefulWidget {
  final String? selectedType;
  final Function(String?) onChanged;
  final FocusNode focusNode;
  final Function(GlobalKey) scrollToField;
  final GlobalKey keyTag;
  final ScrollController scrollController;

  const TypeDropdown({
    super.key,
    this.selectedType,
    required this.onChanged,
    required this.focusNode,
    required this.scrollToField,
    required this.keyTag,
    required this.scrollController,
  });

  @override
  TypeDropdownState createState() => TypeDropdownState();
}

class TypeDropdownState extends State<TypeDropdown> {
  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(() {
      print("FocusNode: hasFocus=${widget.focusNode.hasFocus}");
    });
  }

  @override
  Widget build(BuildContext context) {
    print("Build: TypeDropdown reconstruído");
    const List<String> medicationTypes = ["Comprimidos", "Cápsulas", "Gotas", "Xarope", "Injeção"];

    return Column(
      key: widget.keyTag,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Tipo do Medicamento", style: _getLabelStyle()),
        const SizedBox(height: 4),
        Focus(
          focusNode: widget.focusNode,
          onFocusChange: (hasFocus) {
            print("onFocusChange: hasFocus=$hasFocus");
            setState(() {
              print("setState: Atualizando borda para hasFocus=$hasFocus");
            });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            decoration: _getDropdownDecoration(hasFocus: widget.focusNode.hasFocus),
            child: DropdownButton2<String>(
              isExpanded: true,
              isDense: false,
              openWithLongPress: false,
              hint: const Padding(
                padding: EdgeInsets.symmetric(vertical: 2.0),
                child: Text(
                  "Selecione o tipo",
                  style: TextStyle(
                    fontSize: 20,
                    color: Color.fromRGBO(0, 85, 128, 1),
                  ),
                  textAlign: TextAlign.center,
                ),
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
              value: widget.selectedType,
              onChanged: (String? newValue) {
                print("Dropdown Tipo: Selecionado $newValue");
                widget.onChanged(newValue);
              },
              onMenuStateChange: (isOpen) async {
                print("Dropdown Tipo: Menu ${isOpen ? 'aberto' : 'fechado'}");
                if (isOpen) {
                  print("onMenuStateChange: Tipo - Ajustando rolagem dinâmica");
                  await Future.delayed(const Duration(milliseconds: 50));
                  try {
                    final box = widget.keyTag.currentContext!.findRenderObject() as RenderBox;
                    final position = box.localToGlobal(Offset.zero);
                    final screenHeight = MediaQuery.of(context).size.height;
                    const bottomMargin = 310.0;

                    final distanceToBottom = screenHeight - position.dy;
                    if (distanceToBottom < bottomMargin) {
                      final scrollOffset = bottomMargin - distanceToBottom;
                      final newOffset = widget.scrollController.offset + scrollOffset;
                      await widget.scrollController.animateTo(
                        newOffset,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                      print("Rolagem ajustada em $scrollOffset pixels para Tipo");
                    }
                  } catch (e) {
                    print("Erro ao ajustar rolagem dinâmica para Tipo: $e");
                    widget.scrollToField(widget.keyTag);
                  }
                }
              },
              dropdownStyleData: DropdownStyleData(
                maxHeight: 300,
                width: MediaQuery.of(context).size.width - 40,
                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4.0),
                  color: Colors.grey[200],
                ),
                offset: const Offset(-15, -5),
              ),
              buttonStyleData: const ButtonStyleData(
                height: 73,
                padding: EdgeInsets.symmetric(horizontal: 12.0),
              ),
              iconStyleData: const IconStyleData(
                icon: Icon(
                  Icons.arrow_drop_down,
                  color: Color.fromRGBO(0, 85, 128, 1),
                  size: 30,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  TextStyle _getLabelStyle() {
    return const TextStyle(
      color: Color.fromRGBO(0, 85, 128, 1),
      fontSize: 20,
      fontWeight: FontWeight.bold,
    );
  }

  BoxDecoration _getDropdownDecoration({required bool hasFocus}) {
    print("getDropdownDecoration: hasFocus=$hasFocus");
    return BoxDecoration(
      color: Colors.grey[200],
      border: Border.all(
        color: hasFocus ? const Color.fromRGBO(85, 170, 85, 1) : Colors.grey,
        width: hasFocus ? 5.0 : 1.0,
      ),
      borderRadius: BorderRadius.circular(4.0),
    );
  }
}

class FrequencyDropdown extends StatefulWidget {
  final String? selectedFrequency;
  final Function(String?) onChanged;
  final FocusNode focusNode;
  final Function(GlobalKey) scrollToField;
  final GlobalKey keyTag;
  final ScrollController scrollController;

  const FrequencyDropdown({
    super.key,
    this.selectedFrequency,
    required this.onChanged,
    required this.focusNode,
    required this.scrollToField,
    required this.keyTag,
    required this.scrollController,
  });

  @override
  FrequencyDropdownState createState() => FrequencyDropdownState();
}

class FrequencyDropdownState extends State<FrequencyDropdown> {
  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(() {
      print("FocusNode (Frequency): hasFocus=${widget.focusNode.hasFocus}");
    });
  }

  @override
  Widget build(BuildContext context) {
    print("Build: FrequencyDropdown reconstruído");
    const List<String> frequencyOptions = [
      "1x ao dia",
      "2x ao dia",
      "3x ao dia",
      "4x ao dia",
      "5x ao dia",
    ];

    return Column(
      key: widget.keyTag,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Modo de Usar", style: _getLabelStyle()),
        const SizedBox(height: 4),
        Focus(
          focusNode: widget.focusNode,
          onFocusChange: (hasFocus) {
            print("onFocusChange (Frequency): hasFocus=$hasFocus");
            setState(() {
              print("setState: Atualizando borda para hasFocus=$hasFocus");
            });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            decoration: _getDropdownDecoration(hasFocus: widget.focusNode.hasFocus),
            child: DropdownButton2<String>(
              isExpanded: true,
              isDense: false,
              openWithLongPress: false,
              hint: const Padding(
                padding: EdgeInsets.symmetric(vertical: 2.0),
                child: Text(
                  "Selecione o modo",
                  style: TextStyle(
                    fontSize: 20,
                    color: Color.fromRGBO(0, 85, 128, 1),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              items: frequencyOptions.map((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(
                    value,
                    style: const TextStyle(fontSize: 24),
                    textAlign: TextAlign.center,
                  ),
                );
              }).toList(),
              value: widget.selectedFrequency,
              onChanged: (String? newValue) {
                print("Dropdown Frequência: Selecionado $newValue");
                widget.onChanged(newValue);
              },
              onMenuStateChange: (isOpen) async {
                print("Dropdown Frequência: Menu ${isOpen ? 'aberto' : 'fechado'}");
                if (isOpen) {
                  print("onMenuStateChange: Frequência - Ajustando rolagem dinâmica");
                  await Future.delayed(const Duration(milliseconds: 50));
                  try {
                    final box = widget.keyTag.currentContext!.findRenderObject() as RenderBox;
                    final position = box.localToGlobal(Offset.zero);
                    final screenHeight = MediaQuery.of(context).size.height;
                    const bottomMargin = 310.0;

                    final distanceToBottom = screenHeight - position.dy;
                    if (distanceToBottom < bottomMargin) {
                      final scrollOffset = bottomMargin - distanceToBottom;
                      final newOffset = widget.scrollController.offset + scrollOffset;
                      await widget.scrollController.animateTo(
                        newOffset,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                      print("Rolagem ajustada em $scrollOffset pixels para Frequência");
                    }
                  } catch (e) {
                    print("Erro ao ajustar rolagem dinâmica para Frequência: $e");
                    widget.scrollToField(widget.keyTag);
                  }
                }
              },
              dropdownStyleData: DropdownStyleData(
                maxHeight: 300,
                width: MediaQuery.of(context).size.width - 40,
                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4.0),
                  color: Colors.grey[200],
                ),
                offset: const Offset(-15, -5),
              ),
              buttonStyleData: const ButtonStyleData(
                height: 73,
                padding: EdgeInsets.symmetric(horizontal: 12.0),
              ),
              iconStyleData: const IconStyleData(
                icon: Icon(
                  Icons.arrow_drop_down,
                  color: Color.fromRGBO(0, 85, 128, 1),
                  size: 30,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  TextStyle _getLabelStyle() {
    return const TextStyle(
      color: Color.fromRGBO(0, 85, 128, 1),
      fontSize: 20,
      fontWeight: FontWeight.bold,
    );
  }

  BoxDecoration _getDropdownDecoration({required bool hasFocus}) {
    print("getDropdownDecoration (Frequency): hasFocus=$hasFocus");
    return BoxDecoration(
      color: Colors.grey[200],
      border: Border.all(
        color: hasFocus ? const Color.fromRGBO(85, 170, 85, 1) : Colors.grey,
        width: hasFocus ? 5.0 : 1.0,
      ),
      borderRadius: BorderRadius.circular(4.0),
    );
  }
}