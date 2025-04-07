import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as path;
import 'medication_registration_screen.dart';
import 'medication_list_screen.dart';
import 'user_registration_screen.dart';
import 'caregiver_registration_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

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
              icon: const Icon(Icons.menu, size: 42),
              color: const Color.fromRGBO(0, 105, 148, 1),
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
          ),
        ),
      ),
      drawer: Drawer(
        child: ListView(
          padding: const EdgeInsets.only(top: 40.0, left: 16.0),
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(
                color: Color.fromRGBO(0, 105, 148, 1),
              ),
              child: RichText(
                text: const TextSpan(
                  children: [
                    TextSpan(
                      text: 'Medi',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextSpan(
                      text: 'Alerta',
                      style: TextStyle(
                        color: Color.fromRGBO(85, 170, 85, 1),
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            ListTile(
              title: const Text(
                'Meu Cadastro',
                style: TextStyle(
                  color: Color.fromRGBO(0, 85, 128, 1),
                  fontSize: 20,
                ),
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const UserRegistrationScreen()),
                );
              },
            ),
            ListTile(
              title: const Text(
                'Cadastrar Cuidador',
                style: TextStyle(
                  color: Color.fromRGBO(0, 85, 128, 1),
                  fontSize: 20,
                ),
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const CaregiverRegistrationScreen()),
                );
              },
            ),
            ListTile(
              title: const Text(
                'Cadastrar Medicamentos',
                style: TextStyle(
                  color: Color.fromRGBO(0, 85, 128, 1),
                  fontSize: 20,
                ),
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const MedicationRegistrationScreen()),
                );
              },
            ),
            ListTile(
              title: const Text(
                'Lista de Medicamentos',
                style: TextStyle(
                  color: Color.fromRGBO(0, 85, 128, 1),
                  fontSize: 20,
                ),
              ),
              onTap: () async {
                final database = await getDatabase();
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => MedicationListScreen(database: database)),
                );
              },
            ),
            ListTile(
              title: const Text(
                'Alertas',
                style: TextStyle(
                  color: Color.fromRGBO(0, 85, 128, 1),
                  fontSize: 20,
                ),
              ),
              onTap: () {},
            ),
          ],
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 40),
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
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        height: 1.5,
                      ),
                    ),
                    TextSpan(
                      text: 'Alerta!',
                      style: TextStyle(
                        color: Color.fromRGBO(85, 170, 85, 1),
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 80),
              ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromRGBO(0, 105, 148, 1),
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                ),
                child: const Text(
                  'Ver Alertas do Dia',
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
  }

  // Função auxiliar para obter o banco de dados (será usada no MedicationListScreen)
  Future<Database> getDatabase() async {
    return await openDatabase(
      path.join(await getDatabasesPath(), 'medications.db'),
      onCreate: (db, version) {
        return db.execute(
          'CREATE TABLE medications(id INTEGER PRIMARY KEY, name TEXT, stock TEXT, type TEXT, dosage TEXT, frequency INTEGER, times TEXT, startDate TEXT, isContinuous INTEGER, imagePath TEXT)',
        );
      },
      version: 1,
    );
  }
}