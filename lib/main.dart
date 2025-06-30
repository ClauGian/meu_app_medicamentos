import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as path;
import 'package:firebase_core/firebase_core.dart'; // Adicionado
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
          final horario = args?['horario'] ?? '08:00';
          final medicationIds = args != null && args['medicationIds'] is List
              ? List<String>.from(args['medicationIds'].map((e) => e.toString()))
              : <String>[];
          return MaterialPageRoute(
            builder: (context) => MedicationAlertScreen(
              horario: horario,
              medicationIds: medicationIds,
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

  await Firebase.initializeApp(); // Adicionado para inicializar o Firebase

  runApp(FutureBuilder<Widget>(
    future: Future(() async {
      try {
        final notificationService = NotificationService();
        final database = await DatabaseSingleton.getInstance();
        await notificationService.init(database);
        print('DEBUG: NotificationService inicializado com sucesso no main');

        Widget initialScreen = WelcomeScreen(
          database: database,
          notificationService: notificationService,
        );

        // Verificar notificação inicial
        final notification = await notificationService.getInitialNotification();
        if (notification != null && notification.payload != null) {
          final payload = notification.payload!;
          print('DEBUG: Payload recebido: $payload, Tipo: ${payload.runtimeType}');
          if (payload.contains('|')) {
            final parts = payload.split('|');
            print('DEBUG: Partes do payload: $parts, Tipo: ${parts.runtimeType}');
            if (parts.length >= 2 && parts[1].isNotEmpty) {
              final horario = parts[0];
              final rawIds = parts[1].split(',');
              final medicationIds = List<String>.from(rawIds.map((e) => e.toString()));
              print('DEBUG: medicationIds final: $medicationIds, Tipo: ${medicationIds.runtimeType}');
              initialScreen = MedicationAlertScreen(
                horario: horario,
                medicationIds: medicationIds,
                database: database,
                notificationService: notificationService,
              );
              await notificationService.cancelNotification(notification.id!);
              print('DEBUG: Notificação inicial ID ${notification.id} cancelada');
            }
          }
        } else {
          // Verificar rota inicial via MethodChannel
          const platform = MethodChannel('com.claudinei.medialerta/navigation');
          try {
            final result = await platform.invokeMethod('getInitialRoute');
            if (result != null) {
              final routeData = Map<String, dynamic>.from(result);
              print('DEBUG: Initial route data: $routeData');
              if (routeData['route'] == 'medication_alert') {
                final horario = routeData['horario'] ?? '08:00';
                final medicationIds = List<String>.from(routeData['medicationIds'] ?? []);
                if (medicationIds.isNotEmpty) {
                  initialScreen = MedicationAlertScreen(
                    horario: horario,
                    medicationIds: medicationIds,
                    database: database,
                    notificationService: notificationService,
                  );
                }
              }
            }
          } catch (e) {
            print('DEBUG: Erro ao obter rota inicial: $e');
          }
        }

        return MyApp(
          database: database,
          notificationService: notificationService,
          initialScreen: initialScreen,
        );
      } catch (e, stackTrace) {
        print('DEBUG: Erro durante inicialização do aplicativo: $e');
        print('DEBUG: StackTrace: $stackTrace');
        throw e;
      }
    }),
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const MaterialApp(
          home: Scaffold(
            body: Center(child: CircularProgressIndicator()),
          ),
        );
      } else if (snapshot.hasError) {
        print('DEBUG: Erro no FutureBuilder: ${snapshot.error}');
        return MaterialApp(
          home: Scaffold(
            body: Center(
              child: Text('Erro ao inicializar o aplicativo: ${snapshot.error}'),
            ),
          ),
        );
      } else {
        return snapshot.data as Widget;
      }
    },
  ));
}