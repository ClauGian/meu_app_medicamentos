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
              'assets/imagem_senhora.png', // Caminho corrigido
              width: 200,
              height: 200,
              errorBuilder: (context, error, stackTrace) {
                return const Text('Imagem não encontrada');
              },
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                print('Clicou em Cadastrar-se');
              },
              child: const Text('Cadastrar-se'),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () {
                print('Clicou em Entrar');
              },
              child: const Text('Entrar'),
            ),
          ],
        ),
      ),
    );
  }
}