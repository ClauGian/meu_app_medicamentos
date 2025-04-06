import 'package:flutter/material.dart';

class WelcomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Bem-vindo ao Meu App Medicamentos'),
      ),
      body: Center(
        child: Text('Tela de Boas-vindas funcionando!'),
      ),
    );
  }
}