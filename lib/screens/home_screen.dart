import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart'; // Para Database, openDatabase, getDatabasesPath
import 'package:path/path.dart' as path; // Para path.join
import 'medication_list_screen.dart';
import 'medication_registration_screen.dart';
import 'user_registration_screen.dart'; // Para UserRegistrationScreen
import 'caregiver_registration_screen.dart'; // Para CaregiverRegistrationScreen


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
        backgroundColor: const Color(0xFFE5E5E5),
        child: Padding(
          padding: const EdgeInsets.only(top: 20.0),
          child: ListView(
            padding: const EdgeInsets.only(left: 16.0), // Removi o top: 40.0 pra não somar espaço
            children: [
              const SizedBox(height: 40), // Espaço no topo do Drawer
              Container(
                height: 80, // Altura fixa, menor que o DrawerHeader padrão
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
              SizedBox(height: 40), // ou o valor de espaço que quiser
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
                onTap: () async {
                  final database = await getDatabase();
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
                onTap: () {},
              ),
            ],
          ),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start, // <- alterado aqui
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 100), // esse controla o espaço até o "Bem-vindo"
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

  Future<Database> getDatabase() async {
    return await openDatabase(
      path.join(await getDatabasesPath(), 'medications.db'),
      onCreate: (db, version) async {
        // Tabela de medicamentos (já existia)
        await db.execute(
          'CREATE TABLE medications(id INTEGER PRIMARY KEY, name TEXT, stock TEXT, type TEXT, dosage TEXT, frequency INTEGER, times TEXT, startDate TEXT, isContinuous INTEGER, imagePath TEXT)',
        );
        // Tabela de usuários
        await db.execute(
          'CREATE TABLE users(id INTEGER PRIMARY KEY, name TEXT, phone TEXT)',
        );
        // Tabela de cuidadores
        await db.execute(
          'CREATE TABLE caregivers(id INTEGER PRIMARY KEY, name TEXT, phone TEXT)',
        );
      },
      version: 1,
    );
  }
}