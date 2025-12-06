import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // ADICIONAR
import 'package:sqflite/sqflite.dart';
import 'home_screen.dart';
import 'medication_alert_screen.dart'; // ADICIONAR
import '../notification_service.dart';


class WelcomeScreen extends StatefulWidget {
  final Database database;
  final NotificationService notificationService;

  const WelcomeScreen({
    super.key,
    required this.database,
    required this.notificationService,
  });

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {


  @override
  void initState() {
    super.initState();
    print('DEBUG: WelcomeScreen initState chamado');
    
    // Verificar se há dados de notificação pendentes
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      print('DEBUG: WelcomeScreen verificando dados de notificação');
      
      try {
        final routeData = await widget.notificationService.getInitialRouteData();
        print('DEBUG: WelcomeScreen recebeu routeData: $routeData');
        
        if (routeData != null && routeData['route'] == 'medication_alert') {
          if (!mounted) return;
          
          final horario = routeData['horario'] as String? ?? '08:00';
          final medicationIds = (routeData['medicationIds'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ?? <String>[];
          
          print('DEBUG: WelcomeScreen navegando para MedicationAlert com horario=$horario, ids=$medicationIds');
          
          // Importar necessário no topo do arquivo
          final rootIsolateToken = RootIsolateToken.instance;
          if (rootIsolateToken == null) {
            print('DEBUG: ERRO: RootIsolateToken.instance retornou null');
            return;
          }
          
          // Importar MedicationAlertScreen
          Navigator.of(context).pushReplacement(
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
          
          print('DEBUG: WelcomeScreen navegação concluída');
        } else {
          print('DEBUG: WelcomeScreen sem dados de notificação, permanecendo na tela');
        }
      } catch (e) {
        print('DEBUG: WelcomeScreen erro ao verificar notificação: $e');
      }
    });
  }


 
  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) async {
        if (!didPop) {
          // Mover app para background em vez de fechar
          SystemChannels.platform.invokeMethod('SystemNavigator.pop');
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFCCCCCC),
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 40),
                RichText(
                  text: const TextSpan(
                    children: [
                      TextSpan(
                        text: 'Medi',
                        style: TextStyle(
                          color: Color.fromRGBO(0, 105, 148, 1),
                          fontSize: 56,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextSpan(
                        text: 'Alerta',
                        style: TextStyle(
                          color: Color.fromRGBO(85, 170, 85, 1),
                          fontSize: 56,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),
                Image.asset(
                  'assets/imagem_senhora.png',
                  height: MediaQuery.of(context).size.height * 0.40,
                  errorBuilder: (context, error, stackTrace) {
                    print('DEBUG: Erro ao carregar asset: $error');
                    return const Icon(
                      Icons.error,
                      size: 150,
                      color: Colors.red,
                    );
                  },
                ),
                const SizedBox(height: 30),
                const Text(
                  'Seu remédio na hora certa.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color.fromRGBO(0, 85, 128, 1),
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 60),
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => HomeScreen(
                          database: widget.database,
                          notificationService: widget.notificationService,
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color.fromRGBO(0, 105, 148, 1),
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                  ),
                  child: const Text(
                    "Começar",
                    style: TextStyle(fontSize: 24, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}