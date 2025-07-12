import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Mantenha, pois NotificationService pode usá-lo
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

  final startTime = DateTime.now().millisecondsSinceEpoch;
  late sqflite.Database database;
  late NotificationService notificationService;

  try {
    // Inicializar Firebase e banco de dados em paralelo
    final firebaseFuture = Firebase.initializeApp();
    final databaseHelper = DatabaseHelper();
    final databaseFuture = databaseHelper.database;

    await Future.wait([
      firebaseFuture.then((_) {
        print('DEBUG: Firebase inicializado - Elapsed: ${DateTime.now().millisecondsSinceEpoch - startTime}ms');
      }),
      databaseFuture.then((db) {
        database = db;
        print('DEBUG: Database inicializado - Elapsed: ${DateTime.now().millisecondsSinceEpoch - startTime}ms');
      }),
    ]);

    notificationService = NotificationService();
    await notificationService.init(database);
    print('DEBUG: NotificationService.init concluído - Elapsed: ${DateTime.now().millisecondsSinceEpoch - startTime}ms');

    // Remove toda a lógica de determinação da tela inicial aqui.
    // Ela será feita no FutureBuilder dentro do MyApp.

    runApp(MyApp(
      database: database,
      notificationService: notificationService,
      // initialScreen: initialScreen, <-- Remova esta linha
      // initialRouteData: initialRouteData, <-- Remova esta linha se existir
    ));

    print('DEBUG: App rodando - Elapsed: ${DateTime.now().millisecondsSinceEpoch - startTime}ms');

  } catch (e, stackTrace) {
    print('DEBUG: Erro na inicialização do main: $e');
    print('DEBUG: StackTrace: $stackTrace');
    runApp(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text('Erro ao iniciar o aplicativo: $e'),
          ),
        ),
      ),
    );
  }
}


class MyApp extends StatefulWidget {
  final sqflite.Database database;
  final NotificationService notificationService;
  // final Widget initialScreen; // <-- REMOVA ESTE CAMPO AQUI TAMBÉM
  // final Map<String, dynamic>? initialRouteData; // <-- REMOVA ESTE CAMPO AQUI TAMBÉM

  const MyApp({
    super.key,
    required this.database,
    required this.notificationService,
    // initialScreen, // <-- REMOVA ESTE PARÂMETRO NOMEADO
    // initialRouteData, // <-- REMOVA ESTE PARÂMETRO NOMEADO
  });

  @override
  State<MyApp> createState() => _MyAppState();
}


class _MyAppState extends State<MyApp> {
  // Remova o ValueNotifier, ele não é necessário com o FutureBuilder na home
  // final ValueNotifier<Map<String, dynamic>?> _currentInitialRouteData = ValueNotifier(null);

  @override
  void initState() {
    super.initState();
    // A lógica de navegação em tempo de execução via MethodChannel
    // deve ser configurada no NotificationService, não aqui.
    // O NotificationService.init() já deveria estar fazendo isso.
    // Vamos garantir que a _handlePlatformMethodCall esteja no NotificationService.
  }

  @override
  Widget build(BuildContext context) {
    print('DEBUG: Construindo MyApp - FutureBuilder irá obter getInitialRouteData');
    return MaterialApp(
      title: 'MediAlerta',
      navigatorKey: NotificationService.navigatorKey, // Garanta que esta key esteja aqui
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      // A HOME DO SEU APP É ONDE A LÓGICA DE DETECÇÃO DA ROTA INICIAL DEVE ACONTECER
      home: FutureBuilder<Map<String, dynamic>?>(
        future: widget.notificationService.getInitialRouteData(), // Chamada ao método do NotificationService
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            // Mostra um CircularProgressIndicator enquanto aguarda os dados da rota inicial
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            );
          }

          final initialData = snapshot.data;
          print('DEBUG: initialData no FutureBuilder: $initialData');

          if (initialData != null && initialData['route'] == 'medication_alert') {
            final horario = initialData['horario'] as String? ?? '08:00';
            final medicationIds =
                (initialData['medicationIds'] as List<dynamic>?)
                        ?.map((e) => e.toString())
                        .toList() ??
                    <String>[];
            print('DEBUG: Definindo MedicationAlertScreen como tela inicial via FutureBuilder.');
            return MedicationAlertScreen(
              horario: horario,
              medicationIds: medicationIds,
              database: widget.database,
              notificationService: widget.notificationService,
            );
          } else {
            print('DEBUG: Nenhuma rota especial, definindo WelcomeScreen como tela inicial.');
            return WelcomeScreen(
              database: widget.database,
              notificationService: widget.notificationService,
            );
          }
        },
      ),
      onGenerateRoute: (settings) {
        print('DEBUG: Gerando rota para: ${settings.name}, argumentos: ${settings.arguments}');
        // Esta parte do onGenerateRoute só deve ser para navegação interna do app,
        // não para o lançamento inicial por notificação/alarme, que é handled pelo 'home' (FutureBuilder).

        if (settings.name == 'medication_alert') {
          final args = settings.arguments as Map<String, dynamic>?;
          final horario = args?['horario'] as String? ?? '08:00';
          final medicationIds = (args?['medicationIds'] as List<dynamic>?)
                  ?.map((e) => e.toString())
                  .toList() ??
              <String>[];
          print('DEBUG: Construindo MedicationAlertScreen via onGenerateRoute com horario=$horario, medicationIds=$medicationIds');
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