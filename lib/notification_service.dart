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
    _database = db;

    tz.initializeTimeZones();

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );

    await _notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
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

            // Navegar para MedicationAlertScreen
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
    final androidPlugin = _notificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      bool? granted = await androidPlugin.requestNotificationsPermission();
      print('Permissão de notificação concedida: $granted');
    }
  }

  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    required String sound,
    required String payload,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      'medication_channel',
      'Lembrete de Medicamento',
      importance: Importance.high,
      priority: Priority.high,
      sound: RawResourceAndroidNotificationSound(sound),
    );

    final notificationDetails = NotificationDetails(
      android: androidDetails,
    );

    await _notificationsPlugin.show(
      id,
      title,
      body,
      notificationDetails,
      payload: payload,
    );
  }

  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    String? sound,
    required String payload,
    required DateTime scheduledTime,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      'medication_channel',
      'Lembrete de Medicamento',
      importance: Importance.high,
      priority: Priority.high,
      sound: sound != null ? RawResourceAndroidNotificationSound(sound) : null,
    );

    final notificationDetails = NotificationDetails(
      android: androidDetails,
    );

    await _notificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(scheduledTime, tz.local),
      notificationDetails,
      payload: payload,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );
  }
}