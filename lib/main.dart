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
        'CREATE TABLE medications(id INTEGER PRIMARY KEY, name TEXT, frequency TEXT, times TEXT, continuous INTEGER, photoPath TEXT)',
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
        '/welcome': (context) => const WelcomeScreen(),
        '/home': (context) => const HomeScreen(),
        '/register': (context) => const MedicationRegistrationScreen(),
        '/list': (context) => MedicationListScreen(database: database),
      },
    );
  }
}