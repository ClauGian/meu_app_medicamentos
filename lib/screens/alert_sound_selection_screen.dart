import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';

class AlertSoundSelectionScreen extends StatefulWidget {
  const AlertSoundSelectionScreen({super.key});

  @override
  State<AlertSoundSelectionScreen> createState() => _AlertSoundSelectionScreenState();
}

class _AlertSoundSelectionScreenState extends State<AlertSoundSelectionScreen> {
  final AudioPlayer audioPlayer = AudioPlayer();
  final List<String> sounds = ['alarm.mp3', 'alert.mp3', 'malta.mp3', 'simple.mp3', 'violin.mp3'];

  String? selectedSound;
  bool _isPlaying = false;

  Future<void> _togglePlayStop() async {
    if (_isPlaying) {
      await audioPlayer.stop();
      setState(() {
        _isPlaying = false;
      });
    } else {
      if (selectedSound != null) {
        await audioPlayer.stop(); // Garante que qualquer áudio anterior seja parado
        try {
          await audioPlayer.play(AssetSource('sounds/$selectedSound'));
          setState(() {
            _isPlaying = true;
          });
        } catch (e) {
          print('Erro ao reproduzir áudio: $e');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Erro ao reproduzir o som.')),
          );
        }
        audioPlayer.onPlayerComplete.listen((event) {
          setState(() {
            _isPlaying = false;
          });
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Selecione um som primeiro.')),
        );
      }
    }
  }

  @override
  void dispose() {
    audioPlayer.stop();
    audioPlayer.dispose();
    super.dispose();
  }

  void _saveSound() {
    if (selectedSound == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, selecione um som.')),
      );
      return;
    }

    // TODO: Salvar no banco ou SharedPreferences
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Som "$selectedSound" salvo com sucesso!'),
        duration: const Duration(seconds: 2),
      ),
    );

    // Atrasar o pop para garantir que o SnackBar seja exibido
    Future.delayed(const Duration(seconds: 3), () {
      Navigator.pop(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    // Removido log do renderingBackend (não disponível nesta versão)
    return Scaffold(
      backgroundColor: const Color(0xFFCCCCCC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFCCCCCC),
        elevation: 0,
        centerTitle: true,
        toolbarHeight: 100,
        title: const Column(
          children: [
            Text(
              "Selecionar",
              style: TextStyle(
                color: Color.fromRGBO(0, 105, 148, 1),
                fontSize: 36,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              "Alerta",
              style: TextStyle(
                color: Color.fromRGBO(85, 170, 85, 1),
                fontSize: 36,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Selecione o som:',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color.fromRGBO(0, 105, 148, 1),
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView.separated(
                itemCount: sounds.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final sound = sounds[index];
                  final isSelected = sound == selectedSound;
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        selectedSound = sound;
                        _isPlaying = false; // Para evitar bug visual
                        audioPlayer.stop();
                      });
                    },
                    child: Container(
                      height: 50,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color.fromARGB(255, 126, 247, 172) : const Color.fromARGB(255, 250, 215, 215),
                        border: Border.all(
                          color: isSelected ? const Color.fromRGBO(85, 170, 85, 1) : Colors.grey,
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        sound.replaceAll('.mp3', ''),
                        style: const TextStyle(fontSize: 20),
                      ),
                    ),
                  );
                },
                cacheExtent: 1000.0, // Aumenta o cache para melhorar rolagem
              ),
            ),
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), // Reduz padding vertical para menor altura
                width: 300, // Aumenta a largura (ajuste conforme necessário)
                decoration: BoxDecoration(
                  color: const Color.fromARGB(255, 131, 246, 175), // Verde claro como background
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: const Color.fromARGB(255, 102, 102, 102).withValues(alpha: 0.3),
                      spreadRadius: 2,
                      blurRadius: 5,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(
                        _isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                        color: const Color.fromRGBO(0, 105, 148, 1),
                        size: 60,
                      ),
                      onPressed: _togglePlayStop,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      selectedSound?.replaceAll('.mp3', '') ?? 'Reproduzir',
                      style: const TextStyle(
                        fontSize: 20,
                        color: Color.fromRGBO(0, 105, 148, 1),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            
            Center(
              child: ElevatedButton(
                onPressed: _saveSound,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromRGBO(0, 105, 148, 1),
                  padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 16),
                ),
                child: const Text(
                  'Salvar',
                  style: TextStyle(
                    color: Color.fromRGBO(85, 170, 85, 1),
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
