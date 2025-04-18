import 'package:flutter/material.dart';

class InstructionsScreen extends StatelessWidget {
  const InstructionsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Como Usar o MediAlerta'),
        backgroundColor: const Color.fromRGBO(0, 105, 148, 1),
        foregroundColor: Colors.white,
      ),
      backgroundColor: const Color(0xFFCCCCCC),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: const [
            Text(
              'Bem-vindo ao MediAlerta!',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color.fromRGBO(0, 105, 148, 1),
              ),
            ),
            SizedBox(height: 16),
            Text(
              'O MediAlerta é seu assistente para gerenciar medicações. Veja como usar cada área do app:',
              style: TextStyle(fontSize: 18, color: Colors.black87),
            ),
            SizedBox(height: 16),
            Text(
              '1. Meu Cadastro',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color.fromRGBO(0, 85, 128, 1),
              ),
            ),
            Text(
              'Cadastre suas informações pessoais, como nome e telefone, para personalizar sua experiência.',
              style: TextStyle(fontSize: 16, color: Colors.black87),
            ),
            SizedBox(height: 12),
            Text(
              '2. Cadastrar Cuidador',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color.fromRGBO(0, 85, 128, 1),
              ),
            ),
            Text(
              'Adicione um cuidador para receber notificações se você pular doses de medicamentos.',
              style: TextStyle(fontSize: 16, color: Colors.black87),
            ),
            SizedBox(height: 12),
            Text(
              '3. Cadastrar Medicamentos',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color.fromRGBO(0, 85, 128, 1),
              ),
            ),
            Text(
              'Registre seus medicamentos, incluindo nome, dose, horários e quantidade em estoque.',
              style: TextStyle(fontSize: 16, color: Colors.black87),
            ),
            SizedBox(height: 12),
            Text(
              '4. Lista de Medicamentos',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color.fromRGBO(0, 85, 128, 1),
              ),
            ),
            Text(
              'Veja todos os medicamentos cadastrados e gerencie seus detalhes.',
              style: TextStyle(fontSize: 16, color: Colors.black87),
            ),
            SizedBox(height: 12),
            Text(
              '5. Alertas',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color.fromRGBO(0, 85, 128, 1),
              ),
            ),
            Text(
              'Receba lembretes para tomar seus medicamentos e veja os alertas do dia.',
              style: TextStyle(fontSize: 16, color: Colors.black87),
            ),
          ],
        ),
      ),
    );
  }
}