import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import '../notification_service.dart'; // Adicionado
import 'medication_list_screen.dart';
import 'medication_registration_screen.dart';
import 'instructions_screen.dart';
import 'daily_alerts_screen.dart';
import 'alert_sound_selection_screen.dart';

class HomeScreen extends StatefulWidget {
  final Database database;
  final NotificationService notificationService; // Novo parâmetro

  const HomeScreen({
    super.key,
    required this.database,
    required this.notificationService,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFCCCCCC),
      appBar: AppBar(
        toolbarHeight: 120,
        leadingWidth: 100,         // espaço extra para a hitbox do ícone
        titleSpacing: 0,           // evita deslocamentos automáticos do título
        backgroundColor: const Color(0xFFCCCCCC),
        elevation: 0,
        leading: Builder(
          builder: (context) => Padding(
            padding: const EdgeInsets.only(top: 20.0, left: 16.0),
            child: Container(
              decoration: const BoxDecoration(
                color: Color.fromRGBO(0, 105, 148, 1), // azul do app
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.menu, size: 40, color: Colors.white),
                onPressed: () => Scaffold.of(context).openDrawer(),
                padding: EdgeInsets.zero, // remove o padding interno
                constraints: const BoxConstraints( // define tamanho exato do círculo
                  minWidth: 60,
                  minHeight: 60,
                ),
              ),
            ),
          ),
        ),

        title: Padding(
          // deixamos apenas um pequeno left aqui porque já controlamos leadingWidth
          padding: const EdgeInsets.only(top: 22.0, left: 8.0),
          child: Align(
            alignment: Alignment.centerLeft, // garante alinhamento à esquerda da área do title
            child: RichText(
              text: const TextSpan(
                children: [
                  TextSpan(
                    text: 'Medi',
                    style: TextStyle(
                      color: Color.fromRGBO(0, 105, 148, 1),
                      fontSize: 45,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextSpan(
                    text: 'Alerta',
                    style: TextStyle(
                      color: Color.fromRGBO(85, 170, 85, 1),
                      fontSize: 45,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      drawer: Drawer(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            topRight: Radius.zero,
            bottomRight: Radius.circular(30),
          ),
        ),
        backgroundColor: const Color(0xFFF0F8F0),
        child: Column(
          children: [
            SafeArea(
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color.fromRGBO(0, 105, 148, 1),
                      Color.fromRGBO(85, 170, 85, 1),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.only(top: 10.0, bottom: 12.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white, size: 32),
                        onPressed: () {
                          Navigator.pop(context); // Volta à Home
                        },
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'MediAlerta',
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(12.0),
                children: [
                  _buildMenuCard(Icons.medical_services, 'Cadastrar Medicamentos', () {
                    Navigator.push(context, MaterialPageRoute(
                      builder: (context) => MedicationRegistrationScreen(
                        database: widget.database,
                        notificationService: widget.notificationService, // Corrigido
                      ),
                    ));
                  }),
                  _buildMenuCard(Icons.alarm_add, 'Cadastrar Alertas', () {
                    Navigator.push(context, MaterialPageRoute(
                      builder: (context) => const AlertSoundSelectionScreen(),
                    ));
                  }),
                  _buildMenuCard(Icons.list_alt, 'Lista de Medicamentos', () {
                    Navigator.push(context, MaterialPageRoute(
                      builder: (context) => MedicationListScreen(
                        database: widget.database,
                        notificationService: widget.notificationService,
                      ),
                    ));
                  }),
                  _buildMenuCard(Icons.today, 'Alertas do Dia', () {
                    Navigator.push(context, MaterialPageRoute(
                      builder: (context) => DailyAlertsScreen(
                        database: widget.database,
                        notificationService: widget.notificationService,
                      ),
                    ));
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              
              const Text(
                'Home',
                textAlign: TextAlign.left,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue, // troque para a cor que preferir
                ),
              ),

              const SizedBox(height: 40), // distância entre "Home" e "Bem-vindo ao"

              RichText(
                textAlign: TextAlign.center,
                text: const TextSpan(
                  children: [
                    TextSpan(
                      text: 'Bem-vindo ao ',
                      style: TextStyle(
                        color: Color.fromRGBO(0, 105, 148, 1),
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        height: 1.5,
                      ),
                    ),
                    TextSpan(
                      text: 'Medi',
                      style: TextStyle(
                        color: Color.fromRGBO(0, 105, 148, 1),
                        fontSize: 42,
                        fontWeight: FontWeight.bold,
                        height: 1.5,
                      ),
                    ),
                    TextSpan(
                      text: 'Alerta!',
                      style: TextStyle(
                        color: Color.fromRGBO(85, 170, 85, 1),
                        fontSize: 42,
                        fontWeight: FontWeight.bold,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 50),

              RichText(
                textAlign: TextAlign.center,
                text: const TextSpan(
                  style: TextStyle(
                    color: Color.fromRGBO(0, 105, 148, 1),
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  children: [
                    TextSpan(
                      text:
                          'Para aproveitar melhor todas as funções do MediAlerta, toque no botão abaixo e veja o Guia do App.',
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 80),

              Center(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const InstructionsScreen(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color.fromRGBO(0, 105, 148, 1),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 40,
                      vertical: 15,
                    ),
                  ),
                  child: const Text(
                    'Guia do App',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuCard(IconData icon, String title, VoidCallback onTap) {
    return Container(
      height: 80,
      margin: const EdgeInsets.only(bottom: 12.0),
      padding: const EdgeInsets.symmetric(horizontal: 12.0),
      decoration: BoxDecoration(
        color: const Color.fromRGBO(85, 170, 85, 0.15),
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: Center(
        child: ListTile(
          leading: Icon(icon, size: 28, color: const Color.fromRGBO(85, 170, 85, 1)),
          title: Text(
            title,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color.fromRGBO(0, 85, 128, 1),
              height: 1.1,
            ),
          ),
          onTap: onTap,
          contentPadding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 0.0),
          horizontalTitleGap: 12,
          dense: true,
        ),
      ),
    );
  }
}