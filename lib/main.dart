import 'package:flutter/material.dart';
import 'screens/welcome_screen.dart';
import 'notification_service.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as path;

Future<Database> _initDatabase() async {
  final dbPath = await getDatabasesPath();
  final pathName = path.join(dbPath, 'medications.db');
  final database = await openDatabase(
    pathName,
    version: 1,
    onCreate: (db, version) async {
      await db.execute('CREATE TABLE medications (id INTEGER PRIMARY KEY AUTOINCREMENT, nome TEXT NOT NULL, quantidade INTEGER, dosagem_diaria INTEGER, tipo_medicamento TEXT, frequencia TEXT, horarios TEXT, startDate TEXT, isContinuous INTEGER, foto_embalagem TEXT, skip_count INTEGER, cuidador_id TEXT)');
      await db.execute('CREATE TABLE IF NOT EXISTS users(id INTEGER PRIMARY KEY, name TEXT, phone TEXT)');
      await db.execute('CREATE TABLE IF NOT EXISTS caregivers(id INTEGER PRIMARY KEY, name TEXT, phone TEXT)');
      print("DEBUG: Criação das tabelas concluída.");
    },
  );

  if (!await database.isOpen) {
    throw Exception("Erro: Banco de dados não está aberto.");
  }

  print("openDatabase concluído: $database");
  return database;
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final database = await _initDatabase();
  await NotificationService().init(database);
  runApp(MyApp(database: database));
}

class MyApp extends StatelessWidget {
  final Database database;

  const MyApp({super.key, required this.database});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MediAlerta',
      navigatorKey: NotificationService.navigatorKey, // Adicionar navigatorKey
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: const Color(0xFFF0F0F0),
      ),
      home: WelcomeScreen(database: database),
    );
  }
}