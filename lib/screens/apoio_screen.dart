import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ApoioScreen extends StatelessWidget {
  const ApoioScreen({super.key});

  static const String chavePix =
      '4321555d-f880-4b6c-8801-ad0f093dd1d1';

  static const Color corPadrao = Color.fromRGBO(0, 105, 148, 1);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFCCCCCC),
      appBar: AppBar(
        toolbarHeight: 100.0,
        backgroundColor: const Color(0xFFCCCCCC),
        centerTitle: true,
        title: const Padding(
          padding: EdgeInsets.only(top: 20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Apoiar',
                style: TextStyle(
                  color: corPadrao,
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'MediAlerta',
                style: TextStyle(
                  color: Color.fromRGBO(85, 170, 85, 1),
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        leading: Padding(
          padding: const EdgeInsets.only(top: 20.0),
          child: IconButton(
            icon: const Icon(
              Icons.arrow_back,
              color: corPadrao,
              size: 42,
            ),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Descricao(),
            SizedBox(height: 24),
            _QrPixImage(),
            SizedBox(height: 24),
            _ChavePix(),
            SizedBox(height: 24),
            Center(
              child: _BotaoCopiarPix(),
            ),
          ],
        ),
      ),
    );
  }
}

class _Descricao extends StatelessWidget {
  const _Descricao();

  @override
  Widget build(BuildContext context) {
    return const Text(
      'O MediAlerta é um projeto independente, criado com carinho para ajudar pessoas a lembrarem de seus medicamentos no dia a dia.\n\n'
      'Ele é e continuará sendo gratuito.\n\n'
      'Se este aplicativo te ajuda de alguma forma, você pode apoiar o projeto com uma doação voluntária. Qualquer valor é bem-vindo.',
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 24,
        color: ApoioScreen.corPadrao,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}

class _QrPixImage extends StatelessWidget {
  const _QrPixImage();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Image.asset(
        'assets/qr_pix.png',
        width: 220,
        height: 220,
        fit: BoxFit.contain,
      ),
    );
  }
}

class _ChavePix extends StatelessWidget {
  const _ChavePix();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: const [
        Text(
          'Chave PIX:',
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.bold,
            color: ApoioScreen.corPadrao,
          ),
        ),
        SizedBox(height: 8),
        SelectableText(
          ApoioScreen.chavePix,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: ApoioScreen.corPadrao,
          ),
        ),
      ],
    );
  }
}

class _BotaoCopiarPix extends StatelessWidget {
  const _BotaoCopiarPix();

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color.fromRGBO(0, 105, 148, 1),
        padding: const EdgeInsets.symmetric(
          horizontal: 40,
          vertical: 15,
        ),
      ),
      onPressed: () {
        Clipboard.setData(
          const ClipboardData(text: ApoioScreen.chavePix),
        );

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Chave PIX copiada',
              style: TextStyle(fontSize: 18),
            ),
          ),
        );
      },
      child: const Text(
        'Copiar chave PIX',
        style: TextStyle(
          color: Colors.white,
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

