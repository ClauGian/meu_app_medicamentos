import 'package:flutter/material.dart';
import 'screens/welcome_screen.dart';
import 'notification_service.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as path;
import 'package:workmanager/workmanager.dart';

// Função de callback do Workmanager (adicionada fora de qualquer classe)
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    print('DEBUG: Executando tarefa Workmanager: $task');
    final notificationService = NotificationService();
    await notificationService.init(inputData!['database'] as Database);
    await notificationService.showNotification(
      id: inputData['id'] as int,
      title: inputData['title'] as String,
      body: inputData['body'] as String,
      sound: 'alarm',
      payload: inputData['payload'] as String,
    );
    return Future.value(true);
  });
}

Future<Database> _initDatabase() async {
  final dbPath = await getDatabasesPath();
  final pathName = path.join(dbPath, 'medications.db');
  final database = await openDatabase(
    pathName,
    version: 2,
    onCreate: (db, version) async {
      await db.execute('CREATE TABLE medications (id INTEGER PRIMARY KEY AUTOINCREMENT, nome TEXT NOT NULL, quantidade INTEGER NOT NULL, dosagem_diaria INTEGER NOT NULL, tipo_medicamento TEXT, frequencia TEXT, horarios TEXT, startDate TEXT, isContinuous INTEGER, foto_embalagem TEXT, skip_count INTEGER, cuidador_id TEXT)');
      await db.execute('CREATE TABLE IF NOT EXISTS users(id INTEGER PRIMARY KEY, name TEXT, phone TEXT)');
      await db.execute('CREATE TABLE IF NOT EXISTS caregivers(id INTEGER PRIMARY KEY, name TEXT, phone TEXT)');
      print("DEBUG: Criação das tabelas concluída.");
    },
    onUpgrade: (db, oldVersion, newVersion) async {
      if (oldVersion < 2) {
        await db.execute('ALTER TABLE medications RENAME TO medications_old');
        await db.execute('CREATE TABLE medications (id INTEGER PRIMARY KEY AUTOINCREMENT, nome TEXT NOT NULL, quantidade INTEGER NOT NULL, dosagem_diaria INTEGER NOT NULL, tipo_medicamento TEXT, frequencia TEXT, horarios TEXT, startDate TEXT, isContinuous INTEGER, foto_embalagem TEXT, skip_count INTEGER, cuidador_id TEXT)');
        await db.execute('INSERT INTO medications (id, nome, quantidade, dosagem_diaria, tipo_medicamento, frequencia, horarios, startDate, isContinuous, foto_embalagem, skip_count, cuidador_id) SELECT id, nome, COALESCE(quantidade, 0), COALESCE(dosagem_diaria, 0), tipo_medicamento, frequencia, horarios, startDate, isContinuous, foto_embalagem, skip_count, cuidador_id FROM medications_old');
        await db.execute('DROP TABLE medications_old');
        print("DEBUG: Migração para versão 2 concluída.");
      }
    },
  );

  if (!database.isOpen) {
    throw Exception("Erro: Banco de dados não está aberto.");
  }

  print("openDatabase concluído: $database");
  return database;
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Inicializar o Workmanager
  Workmanager().initialize(callbackDispatcher, isInDebugMode: true);
  final database = await _initDatabase();
  await NotificationService().init(database);
  print('DEBUG: NotificationService inicializado com sucesso');
  runApp(MyApp(database: database));
}

class MyApp extends StatelessWidget {
  final Database database;

  const MyApp({super.key, required this.database});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MediAlerta',
      navigatorKey: NotificationService.navigatorKey,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: const Color(0xFFF0F0F0),
      ),
      home: WelcomeScreen(database: database),
    );
  }
}