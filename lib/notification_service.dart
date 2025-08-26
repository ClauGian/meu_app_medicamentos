import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:sqflite/sqflite.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter/services.dart';
import 'screens/medication_alert_screen.dart';
import 'package:just_audio/just_audio.dart'; // Mantém apenas just_audio

final _processedNotificationIds = <int>{};
final AudioPlayer audioPlayer = AudioPlayer();

@pragma('vm:entry-point')
void notificationBackgroundHandler(NotificationResponse response) {
  NotificationService.handleNotificationResponse(response);
}

class NotificationService {
  static final NotificationService _notificationService = NotificationService._internal();
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  static AudioPlayer? _audioPlayer;

  static const _navigationChannel = MethodChannel('com.claudinei.medialerta/navigation');
  final MethodChannel _deviceChannel = const MethodChannel('com.claudinei.medialerta/device');
  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  Database? _database;

  factory NotificationService() {
    return _notificationService;
  }

  NotificationService._internal() {
    initializeNotificationListeners();
  }



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
    try {
      // 🔹 Inicializar o BackgroundIsolateBinaryMessenger
      BackgroundIsolateBinaryMessenger.ensureInitialized(token);
      print('DEBUG: BackgroundIsolateBinaryMessenger inicializado no Isolate');

      // 🔹 Configurar canal de notificação
      final androidPlugin = FlutterLocalNotificationsPlugin().resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        // Deletar canais antigos para evitar cache
        await androidPlugin.deleteNotificationChannel('medication_channel');
        await androidPlugin.deleteNotificationChannel('medication_channel_v2');
        print('DEBUG: Canais de notificação medication_channel e medication_channel_v2 deletados para recriação');

        // Criar grupo de canais
        await androidPlugin.createNotificationChannelGroup(
          const AndroidNotificationChannelGroup(
            'medication_group',
            'Medicamentos',
            description: 'Grupo de notificações para lembretes de medicamentos',
          ),
        );

        // Criar novo canal sem som nativo
        await androidPlugin.createNotificationChannel(
          const AndroidNotificationChannel(
            'medication_channel_v2', // 🔹 Novo ID de canal
            'Lembrete de Medicamento',
            description: 'Canal sem som, controle feito pelo app',
            importance: Importance.max,
            playSound: false, // 🔹 Desativar som nativo
            sound: null, // 🔹 Sem som nativo
            enableVibration: true,
            enableLights: true,
            ledColor: Colors.blue,
            showBadge: false,
            groupId: 'medication_group',
          ),
        );
        print('DEBUG: Canal de notificação medication_channel_v2 recriado sem som nativo');
      } else {
        print('DEBUG: ERRO: AndroidFlutterLocalNotificationsPlugin não disponível');
      }
    } catch (e, stackTrace) {
      print('DEBUG: Erro ao inicializar tarefas pesadas: $e');
      print('DEBUG: StackTrace: $stackTrace');
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

    // 🔹 Garantir que o AudioPlayer esteja inicializado
    if (_audioPlayer == null) {
      _audioPlayer = AudioPlayer();
      print('DEBUG: AudioPlayer inicializado em handleNotificationResponse');
    }

    // 🔹 Parar o som imediatamente, independentemente da ação
    try {
      await _notificationService.stopAlarmSound();
      print('DEBUG: Som de alarme parado ao iniciar processamento da notificação ID ${response.id}');
    } catch (e) {
      print('DEBUG: Erro ao parar som no início do handleNotificationResponse: $e');
    }

    // 🔹 Verificar se a notificação já foi processada
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
          sound: 'malta', // 🔹 Forçar malta.mp3
        );
        print('DEBUG: Notificação reagendada para 15 minutos depois: $newScheduledTime');
      } else if (response.actionId == 'view_action' || response.actionId == null) {
        // Ação "Ver" ou toque na notificação
        print('DEBUG: Processando ação view_action ou toque na notificação ID ${response.id}');
        await _notificationService._notificationsPlugin.cancel(response.id!); // 🔹 Cancelar notificação imediatamente
        print('DEBUG: Notificação nativa ID ${response.id} cancelada (view_action)');

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
      // Adicionar o som ao payload
      final updatedPayload = '$payload|$sound';
      // Passar o delay para _showNativeNotification
      await _showNativeNotification(id, title, body, updatedPayload, sound, scheduledTime, delay);
      print('DEBUG: Notificação agendada diretamente com flutter_local_notifications');
    } catch (e, stackTrace) {
      print('DEBUG: Erro ao agendar notificação: $e');
      print('DEBUG: StackTrace: $stackTrace');
    }
  }



  Future<void> _showNativeNotification(int id, String title, String? body, String payload, String sound, DateTime scheduledTime, int delay) async {
    try {
      tz.initializeTimeZones();
      final localTimeZone = tz.getLocation('America/Sao_Paulo');
      tz.setLocalLocation(localTimeZone);
      print('DEBUG: Timezone inicializado: ${tz.local.name}');

      final androidPlugin = _notificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        await androidPlugin.deleteNotificationChannel('medication_channel');
        await androidPlugin.deleteNotificationChannel('medication_channel_v2');
        print('DEBUG: Canais de notificação medication_channel e medication_channel_v2 deletados para recriação');
        
        await androidPlugin.createNotificationChannelGroup(
          const AndroidNotificationChannelGroup(
            'medication_group',
            'Medicamentos',
            description: 'Grupo de notificações para lembretes de medicamentos',
          ),
        );
        await androidPlugin.createNotificationChannel(
          const AndroidNotificationChannel(
            'medication_channel_v2',
            'Lembrete de Medicamento',
            description: 'Canal sem som, controle feito pelo app',
            importance: Importance.max,
            playSound: false,
            sound: null,
            enableVibration: true,
            enableLights: true,
            ledColor: Colors.blue,
            showBadge: false,
            groupId: 'medication_group',
          ),
        );
        print('DEBUG: Canal de notificação medication_channel_v2 recriado sem som nativo');
      } else {
        print('DEBUG: ERRO: AndroidFlutterLocalNotificationsPlugin não disponível');
        return;
      }

      final bool? notificationsEnabled = await androidPlugin.areNotificationsEnabled();
      print('DEBUG: Notificações habilitadas: $notificationsEnabled');
      if (notificationsEnabled == false) {
        print('DEBUG: ERRO: Permissões de notificação não concedidas');
        await androidPlugin.requestNotificationsPermission();
        print('DEBUG: Solicitação de permissão de notificação enviada');
        return;
      }

      final bool? exactAlarmPermission = await androidPlugin.requestExactAlarmsPermission();
      print('DEBUG: Permissões de alarme exato concedidas: $exactAlarmPermission');
      if (exactAlarmPermission == false) {
        print('DEBUG: ERRO: Permissões de alarme exato não concedidas');
        return;
      }

      final now = tz.TZDateTime.now(tz.local);
      final scheduledTZDateTime = now.add(Duration(milliseconds: delay));
      print('DEBUG: Horário atual do dispositivo (TZ): $now');
      print('DEBUG: Horário agendado convertido para TZDateTime: $scheduledTZDateTime');
      print('DEBUG: Delay em milissegundos: $delay');

      // 🔹 Usar show com delay para testar o listener
      await Future.delayed(Duration(milliseconds: delay));
      await _notificationsPlugin.show(
        id,
        title,
        body ?? 'Toque para ver os medicamentos',
        NotificationDetails(
          android: AndroidNotificationDetails(
            'medication_channel_v2',
            'Lembrete de Medicamento',
            channelDescription: 'Canal sem som, controle feito pelo app',
            importance: Importance.max,
            priority: Priority.high,
            playSound: false,
            sound: null,
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
            category: null,
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
        payload: payload,
      );
      print('DEBUG: Notificação exibida com sucesso com ID $id');

      // 🔹 Forçar som manualmente após exibição
      try {
        print('DEBUG: Tentando forçar som: $sound');
        await playAlarmSound(sound);
        print('DEBUG: Som forçado manualmente após exibição, estado do player: ${_audioPlayer?.playing}');
      } catch (e, stackTrace) {
        print('DEBUG: Erro ao forçar som após exibição: $e');
        print('DEBUG: StackTrace: $stackTrace');
      }

      // 🔹 Log de notificações ativas
      final activeNotifications = await _notificationsPlugin.getActiveNotifications();
      print('DEBUG: Notificações ativas após exibição: $activeNotifications');
    } catch (e, stackTrace) {
      print('DEBUG: Erro ao exibir notificação nativa: $e');
      print('DEBUG: StackTrace: $stackTrace');
    }
  }



  Future<void> initializeNotificationListeners() async {
    // 🔹 Pré-carregar o AudioPlayer
    if (_audioPlayer == null) {
      _audioPlayer = AudioPlayer();
      await _audioPlayer!.setAsset('assets/sounds/malta.mp3');
      await _audioPlayer!.setLoopMode(LoopMode.off);
      await _audioPlayer!.setVolume(1.0);
      await _audioPlayer!.stop();
      print('DEBUG: AudioPlayer pré-carregado com malta.mp3');
    }

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    final InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );

    try {
      await _notificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) async {
          print('DEBUG: Notificação recebida - ID: ${response.id}, Payload: ${response.payload}, Action: ${response.actionId}');

          // 🔹 Tocar som apenas se não houver ação (notificação recém-exibida)
          if (response.actionId == null) {
            final payloadParts = response.payload?.split('|') ?? [];
            final sound = payloadParts.length >= 3 ? payloadParts[2] : 'malta';
            print('DEBUG: Tocando som para notificação recém-exibida: $sound');
            try {
              await playAlarmSound(sound);
              print('DEBUG: Som iniciado para notificação ID ${response.id}, estado do player: ${_audioPlayer!.playing}');
            } catch (e, stackTrace) {
              print('DEBUG: Erro ao tocar som para notificação exibida: $e');
              print('DEBUG: StackTrace: $stackTrace');
            }
          } else {
            print('DEBUG: Ignorando som para ação ${response.actionId}, delegando para handleNotificationResponse');
            try {
              await stopAlarmSound();
              print('DEBUG: Som parado para ação ${response.actionId}');
            } catch (e) {
              print('DEBUG: Erro ao parar som para ação ${response.actionId}: $e');
            }
          }
        },
      );
      print('DEBUG: FlutterLocalNotificationsPlugin inicializado com sucesso');
    } catch (e, stackTrace) {
      print('DEBUG: Erro ao inicializar FlutterLocalNotificationsPlugin: $e');
      print('DEBUG: StackTrace: $stackTrace');
    }
  }



  Future<void> playAlarmSound(String sound) async {
    try {
      // 🔹 Inicializar o _audioPlayer se necessário
      if (_audioPlayer == null) {
        _audioPlayer = AudioPlayer();
        print('DEBUG: AudioPlayer inicializado em playAlarmSound');
      }

      // 🔹 Verificar se o player está em estado de carregamento
      if (_audioPlayer!.processingState == ProcessingState.loading ||
          _audioPlayer!.processingState == ProcessingState.buffering) {
        print('DEBUG: AudioPlayer está carregando, reinicializando...');
        await _audioPlayer!.stop();
        await _audioPlayer!.dispose();
        _audioPlayer = AudioPlayer();
      }

      // 🔹 Parar qualquer som anterior
      await _audioPlayer!.stop();
      print('DEBUG: Som anterior parado em playAlarmSound');

      // 🔹 Definir o caminho do asset
      final assetPath = 'assets/sounds/$sound.mp3';
      print('DEBUG: Tentando carregar asset: $assetPath');

      // 🔹 Verificar se o asset existe
      try {
        final asset = await DefaultAssetBundle.of(WidgetsBinding.instance.rootElement!).load(assetPath);
        print('DEBUG: Asset $assetPath encontrado, tamanho: ${asset.buffer.lengthInBytes} bytes');
      } catch (e) {
        print('DEBUG: ERRO: Asset $assetPath não encontrado: $e');
        return;
      }

      // 🔹 Configurar e tocar o som
      await _audioPlayer!.setAsset(assetPath);
      await _audioPlayer!.setLoopMode(LoopMode.all);
      await _audioPlayer!.setVolume(1.0);
      
      // 🔹 Adicionar delay para garantir carregamento
      await Future.delayed(const Duration(milliseconds: 500));
      await _audioPlayer!.play();
      print('DEBUG: Som de alarme iniciado após delay, estado do player: ${_audioPlayer!.playing}');
    } catch (e, stackTrace) {
      print('DEBUG: Erro ao tocar som de alarme: $e');
      print('DEBUG: StackTrace: $stackTrace');
      // 🔹 Fallback para notificação sem som
      final androidDetails = AndroidNotificationDetails(
        'medication_channel_v2',
        'Lembrete de Medicamento',
        channelDescription: 'Canal sem som, controle feito pelo app',
        importance: Importance.max,
        priority: Priority.high,
        playSound: false,
        sound: null,
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
        category: null,
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
        'Não foi possível tocar o som do alarme',
        NotificationDetails(android: androidDetails),
      );
      print('DEBUG: Notificação de erro no som exibida com ID 9999');
    }
  }



  Future<void> stopAlarmSound() async {
    try {
      // 🔹 Inicializar o _audioPlayer se necessário
      if (_audioPlayer == null) {
        _audioPlayer = AudioPlayer();
        print('DEBUG: AudioPlayer inicializado em stopAlarmSound');
      }

      if (_audioPlayer!.playing) {
        await _audioPlayer!.stop();
        print('DEBUG: Som do alarme parado com sucesso');
      }
      await _audioPlayer!.dispose();
      _audioPlayer = AudioPlayer(); // Recria o player para o próximo uso
      print('DEBUG: AudioPlayer disposto e reinicializado');
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