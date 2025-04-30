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

  @override
  void dispose() {
    audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _togglePlayStop() async {
    if (_isPlaying) {
      await audioPlayer.stop();
      setState(() {
        _isPlaying = false;
      });
    } else {
      if (selectedSound != null) {
        await audioPlayer.play(AssetSource('sounds/$selectedSound'));
        setState(() {
          _isPlaying = true;
        });
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

  void _saveSound() {
    if (selectedSound == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, selecione um som.')),
      );
      return;
    }

    // TODO: Salvar no banco ou SharedPreferences
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Som "$selectedSound" salvo com sucesso!')),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFCCCCCC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFCCCCCC),
        elevation: 0,
        centerTitle: true,
        toolbarHeight: 90,
        title: const Column(
          children: [
            Text(
              "Selecionar",
              style: TextStyle(
                color: Color.fromRGBO(0, 105, 148, 1),
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              "Som do Alerta",
              style: TextStyle(
                color: Color.fromRGBO(85, 170, 85, 1),
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Toque em uma opção para selecionar o som do alerta:',
              style: TextStyle(
                color: Color.fromRGBO(0, 105, 148, 1),
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView.separated(
                itemCount: sounds.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
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
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFFE0F7E9) : Colors.white,
                        border: Border.all(
                          color: isSelected ? const Color.fromRGBO(85, 170, 85, 1) : Colors.grey,
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        sound.replaceAll('.mp3', ''),
                        style: const TextStyle(fontSize: 18),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
            Center(
              child: ElevatedButton.icon(
                onPressed: _togglePlayStop,
                icon: Icon(_isPlaying ? Icons.stop : Icons.play_arrow),
                label: Text(_isPlaying ? 'Parar' : 'Ouvir som selecionado'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromRGBO(0, 105, 148, 1),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
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
