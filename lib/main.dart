import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as path;
import 'screens/welcome_screen.dart';
import 'screens/medication_alert_screen.dart';
import 'screens/daily_alerts_screen.dart';
import 'screens/home_screen.dart';
import 'notification_service.dart';

class DatabaseSingleton {
  static Database? _database;
  static bool _isInitializing = false;

  static Future<Database> getInstance() async {
    if (_database != null && _database!.isOpen) {
      print('DEBUG: Retornando instância existente do banco de dados');
      return _database!;
    }

    if (_isInitializing) {
      print('DEBUG: Aguardando inicialização do banco de dados');
      while (_isInitializing) {
        await Future.delayed(Duration(milliseconds: 100));
      }
      return _database!;
    }

    _isInitializing = true;
    try {
      print('DEBUG: Iniciando inicialização do banco de dados');
      final dbPath = await getDatabasesPath();
      final pathName = path.join(dbPath, 'medications.db');
      final database = await openDatabase(
        pathName,
        version: 3,
        onCreate: (db, version) async {
          await db.execute('CREATE TABLE medications (id INTEGER PRIMARY KEY AUTOINCREMENT, nome TEXT NOT NULL, quantidade INTEGER NOT NULL, dosagem_diaria INTEGER NOT NULL, tipo_medicamento TEXT, frequencia TEXT, horarios TEXT, startDate TEXT, isContinuous INTEGER, foto_embalagem TEXT, skip_count INTEGER, cuidador_id TEXT)');
          await db.execute('CREATE TABLE IF NOT EXISTS users(id INTEGER PRIMARY KEY, name TEXT, phone TEXT, date TEXT)');
          await db.execute('CREATE TABLE IF NOT EXISTS caregivers(id INTEGER PRIMARY KEY, name TEXT, phone TEXT)');
          await db.execute('CREATE INDEX idx_medications_id ON medications(id)');
          await db.execute('CREATE INDEX idx_medications_horarios ON medications(horarios)');
          await db.execute('CREATE INDEX idx_medications_startDate ON medications(startDate)');
          print("DEBUG: Criação das tabelas e índices concluída.");
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
      _database = database;
      _isInitializing = false;
      return _database!;
    } catch (e) {
      print('DEBUG: Erro ao inicializar banco de dados: $e');
      _isInitializing = false;
      rethrow;
    }
  }
}

class MyApp extends StatefulWidget {
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
  MyAppState createState() => MyAppState();
}

class MyAppState extends State<MyApp> {
  static const platform = MethodChannel('com.claudinei.medialerta/navigation');
  Map<String, dynamic>? initialRouteData;

  @override
  void initState() {
    super.initState();
    _getInitialRoute();
  }

  Future<void> _getInitialRoute() async {
    try {
      final result = await platform.invokeMethod('getInitialRoute');
      if (result != null) {
        setState(() {
          initialRouteData = Map<String, dynamic>.from(result);
          print('DEBUG: Initial route data: $initialRouteData');
        });
        if (initialRouteData?['route'] == 'medication_alert') {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            NotificationService.navigatorKey.currentState?.pushNamed(
              'medication_alert',
              arguments: {
                'horario': initialRouteData?['horario'] ?? '08:00',
                'medicationIds': List<String>.from(initialRouteData?['medicationIds'] ?? []),
              },
            );
          });
        }
      }
    } catch (e) {
      print('DEBUG: Erro ao obter rota inicial: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MediAlerta',
      navigatorKey: NotificationService.navigatorKey,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: const Color(0xFFF0F0F0),
      ),
      home: widget.initialScreen,
      onGenerateRoute: (settings) {
        print('DEBUG: Gerando rota para: ${settings.name}, argumentos: ${settings.arguments}');
        if (settings.name == 'medication_alert') {
          final args = settings.arguments as Map<String, dynamic>?;
          if (args == null || args['medicationIds'] == null || args['horario'] == null) {
            print('DEBUG: Argumentos inválidos, redirecionando para WelcomeScreen');
            return MaterialPageRoute(
              builder: (context) => WelcomeScreen(
                database: widget.database!,
                notificationService: widget.notificationService,
              ),
            );
          }
          final medicationIds = args['medicationIds'] is List
              ? List<String>.from(args['medicationIds'].map((e) => e.toString()))
              : <String>[];
          print('DEBUG: medicationIds: $medicationIds, Tipo: ${medicationIds.runtimeType}');
          if (medicationIds.isEmpty) {
            print('DEBUG: Lista de medicationIds vazia, tentando buscar por horário');
            return MaterialPageRoute(
              builder: (context) => MedicationAlertScreen(
                horario: args['horario'] ?? '08:00',
                medicationIds: <String>[],
                database: widget.database!,
                notificationService: widget.notificationService,
              ),
            );
          }
          return MaterialPageRoute(
            builder: (context) => MedicationAlertScreen(
              horario: args['horario'] ?? '08:00',
              medicationIds: medicationIds, // Linha 172
              database: widget.database!,
              notificationService: widget.notificationService,
            ),
          );
        } else if (settings.name == 'welcome_screen') {
          return MaterialPageRoute(
            builder: (context) => WelcomeScreen(
              database: widget.database!,
              notificationService: widget.notificationService,
            ),
          );
        } else if (settings.name == 'home_screen') {
          return MaterialPageRoute(
            builder: (context) => HomeScreen(
              database: widget.database!,
              notificationService: widget.notificationService,
            ),
          );
        } else if (settings.name == 'daily_alerts_screen') {
          return MaterialPageRoute(
            builder: (context) => DailyAlertsScreen(
              database: widget.database!,
              notificationService: widget.notificationService,
            ),
          );
        }
        return MaterialPageRoute(
          builder: (context) => WelcomeScreen(
            database: widget.database!,
            notificationService: widget.notificationService,
          ),
        );
      },
    );
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  print('DEBUG: Iniciando main');

  runApp(const MaterialApp(
    home: Scaffold(
      body: Center(child: CircularProgressIndicator()),
    ),
  ));

  try {
    final notificationService = NotificationService();
    final database = await DatabaseSingleton.getInstance();
    await notificationService.init(database);
    print('DEBUG: NotificationService inicializado com sucesso no main');

    Widget initialScreen = WelcomeScreen(
      database: database,
      notificationService: notificationService,
    );
    final notification = await notificationService.getInitialNotification();
    if (notification != null && notification.payload != null) {
      final payload = notification.payload!;
      print('DEBUG: Payload recebido: $payload, Tipo: ${payload.runtimeType}');
      if (payload.contains('|')) {
        final parts = payload.split('|');
        print('DEBUG: Partes do payload: $parts, Tipo: ${parts.runtimeType}');
        if (parts.length < 2 || parts[1].isEmpty) {
          print('DEBUG: Payload inválido: $payload');
          initialScreen = WelcomeScreen(
            database: database,
            notificationService: notificationService,
          );
        } else {
          final horario = parts[0];
          print('DEBUG: Horario: $horario, Tipo: ${horario.runtimeType}');
          final rawIds = parts[1].split(',');
          print('DEBUG: IDs brutos: $rawIds, Tipo: ${rawIds.runtimeType}');
          final medicationIds = List<String>.from(rawIds.map((e) => e.toString()));
          print('DEBUG: medicationIds final: $medicationIds, Tipo: ${medicationIds.runtimeType}');
          initialScreen = MedicationAlertScreen(
            horario: horario,
            medicationIds: medicationIds,
            database: database,
            notificationService: notificationService,
          );
          notificationService.cancelNotification(notification.id!);
          print('DEBUG: Notificação inicial ID ${notification.id} cancelada');
        }
      }
    }

    runApp(MyApp(
      database: database,
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