import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:sqflite/sqflite.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'screens/full_screen_notification.dart';
import 'dart:typed_data';
import 'package:path/path.dart' as path;
import 'dart:async';
import 'package:timezone/timezone.dart' as tz;
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'database_helper.dart';
import 'main.dart' show initDatabase, MyApp;

final _processedNotificationIds = <int>{};

@pragma('vm:entry-point')
void notificationBackgroundHandler(NotificationResponse response) {
  NotificationService.handleNotificationResponse(response);
}

class NotificationService {
  static final NotificationService _notificationService = NotificationService._internal();
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  static bool _isFullScreenNotificationOpen = false;
  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  Database? _database;

  factory NotificationService() {
    return _notificationService;
  }

  NotificationService._internal();

  Future<void> init(Database db) async {
    print('DEBUG: Iniciando NotificationService - Start: ${DateTime.now()}');
    final startTime = DateTime.now().millisecondsSinceEpoch;
    _database = db;

    try {
      tz.initializeTimeZones(); // Sem await, tratado como síncrono
      print('DEBUG: Timezones inicializados - Elapsed: ${DateTime.now().millisecondsSinceEpoch - startTime}ms');

      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      const InitializationSettings initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid,
      );

      print('DEBUG: Registrando callbacks para FlutterLocalNotificationsPlugin');
      bool? initialized = await _notificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: handleNotificationResponse,
        onDidReceiveBackgroundNotificationResponse: notificationBackgroundHandler,
      );
      print('DEBUG: FlutterLocalNotificationsPlugin inicializado: $initialized - Elapsed: ${DateTime.now().millisecondsSinceEpoch - startTime}ms');
      if (initialized != true) {
        print('DEBUG: Falha ao inicializar FlutterLocalNotificationsPlugin');
        return;
      }

      final androidPlatformChannelSpecifics = await _notificationsPlugin.getNotificationAppLaunchDetails();
      if (androidPlatformChannelSpecifics?.didNotificationLaunchApp ?? false) {
        final payload = androidPlatformChannelSpecifics!.notificationResponse?.payload;
        if (payload != null) {
          print('DEBUG: Notificação inicial encontrada: $payload');
          handleNotificationResponse(androidPlatformChannelSpecifics.notificationResponse!);
        }
      }

      final androidPlugin = _notificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        await androidPlugin.deleteNotificationChannel('medication_channel');
        await androidPlugin.deleteNotificationChannelGroup('medication_group');
        print('DEBUG: Canal e grupo de notificação medication_channel excluídos - Elapsed: ${DateTime.now().millisecondsSinceEpoch - startTime}ms');

        await androidPlugin.createNotificationChannelGroup(
          const AndroidNotificationChannelGroup(
            'medication_group',
            'Lembretes de Medicamentos',
            description: 'Grupo para lembretes de medicamentos',
          ),
        );
        print('DEBUG: Grupo de canais medication_group criado - Elapsed: ${DateTime.now().millisecondsSinceEpoch - startTime}ms');

        await androidPlugin.createNotificationChannel(
          const AndroidNotificationChannel(
            'medication_channel',
            'Lembrete de Medicamento',
            description: 'Notificações para lembretes de medicamentos',
            importance: Importance.max,
            playSound: false,
            sound: null,
            enableVibration: true,
            enableLights: false,
            showBadge: false,
            groupId: 'medication_group',
          ),
        );
        print('DEBUG: Canal de notificação medication_channel criado - Elapsed: ${DateTime.now().millisecondsSinceEpoch - startTime}ms');

        bool? notificationsGranted = await androidPlugin.requestNotificationsPermission();
        print('DEBUG: Permissão de notificação concedida: $notificationsGranted - Elapsed: ${DateTime.now().millisecondsSinceEpoch - startTime}ms');
        if (notificationsGranted == null || !notificationsGranted) {
          print('DEBUG: Permissão de notificação não concedida');
          return;
        }

        bool? exactAlarmsGranted = await androidPlugin.requestExactAlarmsPermission();
        print('DEBUG: Permissão de alarme exato concedida: $exactAlarmsGranted - Elapsed: ${DateTime.now().millisecondsSinceEpoch - startTime}ms');
        if (exactAlarmsGranted == null || !exactAlarmsGranted) {
          print('DEBUG: Permissão de alarme exato não concedida');
          return;
        }
      }
      print('DEBUG: NotificationService inicializado com sucesso - Total Elapsed: ${DateTime.now().millisecondsSinceEpoch - startTime}ms');
    } catch (e) {
      print('DEBUG: Erro ao inicializar NotificationService: $e');
    }
  }



  Future<NotificationResponse?> getInitialNotification() async {
    print('DEBUG: Verificando notificação inicial');
    try {
      final details = await _notificationsPlugin.getNotificationAppLaunchDetails();
      if (details != null && details.didNotificationLaunchApp && details.notificationResponse != null) {
        print('DEBUG: Notificação inicial encontrada: ${details.notificationResponse!.payload}');
        return details.notificationResponse;
      }
      print('DEBUG: Nenhuma notificação inicial encontrada');
      return null;
    } catch (e) {
      print('DEBUG: Erro ao obter notificação inicial: $e');
      return null;
    }
  }

  Future<void> cancelNotification(int id) async {
    await stopNotificationSound(id);
  }

  static Future<void> handleNotificationResponse(NotificationResponse response) async {
    print('DEBUG: Iniciando handleNotificationResponse - ID: ${response.id}, Payload: ${response.payload}, Action: ${response.actionId}');
    if (response.payload == null || response.id == null) {
      print('DEBUG: ERRO: Payload ou ID nulo');
      return;
    }

    if (_processedNotificationIds.contains(response.id)) {
      print('DEBUG: Notificação ID ${response.id} já processada, ignorando');
      return;
    }
    _processedNotificationIds.add(response.id!);

    // Cancelar notificação imediatamente
    try {
      await _notificationService._notificationsPlugin.cancel(response.id!);
      print('DEBUG: Notificação nativa ID ${response.id} cancelada');
    } catch (e) {
      print('DEBUG: Erro ao cancelar notificação: $e');
    }

    if (_isFullScreenNotificationOpen) {
      print('DEBUG: FullScreenNotification já aberta, ignorando');
      return;
    }

    try {
      final payloadParts = response.payload!.split('|');
      if (payloadParts.length < 2) {
        print('DEBUG: ERRO: Payload inválido: ${response.payload}');
        return;
      }
      final horario = payloadParts[0];
      final medicationIds = payloadParts[1].split(',');

      AudioPlayer? audioPlayer;
      try {
        audioPlayer = AudioPlayer();
        await audioPlayer.setSource(AssetSource('sounds/alarm.mp3'));
        await audioPlayer.setVolume(1.0);
        await audioPlayer.setReleaseMode(ReleaseMode.loop);
        await audioPlayer.resume();
        print('DEBUG: AudioPlayer iniciado');
      } catch (e) {
        print('DEBUG: Erro ao iniciar AudioPlayer: $e');
        audioPlayer = null;
      }

      // Inicializar banco de dados se necessário
      if (_notificationService._database == null) {
        _notificationService._database = await initDatabase();
        await _notificationService.init(_notificationService._database!);
      }
      _isFullScreenNotificationOpen = true;
      navigatorKey.currentState?.pushReplacement(
        MaterialPageRoute(
          builder: (context) => FullScreenNotification(
            horario: horario,
            medicationIds: medicationIds,
            database: _notificationService._database!,
            audioPlayer: audioPlayer,
            onClose: () {
              _isFullScreenNotificationOpen = false;
              if (audioPlayer != null) {
                audioPlayer.stop();
                print('DEBUG: AudioPlayer parado no onClose');
              }
              _processedNotificationIds.remove(response.id);
            },
          ),
        ),
      );
      print('DEBUG: Navegação para FullScreenNotification concluída');
    } catch (e) {
      print('DEBUG: ERRO ao processar notificação: $e');
      _isFullScreenNotificationOpen = false;
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
        priority: Priority.high,
        playSound: false,
        sound: null,
        showWhen: true,
        visibility: NotificationVisibility.public,
        enableVibration: true,
        enableLights: false,
        autoCancel: true,
        ongoing: false,
        fullScreenIntent: true,
        timeoutAfter: 100, // Reduzir timeout
        category: AndroidNotificationCategory.alarm,
        additionalFlags: Int32List.fromList([4]),
      );
      final notificationDetails = NotificationDetails(android: androidDetails);

      final modifiedPayload = payload.isNotEmpty ? '$payload|fallback' : payload;

      await _notificationsPlugin.show(
        id,
        title,
        body,
        notificationDetails,
        payload: modifiedPayload,
      );
      print('DEBUG: Notificação exibida com sucesso');
    } catch (e) {
      print('DEBUG: Erro ao exibir notificação: $e');
    }
  }



  Future<void> scheduleNotification({
    required int id,
    required String title,
    String? body,
    required String payload,
    required DateTime scheduledTime,
    String sound = 'alarm',
  }) async {
    print('DEBUG: Agendando notificação com id: $id, title: $title, sound: $sound, scheduledTime: $scheduledTime');

    final now = DateTime.now();
    final delay = scheduledTime.difference(now).inMilliseconds;
    print('DEBUG: Horário atual do dispositivo: $now');
    print('DEBUG: Diferença de tempo (scheduledTime - now): ${delay / 1000} segundos');

    if (delay < 0) {
      print('DEBUG: Horário agendado já passou, ignorando');
      return;
    }

    // Agendar alarme com android_alarm_manager_plus
    try {
      await AndroidAlarmManager.oneShotAt(
        scheduledTime,
        id,
        alarmCallback,
        exact: true,
        wakeup: true,
        allowWhileIdle: true,
        rescheduleOnReboot: true,
        params: {
          'id': id,
          'title': title,
          'body': body ?? 'Você tem medicamentos para tomar',
          'payload': payload,
          'sound': sound,
        },
      );
      print('DEBUG: Alarme agendado com android_alarm_manager_plus');
    } catch (e) {
      print('DEBUG: Erro ao agendar alarme: $e');
    }

    // Agendar notificação nativa com flutter_local_notifications como fallback
    try {
      final tz.TZDateTime tzScheduledTime = tz.TZDateTime.from(scheduledTime, tz.local);
      await _notificationsPlugin.zonedSchedule(
        id,
        title,
        body ?? 'Você tem medicamentos para tomar',
        tzScheduledTime,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'medication_channel',
            'Medication Reminders',
            channelDescription: 'Notificações para lembretes de medicamentos',
            importance: Importance.max,
            priority: Priority.high,
            sound: RawResourceAndroidNotificationSound(sound),
            playSound: true,
            fullScreenIntent: true,
            visibility: NotificationVisibility.public,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: payload,
      );
      print('DEBUG: Notificação nativa agendada com zonedSchedule');
    } catch (e) {
      print('DEBUG: Erro ao agendar notificação nativa: $e');
    }

    print('DEBUG: Agendamento configurado com sucesso');
  }



  static Future<void> alarmCallback(int id, Map<String, dynamic> params) async {
    print('DEBUG: Iniciando alarmCallback para ID $id com params: $params');
    try {
      // Inicializar banco de dados se necessário
      if (_notificationService._database == null) {
        print('DEBUG: Banco de dados nulo, inicializando via initDatabase');
        _notificationService._database = await initDatabase();
        await _notificationService.init(_notificationService._database!);
        print('DEBUG: Banco de dados inicializado com sucesso');
      }
      final payload = params['payload'] as String;
      print('DEBUG: Processando payload: $payload');
      final payloadParts = payload.split('|');
      if (payloadParts.length >= 2) {
        final horario = payloadParts[0];
        final medicationIds = payloadParts[1].split(',');
        print('DEBUG: Horario: $horario, Medication IDs: $medicationIds');

        AudioPlayer? audioPlayer;
        try {
          audioPlayer = AudioPlayer();
          await audioPlayer.setSource(AssetSource('sounds/alarm.mp3'));
          await audioPlayer.setVolume(1.0);
          await audioPlayer.setReleaseMode(ReleaseMode.loop);
          await audioPlayer.resume();
          print('DEBUG: AudioPlayer iniciado para alarme');
        } catch (e) {
          print('DEBUG: Erro ao iniciar AudioPlayer no alarme: $e');
          audioPlayer = null;
        }

        if (!_isFullScreenNotificationOpen) {
          _isFullScreenNotificationOpen = true;
          final navigatorState = navigatorKey.currentState;
          print('DEBUG: NavigatorState disponível: ${navigatorState != null && navigatorState.mounted}');
          if (navigatorState != null && navigatorState.mounted) {
            navigatorState.pushReplacement(
              MaterialPageRoute(
                builder: (context) => FullScreenNotification(
                  horario: horario,
                  medicationIds: medicationIds,
                  database: _notificationService._database!,
                  audioPlayer: audioPlayer,
                  onClose: () {
                    _isFullScreenNotificationOpen = false;
                    if (audioPlayer != null) {
                      audioPlayer.stop();
                      print('DEBUG: AudioPlayer parado no onClose do alarme');
                    }
                  },
                ),
              ),
            );
            print('DEBUG: Navegação para FullScreenNotification via alarme concluída');
          } else {
            print('DEBUG: NavigatorState não disponível, inicializando app');
            WidgetsFlutterBinding.ensureInitialized();
            await _notificationService.init(_notificationService._database!);
            runApp(MyApp(
              database: null,
              notificationService: _notificationService,
              initialScreen: FullScreenNotification(
                horario: horario,
                medicationIds: medicationIds,
                database: _notificationService._database!,
                audioPlayer: audioPlayer,
                onClose: () {
                  _isFullScreenNotificationOpen = false;
                  if (audioPlayer != null) {
                    audioPlayer.stop();
                    print('DEBUG: AudioPlayer parado no onClose do alarme');
                  }
                },
              ),
            ));
            print('DEBUG: App inicializado com FullScreenNotification');
          }
        } else {
          print('DEBUG: FullScreenNotification já aberta, ignorando');
          if (audioPlayer != null) {
            await audioPlayer.stop();
            print('DEBUG: AudioPlayer parado devido a FullScreenNotification já aberta');
          }
        }
      } else {
        print('DEBUG: ERRO: Payload inválido no alarme: $payload');
      }
    } catch (e, stackTrace) {
      print('DEBUG: Erro ao processar alarme: $e');
      print('DEBUG: StackTrace: $stackTrace');
      _isFullScreenNotificationOpen = false;
    }
  }




  Future<void> stopNotificationSound(int id) async {
    print('DEBUG: Parando som da notificação com id: $id');
    try {
      await _notificationsPlugin.cancel(id);
      print('DEBUG: Notificação cancelada com sucesso');
    } catch (e) {
      print('DEBUG: Erro ao parar notificação: $e');
    }
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