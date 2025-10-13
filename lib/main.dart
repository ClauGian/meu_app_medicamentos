import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:firebase_core/firebase_core.dart';
import 'screens/welcome_screen.dart';
import 'screens/medication_alert_screen.dart';
import 'notification_service.dart';
import 'database_helper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  print('DEBUG: Iniciando main');

  final startTime = DateTime.now().millisecondsSinceEpoch;

  // Inicializar o Database
  final databaseHelper = DatabaseHelper();
  final sqflite.Database database = await databaseHelper.database;
  print('DEBUG: Database inicializado - Elapsed: ${DateTime.now().millisecondsSinceEpoch - startTime}ms');

  // Inicializar o NotificationService
  final NotificationService notificationService = NotificationService();
  await notificationService.init(database);
  print('DEBUG: NotificationService.init concluído - Elapsed: ${DateTime.now().millisecondsSinceEpoch - startTime}ms');

  // Configurar o MethodChannel handler
  const MethodChannel('com.claudinei.medialerta/navigation').setMethodCallHandler((call) async {
    if (call.method == 'navigateToMedicationAlert') {
      final args = call.arguments as Map;
      print('DEBUG: Navegando para MedicationAlertScreen via MethodChannel com args=$args');

      final navigator = NotificationService.navigatorKey.currentState;
      if (navigator == null || !navigator.mounted) {
        print('DEBUG: Navigator não disponível, será tratado pelo onGenerateRoute');
        return null;
      }

      final horario = args['horario'] as String? ?? '08:00';
      final medicationIds = (args['medicationIds'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? <String>[];

      final rootIsolateToken = RootIsolateToken.instance;
      if (rootIsolateToken == null) {
        print('DEBUG: ERRO: RootIsolateToken.instance retornou null');
        return null;
      }

      navigator.pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => MedicationAlertScreen(
            horario: horario,
            medicationIds: medicationIds,
            database: database,
            notificationService: notificationService,
            rootIsolateToken: rootIsolateToken,
          ),
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
        ),
      );
      print('DEBUG: Navegação substituída para MedicationAlertScreen concluída');
    }
    return null;
  });

  try {
    await Firebase.initializeApp();
    print('DEBUG: Firebase inicializado - Elapsed: ${DateTime.now().millisecondsSinceEpoch - startTime}ms');

    // Obter dados de rota inicial
    final routeData = await notificationService.getInitialRouteData();
    print('DEBUG: initialRouteData obtida: $routeData');
    final initialRoute = routeData != null && routeData['route'] == 'medication_alert' ? '/medication_alert' : '/welcome';
    print('DEBUG: Rota inicial determinada: $initialRoute');

    runApp(MyApp(
      database: database,
      notificationService: notificationService,
      initialRoute: initialRoute,
      initialRouteData: routeData, // Passar os dados diretamente
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
  final String initialRoute;
  final Map<String, dynamic>? initialRouteData; // Nova propriedade para os dados de rota

  const MyApp({
    super.key,
    required this.database,
    required this.notificationService,
    required this.initialRoute,
    this.initialRouteData,
  });

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    // Configurar navegação assíncrona, se necessário
    if (widget.initialRoute == '/medication_alert' && widget.initialRouteData != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final navigator = NotificationService.navigatorKey.currentState;
        if (navigator != null && navigator.mounted) {
          final routeData = widget.initialRouteData!;
          final horario = routeData['horario'] as String? ?? '08:00';
          final medicationIds = (routeData['medicationIds'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? <String>[];
          final rootIsolateToken = RootIsolateToken.instance;

          if (rootIsolateToken == null) {
            print('DEBUG: ERRO: RootIsolateToken.instance retornou null');
            return;
          }

          navigator.pushReplacement(
            MaterialPageRoute(
              builder: (context) => MedicationAlertScreen(
                horario: horario,
                medicationIds: medicationIds,
                database: widget.database,
                notificationService: widget.notificationService,
                rootIsolateToken: rootIsolateToken,
              ),
            ),
          );
          print('DEBUG: Navegação substituída para MedicationAlertScreen via Navigator');
        } else {
          print('DEBUG: Navigator não disponível após inicialização');
        }
      });
    }
  }


  List<Route<dynamic>> _generateInitialRoutes(String initialRoute) {
    print('DEBUG: Gerando rotas iniciais para: $initialRoute, initialRouteData: ${widget.initialRouteData}');

    // Normalizar initialRoute removendo / inicial se presente
    final normalizedRoute = initialRoute.startsWith('/') ? initialRoute.substring(1) : initialRoute;

    if (normalizedRoute == 'medication_alert' && widget.initialRouteData != null) {
      print('DEBUG: Condição para medication_alert atendida');
      final routeData = widget.initialRouteData!;
      final horario = routeData['horario'] as String? ?? '08:00';
      final medicationIds = (routeData['medicationIds'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? <String>[];
      final rootIsolateToken = RootIsolateToken.instance;

      if (rootIsolateToken == null) {
        print('DEBUG: ERRO: RootIsolateToken.instance retornou null em _generateInitialRoutes');
        return [
          MaterialPageRoute(
            builder: (context) => const Scaffold(body: Center(child: Text('Erro: RootIsolateToken nulo'))),
          )
        ];
      }

      print('DEBUG: Gerando rota inicial para MedicationAlertScreen com horario=$horario, medicationIds=$medicationIds');
      return [
        MaterialPageRoute(
          builder: (context) => MedicationAlertScreen(
            horario: horario,
            medicationIds: medicationIds,
            database: widget.database,
            notificationService: widget.notificationService,
            rootIsolateToken: rootIsolateToken,
          ),
          settings: const RouteSettings(name: '/medication_alert'),
        )
      ];
    }

    // Rota padrão: WelcomeScreen
    print('DEBUG: Rotas iniciais padrão: /welcome');
    return [
      MaterialPageRoute(
        builder: (context) => WelcomeScreen(
          database: widget.database,
          notificationService: widget.notificationService,
        ),
        settings: const RouteSettings(name: '/welcome'),
      )
    ];
  }



  @override
  Widget build(BuildContext context) {
    print('DEBUG: Construindo MyApp - Configurando MaterialApp');
    return MaterialApp(
      navigatorKey: NotificationService.navigatorKey,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      initialRoute: widget.initialRoute,
      onGenerateInitialRoutes: _generateInitialRoutes,
      onGenerateRoute: (settings) {
        print('DEBUG: Gerando rota para: ${settings.name}, argumentos: ${settings.arguments}');

        if (settings.name == '/medication_alert' && widget.initialRouteData != null) {
          final routeData = widget.initialRouteData!;
          if (routeData['route'] == 'medication_alert') {
            final horario = routeData['horario'] as String? ?? '08:00';
            final medicationIds = (routeData['medicationIds'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? <String>[];
            final rootIsolateToken = RootIsolateToken.instance;

            if (rootIsolateToken == null) {
              print('DEBUG: ERRO: RootIsolateToken.instance retornou null');
              return MaterialPageRoute(
                builder: (context) => const Scaffold(body: Center(child: Text('Erro: RootIsolateToken nulo'))),
              );
            }

            print('DEBUG: Construindo MedicationAlertScreen com horario=$horario, medicationIds=$medicationIds');
            return MaterialPageRoute(
              builder: (context) => MedicationAlertScreen(
                horario: horario,
                medicationIds: medicationIds,
                database: widget.database,
                notificationService: widget.notificationService,
                rootIsolateToken: rootIsolateToken,
              ),
              settings: settings,
            );
          }
        }

        // Evitar renderizar WelcomeScreen imediatamente, retornando um placeholder temporário
        print('DEBUG: Rota não é /medication_alert ou initialRouteData nulo, retornando placeholder');
        return MaterialPageRoute(
          builder: (context) => const SizedBox.shrink(), // Placeholder vazio até a navegação ser processada
          settings: const RouteSettings(name: '/placeholder'),
        );
      },
    );
  }
}