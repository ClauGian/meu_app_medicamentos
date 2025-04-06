import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as path;
import 'medication_list_screen.dart';

class MedicationRegistrationScreen extends StatefulWidget {
  final Database database; // Adicionado
  final Map<String, dynamic>? medication; // Adicionado para edição

  const MedicationRegistrationScreen({required this.database, this.medication, super.key});

  @override
  State<MedicationRegistrationScreen> createState() => _MedicationRegistrationScreenState();
}

class _MedicationRegistrationScreenState extends State<MedicationRegistrationScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _stockController = TextEditingController();
  final TextEditingController _dosageController = TextEditingController();
  final TextEditingController _startDateController = TextEditingController();
  final List<TextEditingController> _timeControllers = [TextEditingController()];
  final FocusNode _nameFocusNode = FocusNode();
  String? _type = 'Comprimidos';
  String? _frequency = '1';
  bool _isContinuous = false;
  File? _image;
  bool _showPhotoOption = true;

  @override
  void initState() {
    super.initState();
    if (widget.medication != null) {
      _nameController.text = widget.medication!['name'] ?? '';
      _stockController.text = widget.medication!['stock'].toString();
      _type = widget.medication!['type'];
      _dosageController.text = widget.medication!['dosage'] ?? '';
      _frequency = widget.medication!['frequency'].toString();
      _startDateController.text = widget.medication!['startDate'] ?? '';
      _isContinuous = widget.medication!['continuous'] == 1;
      if (widget.medication!['photoPath'] != null) {
        _image = File(widget.medication!['photoPath']);
        _showPhotoOption = false;
      }
      final times = (widget.medication!['times'] as String?)?.split(',') ?? [];
      _timeControllers.clear();
      for (var time in times) {
        _timeControllers.add(TextEditingController(text: time));
      }
    }
  }

  Future<void> _saveMedication(BuildContext context) async {
    print('Tentando salvar no banco de dados');
    try {
      await widget.database.insert(
        'medications',
        {
          'name': _nameController.text,
          'stock': int.tryParse(_stockController.text) ?? 0,
          'type': _type,
          'dosage': _dosageController.text,
          'frequency': _frequency,
          'times': _timeControllers.map((c) => c.text).join(','),
          'startDate': _startDateController.text,
          'continuous': _isContinuous ? 1 : 0,
          'photoPath': _image?.path,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => MedicationListScreen(database: widget.database),
        ),
      );
    } catch (e) {
      print('Erro ao salvar no banco de dados: $e');
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      setState(() {
        _startDateController.text = DateFormat('dd/MM/yyyy').format(picked);
      });
    }
  }

  Future<void> _selectTime(BuildContext context, int index) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() {
        _timeControllers[index].text = picked.format(context);
      });
    }
  }

  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
        _showPhotoOption = false;
      });
    }
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label, {
    TextInputType keyboardType = TextInputType.text,
    bool centerText = true,
    List<TextInputFormatter>? inputFormatters,
  }) {
    final FocusNode focusNode = label == "Nome do Medicamento" ? _nameFocusNode : FocusNode();
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
              style: const TextStyle(
                color: Color.fromRGBO(0, 85, 128, 1),
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            TextField(
              controller: controller,
              keyboardType: keyboardType,
              textAlign: centerText ? TextAlign.center : TextAlign.left,
              textCapitalization: label == "Nome do Medicamento"
                  ? TextCapitalization.words
                  : TextCapitalization.none,
              readOnly: label == "Data de Início",
              onTap: label == "Data de Início" ? () => _selectDate(context) : null,
              focusNode: focusNode,
              inputFormatters: inputFormatters,
              decoration: InputDecoration(
                hintText: hasFocus ? null : null,
                labelText: label == "Nome do Medicamento"
                    ? "Insira o nome"
                    : label == "Quantidade Total"
                        ? "Insira a quantidade total"
                        : label == "Dosagem (por dia)"
                            ? "Insira a quantidade diária"
                            : "Insira a data",
                labelStyle: const TextStyle(
                  fontSize: 20,
                  color: Color.fromRGBO(0, 85, 128, 1),
                ),
                floatingLabelBehavior: FloatingLabelBehavior.never,
                filled: true,
                fillColor: Colors.grey[200],
                border: const OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.grey, width: 2.0),
                ),
              ),
              style: const TextStyle(fontSize: 24),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTypeDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Tipo",
          style: TextStyle(
            color: Color.fromRGBO(0, 85, 128, 1),
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        DropdownButtonFormField<String>(
          value: _type,
          items: ['Comprimidos', 'Cápsulas', 'Gotas', 'Injeção', 'Xarope']
              .map((String value) => DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  ))
              .toList(),
          onChanged: (newValue) {
            setState(() {
              _type = newValue;
            });
          },
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.grey[200],
            border: const OutlineInputBorder(),
          ),
        ),
      ],
    );
  }

  Widget _buildFrequencyDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Frequência (vezes ao dia)",
          style: TextStyle(
            color: Color.fromRGBO(0, 85, 128, 1),
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        DropdownButtonFormField<String>(
          value: _frequency,
          items: ['1', '2', '3', '4', '5', '6']
              .map((String value) => DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  ))
              .toList(),
          onChanged: (newValue) {
            setState(() {
              _frequency = newValue;
              final freq = int.parse(newValue!);
              while (_timeControllers.length < freq) {
                _timeControllers.add(TextEditingController());
              }
              while (_timeControllers.length > freq) {
                _timeControllers.removeLast();
              }
            });
          },
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.grey[200],
            border: const OutlineInputBorder(),
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
          style: const TextStyle(
            color: Color.fromRGBO(0, 85, 128, 1),
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          readOnly: true,
          onTap: () => _selectTime(context, index),
          decoration: InputDecoration(
            hintText: "Selecione o horário",
            filled: true,
            fillColor: Colors.grey[200],
            border: const OutlineInputBorder(),
          ),
          style: const TextStyle(fontSize: 24),
        ),
      ],
    );
  }

  Widget _buildContinuousSwitch() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          "Uso Contínuo",
          style: TextStyle(
            color: Color.fromRGBO(0, 85, 128, 1),
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Switch(
          value: _isContinuous,
          onChanged: (value) {
            setState(() {
              _isContinuous = value;
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
        const Text(
          "Foto do Medicamento",
          style: TextStyle(
            color: Color.fromRGBO(0, 85, 128, 1),
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        _image == null
            ? ElevatedButton(
                onPressed: _pickImage,
                child: const Text("Adicionar Foto"),
              )
            : Image.file(_image!, height: 100),
      ],
    );
  }

  Widget _buildSaveButton() {
    return ElevatedButton(
      onPressed: () => _saveMedication(context),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color.fromRGBO(0, 85, 128, 1),
        minimumSize: const Size(double.infinity, 50),
      ),
      child: const Text(
        "Salvar",
        style: TextStyle(fontSize: 20, color: Colors.white),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color.fromRGBO(0, 85, 128, 1),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          "Cadastrar Medicamento",
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 30),
            _buildTextField(_nameController, "Nome do Medicamento", centerText: false),
            const SizedBox(height: 20),
            _buildTextField(
              _stockController,
              "Quantidade Total",
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
            const SizedBox(height: 20),
            _buildTypeDropdown(),
            const SizedBox(height: 20),
            _buildTextField(
              _dosageController,
              "Dosagem (por dia)",
              keyboardType: TextInputType.numberWithOptions(decimal: true),
            ),
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
    super.dispose();
  }
}