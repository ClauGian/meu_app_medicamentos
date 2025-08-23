import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // Importação necessária para a função compute
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:sqflite/sqflite.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter/services.dart';
import 'screens/medication_alert_screen.dart';
import 'package:just_audio/just_audio.dart';

final _processedNotificationIds = <int>{};
final AudioPlayer _audioPlayer = AudioPlayer();

@pragma('vm:entry-point')
void notificationBackgroundHandler(NotificationResponse response) {
  NotificationService.handleNotificationResponse(response);
}

class NotificationService {
  static final NotificationService _notificationService = NotificationService._internal();
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  static const _navigationChannel = MethodChannel('com.claudinei.medialerta/navigation');
  final MethodChannel _deviceChannel = const MethodChannel('com.claudinei.medialerta/device');
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

      // Mover a criação de canais para o Isolate
      await compute(_initializeHeavyTasks, rootIsolateToken);
      print('DEBUG: Canais de notificação inicializados no Isolate - Elapsed: ${DateTime.now().millisecondsSinceEpoch - startTime}ms');

      final activeNotifications = await _notificationsPlugin.getActiveNotifications();
      print('DEBUG: Notificações ativas: $activeNotifications');

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
          sound: RawResourceAndroidNotificationSound('alarm'), // TODO: Substituir por som selecionado em AlertSoundSelection
          enableVibration: true,
          enableLights: true,
          ledColor: Colors.blue,
          showBadge: false,
          groupId: 'medication_group',
        ),
      );
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
      final payloadParts = response.payload!.split('|');
      if (payloadParts.length < 2) {
        print('DEBUG: ERRO: Payload inválido: ${response.payload}');
        return;
      }
      final horario = payloadParts[0];
      final medicationIds = payloadParts[1].split(',').where((id) => id.isNotEmpty).toList();

      if (medicationIds.isEmpty) {
        print('DEBUG: ERRO: Nenhum ID de medicamento válido encontrado no payload: ${response.payload}');
        return;
      }

      if (_notificationService._database == null) {
        print('DEBUG: ERRO: Banco de dados não inicializado no handleNotificationResponse');
        return;
      }

      // Tocar o som quando a notificação é processada
      try {
        await _notificationService._playAlarmSound('alarm');
        print('DEBUG: Som de alarme iniciado ao processar notificação ID ${response.id}');
      } catch (e, stackTrace) {
        print('DEBUG: Erro ao tocar som ao processar notificação: $e');
        print('DEBUG: StackTrace: $stackTrace');
      }

      if (response.actionId == 'snooze_action') {
        // Ação "Adiar 15 minutos"
        await _notificationService._notificationsPlugin.cancel(response.id!);
        print('DEBUG: Notificação nativa ID ${response.id} cancelada (snooze_action)');
        final newScheduledTime = DateTime.now().add(const Duration(minutes: 15));
        await _notificationService.scheduleNotification(
          id: response.id! + 1000000,
          title: 'Hora do Medicamento',
          body: 'Toque para ver os medicamentos',
          payload: response.payload!,
          scheduledTime: newScheduledTime,
          sound: 'alarm',
        );
        print('DEBUG: Notificação reagendada para 15 minutos depois: $newScheduledTime');
      } else if (response.actionId == 'view_action' || response.actionId == null) {
        // Ação "Ver" ou toque na notificação
        print('DEBUG: Processando ação view_action ou toque na notificação ID ${response.id}');
        final navigatorState = NotificationService.navigatorKey.currentState;
        if (navigatorState != null && navigatorState.mounted) {
          final rootIsolateToken = RootIsolateToken.instance;
          if (rootIsolateToken == null) {
            print('DEBUG: ERRO: RootIsolateToken.instance retornou null');
            throw Exception('RootIsolateToken.instance retornou null');
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
      const bigTextStyleInformation = BigTextStyleInformation(
        'Toque para ver os medicamentos',
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
        sound: RawResourceAndroidNotificationSound(sound), // TODO: Substituir por som selecionado em AlertSoundSelection
        playSound: true,
        icon: '@mipmap/ic_launcher',
        largeIcon: DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
        styleInformation: bigTextStyleInformation,
        actions: const [
          AndroidNotificationAction(
            'view_action',
            'Ver',
            showsUserInterface: true,
            cancelNotification: true,
          ),
          AndroidNotificationAction(
            'snooze_action',
            'Adiar 15 minutos',
            cancelNotification: true,
          ),
        ],
        visibility: NotificationVisibility.public,
        enableVibration: true,
        enableLights: true,
        ledColor: Colors.blue,
        autoCancel: true,
        category: AndroidNotificationCategory.alarm,
      );

      await _notificationsPlugin.show(
        id,
        title,
        body,
        NotificationDetails(android: androidDetails),
        payload: payload,
      );
      print('DEBUG: Notificação exibida com sucesso');
    } catch (e, stackTrace) {
      print('DEBUG: Erro ao exibir notificação: $e');
      print('DEBUG: StackTrace: $stackTrace');
    }
  }



  Future<void> scheduleNotification({
    required int id,
    required String title,
    String? body,
    required String payload,
    required DateTime scheduledTime,
    String sound = 'alarm', // TODO: Substituir por som selecionado em AlertSoundSelection
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
      // Passar o delay para _showNativeNotification
      await _showNativeNotification(id, title, body, payload, sound, scheduledTime, delay);
      print('DEBUG: Notificação agendada diretamente com flutter_local_notifications');
    } catch (e, stackTrace) {
      print('DEBUG: Erro ao agendar notificação: $e');
      print('DEBUG: StackTrace: $stackTrace');
    }
  }



  Future<void> _showNativeNotification(int id, String title, String? body, String payload, String sound, DateTime scheduledTime, int delay) async {
    try {
      // Forçar recriação do canal de notificação
      final androidPlugin = _notificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
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
            playSound: false, // 🔹 IMPORTANTE: desativa som do canal
            enableVibration: true,
            enableLights: true,
            ledColor: Colors.blue,
            showBadge: false,
            groupId: 'medication_group',
          ),
        );
        print('DEBUG: Canal de notificação medication_channel recriado');
      }

      final scheduledTZDateTime = tz.TZDateTime.now(tz.local).add(Duration(milliseconds: delay));
      print('DEBUG: Horário agendado convertido para TZDateTime: $scheduledTZDateTime');

      // Agendar notificação
      await _notificationsPlugin.zonedSchedule(
        id,
        title,
        body ?? 'Toque para ver os medicamentos',
        scheduledTZDateTime,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'medication_channel',
            'Lembrete de Medicamento',
            channelDescription: 'Notificações para lembretes de medicamentos',
            importance: Importance.max,
            priority: Priority.high,
            playSound: false, // 🔹 O som será disparado manualmente
            ongoing: true,
            autoCancel: false,
            fullScreenIntent: true,
            icon: '@mipmap/ic_launcher',
            visibility: NotificationVisibility.public,
            enableVibration: true,
            enableLights: true,
            ledColor: Colors.blue,
            ledOnMs: 1000,
            ledOffMs: 500,
            category: AndroidNotificationCategory.alarm,
            actions: const [
              AndroidNotificationAction(
                'view_action',
                'Ver',
                showsUserInterface: true,
                cancelNotification: true,
              ),
              AndroidNotificationAction(
                'snooze_action',
                'Adiar 15 minutos',
                cancelNotification: true,
              ),
            ],
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        payload: payload,
      );

      print('DEBUG: Notificação agendada para $scheduledTZDateTime com ID $id');

      // 🔹 Não chamar _playAlarmSound aqui! Será chamado somente quando a notificação for exibida

    } catch (e, stackTrace) {
      print('DEBUG: Erro ao agendar notificação nativa: $e');
      print('DEBUG: StackTrace: $stackTrace');
    }
  }





  Future<void> _playAlarmSound(String sound) async {
    try {
      print('DEBUG: Tentando carregar asset: assets/sounds/$sound.mp3');
      await _audioPlayer.stop(); // Parar qualquer som anterior
      await _audioPlayer.setAsset('assets/sounds/$sound.mp3');
      await _audioPlayer.setLoopMode(LoopMode.all);
      print('DEBUG: LoopMode.all configurado para $sound.mp3');
      await _audioPlayer.setVolume(1.0);
      await _audioPlayer.play();
      print('DEBUG: Som de alarme iniciado, estado do player: ${_audioPlayer.playing}');
    } catch (e, stackTrace) {
      print('DEBUG: Erro ao tocar som de alarme: $e');
      print('DEBUG: StackTrace: $stackTrace');
      // Tentar um som alternativo como fallback
      try {
        print('DEBUG: Tentando som alternativo: assets/sounds/alert.mp3');
        await _audioPlayer.stop();
        await _audioPlayer.setAsset('assets/sounds/alert.mp3');
        await _audioPlayer.setLoopMode(LoopMode.all);
        print('DEBUG: LoopMode.all configurado para alert.mp3');
        await _audioPlayer.setVolume(1.0);
        await _audioPlayer.play();
        print('DEBUG: Som alternativo iniciado, estado do player: ${_audioPlayer.playing}');
      } catch (e2, stackTrace2) {
        print('DEBUG: Erro ao tocar som alternativo: $e2');
        print('DEBUG: StackTrace: $stackTrace2');
        // Fallback para som nativo
        print('DEBUG: Tentando som nativo como fallback');
        final androidDetails = AndroidNotificationDetails(
          'medication_channel',
          'Lembrete de Medicamento',
          channelDescription: 'Notificações para lembretes de medicamentos',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          sound: RawResourceAndroidNotificationSound(sound),
          audioAttributesUsage: AudioAttributesUsage.alarm,
          ongoing: true,
          autoCancel: false,
          ticker: 'Lembrete de Medicamento',
          icon: '@mipmap/ic_launcher',
          visibility: NotificationVisibility.public,
          enableVibration: true,
          enableLights: true,
          ledColor: Colors.blue,
          ledOnMs: 1000,
          ledOffMs: 500,
          category: AndroidNotificationCategory.alarm,
          fullScreenIntent: true,
          actions: const [
            AndroidNotificationAction(
              'view_action',
              'Ver',
              showsUserInterface: true,
              cancelNotification: true,
            ),
            AndroidNotificationAction(
              'snooze_action',
              'Adiar 15 minutos',
              cancelNotification: true,
            ),
          ],
        );

        await _notificationsPlugin.show(
          9999,
          'Erro no Som',
          'Usando som nativo como fallback',
          NotificationDetails(android: androidDetails),
        );
        print('DEBUG: Notificação de erro no som exibida com ID 9999');
        final activeNotifications = await _notificationsPlugin.getActiveNotifications();
        print('DEBUG: Notificações ativas após exibir fallback de som: $activeNotifications');
      }
    }
  }


  Future<void> stopAlarmSound() async {
    try {
      if (_audioPlayer.playing) {
        await _audioPlayer.stop();
        print('DEBUG: Som do alarme parado com sucesso');
      }
    } catch (e) {
      print('DEBUG: Erro ao parar o som do alarme: $e');
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
      await showNotification(
        id: params['id'] as int,
        title: params['title'] as String,
        body: params['body'] as String,
        sound: params['sound'] as String,
        payload: payload,
      );
      print('DEBUG: Notificação exibida via alarmCallback');
    } catch (e, stackTrace) {
      print('DEBUG: Erro no alarmCallback: $e');
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