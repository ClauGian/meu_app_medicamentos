import 'package:flutter/material.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bem-vindo'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/images/remedio_logo.png',
              width: 200,
              height: 200,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                print('Clicou em Cadastrar-se'); // Apenas um teste por agora
              },
              child: const Text('Cadastrar-se'),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () {
                print('Clicou em Entrar'); // Apenas um teste por agora
              },
              child: const Text('Entrar'),
            ),
          ],
        ),
      ),
    );
  }
}