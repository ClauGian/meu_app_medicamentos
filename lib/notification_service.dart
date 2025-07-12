import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:sqflite/sqflite.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'screens/medication_alert_screen.dart';
import 'dart:async';
import 'package:timezone/timezone.dart' as tz;
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter/services.dart';
import 'dart:isolate';
import 'dart:ui';

final _processedNotificationIds = <int>{};

@pragma('vm:entry-point')
void notificationBackgroundHandler(NotificationResponse response) {
  NotificationService.handleNotificationResponse(response);
}

class NotificationService {
  static final NotificationService _notificationService = NotificationService._internal();
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  static const _fullscreenChannel = MethodChannel('com.claudinei.medialerta/fullscreen');
  // Certifique-se que o NAVIGATION_CHANNEL está com o nome correto
  static const _navigationChannel = MethodChannel('com.claudinei.medialerta/navigation'); // <--- Certifique-se que esta constante está definida

  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  Database? _database;

  factory NotificationService() {
    return _notificationService;
  }

  NotificationService._internal();

  
  Future<Map<String, dynamic>?> getInitialRouteData() async {
    try {
      // Usa o _navigationChannel (corrigido do seu MainActivity.kt)
      final Map<dynamic, dynamic>? result = await _navigationChannel.invokeMethod('getInitialRoute');
      if (result != null) {
        // Converte o resultado para um Map<String, dynamic>
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
      tz.initializeTimeZones();
      tz.setLocalLocation(tz.getLocation('America/Sao_Paulo')); // Ajuste para seu fuso horário
      print('DEBUG: Timezone inicializado - Elapsed: ${DateTime.now().millisecondsSinceEpoch - startTime}ms');

      final androidPlugin = _notificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin == null) {
        print('DEBUG: Falha ao resolver AndroidFlutterLocalNotificationsPlugin');
        throw Exception('Falha ao resolver AndroidFlutterLocalNotificationsPlugin');
      }

      bool? notificationsGranted = await androidPlugin.requestNotificationsPermission();
      print('DEBUG: Permissão de notificações concedida: $notificationsGranted - Elapsed: ${DateTime.now().millisecondsSinceEpoch - startTime}ms');
      if (notificationsGranted == null || !notificationsGranted) {
        print('DEBUG: Permissão de notificações não concedida');
        throw Exception('Permissão de notificações não concedida');
      }

      bool? exactAlarmsGranted = await androidPlugin.requestExactAlarmsPermission();
      print('DEBUG: Permissão de alarme exato concedida: $exactAlarmsGranted - Elapsed: ${DateTime.now().millisecondsSinceEpoch - startTime}ms');
      if (exactAlarmsGranted == null || !exactAlarmsGranted) {
        print('DEBUG: Permissão de alarme exato não concedida');
        throw Exception('Permissão de alarme exato não concedida');
      }

      bool? fullScreenIntentGranted = await androidPlugin.requestFullScreenIntentPermission();
      print('DEBUG: Permissão de tela cheia concedida (inicial): $fullScreenIntentGranted - Elapsed: ${DateTime.now().millisecondsSinceEpoch - startTime}ms');
      if (fullScreenIntentGranted == null || !fullScreenIntentGranted) {
        print('DEBUG: Permissão de tela cheia não concedida');
        throw Exception('Permissão de tela cheia não concedida');
      }

      await androidPlugin.createNotificationChannelGroup(
        const AndroidNotificationChannelGroup(
          'medication_group',
          'Medicamentos',
          description: 'Grupo de notificações para lembretes de medicamentos',
        ),
      );
      print('DEBUG: Grupo de canais de notificação criado - Elapsed: ${DateTime.now().millisecondsSinceEpoch - startTime}ms');

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
      print('DEBUG: Canal de notificação configurado com som: alarm.mp3 - Elapsed: ${DateTime.now().millisecondsSinceEpoch - startTime}ms');

      const initializationSettings = InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      );

      await _notificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: handleNotificationResponse,
        onDidReceiveBackgroundNotificationResponse: notificationBackgroundHandler,
      );
      print('DEBUG: Plugin de notificações inicializado - Elapsed: ${DateTime.now().millisecondsSinceEpoch - startTime}ms');

      // Inicializar AndroidAlarmManager
      final bool alarmManagerInitialized = await AndroidAlarmManager.initialize();
      print('DEBUG: AndroidAlarmManager inicializado: $alarmManagerInitialized - Elapsed: ${DateTime.now().millisecondsSinceEpoch - startTime}ms');
      if (!alarmManagerInitialized) {
        print('DEBUG: Falha ao inicializar AndroidAlarmManager');
        throw Exception('Falha ao inicializar AndroidAlarmManager');
      }

      // Teste do AndroidAlarmManager
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
        navigatorState.pushReplacement(
          MaterialPageRoute(
            builder: (context) => MedicationAlertScreen(
              horario: horario,
              medicationIds: medicationIds, // Mantido como List<String>
              database: _notificationService._database!,
              notificationService: _notificationService,
            ),
          ),
        );
        print('DEBUG: Navegação para MedicationAlertScreen concluída com horario=$horario, medicationIds=$medicationIds');
      } else {
        print('DEBUG: NavigatorState não disponível, adiando navegação');
        // A navegação inicial será tratada no main.dart via getInitialRouteData
      }
    } catch (e, stackTrace) {
      print('DEBUG: ERRO ao processar notificação: $e');
      print('DEBUG: StackTrace: $stackTrace');
    }
  }



  Future<void> showNotification({
    required int id,
    required String title,
    required String body, // 'body' é o conteúdo da notificação, não o payload para a Activity.
    required String sound,
    required String payload, // 'payload' é a string que contém 'horario|medicationIds'.
  }) async {
    print('DEBUG: Iniciando showNotification com id: $id, title: $title, sound: $sound, payload: $payload');
    // REMOVIDO: A verificação de navigatorKey.currentContext para decidir se chama a Activity nativa
    // A chamada à Activity nativa agora é feita de forma mais robusta, independentemente do context.

    // Tentar chamar FullScreenAlarmActivity via MethodChannel
    try {
      print('DEBUG: Tentando chamar FullScreenAlarmActivity via MethodChannel (usando _fullscreenChannel)');
      // NOVO: Usar o MethodChannel estático definido no Trecho 1
      await _fullscreenChannel.invokeMethod('showFullScreenAlarm', {
        // CORREÇÃO: Passar os dados que a Activity nativa espera
        'horario': extractHorarioFromPayload(payload),
        'medicationIds': extractMedicationIdsFromPayload(payload),
        'payload': payload, // É bom passar o payload completo também para o lado nativo
        'title': title, // Título da notificação pode ser útil na Activity
        'body': body,   // Corpo da notificação também pode ser útil
      });
      print('DEBUG: FullScreenAlarmActivity chamada com sucesso via MethodChannel.');
    } catch (e, stackTrace) {
      print('DEBUG: Erro ao chamar FullScreenAlarmActivity via MethodChannel: $e');
      print('DEBUG: StackTrace: $stackTrace');
      // Se houver erro ao chamar a Activity de tela cheia, ainda exibe a notificação padrão
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
      // Verificar se o fuso horário está inicializado
      if (tz.local.name.isEmpty) {
        print('DEBUG: Fuso horário não inicializado, inicializando agora');
        tz.initializeTimeZones();
        tz.setLocalLocation(tz.getLocation('America/Sao_Paulo')); // Ajuste para seu fuso horário
      }

      // Gerar um ID único para o alarme
      final uniqueAlarmId = (id.hashCode ^ payload.hashCode).abs();
      print('DEBUG: Usando uniqueAlarmId: $uniqueAlarmId');

      // Agendar a chamada à FullScreenAlarmActivity usando AndroidAlarmManager
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
        print('DEBUG: ERRO: Falha ao agendar alarme com AndroidAlarmManager');
        // Fallback: Chamar FullScreenAlarmActivity diretamente via MethodChannel
        final payloadParts = payload.split('|');
        if (payloadParts.length >= 2) {
          final horario = payloadParts[0];
          final medicationIds = payloadParts[1].split(',').where((id) => id.isNotEmpty).toList();
          print('DEBUG: Tentando fallback via MethodChannel para FullScreenAlarmActivity');
          final result = await _fullscreenChannel.invokeMethod('showFullScreenAlarm', {
            'horario': horario,
            'medicationIds': medicationIds,
            'payload': payload,
            'title': title,
            'body': body ?? 'Toque para ver os medicamentos',
          });
          if (result == true) {
            print('DEBUG: FullScreenAlarmActivity disparada com sucesso via MethodChannel');
            return; // Não agendar notificação nativa
          }
        }
      }

      // Agendar notificação nativa como fallback
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
}