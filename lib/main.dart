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

  final startTime = DateTime.now().millisecondsSinceEpoch;
  late sqflite.Database database;
  late NotificationService notificationService;

  try {
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

    runApp(MyApp(
      database: database,
      notificationService: notificationService,
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

  const MyApp({
    super.key,
    required this.database,
    required this.notificationService,
  });

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final ValueNotifier<Map<String, dynamic>?> routeDataNotifier = ValueNotifier<Map<String, dynamic>?>(null);

  @override
  void initState() {
    super.initState();
    _initializeRouteData();
  }

  Future<void> _initializeRouteData() async {
    final initialData = await widget.notificationService.getInitialRouteData();
    routeDataNotifier.value = initialData;

    const MethodChannel('com.claudinei.medialerta/navigation').setMethodCallHandler((call) async {
      if (call.method == 'navigateToMedicationAlert') {
        final args = call.arguments as Map;
        print('DEBUG: Navegando para MedicationAlertScreen via MethodChannel com args=$args');
        routeDataNotifier.value = args.cast<String, dynamic>();
      }
      return null;
    });
  }

  @override
  Widget build(BuildContext context) {
    print('DEBUG: Construindo MyApp - Configurando ValueListenableBuilder');
    return MaterialApp(
      title: 'MediAlerta',
      navigatorKey: NotificationService.navigatorKey,
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: ValueListenableBuilder<Map<String, dynamic>?>(
        valueListenable: routeDataNotifier,
        builder: (context, routeData, child) {
          if (routeData == null) {
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            );
          }

          print('DEBUG: routeData no ValueListenableBuilder: $routeData');

          if (routeData['route'] == 'medication_alert') {
            final horario = routeData['horario'] as String? ?? '08:00';
            final medicationIds = (routeData['medicationIds'] as List<dynamic>?)
                    ?.map((e) => e.toString())
                    .toList() ??
                <String>[];
            if (medicationIds.isEmpty) {
              print('DEBUG: AVISO: medicationIds está vazio no ValueListenableBuilder, redirecionando para WelcomeScreen');
              return WelcomeScreen(
                database: widget.database,
                notificationService: widget.notificationService,
              );
            }
            print('DEBUG: Definindo MedicationAlertScreen como tela inicial com horario=$horario, medicationIds=$medicationIds');
            final rootIsolateToken = RootIsolateToken.instance;
            if (rootIsolateToken == null) {
              print('DEBUG: ERRO: RootIsolateToken.instance retornou null no ValueListenableBuilder');
              throw Exception('RootIsolateToken.instance retornou null. Verifique a versão do Flutter ou o contexto da aplicação.');
            }
            return MedicationAlertScreen(
              horario: horario,
              medicationIds: medicationIds,
              database: widget.database,
              notificationService: widget.notificationService,
              rootIsolateToken: rootIsolateToken,
            );
          }
          print('DEBUG: Nenhuma rota especial, definindo WelcomeScreen como tela inicial.');
          return WelcomeScreen(
            database: widget.database,
            notificationService: widget.notificationService,
          );
        },
      ),
      onGenerateRoute: (settings) {
        print('DEBUG: Gerando rota para: ${settings.name}, argumentos: ${settings.arguments}');

        if (settings.name == 'medication_alert') {
          final args = settings.arguments as Map<String, dynamic>? ?? {};
          final horario = args['horario'] as String? ?? '08:00';
          final medicationIds = (args['medicationIds'] as List<dynamic>?)
                  ?.map((e) => e.toString())
                  .toList() ??
              <String>[];
          if (medicationIds.isEmpty) {
            print('DEBUG: AVISO: medicationIds está vazio em onGenerateRoute, redirecionando para WelcomeScreen');
            return MaterialPageRoute(
              builder: (context) => WelcomeScreen(
                database: widget.database,
                notificationService: widget.notificationService,
              ),
            );
          }
          final rootIsolateToken = RootIsolateToken.instance;
          if (rootIsolateToken == null) {
            print('DEBUG: ERRO: RootIsolateToken.instance retornou null em onGenerateRoute');
            throw Exception('RootIsolateToken.instance retornou null. Verifique a versão do Flutter ou o contexto da aplicação.');
          }
          print('DEBUG: Construindo MedicationAlertScreen via onGenerateRoute com horario=$horario, medicationIds=$medicationIds, rootIsolateToken=$rootIsolateToken');
          return MaterialPageRoute(
            builder: (context) => MedicationAlertScreen(
              horario: horario,
              medicationIds: medicationIds,
              database: widget.database,
              notificationService: widget.notificationService,
              rootIsolateToken: rootIsolateToken,
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

  @override
  void dispose() {
    routeDataNotifier.dispose();
    super.dispose();
  }
}