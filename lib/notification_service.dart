import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:sqflite/sqflite.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'screens/medication_alert_screen.dart'; // Importa da subpasta screens/
import 'package:workmanager/workmanager.dart';

const String taskName = 'medication_notification_task';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    print('DEBUG: Executando tarefa Workmanager: $task');
    final notificationService = NotificationService();
    await notificationService.init(inputData!['database'] as Database);
    await notificationService.showNotification(
      id: inputData['id'] as int,
      title: inputData['title'] as String,
      body: inputData['body'] as String,
      sound: 'alarm',
      payload: inputData['payload'] as String,
    );
    return Future.value(true);
  });
}

Future<void> scheduleWorkmanagerNotification({
  required int id,
  required String title,
  required String body,
  required String payload,
  required DateTime scheduledTime,
  required Database database,
}) async {
  await Workmanager().registerOneOffTask(
    '$id',
    taskName,
    inputData: {
      'id': id,
      'title': title,
      'body': body,
      'payload': payload,
      'database': database,
    },
    initialDelay: scheduledTime.difference(DateTime.now()),
    existingWorkPolicy: ExistingWorkPolicy.replace,
  );
  print('DEBUG: Tarefa Workmanager agendada para $scheduledTime');
}

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
            final medication = await _database!.query(
              'medications',
              where: 'id = ?',
              whereArgs: [response.payload],
            );

            if (medication.isNotEmpty) {
              final nome = medication[0]['nome'] as String;
              final dosagemDiaria = medication[0]['dosagem_diaria'] as int;
              final horarios = (medication[0]['horarios'] as String).split(',');
              final dosePorAlarme = dosagemDiaria / horarios.length;
              final fotoPath = medication[0]['foto_embalagem'] as String? ?? '';
              final notificationId = response.id ?? 0;
              final horarioIndex = notificationId % horarios.length;
              final horario = horarios[horarioIndex];

              print('DEBUG: Navegando para MedicationAlertScreen com medicationId: ${response.payload}');
              navigatorKey.currentState?.push(
                MaterialPageRoute(
                  builder: (context) => MedicationAlertScreen(
                    medicationId: response.payload!,
                    nome: nome,
                    dose: dosePorAlarme.toString(),
                    fotoPath: fotoPath,
                    horario: horario,
                    database: _database!,
                  ),
                ),
              );
            }
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
        // Criar canal medication_channel
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
        print('DEBUG: Canal de notificação medication_channel criado');

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
    String? sound,
    required String payload,
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
        'medication_channel',
        'Lembrete de Medicamento',
        channelDescription: 'Notificações para lembretes de medicamentos',
        importance: Importance.max,
        priority: Priority.max,
        sound: sound != null ? RawResourceAndroidNotificationSound(sound) : null,
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

      print('DEBUG: Usando androidScheduleMode: alarmClock');
      await _notificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        tz.TZDateTime.from(scheduledTime, tz.getLocation('America/Sao_Paulo')),
        notificationDetails,
        payload: payload,
        androidScheduleMode: AndroidScheduleMode.alarmClock,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      );

      print('DEBUG: Notificação agendada com sucesso');
      
      // Verificar notificações pendentes
      final pendingNotifications = await _notificationsPlugin.pendingNotificationRequests();
      print('DEBUG: Notificações pendentes: ${pendingNotifications.length}');
      for (var notification in pendingNotifications) {
        print('DEBUG: Notificação pendente - ID: ${notification.id}, Title: ${notification.title}');
      }
    } catch (e) {
      print('DEBUG: Erro ao agendar notificação: $e');
    }
    // Verificar notificações pendentes após 60 segundos
    Future.delayed(Duration(seconds: 60), () async {
      final pendingNotifications = await _notificationsPlugin.pendingNotificationRequests();
      print('DEBUG: Notificações pendentes após 60 segundos: ${pendingNotifications.length}');
      for (var notification in pendingNotifications) {
        print('DEBUG: Notificação pendente após 60 segundos - ID: ${notification.id}, Title: ${notification.title}');
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
}
