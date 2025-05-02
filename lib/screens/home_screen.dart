import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'medication_list_screen.dart';
import 'medication_registration_screen.dart';
import 'user_registration_screen.dart';
import 'caregiver_registration_screen.dart';
import 'instructions_screen.dart';
import 'daily_alerts_screen.dart';
import 'alert_sound_selection_screen.dart';


class HomeScreen extends StatefulWidget {
  final Database database;

  const HomeScreen({super.key, required this.database});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFCCCCCC),
      appBar: AppBar(
        title: Padding(
          padding: const EdgeInsets.only(top: 20.0, left: 16.0),
          child: RichText(
            text: const TextSpan(
              children: [
                TextSpan(
                  text: 'Medi',
                  style: TextStyle(
                    color: Color.fromRGBO(0, 105, 148, 1),
                    fontSize: 42,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextSpan(
                  text: 'Alerta',
                  style: TextStyle(
                    color: Color.fromRGBO(85, 170, 85, 1),
                    fontSize: 42,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
        backgroundColor: const Color(0xFFCCCCCC),
        elevation: 0,
        leading: Builder(
          builder: (context) => Padding(
            padding: const EdgeInsets.only(top: 10.0, left: 16.0),
            child: IconButton(
              icon: const Icon(Icons.menu, size: 50),
              color: const Color.fromRGBO(0, 0, 0, 1),
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
          ),
        ),
      ),
      drawer: Drawer(
        backgroundColor: const Color.fromARGB(255, 217, 242, 217),
        child: Padding(
          padding: const EdgeInsets.only(top: 20.0),
          child: ListView(
            padding: const EdgeInsets.only(left: 8.0),
            children: [
              const SizedBox(height: 24),
              Container(
                height: 70,
                decoration: const BoxDecoration(
                  color: Color.fromRGBO(255, 217, 242, 217),
                ),
                child: Center(
                  child: RichText(
                    text: const TextSpan(
                      children: [
                        TextSpan(
                          text: 'Medi',
                          style: TextStyle(
                            color: Color.fromRGBO(0, 105, 148, 1),
                            fontSize: 40,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextSpan(
                          text: 'Alerta',
                          style: TextStyle(
                            color: Color.fromRGBO(85, 170, 85, 1),
                            fontSize: 40,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              ListTile(
                title: const Text(
                  'Meu Cadastro',
                  style: TextStyle(
                    color: Color.fromRGBO(0, 85, 128, 1),
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const UserRegistrationScreen()),
                  );
                },
              ),
              const Divider(color: Colors.grey),

              ListTile(
                title: const Text(
                  'Cadastrar Cuidador',
                  style: TextStyle(
                    color: Color.fromRGBO(0, 85, 128, 1),
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const CaregiverRegistrationScreen()),
                  );
                },
              ),
              const Divider(color: Colors.grey),

              ListTile(
                title: const Text(
                  'Cadastrar Medicamentos',
                  style: TextStyle(
                    color: Color.fromRGBO(0, 85, 128, 1),
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => MedicationRegistrationScreen(database: widget.database)),
                  );
                },
              ),
              const Divider(color: Colors.grey),

              ListTile(
                title: const Text(
                  'Cadastrar Alertas',
                  style: TextStyle(
                    color: Color.fromRGBO(0, 85, 128, 1),
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const AlertSoundSelectionScreen()),
                  );
                },
              ),
              const Divider(color: Colors.grey),

              ListTile(
                title: const Text(
                  'Lista de Medicamentos',
                  style: TextStyle(
                    color: Color.fromRGBO(0, 85, 128, 1),
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => MedicationListScreen(database: widget.database)),
                  );
                },
              ),
              const Divider(color: Colors.grey),

              ListTile(
                title: const Text(
                  'Alertas do Dia',
                  style: TextStyle(
                    color: Color.fromRGBO(0, 85, 128, 1),
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => DailyAlertsScreen(database: widget.database)),
                  );
                },
              ),
            ],
          ),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 100),
              RichText(
                textAlign: TextAlign.center,
                text: const TextSpan(
                  children: [
                    TextSpan(
                      text: 'Bem-vindo ao ',
                      style: TextStyle(
                        color: Color.fromRGBO(0, 105, 148, 1),
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        height: 1.5,
                      ),
                    ),
                    TextSpan(
                      text: 'Medi',
                      style: TextStyle(
                        color: Color.fromRGBO(0, 105, 148, 1),
                        fontSize: 42,
                        fontWeight: FontWeight.bold,
                        height: 1.5,
                      ),
                    ),
                    TextSpan(
                      text: 'Alerta!',
                      style: TextStyle(
                        color: Color.fromRGBO(85, 170, 85, 1),
                        fontSize: 42,
                        fontWeight: FontWeight.bold,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 50),
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: const TextStyle(
                    color: Color.fromRGBO(0, 105, 148, 1),
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  children: [
                    const TextSpan(text: 'Acesse o menu acima  '),
                    WidgetSpan(
                      alignment: PlaceholderAlignment.middle,
                      child: Icon(Icons.menu, size: 40, color: Colors.black),
                    ),
                    const TextSpan(text: '  e comece a usar seu assistente para cuidar das suas medicações.'),
                  ],
                ),
              ),
              const SizedBox(height: 100),
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const InstructionsScreen()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromRGBO(0, 105, 148, 1),
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                ),
                child: const Text(
                  'Guia do App',
                  style: TextStyle(
                    color: Color.fromRGBO(85, 170, 85, 1),
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}