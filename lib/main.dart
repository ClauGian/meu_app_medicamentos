import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:firebase_core/firebase_core.dart';
import 'screens/welcome_screen.dart';
import 'screens/medication_alert_screen.dart';
import 'screens/daily_alerts_screen.dart';
import 'screens/home_screen.dart';
import 'notification_service.dart';
import 'database_helper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  print('DEBUG: Iniciando main');

  await Firebase.initializeApp();

  final notificationService = NotificationService();
  final databaseHelper = DatabaseHelper();
  final database = await databaseHelper.database;
  await notificationService.init(database);
  print('DEBUG: NotificationService inicializado com sucesso no main');

  runApp(FutureBuilder<Widget>(
    future: Future(() async {
      try {
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
        }

        // Configurar MethodChannel para navegação
        const platform = MethodChannel('com.claudinei.medialerta/navigation');
        platform.setMethodCallHandler((call) async {
          if (call.method == 'navigateToMedicationAlert') {
            final args = call.arguments as Map;
            final horario = args['horario'] as String? ?? '08:00';
            final medicationIds = List<String>.from(args['medicationIds'].map((e) => e.toString()));
            print('DEBUG: navigateToMedicationAlert chamado: horario=$horario, medicationIds=$medicationIds');
            if (medicationIds.isNotEmpty && NotificationService.navigatorKey.currentState != null) {
              NotificationService.navigatorKey.currentState!.pushReplacement(
                MaterialPageRoute(
                  builder: (context) => MedicationAlertScreen(
                    horario: horario,
                    medicationIds: medicationIds,
                    database: database,
                    notificationService: notificationService,
                  ),
                ),
              );
            } else {
              print('DEBUG: Navegação ignorada: medicationIds=$medicationIds, navigatorKey.currentState=${NotificationService.navigatorKey.currentState}');
            }
          }
        });

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

class MyApp extends StatefulWidget {
  final sqflite.Database database;
  final NotificationService notificationService;
  final Widget initialScreen;

  const MyApp({
    super.key,
    required this.database,
    required this.notificationService,
    required this.initialScreen,
  });

  @override
  State<MyApp> createState() => MyAppState();
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
              database: widget.database,
              notificationService: widget.notificationService,
            ),
          );
        } else if (settings.name == 'welcome_screen') {
          return MaterialPageRoute(
            builder: (context) => WelcomeScreen(
              database: widget.database,
              notificationService: widget.notificationService,
            ),
          );
        } else if (settings.name == 'home_screen') {
          return MaterialPageRoute(
            builder: (context) => HomeScreen(
              database: widget.database,
              notificationService: widget.notificationService,
            ),
          );
        } else if (settings.name == 'daily_alerts_screen') {
          return MaterialPageRoute(
            builder: (context) => DailyAlertsScreen(
              database: widget.database,
              notificationService: widget.notificationService,
            ),
          );
        }
        return MaterialPageRoute(
          builder: (context) => WelcomeScreen(
            database: widget.database,
            notificationService: widget.notificationService,
          ),
        );
      },
    );
  }
}