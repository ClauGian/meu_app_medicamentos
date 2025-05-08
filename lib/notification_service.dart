import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:sqflite/sqflite.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'screens/medication_alert_screen.dart'; // Importa da subpasta screens/


class NotificationService {
  static final NotificationService _notificationService = NotificationService._internal();
  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  Database? _database;
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>(); // Chave para navegação

  factory NotificationService() {
    return _notificationService;
  }

  NotificationService._internal();

  Future<void> init(Database db) async {
    print('DEBUG: Iniciando NotificationService');
    _database = db;

    try {
      tz.initializeTimeZones();
      print('DEBUG: Timezones inicializados');

      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      const InitializationSettings initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid,
      );

      bool? initialized = await _notificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) async {
          print('DEBUG: Notificação recebida - ID: ${response.id}, Payload: ${response.payload}, Action: ${response.actionId}');
          if (response.payload != null && _database != null) {
            try {
              print('DEBUG: Processando payload: ${response.payload}');
              final payloadParts = response.payload!.split('|');
              if (payloadParts.length >= 2) {
                // Novo formato: "horario|id1,id2,id3"
                final horario = payloadParts[0]; // Ex.: "08:00"
                final medicationIds = payloadParts[1].split(','); // Ex.: ["1", "2", "3"]
                print('DEBUG: Navegando para MedicationAlertScreen com horario: $horario, medicationIds: $medicationIds');
                final navigatorState = navigatorKey.currentState;
                if (navigatorState != null) {
                  await navigatorState.push(
                    MaterialPageRoute(
                      builder: (context) => MedicationAlertScreen(
                        horario: horario,
                        medicationIds: medicationIds,
                        database: _database!,
                      ),
                    ),
                  );
                  print('DEBUG: Navegação concluída');
                } else {
                  print('DEBUG: ERRO: NavigatorState é nulo, navegação não realizada');
                }
              } else {
                // Compatibilidade com payloads antigos (um único ID)
                print('DEBUG: Payload antigo detectado, consultando medicamento com ID: ${response.payload}');
                final medication = await _database!.query(
                  'medications',
                  where: 'id = ?',
                  whereArgs: [response.payload],
                );

                if (medication.isNotEmpty) {
                  print('DEBUG: Medicamento encontrado: $medication');
                  final nome = medication[0]['nome'] as String;
                  final dosagemDiaria = medication[0]['dosagem_diaria'] as int;
                  final horarios = (medication[0]['horarios'] as String).split(',');
                  final dosePorAlarme = dosagemDiaria / horarios.length;
                  final fotoPath = medication[0]['foto_embalagem'] as String? ?? '';
                  final notificationId = response.id ?? 0;
                  final horarioIndex = notificationId % horarios.length;
                  final horario = horarios[horarioIndex];

                  print('DEBUG: Preparando navegação para MedicationAlertScreen com medicationId: ${response.payload}');
                  final navigatorState = navigatorKey.currentState;
                  if (navigatorState != null) {
                    await navigatorState.push(
                      MaterialPageRoute(
                        builder: (context) => MedicationAlertScreen(
                          horario: horario,
                          medicationIds: [response.payload!], // Compatibilidade com um único ID
                          database: _database!,
                        ),
                      ),
                    );
                    print('DEBUG: Navegação concluída');
                  } else {
                    print('DEBUG: ERRO: NavigatorState é nulo, navegação não realizada');
                  }
                } else {
                  print('DEBUG: ERRO: Nenhum medicamento encontrado para ID: ${response.payload}');
                }
              }
            } catch (e) {
              print('DEBUG: ERRO ao processar notificação: $e');
            }
          } else {
            print('DEBUG: ERRO: Payload ou database nulo - Payload: ${response.payload}, Database: ${_database != null}');
          }
        },
      );
      print('DEBUG: FlutterLocalNotificationsPlugin inicializado: $initialized');
      if (initialized != true) {
        print('DEBUG: Falha ao inicializar FlutterLocalNotificationsPlugin');
        return;
      }

      final androidPlugin = _notificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        // Criar canal para notificações imediatas
        await androidPlugin.createNotificationChannel(
          const AndroidNotificationChannel(
            'medication_channel',
            'Lembrete de Medicamento',
            description: 'Notificações para lembretes de medicamentos',
            importance: Importance.max,
            playSound: true,
            sound: RawResourceAndroidNotificationSound('alarm'),
            enableVibration: true,
            enableLights: true,
          ),
        );
        // Criar canal para notificações agendadas
        await androidPlugin.createNotificationChannel(
          const AndroidNotificationChannel(
            'scheduled_medication_channel',
            'Lembrete Agendado de Medicamento',
            description: 'Notificações agendadas para lembretes de medicamentos',
            importance: Importance.max,
            playSound: true,
            showBadge: true,
            enableVibration: true,
            enableLights: true,
          ),
        );
        print('DEBUG: Canais de notificação medication_channel e scheduled_medication_channel criados');

        // Verificar e solicitar permissões
        bool? notificationsGranted = await androidPlugin.requestNotificationsPermission();
        print('DEBUG: Permissão de notificação concedida: $notificationsGranted');
        if (notificationsGranted == null || !notificationsGranted) {
          print('DEBUG: Permissão de notificação não concedida');
          return;
        }

        bool? exactAlarmsGranted = await androidPlugin.requestExactAlarmsPermission();
        print('DEBUG: Permissão de alarme exato concedida: $exactAlarmsGranted');
        if (exactAlarmsGranted == null || !exactAlarmsGranted) {
          print('DEBUG: Permissão de alarme exato não concedida');
          return;
        }
      } else {
        print('DEBUG: AndroidFlutterLocalNotificationsPlugin não encontrado');
        return;
      }

      print('DEBUG: NotificationService inicializado com sucesso');
    } catch (e) {
      print('DEBUG: Erro ao inicializar NotificationService: $e');
    }
  }


  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    required String sound,
    required String payload,
  }) async {
    print('DEBUG: Exibindo notificação com id: $id, title: $title, sound: $sound');
    try {
      final androidDetails = AndroidNotificationDetails(
        'medication_channel',
        'Lembrete de Medicamento',
        channelDescription: 'Notificações para lembretes de medicamentos',
        importance: Importance.max,
        priority: Priority.max,
        sound: RawResourceAndroidNotificationSound(sound), // Removido sound != null, pois é required
        playSound: true,
        showWhen: true,
        visibility: NotificationVisibility.public,
        enableVibration: true,
        enableLights: true,
        autoCancel: true, // Desaparece após clique
        ongoing: false,
        groupKey: 'medication_group_$id',
        ticker: 'Lembrete de Medicamento',
      );
      final notificationDetails = NotificationDetails(android: androidDetails);

      await _notificationsPlugin.show(
        id,
        title,
        body,
        notificationDetails,
        payload: payload,
      );
      print('DEBUG: Notificação exibida com sucesso');
    } catch (e) {
      print('DEBUG: Erro ao exibir notificação: $e');
    }
  }

  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required String payload, // Substitui medicationId por payload
    required String sound,
    required DateTime scheduledTime,
  }) async {
    final now = DateTime.now();
    print('DEBUG: Agendando notificação com id: $id, title: $title, sound: $sound, scheduledTime: $scheduledTime');
    print('DEBUG: Horário atual do dispositivo: $now');
    print('DEBUG: Diferença de tempo (scheduledTime - now): ${scheduledTime.difference(now).inSeconds} segundos');
    if (scheduledTime.isBefore(now)) {
      print('DEBUG: ERRO: scheduledTime está no passado! Notificação não será agendada.');
      return;
    }
    print('DEBUG: Fuso horário: America/Sao_Paulo, TZDateTime: ${tz.TZDateTime.from(scheduledTime, tz.getLocation('America/Sao_Paulo'))}');
    try {
      // Verificar permissão de alarme exato
      final androidPlugin = _notificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        bool? exactAlarmsGranted = await androidPlugin.requestExactAlarmsPermission();
        print('DEBUG: Permissão de alarme exato concedida: $exactAlarmsGranted');
        if (exactAlarmsGranted == null || !exactAlarmsGranted) {
          print('DEBUG: Falha na permissão de alarme exato, notificação pode não ser agendada');
          return;
        }
      }

      final androidDetails = AndroidNotificationDetails(
        'medication_channel', // Usar o mesmo canal das notificações imediatas
        'Lembrete de Medicamento',
        channelDescription: 'Notificações para lembretes de medicamentos',
        importance: Importance.max,
        priority: Priority.max,
        sound: RawResourceAndroidNotificationSound('alarm'),
        playSound: true,
        showWhen: true,
        visibility: NotificationVisibility.public,
        enableVibration: true,
        enableLights: true,
        autoCancel: false,
        ongoing: false,
        groupKey: 'medication_group_$id',
        ticker: 'Lembrete de Medicamento',
      );

      final notificationDetails = NotificationDetails(
        android: androidDetails,
      );

      print('DEBUG: Usando androidScheduleMode: exactAllowWhileIdle');
      await _notificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        tz.TZDateTime.from(scheduledTime, tz.getLocation('America/Sao_Paulo')),
        notificationDetails,
        payload: payload,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      );

      print('DEBUG: Notificação agendada com sucesso');
      
      // Verificar notificações pendentes
      final pendingNotifications = await _notificationsPlugin.pendingNotificationRequests();
      print('DEBUG: Notificações pendentes: ${pendingNotifications.length}');
      for (var notification in pendingNotifications) {
        print('DEBUG: Notificação pendente - ID: ${notification.id}, Title: ${notification.title}, Payload: ${notification.payload}');
      }
    } catch (e) {
      print('DEBUG: Erro ao agendar notificação: $e');
      rethrow; // Para capturar erros no console
    }
    // Verificar notificações pendentes após 90 segundos
    Future.delayed(Duration(seconds: 90), () async {
      final pendingNotifications = await _notificationsPlugin.pendingNotificationRequests();
      print('DEBUG: Notificações pendentes após 90 segundos: ${pendingNotifications.length}');
      for (var notification in pendingNotifications) {
        print('DEBUG: Notificação pendente após 90 segundos - ID: ${notification.id}, Title: ${notification.title}, Payload: ${notification.payload}');
      }
    });
  }

  Future<void> cancelAllNotifications() async {
    print('DEBUG: Cancelando todas as notificações pendentes');
    try {
      await _notificationsPlugin.cancelAll();
      print('DEBUG: Todas as notificações canceladas com sucesso');
    } catch (e) {
      print('DEBUG: Erro ao cancelar notificações: $e');
    }
  }

  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    return await _notificationsPlugin.pendingNotificationRequests();
  }

}

