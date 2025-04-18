import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as path;
import 'medication_list_screen.dart';
import 'medication_registration_screen.dart';
import 'user_registration_screen.dart';
import 'caregiver_registration_screen.dart';
import 'instructions_screen.dart';
import 'daily_alerts_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Future<Database>? _databaseFuture;

  @override
  void initState() {
    super.initState();
    _databaseFuture = getDatabase();
  }

  Future<Database> getDatabase() async {
    return await openDatabase(
      path.join(await getDatabasesPath(), 'medications.db'),
      onCreate: (db, version) async {
        await db.execute(
          'CREATE TABLE medications(id TEXT PRIMARY KEY, nome TEXT, quantidade_total INTEGER, dosagem_diaria INTEGER, tipo_medicamento TEXT, horarios TEXT, startDate TEXT, isContinuous INTEGER, foto_embalagem TEXT, skip_count INTEGER, cuidador_id TEXT)',
        );
        await db.execute(
          'CREATE TABLE users(id INTEGER PRIMARY KEY, name TEXT, phone TEXT)',
        );
        await db.execute(
          'CREATE TABLE caregivers(id INTEGER PRIMARY KEY, name TEXT, phone TEXT)',
        );
      },
      version: 1,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Database>(
      future: _databaseFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(child: Text("Erro ao carregar o banco de dados: ${snapshot.error}")),
          );
        }
        final database = snapshot.data!;
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
                  icon: const Icon(Icons.menu, size: 42),
                  color: const Color.fromRGBO(0, 105, 148, 1),
                  onPressed: () => Scaffold.of(context).openDrawer(),
                ),
              ),
            ),
          ),
          drawer: Drawer(
            backgroundColor: const Color(0xFFE5E5E5),
            child: Padding(
              padding: const EdgeInsets.only(top: 20.0),
              child: ListView(
                padding: const EdgeInsets.only(left: 16.0),
                children: [
                  const SizedBox(height: 40),
                  Container(
                    height: 80,
                    decoration: const BoxDecoration(
                      color: Color.fromRGBO(0, 105, 148, 1),
                    ),
                    child: Center(
                      child: RichText(
                        text: const TextSpan(
                          children: [
                            TextSpan(
                              text: 'Medi',
                              style: TextStyle(
                                color: Colors.white,
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
                  const SizedBox(height: 40),
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
                        MaterialPageRoute(builder: (context) => const MedicationRegistrationScreen()),
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
                        MaterialPageRoute(builder: (context) => MedicationListScreen(database: database)),
                      );
                    },
                  ),
                  const Divider(color: Colors.grey),
                  ListTile(
                    title: const Text(
                      'Alertas',
                      style: TextStyle(
                        color: Color.fromRGBO(0, 85, 128, 1),
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => DailyAlertsScreen(database: database)),
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
                  const Text(
                    'O seu assistente para lhe ajudar com sua medicação.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color.fromRGBO(0, 105, 148, 1),
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
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
                      'Guia do App', // Mude para 'Guia do App' se preferir
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}