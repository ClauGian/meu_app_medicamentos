import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:firebase_core/firebase_core.dart';
import 'screens/welcome_screen.dart';
import 'screens/medication_alert_screen.dart';
import 'notification_service.dart';
import 'database_helper.dart';
import 'screens/loading_screen.dart'; // ADICIONAR


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Log crítico para confirmar que Flutter está executando
  debugPrint('═══════════════════════════════════════');
  debugPrint('DEBUG: FLUTTER MAIN INICIADO');
  debugPrint('═══════════════════════════════════════');

  final startTime = DateTime.now().millisecondsSinceEpoch;

  // Inicializar o Database
  final databaseHelper = DatabaseHelper();
  final sqflite.Database database = await databaseHelper.database;
  print('DEBUG: Database inicializado - Elapsed: ${DateTime.now().millisecondsSinceEpoch - startTime}ms');

  // Inicializar o NotificationService
  final NotificationService notificationService = NotificationService();
  try {
    await notificationService.init(database);
    print('DEBUG: NotificationService.init concluído - Elapsed: ${DateTime.now().millisecondsSinceEpoch - startTime}ms');
  } catch (e) {
    print('DEBUG: ERRO ao inicializar NotificationService: $e');
    print('DEBUG: Continuando mesmo com erro...');
    // Continuar mesmo com erro para não travar o app
  }

  try {
    await Firebase.initializeApp();
    print('DEBUG: Firebase inicializado - Elapsed: ${DateTime.now().millisecondsSinceEpoch - startTime}ms');

  // NÃO buscar dados aqui, deixar o Android fornecer
    print('DEBUG: Pulando getInitialRouteData no main()');

    runApp(MyApp(
      database: database,
      notificationService: notificationService,
      initialRoute: '/loading', // Começar com loading
      initialRouteData: null, // Será buscado depois
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
    print('DEBUG: initState do _MyAppState chamado');
    
    // Configurar MethodChannel handler para receber navegação do Android
    const platform = MethodChannel('com.claudinei.medialerta/navigation');
    platform.setMethodCallHandler((call) async {
      print('DEBUG: MethodChannel recebeu chamada: ${call.method}');
      
      if (call.method == 'navigateToMedicationAlert') {
        final args = call.arguments as Map;
        print('DEBUG: Navegando para MedicationAlertScreen via MethodChannel com args=$args');

        final navigator = NotificationService.navigatorKey.currentState;
        if (navigator == null || !navigator.mounted) {
          print('DEBUG: Navigator não disponível no MethodChannel handler');
          return null;
        }

        final horario = args['horario'] as String? ?? '08:00';
        final medicationIds = (args['medicationIds'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ?? <String>[];
        final rootIsolateToken = RootIsolateToken.instance;

        if (rootIsolateToken == null) {
          print('DEBUG: ERRO: RootIsolateToken.instance retornou null');
          return null;
        }

        print('DEBUG: Executando navegação via MethodChannel');

        navigator.pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => MedicationAlertScreen(
              horario: horario,
              medicationIds: medicationIds,
              database: widget.database,
              notificationService: widget.notificationService,
              rootIsolateToken: rootIsolateToken,
            ),
            transitionDuration: Duration.zero,
            reverseTransitionDuration: Duration.zero,
          ),
        );
        
        print('DEBUG: Navegação via MethodChannel concluída');
      }
      return null;
    });
    
    // Aguardar 500ms antes de buscar dados iniciais
    Future.delayed(const Duration(milliseconds: 500), () async {
      print('DEBUG: Delay concluído, buscando dados do Android');
      
      try {
        final result = await platform.invokeMethod('getInitialRoute');
        
        print('DEBUG: Dados recebidos do Android: $result');
        
        if (result != null && result is Map) {
          final routeData = Map<String, dynamic>.from(result);
          
          if (routeData['route'] == 'medication_alert') {
            final navigator = NotificationService.navigatorKey.currentState;
            
            if (navigator != null && navigator.mounted) {
              final horario = routeData['horario'] as String? ?? '08:00';
              final medicationIds = (routeData['medicationIds'] as List<dynamic>?)
                  ?.map((e) => e.toString())
                  .toList() ?? <String>[];
              final rootIsolateToken = RootIsolateToken.instance;

              if (rootIsolateToken == null) {
                print('DEBUG: ERRO: RootIsolateToken.instance retornou null');
                return;
              }

              print('DEBUG: Navegando para MedicationAlertScreen com horario=$horario, ids=$medicationIds');

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
              
              print('DEBUG: Navegação concluída');
            } else {
              print('DEBUG: Navigator não disponível');
            }
          } else {
            print('DEBUG: Rota não é medication_alert, ignorando navegação');
          }
        } else {
          print('DEBUG: Nenhum dado de rota recebido do Android');
        }
      } catch (e) {
        print('DEBUG: Erro ao buscar dados do Android: $e');
      }
    });
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

    // Rota de loading
    if (normalizedRoute == 'loading') {
      print('DEBUG: Rotas iniciais: /loading');
      return [
        MaterialPageRoute(
          builder: (context) => LoadingScreen(
            database: widget.database,
            notificationService: widget.notificationService,
          ),
          settings: const RouteSettings(name: '/loading'),
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
    debugPrint('═══════════════════════════════════════');
    debugPrint('DEBUG: MYAPP BUILD CHAMADO');
    debugPrint('═══════════════════════════════════════');
    
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