import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:sqflite/sqflite.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'screens/medication_alert_screen.dart';
import 'dart:async';
import 'package:timezone/timezone.dart' as tz;
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';


final _processedNotificationIds = <int>{};

@pragma('vm:entry-point')
void notificationBackgroundHandler(NotificationResponse response) {
  NotificationService.handleNotificationResponse(response);
}

class NotificationService {
  static final NotificationService _notificationService = NotificationService._internal();
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  static const _navigationChannel = MethodChannel('com.claudinei.medialerta/navigation');
  final MethodChannel _deviceChannel = const MethodChannel('com.claudinei.medialerta/device');
  final MethodChannel _fullscreenChannel = const MethodChannel('com.claudinei.medialerta/fullscreen');
  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  Database? _database;


  factory NotificationService() {
    return _notificationService;
  }

  NotificationService._internal();

  Future<Map<String, dynamic>?> getInitialRouteData() async {
    try {
      final Map<dynamic, dynamic>? result = await _navigationChannel.invokeMethod('getInitialRoute');
      if (result != null) {
        return Map<String, dynamic>.from(result);
      }
      return null;
    } on PlatformException catch (e) {
      print("DEBUG: Erro ao obter initialRouteData: ${e.message}");
      return null;
    }
  }



  Future<void> init(Database database) async {
    final int startTime = DateTime.now().millisecondsSinceEpoch;
    print('DEBUG: Iniciando NotificationService.init - Elapsed: 0ms');
    _database = database;

    try {
      // Inicializar o timezone na thread principal
      tz.initializeTimeZones();
      tz.setLocalLocation(tz.getLocation('America/Sao_Paulo'));
      print('DEBUG: Timezone inicializado na thread principal - Elapsed: ${DateTime.now().millisecondsSinceEpoch - startTime}ms');

      // Solicitar isenção de otimizações de bateria
      await requestBatteryOptimizationsExemption();
      print('DEBUG: Verificação de otimizações de bateria concluída - Elapsed: ${DateTime.now().millisecondsSinceEpoch - startTime}ms');

      // Obter o RootIsolateToken para o Isolate
      final rootIsolateToken = RootIsolateToken.instance;
      if (rootIsolateToken == null) {
        print('DEBUG: RootIsolateToken não disponível');
        throw Exception('RootIsolateToken não disponível');
      }

      // Mover apenas a criação de canais para o Isolate
      await compute(_initializeHeavyTasks, rootIsolateToken);
      print('DEBUG: Canais de notificação inicializados no Isolate - Elapsed: ${DateTime.now().millisecondsSinceEpoch - startTime}ms');

      final androidPlugin = _notificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin == null) {
        print('DEBUG: Falha ao resolver AndroidFlutterLocalNotificationsPlugin');
        throw Exception('Falha ao resolver AndroidFlutterLocalNotificationsPlugin');
      }

      bool? notificationsGranted = await androidPlugin.requestNotificationsPermission();
      print('DEBUG: Permissão de notificações concedida: $notificationsGranted - Elapsed: ${DateTime.now().millisecondsSinceEpoch - startTime}ms');
      if (notificationsGranted == null || !notificationsGranted) {
        throw Exception('Permissão de notificações não concedida');
      }

      bool? exactAlarmsGranted = await androidPlugin.requestExactAlarmsPermission();
      print('DEBUG: Permissão de alarme exato concedida: $exactAlarmsGranted - Elapsed: ${DateTime.now().millisecondsSinceEpoch - startTime}ms');
      if (exactAlarmsGranted == null || !exactAlarmsGranted) {
        throw Exception('Permissão de alarme exato não concedida');
      }

      bool? fullScreenIntentGranted = await androidPlugin.requestFullScreenIntentPermission();
      print('DEBUG: Permissão de tela cheia concedida (inicial): $fullScreenIntentGranted - Elapsed: ${DateTime.now().millisecondsSinceEpoch - startTime}ms');
      if (fullScreenIntentGranted == null || !fullScreenIntentGranted) {
        throw Exception('Permissão de tela cheia não concedida');
      }

      const initializationSettings = InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      );

      await _notificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: handleNotificationResponse,
        onDidReceiveBackgroundNotificationResponse: notificationBackgroundHandler,
      );
      print('DEBUG: Plugin de notificações inicializado - Elapsed: ${DateTime.now().millisecondsSinceEpoch - startTime}ms');

      final bool alarmManagerInitialized = await AndroidAlarmManager.initialize();
      print('DEBUG: AndroidAlarmManager inicializado: $alarmManagerInitialized - Elapsed: ${DateTime.now().millisecondsSinceEpoch - startTime}ms');
      if (!alarmManagerInitialized) {
        throw Exception('Falha ao inicializar AndroidAlarmManager');
      }

      await AndroidAlarmManager.oneShot(
        const Duration(seconds: 2),
        999999,
        testAlarmCallback,
        exact: true,
        allowWhileIdle: true,
        wakeup: true,
      );
      print('DEBUG: Teste de AndroidAlarmManager agendado para ID 999999');
    } catch (e, stackTrace) {
      print('DEBUG: Erro durante inicialização do NotificationService: $e');
      print('DEBUG: StackTrace: $stackTrace');
      rethrow;
    }
    print('DEBUG: NotificationService.init concluído - Elapsed: ${DateTime.now().millisecondsSinceEpoch - startTime}ms');
  }



  Future<void> requestBatteryOptimizationsExemption() async {
    final bool isIgnoring = await _isIgnoringBatteryOptimizations();
    print('DEBUG: isIgnoringBatteryOptimizations: $isIgnoring');
    if (!isIgnoring) {
      print('DEBUG: Solicitando isenção de otimizações de bateria');
      try {
        await _deviceChannel.invokeMethod('requestBatteryOptimizationsExemption');
        print('DEBUG: Solicitação de isenção de otimizações de bateria enviada');
      } catch (e, stackTrace) {
        print('DEBUG: Erro ao solicitar isenção de otimizações de bateria: $e');
        print('DEBUG: StackTrace: $stackTrace');
      }
    } else {
      print('DEBUG: Isenção de otimizações de bateria já concedida');
    }
  }




  Future<bool> _isIgnoringBatteryOptimizations() async {
    try {
      final result = await _deviceChannel.invokeMethod('isIgnoringBatteryOptimizations');
      return result == true;
    } catch (e, stackTrace) {
      print('DEBUG: Erro ao verificar otimizações de bateria: $e');
      print('DEBUG: StackTrace: $stackTrace');
      return false;
    }
  }





  static Future<void> _initializeHeavyTasks(RootIsolateToken token) async {
    // Inicializar o BackgroundIsolateBinaryMessenger com o RootIsolateToken
    BackgroundIsolateBinaryMessenger.ensureInitialized(token);

    final androidPlugin = FlutterLocalNotificationsPlugin().resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannelGroup(
        const AndroidNotificationChannelGroup(
          'medication_group',
          'Medicamentos',
          description: 'Grupo de notificações para lembretes de medicamentos',
        ),
      );
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
          ledColor: Colors.blue,
          showBadge: false,
          groupId: 'medication_group',
        ),
      );
    }
  }



  @pragma('vm:entry-point')
  static Future<void> testAlarmCallback(int id, Map<String, dynamic> params) async {
    print('DEBUG: Teste de AndroidAlarmManager disparado para ID $id com params: $params');
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
    print('DEBUG: Cancelando notificação com id: $id');
    try {
      await _notificationsPlugin.cancel(id);
      print('DEBUG: Notificação cancelada com sucesso');
    } catch (e) {
      print('DEBUG: Erro ao cancelar notificação: $e');
    }
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

    try {
      await _notificationService._notificationsPlugin.cancel(response.id!);
      print('DEBUG: Notificação nativa ID ${response.id} cancelada');
    } catch (e, stackTrace) {
      print('DEBUG: Erro ao cancelar notificação: $e');
      print('DEBUG: StackTrace: $stackTrace');
    }

    try {
      final payloadParts = response.payload!.split('|');
      if (payloadParts.length < 2) {
        print('DEBUG: ERRO: Payload inválido: ${response.payload}');
        return;
      }
      final horario = payloadParts[0];
      final medicationIds = payloadParts[1]
          .split(',')
          .where((id) => id.isNotEmpty)
          .toList();

      if (medicationIds.isEmpty) {
        print('DEBUG: ERRO: Nenhum ID de medicamento válido encontrado no payload: ${response.payload}');
        return;
      }

      if (_notificationService._database == null) {
        print('DEBUG: ERRO: Banco de dados não inicializado no handleNotificationResponse');
        return;
      }

      final navigatorState = NotificationService.navigatorKey.currentState;
      if (navigatorState != null && navigatorState.mounted) {
        final rootIsolateToken = RootIsolateToken.instance;
        if (rootIsolateToken == null) {
          print('DEBUG: ERRO: RootIsolateToken.instance retornou null em notification_service.dart');
          throw Exception('RootIsolateToken.instance retornou null. Verifique a versão do Flutter ou o contexto da aplicação.');
        }
        navigatorState.pushReplacement(
          MaterialPageRoute(
            builder: (context) => MedicationAlertScreen(
              horario: horario,
              medicationIds: medicationIds,
              database: _notificationService._database!,
              notificationService: _notificationService,
              rootIsolateToken: rootIsolateToken,
            ),
          ),
        );
        print('DEBUG: Navegação para MedicationAlertScreen concluída com horario=$horario, medicationIds=$medicationIds');
      } else {
        print('DEBUG: NavigatorState não disponível, adiando navegação');
      }
    } catch (e, stackTrace) {
      print('DEBUG: ERRO ao processar notificação: $e');
      print('DEBUG: StackTrace: $stackTrace');
    }
  }



  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    required String sound,
    required String payload,
  }) async {
    print('DEBUG: Iniciando showNotification with id: $id, title: $title, sound: $sound, payload: $payload');
    try {
      print('DEBUG: Tentando chamar FullScreenAlarmActivity via MethodChannel (usando _fullscreenChannel)');
      await _fullscreenChannel.invokeMethod('showFullScreenAlarm', {
        'horario': extractHorarioFromPayload(payload),
        'medicationIds': extractMedicationIdsFromPayload(payload),
        'payload': payload,
        'title': title,
        'body': body,
      });
      print('DEBUG: FullScreenAlarmActivity chamada com sucesso via MethodChannel.');
    } catch (e, stackTrace) {
      print('DEBUG: Erro ao chamar FullScreenAlarmActivity via MethodChannel: $e');
      print('DEBUG: StackTrace: $stackTrace');
      await _notificationsPlugin.show(
        id,
        title,
        body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'medication_channel',
            'Lembrete de Medicamento',
            channelDescription: 'Notificações para lembretes de medicamentos',
            importance: Importance.max,
            priority: Priority.high,
            sound: RawResourceAndroidNotificationSound(sound),
            playSound: true,
            icon: '@mipmap/ic_launcher',
            largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
            fullScreenIntent: true,
            visibility: NotificationVisibility.public,
            enableVibration: true,
            enableLights: true,
            ledColor: Colors.blue,
            autoCancel: true,
            category: AndroidNotificationCategory.alarm,
          ),
        ),
        payload: payload,
      );
      print('DEBUG: Notificação padrão exibida como fallback');
    }
  }



  String extractHorarioFromPayload(String payload) {
    final parts = payload.split('|');
    return parts.isNotEmpty ? parts[0] : '08:00';
  }

  List<String> extractMedicationIdsFromPayload(String payload) {
    final parts = payload.split('|');
    return parts.length > 1 ? parts[1].split(',').where((id) => id.isNotEmpty).toList() : [];
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

    try {
      final uniqueAlarmId = (id.hashCode ^ payload.hashCode).abs();
      print('DEBUG: Usando uniqueAlarmId: $uniqueAlarmId');

      // Verificar estado do dispositivo antes de agendar
      print('DEBUG: Estado do dispositivo: isInDozeMode=${await _isInDozeMode()}, isIgnoringBatteryOptimizations=${await _isIgnoringBatteryOptimizations()}');

      try {
        final alarmScheduled = await AndroidAlarmManager.oneShot(
          Duration(milliseconds: delay),
          uniqueAlarmId,
          alarmCallback,
          exact: true,
          allowWhileIdle: true,
          wakeup: true,
          params: {
            'id': id,
            'title': title,
            'body': body ?? 'Toque para ver os medicamentos',
            'payload': payload,
            'sound': sound,
          },
        );
        print('DEBUG: Alarme agendado com AndroidAlarmManager para $scheduledTime, sucesso: $alarmScheduled');
        if (!alarmScheduled) {
          print('DEBUG: ERRO: Falha ao agendar alarme com AndroidAlarmManager - Verificando permissões');
          final androidPlugin = _notificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
          bool? exactAlarmsGranted = await androidPlugin?.requestExactAlarmsPermission();
          print('DEBUG: Permissão de alarme exato após falha: $exactAlarmsGranted');
          if (exactAlarmsGranted == true) {
            try {
              final retryScheduled = await AndroidAlarmManager.oneShot(
                Duration(milliseconds: delay),
                uniqueAlarmId,
                alarmCallback,
                exact: true,
                allowWhileIdle: true,
                wakeup: true,
                params: {
                  'id': id,
                  'title': title,
                  'body': body ?? 'Toque para ver os medicamentos',
                  'payload': payload,
                  'sound': sound,
                },
              );
              print('DEBUG: Tentativa de reagendamento com AndroidAlarmManager, sucesso: $retryScheduled');
              if (!retryScheduled) {
                print('DEBUG: ERRO: Reagendamento falhou, usando fallback via MethodChannel');
              } else {
                return; // Sucesso no reagendamento, sair sem usar fallback
              }
            } catch (retryError, retryStackTrace) {
              print('DEBUG: Exceção ao tentar reagendar com AndroidAlarmManager: $retryError');
              print('DEBUG: StackTrace: $retryStackTrace');
            }
          } else {
            print('DEBUG: Permissão de alarme exato não concedida, usando fallback via MethodChannel');
          }
          // Prosseguir com o fallback via Timer
          print('DEBUG: Agendando fallback via Timer para FullScreenAlarmActivity após $delay ms');
          final payloadParts = payload.split('|');
          if (payloadParts.length >= 2) {
            final horario = payloadParts[0];
            final medicationIds = payloadParts[1].split(',').where((id) => id.isNotEmpty).toList();
            Timer(Duration(milliseconds: delay), () async {
              print('DEBUG: Timer disparado, chamando MethodChannel showFullScreenAlarm com horario=$horario, medicationIds=$medicationIds');
              try {
                final result = await _fullscreenChannel.invokeMethod('showFullScreenAlarm', {
                  'horario': horario,
                  'medicationIds': medicationIds,
                  'payload': payload,
                  'title': title,
                  'body': body ?? 'Toque para ver os medicamentos',
                });
                print('DEBUG: FullScreenAlarmActivity disparada com sucesso via MethodChannel após $delay ms, resultado: $result');
              } catch (fallbackError, fallbackStackTrace) {
                print('DEBUG: Erro no fallback do MethodChannel: $fallbackError');
                print('DEBUG: StackTrace: $fallbackStackTrace');
                // Tentar notificação nativa como último recurso
                await _notificationsPlugin.show(
                  id,
                  title,
                  body ?? 'Toque para ver os medicamentos',
                  NotificationDetails(
                    android: AndroidNotificationDetails(
                      'medication_channel',
                      'Lembrete de Medicamento',
                      channelDescription: 'Notificações para lembretes de medicamentos',
                      importance: Importance.max,
                      priority: Priority.high,
                      sound: RawResourceAndroidNotificationSound(sound),
                      playSound: true,
                      icon: '@mipmap/ic_launcher',
                      largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
                      fullScreenIntent: true,
                      visibility: NotificationVisibility.public,
                      enableVibration: true,
                      enableLights: true,
                      ledColor: Colors.blue,
                      autoCancel: true,
                      category: AndroidNotificationCategory.alarm,
                    ),
                  ),
                  payload: payload,
                );
                print('DEBUG: Notificação nativa exibida como último recurso');
              }
            });
            return;
          }
        }
      } catch (e, stackTrace) {
        print('DEBUG: Exceção capturada ao agendar alarme com AndroidAlarmManager: $e');
        print('DEBUG: StackTrace: $stackTrace');
        // Fallback para Timer
        print('DEBUG: Agendando fallback via Timer para FullScreenAlarmActivity após $delay ms');
        final payloadParts = payload.split('|');
        if (payloadParts.length >= 2) {
          final horario = payloadParts[0];
          final medicationIds = payloadParts[1].split(',').where((id) => id.isNotEmpty).toList();
          Timer(Duration(milliseconds: delay), () async {
            print('DEBUG: Timer disparado, chamando MethodChannel showFullScreenAlarm com horario=$horario, medicationIds=$medicationIds');
            try {
              final result = await _fullscreenChannel.invokeMethod('showFullScreenAlarm', {
                'horario': horario,
                'medicationIds': medicationIds,
                'payload': payload,
                'title': title,
                'body': body ?? 'Toque para ver os medicamentos',
              });
              print('DEBUG: FullScreenAlarmActivity disparada com sucesso via MethodChannel após $delay ms, resultado: $result');
            } catch (fallbackError, fallbackStackTrace) {
              print('DEBUG: Erro no fallback do MethodChannel: $fallbackError');
              print('DEBUG: StackTrace: $fallbackStackTrace');
              // Tentar notificação nativa como último recurso
              await _notificationsPlugin.show(
                id,
                title,
                body ?? 'Toque para ver os medicamentos',
                NotificationDetails(
                  android: AndroidNotificationDetails(
                    'medication_channel',
                    'Lembrete de Medicamento',
                    channelDescription: 'Notificações para lembretes de medicamentos',
                    importance: Importance.max,
                    priority: Priority.high,
                    sound: RawResourceAndroidNotificationSound(sound),
                    playSound: true,
                    icon: '@mipmap/ic_launcher',
                    largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
                    fullScreenIntent: true,
                    visibility: NotificationVisibility.public,
                    enableVibration: true,
                    enableLights: true,
                    ledColor: Colors.blue,
                    autoCancel: true,
                    category: AndroidNotificationCategory.alarm,
                  ),
                ),
                payload: payload,
              );
              print('DEBUG: Notificação nativa exibida como último recurso');
            }
          });
          return;
        }
      }

      final tz.TZDateTime tzScheduledTime = tz.TZDateTime.from(scheduledTime, tz.local);
      final List<AndroidNotificationAction> actions = [
        const AndroidNotificationAction(
          'view_action',
          'Ver',
          showsUserInterface: true,
          cancelNotification: true,
        ),
      ];
      final BigTextStyleInformation bigTextStyleInformation = BigTextStyleInformation(
        body ?? 'Toque para ver os medicamentos',
        htmlFormatBigText: false,
        contentTitle: 'Hora do Medicamento',
        htmlFormatContentTitle: false,
        summaryText: 'Toque para ver os medicamentos',
        htmlFormatSummaryText: false,
      );

      final androidDetails = AndroidNotificationDetails(
        'medication_channel',
        'Lembrete de Medicamento',
        channelDescription: 'Notificações para lembretes de medicamentos',
        importance: Importance.max,
        priority: Priority.high,
        sound: RawResourceAndroidNotificationSound(sound),
        playSound: true,
        icon: '@mipmap/ic_launcher',
        largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
        styleInformation: bigTextStyleInformation,
        actions: actions,
        fullScreenIntent: true,
        visibility: NotificationVisibility.public,
        enableVibration: true,
        enableLights: true,
        ledColor: Colors.blue,
        ledOnMs: 1000,
        ledOffMs: 500,
        autoCancel: true,
        category: AndroidNotificationCategory.alarm,
      );

      await _notificationsPlugin.zonedSchedule(
        id,
        'Hora do Medicamento',
        body ?? 'Toque para ver os medicamentos',
        tzScheduledTime,
        NotificationDetails(android: androidDetails),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        payload: payload,
      );
      print('DEBUG: Notificação nativa agendada com sucesso para $tzScheduledTime');
    } catch (e, stackTrace) {
      print('DEBUG: Erro ao agendar notificação: $e');
      print('DEBUG: StackTrace: $stackTrace');
      rethrow;
    }
  }



  @pragma('vm:entry-point')
  Future<void> alarmCallback(int id, Map<String, dynamic> params) async {
    print('DEBUG: Iniciando alarmCallback para ID $id com params: $params');
    try {
      final payload = params['payload'] as String?;
      if (payload == null || payload.isEmpty) {
        print('DEBUG: ERRO: Payload nulo ou vazio no alarmCallback');
        return;
      }
      print('DEBUG: Processando payload: $payload');
      final payloadParts = payload.split('|');
      if (payloadParts.length >= 2) {
        final horario = payloadParts[0];
        final medicationIds = payloadParts[1].split(',').where((id) => id.isNotEmpty).toList();
        print('DEBUG: Horario: $horario, Medication IDs: $medicationIds');

        final result = await _fullscreenChannel.invokeMethod('showFullScreenAlarm', {
          'horario': horario,
          'medicationIds': medicationIds,
          'payload': payload,
          'title': params['title'] as String? ?? 'Hora do Medicamento',
          'body': params['body'] as String? ?? 'Toque para ver os medicamentos',
        });
        print('DEBUG: FullScreenAlarmActivity chamada com sucesso via alarmCallback, resultado: $result');
      } else {
        print('DEBUG: ERRO: Payload inválido no alarme: $payload');
      }
    } catch (e, stackTrace) {
      print('DEBUG: Erro ao chamar FullScreenAlarmActivity via alarmCallback: $e');
      print('DEBUG: StackTrace: $stackTrace');
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


  Future<bool> _isInDozeMode() async {
    try {
      final result = await MethodChannel('com.claudinei.medialerta/device').invokeMethod('isInDozeMode');
      return result as bool;
    } catch (e) {
      print('DEBUG: Erro ao verificar Doze Mode: $e');
      return false;
    }
  }
}