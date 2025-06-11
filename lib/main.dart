import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as path;
import 'screens/welcome_screen.dart';
import 'screens/medication_alert_screen.dart';
import 'notification_service.dart';

Future<Database> initDatabase() async {
  print('DEBUG: Iniciando _initDatabase');
  final dbPath = await getDatabasesPath();
  final pathName = path.join(dbPath, 'medications.db');
  try {
    final database = await openDatabase(
      pathName,
      version: 3,
      onCreate: (db, version) async {
        await db.execute('CREATE TABLE medications (id INTEGER PRIMARY KEY AUTOINCREMENT, nome TEXT NOT NULL, quantidade INTEGER NOT NULL, dosagem_diaria INTEGER NOT NULL, tipo_medicamento TEXT, frequencia TEXT, horarios TEXT, startDate TEXT, isContinuous INTEGER, foto_embalagem TEXT, skip_count INTEGER, cuidador_id TEXT)');
        await db.execute('CREATE TABLE IF NOT EXISTS users(id INTEGER PRIMARY KEY, name TEXT, phone TEXT, date TEXT)');
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
        if (oldVersion < 3) {
          await db.execute('ALTER TABLE users ADD COLUMN date TEXT');
          print("DEBUG: Coluna date adicionada à tabela users.");
        }
      },
    );
    if (!database.isOpen) {
      throw Exception("Erro: Banco de dados não está aberto.");
    }
    try {
      await database.rawQuery('PRAGMA journal_mode=WAL;');
      print('DEBUG: Configuração PRAGMA journal_mode=WAL concluída');
    } catch (e) {
      print('DEBUG: Erro ao configurar PRAGMA journal_mode=WAL: $e');
    }
    print("DEBUG: openDatabase concluído: $database");
    return database;
  } catch (e) {
    print('DEBUG: Erro ao inicializar banco de dados: $e');
    rethrow;
  }
}

class MyApp extends StatelessWidget {
  final Database? database;
  final NotificationService notificationService;
  final Widget initialScreen;

  const MyApp({
    super.key,
    required this.database,
    required this.notificationService,
    required this.initialScreen,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MediAlerta',
      navigatorKey: NotificationService.navigatorKey,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: const Color(0xFFF0F0F0),
      ),
      home: initialScreen,
      onGenerateRoute: (settings) {
        if (settings.name == 'medication_alert') {
          final args = settings.arguments as Map<String, dynamic>?;
          return MaterialPageRoute(
            builder: (context) => FutureBuilder<Database>(
              future: initDatabase(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  );
                } else if (snapshot.hasError) {
                  print('DEBUG: Erro ao carregar banco de dados: ${snapshot.error}');
                  return const Scaffold(
                    body: Center(child: Text('Erro ao carregar o aplicativo.')),
                  );
                } else {
                  return MedicationAlertScreen(
                    horario: args?['horario'] ?? '08:00',
                    medicationIds: (args?['medicationIds'] as String?)?.split(',') ?? [],
                    database: snapshot.data!,
                  );
                }
              },
            ),
          );
        }
        return null;
      },
    );
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  print('DEBUG: Iniciando main');

  // Tela de carregamento inicial
  runApp(const MaterialApp(
    home: Scaffold(
      body: Center(child: CircularProgressIndicator()),
    ),
  ));

  try {
    final notificationService = NotificationService();
    final notification = await notificationService.getInitialNotification();
    Future<Database>? databaseFuture;

    Future<Database> getDatabase() async {
      databaseFuture ??= initDatabase();
      return databaseFuture!;
    }

    // Inicializar initialScreen com um valor padrão
    Widget initialScreen = FutureBuilder<Database>(
      future: getDatabase(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        } else if (snapshot.hasError) {
          print('DEBUG: Erro ao carregar banco de dados: ${snapshot.error}');
          return const Scaffold(
            body: Center(child: Text('Erro ao carregar o aplicativo.')),
          );
        } else {
          return WelcomeScreen(
            database: snapshot.data!,
            notificationService: notificationService,
          );
        }
      },
    );

    if (notification != null && notification.payload != null) {
      final database = await getDatabase();
      await Future.delayed(const Duration(milliseconds: 100)); // Aliviar thread principal
      await notificationService.init(database);
      print('DEBUG: NotificationService inicializado para notificação inicial');
      final payload = notification.payload!;
      if (payload.contains('|')) {
        final parts = payload.split('|');
        final horario = parts[0];
        final medicationIds = parts[1].split(',');
        initialScreen = MedicationAlertScreen(
          horario: horario,
          medicationIds: medicationIds,
          database: database,
        );
        // Cancelar a notificação após exibir a tela
        notificationService.cancelNotification(notification.id!);
        print('DEBUG: Notificação inicial ID ${notification.id} cancelada');
      }
    } else {
      await Future.delayed(const Duration(milliseconds: 100)); // Aliviar thread principal
      final database = await getDatabase();
      await notificationService.init(database);
      print('DEBUG: NotificationService inicializado com sucesso no main');
    }

    runApp(MyApp(
      database: null, // Não passa o database diretamente, usa FutureBuilder
      notificationService: notificationService,
      initialScreen: initialScreen,
    ));
  } catch (e) {
    print('DEBUG: Erro durante inicialização do aplicativo: $e');
    runApp(const MaterialApp(
      home: Scaffold(
        body: Center(
          child: Text('Erro ao inicializar o aplicativo. Tente novamente.'),
        ),
      ),
    ));
  }
}