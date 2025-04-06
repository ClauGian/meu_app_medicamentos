import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as path;
import 'welcome_screen.dart';
import 'home_screen.dart';
import 'medication_registration_screen.dart';
import 'medication_list_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final database = await openDatabase(
    path.join(await getDatabasesPath(), 'medications.db'),
    onCreate: (db, version) {
      return db.execute(
        'CREATE TABLE medications(id INTEGER PRIMARY KEY, name TEXT, stock INTEGER, type TEXT, dosage TEXT, frequency TEXT, times TEXT, startDate TEXT, continuous INTEGER, photoPath TEXT)',
      );
    },
    version: 1,
  );
  runApp(MyApp(database: database));
}

class MyApp extends StatelessWidget {
  final Database database;

  const MyApp({required this.database, super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      initialRoute: '/welcome',
      routes: {
        '/welcome': (context) => WelcomeScreen(database: database), // Corrigido
        '/home': (context) => HomeScreen(database: database),
        '/register': (context) => MedicationRegistrationScreen(database: database),
        '/list': (context) => MedicationListScreen(database: database),
      },
    );
  }
}