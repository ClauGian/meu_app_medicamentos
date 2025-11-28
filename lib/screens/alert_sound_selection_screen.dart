import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:just_audio/just_audio.dart';

class AlertSoundSelectionScreen extends StatefulWidget {
  const AlertSoundSelectionScreen({super.key});

  @override
  State<AlertSoundSelectionScreen> createState() => _AlertSoundSelectionScreenState();
}

class _AlertSoundSelectionScreenState extends State<AlertSoundSelectionScreen> {
  final AudioPlayer audioPlayer = AudioPlayer();
  final List<String> sounds = ['alarm', 'alert', 'malta', 'simple', 'violin'];
  String? selectedSound;
  bool _isPlaying = false;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _loadSelectedSound();  
  }

  Future<void> _loadSelectedSound() async {
    final prefs = await SharedPreferences.getInstance();
    final savedSound = prefs.getString('selected_sound');
    setState(() {
      selectedSound = savedSound;
      _isEditing = savedSound == null; // Habilitar edição se não houver som salvo
    });
    print('DEBUG: Som carregado: $savedSound');
  }

  Future<void> _togglePlayStop() async {
    if (_isPlaying) {
      await audioPlayer.stop();
      setState(() {
        _isPlaying = false;
      });
    } else {
      if (selectedSound != null) {
        await audioPlayer.stop();
        try {
          await audioPlayer.setAsset('sounds/$selectedSound');
          await audioPlayer.setLoopMode(LoopMode.off);
          await audioPlayer.setVolume(1.0);
          await audioPlayer.play();
          setState(() {
            _isPlaying = true;
          });

          // Monitorar a conclusão da reprodução
          audioPlayer.playerStateStream.listen((playerState) {
            if (playerState.processingState == ProcessingState.completed) {
              setState(() {
                _isPlaying = false;
              });
            }
          });
        } catch (e) {
          print('Erro ao reproduzir áudio: $e');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Erro ao reproduzir o som.')),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Selecione um som primeiro.')),
        );
      }
    }
  }



  void _toggleEditing() {
    setState(() {
      _isEditing = !_isEditing;
    });
    print('DEBUG: Modo de edição: $_isEditing');
  }

  void _saveSound() {
    if (selectedSound == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, selecione um som.')),
      );
      return;
    }

    SharedPreferences.getInstance().then((prefs) {
      prefs.setString('selected_sound', selectedSound!);
      print('DEBUG: Som salvo: $selectedSound');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Som "${selectedSound!.replaceAll('.mp3', '')}" salvo com sucesso!'),
          duration: const Duration(seconds: 2),
        ),
      );
      setState(() {
        _isEditing = false;
      });
      Future.delayed(const Duration(seconds: 2), () {
        Navigator.pop(context);
      });
    });
  }

  @override
  void dispose() {
    audioPlayer.stop();
    audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                    onTap: _isEditing
                        ? () {
                            setState(() {
                              selectedSound = sound;
                              _isPlaying = false;
                              audioPlayer.stop();
                            });
                          }
                        : null,
                    child: Container(
                      height: 50,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color.fromARGB(255, 44, 184, 98) : const Color.fromARGB(255, 250, 215, 215),
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
                cacheExtent: 1000.0,
              ),
            ),
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                width: 300,
                decoration: BoxDecoration(
                  color: const Color.fromARGB(255, 131, 246, 175),
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
                onPressed: _isEditing ? _saveSound : _toggleEditing,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromRGBO(0, 105, 148, 1),
                  padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 16),
                ),
                child: Text(
                  _isEditing ? 'Salvar' : 'Alterar',
                  style: const TextStyle(
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