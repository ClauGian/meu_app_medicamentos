import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:sqflite/sqflite.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart'; // Mantém apenas just_audio
// ignore: unused_import
import 'package:flutter_isolate/flutter_isolate.dart';
import 'package:path/path.dart';
import 'screens/medication_list_screen.dart';
import 'dart:async';


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

  static const MethodChannel _navigationChannel = MethodChannel('com.claudinei.medialerta/navigation');
  static const MethodChannel _actionChannel = MethodChannel('com.claudinei.medialerta/notification_actions');
  static const MethodChannel _fullscreenChannel = MethodChannel('com.claudinei.medialerta/fullscreen');
  static const MethodChannel _notificationChannel = MethodChannel('com.claudinei.medialerta/notification'); // <- Adicionar 'MethodChannel' aqui
  
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
      // Verificar se o app foi iniciado por uma notificação
      final didNotificationLaunchApp = await _notificationsPlugin
          .getNotificationAppLaunchDetails()
          .then((details) => details?.didNotificationLaunchApp ?? false);
      print('DEBUG: Verificando notificação de inicialização do app: didNotificationLaunchApp=$didNotificationLaunchApp');

      // Consultar o MethodChannel independentemente de didNotificationLaunchApp
      final Map<dynamic, dynamic>? result = await _navigationChannel.invokeMethod('getInitialRoute');
      if (result != null) {
        final routeData = Map<String, dynamic>.from(result);
        print('DEBUG: initialRouteData obtida: $routeData');
        // Verificar se a rota é válida
        if (routeData['route'] == 'medication_alert') {
          return routeData;
        }
      }
      print('DEBUG: Nenhum dado de rota inicial válido encontrado');
      return null;
    } on PlatformException catch (e) {
      print('DEBUG: Erro ao obter initialRouteData: ${e.message}');
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

      // Configurar o callback para ações de notificação via MethodChannel
      const channel = MethodChannel('com.claudinei.medialerta/notification_actions');
      channel.setMethodCallHandler((call) async {
        print('DEBUG: MethodChannel com.claudinei.medialerta/notification_actions chamado - method: ${call.method}, arguments: ${call.arguments} - Elapsed: ${DateTime.now().millisecondsSinceEpoch - startTime}ms');
        if (call.method == 'handleNotificationAction') {
          final id = call.arguments['id'] as int?;
          final payload = call.arguments['payload'] as String?;
          final actionId = call.arguments['actionId'] as String?;
          print('DEBUG: Iniciando handleNotificationResponse - ID: $id, Payload: $payload, Action: $actionId - Elapsed: ${DateTime.now().millisecondsSinceEpoch - startTime}ms');
          
          if (id != null && payload != null && actionId != null) {
            if (actionId == 'snooze_action') {
              print('DEBUG: Notificação ID $id cancelada (snooze_action) - Elapsed: ${DateTime.now().millisecondsSinceEpoch - startTime}ms');
              final parts = payload.split('|');
              if (parts.length >= 2) {
                final horario = parts[0];
                final medicationIds = parts[1].split(',').map(int.parse).toList();
                final sound = parts.length > 2 ? parts[2] : 'malta';
                final newTime = DateTime.now().add(Duration(minutes: 15));
                print('DEBUG: Notificação reagendada para 15 minutos depois: $newTime - Elapsed: ${DateTime.now().millisecondsSinceEpoch - startTime}ms');
                await scheduleNotification(
                  id: id,
                  title: 'Alerta de Medicamento',
                  body: 'Você tem ${medicationIds.length} medicamentos para tomar',
                  payload: '$horario|${medicationIds.join(',')}|$sound',
                  scheduledTime: newTime,
                  sound: sound,
                );
              }
            }
          }
        }
      });

      final bool alarmManagerInitialized = await AndroidAlarmManager.initialize();
      print('DEBUG: AndroidAlarmManager inicializado: $alarmManagerInitialized - Elapsed: ${DateTime.now().millisecondsSinceEpoch - startTime}ms');
      if (!alarmManagerInitialized) {
        throw Exception('Falha ao inicializar AndroidAlarmManager');
      }

      // 🔹 REAGENDAR TODOS OS ALARMES AO INICIAR O APP
      print('DEBUG: Reagendando todos os alarmes ao iniciar app...');
      await scheduleAllMedicationAlarms();
      print('DEBUG: Reagendamento concluído - Elapsed: ${DateTime.now().millisecondsSinceEpoch - startTime}ms');

      // 🔹 INICIAR REAGENDAMENTO PERIÓDICO
      startPeriodicRescheduling();
      print('DEBUG: Reagendamento periódico iniciado - Elapsed: ${DateTime.now().millisecondsSinceEpoch - startTime}ms');

    } catch (e, stackTrace) {
      print('DEBUG: Erro durante inicialização do NotificationService: $e');
      print('DEBUG: StackTrace: $stackTrace');
      rethrow;
    }
    print('DEBUG: NotificationService.init concluído - Elapsed: ${DateTime.now().millisecondsSinceEpoch - startTime}ms');
  }



  // 🔹 Reagendar alarmes periodicamente (a cada 4 horas)
  void startPeriodicRescheduling() {
    Timer.periodic(const Duration(hours: 4), (timer) async {
      print('DEBUG: ⏰ Reagendamento periódico executado às ${DateTime.now()}');
      try {
        await scheduleAllMedicationAlarms();
        print('DEBUG: ✅ Reagendamento periódico concluído com sucesso');
      } catch (e) {
        print('DEBUG: ❌ Erro no reagendamento periódico: $e');
      }
    });
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
        await androidPlugin.deleteNotificationChannel('medication_channel_v3');
        print('DEBUG: Canais de notificação medication_channel e medication_channel_v3 deletados para recriação');

        // Criar grupo de canais
        await androidPlugin.createNotificationChannelGroup(
          const AndroidNotificationChannelGroup(
            'medication_group',
            'Medicamentos',
            description: 'Grupo de notificações para lembretes de medicamentos',
          ),
        );

        // Criar novo canal com som nativo
        await androidPlugin.createNotificationChannel(
          const AndroidNotificationChannel(
            'medication_channel_v3',
            'Lembrete de Medicamento',
            description: 'Canal para lembretes de medicamentos com som nativo',
            importance: Importance.max,
            playSound: true, // 🔹 Ativar som nativo
            //sound: RawResourceAndroidNotificationSound('malta'), // 🔹 Usar malta.mp3 por padrão
            enableVibration: true,
            enableLights: true,
            ledColor: Colors.blue,
            showBadge: false,
            groupId: 'medication_group',
          ),
        );
        print('DEBUG: Canal de notificação medication_channel_v3 recriado com som nativo');
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
    print('DEBUG: Iniciando handleNotificationResponse - ID: ${response.id}, Payload: ${response.payload}, Action: ${response.actionId ?? "Nenhum actionId recebido"}');
    print('DEBUG: Verificando se stopAlarmSound será chamado');
    print('DEBUG: Todas as propriedades do response: id=${response.id}, payload=${response.payload}, actionId=${response.actionId}, notificationResponseType=${response.notificationResponseType}');

    if (_audioPlayer == null) {
      _audioPlayer = AudioPlayer();
      print('DEBUG: AudioPlayer inicializado em handleNotificationResponse');
    }

    // 🔹 Parar imediatamente qualquer som do alarme
    try {
      await _notificationService.stopAlarmSound();
      print('DEBUG: Som de alarme parado ao iniciar processamento da notificação ID ${response.id}');
    } catch (e) {
      print('DEBUG: Erro ao parar som: $e');
    }

    if (response.payload == null || response.id == null) {
      print('DEBUG: Payload ou ID nulo');
      return;
    }

    if (_processedNotificationIds.contains(response.id)) {
      print('DEBUG: Notificação ID ${response.id} já processada, ignorando');
      return;
    }
    _processedNotificationIds.add(response.id!);

    try {
      // 🔹 Tratamento especial para notificação de estoque baixo
      if (response.payload == 'estoque_baixo' || response.actionId == 'view_medications') {
        await _notificationService._notificationsPlugin.cancel(response.id!);
        print('DEBUG: Notificação ID ${response.id} cancelada (estoque_baixo)');

        final navigator = NotificationService.navigatorKey.currentState;
        if (navigator != null && navigator.mounted) {
          navigator.pushReplacement(
            MaterialPageRoute(
              builder: (context) => MedicationListScreen(
                database: _notificationService._database!,
                notificationService: _notificationService,
              ),
            ),
          );
          print('DEBUG: Navegação para MedicationListScreen concluída');
        } else {
          print('DEBUG: Navigator não disponível para navegação');
        }
        return;
      }

      final payloadParts = response.payload!.split('|');
      if (payloadParts.length < 2) {
        print('DEBUG: Payload inválido: ${response.payload}');
        return;
      }

      final horario = payloadParts[0];
      final medicationIds = payloadParts[1].split(',').where((id) => id.isNotEmpty).toList();
      final sound = payloadParts.length >= 3 ? payloadParts[2] : 'malta';
      print('DEBUG: Payload processado - Horário: $horario, MedicationIds: $medicationIds, Sound: $sound');

      // 🔹 Ação "Ver" (alarmes normais) → abrir MedicationAlertScreen  
      if (response.actionId == 'view_medications') {
        await _notificationService._notificationsPlugin.cancel(response.id!);
        print('DEBUG: Notificação ID ${response.id} cancelada (view_medications)');

        final navigator = NotificationService.navigatorKey.currentState;
        if (navigator != null && navigator.mounted) {
          navigator.pushReplacement(
            MaterialPageRoute(
              builder: (context) => MedicationListScreen(
                database: _notificationService._database!,
                notificationService: _notificationService,
              ),
            ),
          );
          print('DEBUG: Navegação para MedicationListScreen concluída');
        } else {
          print('DEBUG: Navigator não disponível para navegação');
        }
      }

      // 🔹 Clique genérico → cancelar notificação, sem navegação
      else {
        await _notificationService._notificationsPlugin.cancel(response.id!);
        print('DEBUG: Clique genérico na notificação (actionId: ${response.actionId ?? "null"}), notificação cancelada, sem navegação');
      }
    } catch (e, stackTrace) {
      print('DEBUG: ERRO ao processar notificação: $e');
      print('DEBUG: StackTrace: $stackTrace');
    }
  }


  Future<void> scheduleFullScreen({
    required String horario,
    required List<String> medicationIds,
    String? payload,
    String? title,
    String? body,
    int delaySeconds = 0,
  }) async {
    try {
      await _fullscreenChannel.invokeMethod('scheduleFullScreen', {
        'horario': horario,
        'medicationIds': medicationIds,
        'payload': payload,
        'title': title,
        'body': body,
        'delaySeconds': delaySeconds,
      });
      print('DEBUG: Agendamento da FullScreen enviado via MethodChannel');
    } catch (e, stackTrace) {
      print('DEBUG: Erro ao agendar FullScreen: $e');
      print(stackTrace);
    }
  }


  Future<void> scheduleNotification({
    required int id,
    required String title,
    String? body,
    required String payload,
    required DateTime scheduledTime,
    String sound = 'malta',
  }) async {
    print('DEBUG: Agendando notificação com id: $id, title: $title, sound: $sound, scheduledTime: $scheduledTime');
    final now = DateTime.now();
    final delay = scheduledTime.difference(now).inSeconds;
    print('DEBUG: Horário atual do dispositivo: $now');
    print('DEBUG: Diferença de tempo (scheduledTime - now): $delay segundos');

    if (delay < 0) {
      print('DEBUG: Horário agendado já passou, exibindo notificação imediatamente');
      await showNotification(
        id: id,
        title: title,
        body: body ?? 'Toque para ver os medicamentos',
        sound: sound,
        payload: '$payload|$sound',
      );
      return;
    }

    try {
      await _notificationChannel.invokeMethod('scheduleNotification', {
        'id': id,
        'title': title,
        'body': body ?? 'Toque para ver os medicamentos',
        'payload': payload,
        'sound': sound,
        'scheduledTime': scheduledTime.millisecondsSinceEpoch,
      });
      
      print('DEBUG: Alarme agendado com sucesso via MethodChannel para $scheduledTime (ID: $id)');
    } catch (e, stackTrace) {
      print('DEBUG: Erro ao agendar via MethodChannel: $e');
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

    // Configuração do som para Android
    final String soundFile = sound.isEmpty ? 'malta' : sound; // Fallback para som padrão
    print('DEBUG: Configurando som nativo: $soundFile');

    // Detalhes da notificação para Android
    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'medication_channel_v3',
      'MediAlerta Notifications',
      channelDescription: 'Notificações para lembretes de medicamentos',
      importance: Importance.max,
      priority: Priority.high,
      sound: RawResourceAndroidNotificationSound(soundFile),
      playSound: true,
      enableVibration: true,
      category: AndroidNotificationCategory.alarm,
      fullScreenIntent: true,
      color: Color(0xFF006994),
      colorized: true,
      largeIcon: DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
      styleInformation: BigTextStyleInformation(
        body,
        contentTitle: title,
        summaryText: '⚕️ MediAlerta',
        htmlFormatBigText: true,
        htmlFormatContentTitle: true,
      ),
      actions: [
        AndroidNotificationAction(
          'view_medications',
          'Ver',
          showsUserInterface: true,
        ),
      ],
    );

    // Detalhes gerais da notificação
    final NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
    );

    try {
      // Não chamar playAlarmSound para evitar conflitos
      print('DEBUG: Exibindo notificação sem chamar playAlarmSound');
      await _notificationsPlugin.show(
        id,
        title,
        body,
        notificationDetails,
        payload: payload,
      );
      print('DEBUG: Notificação exibida com sucesso via flutter_local_notifications');
    } catch (e, stackTrace) {
      print('DEBUG: Erro ao exibir notificação: $e');
      print('DEBUG: StackTrace: $stackTrace');
    }
  }



  Future<void> playAlarmSound(String sound) async {
    try {
      print('DEBUG: Iniciando playAlarmSound para som: $sound');

      // Inicializar AudioPlayer se necessário
      if (_audioPlayer == null) {
        _audioPlayer = AudioPlayer();
        print('DEBUG: AudioPlayer inicializado em playAlarmSound');
      }

      // Parar qualquer reprodução anterior
      if (_audioPlayer!.playing) {
        await _audioPlayer!.stop();
        print('DEBUG: Reprodução anterior parada');
      }

      // Configurar o canal de áudio para STREAM_ALARM no Android
      try {
        await _deviceChannel.invokeMethod('setAudioModeToAlarm');
        print('DEBUG: Modo de áudio configurado para STREAM_ALARM');
      } catch (e) {
        print('DEBUG: Erro ao configurar modo de áudio: $e');
      }

      // Configurar o asset do som
      final String soundFile = sound.isEmpty ? 'malta' : sound;
      final String assetPath = 'assets/sounds/$soundFile.mp3';
      print('DEBUG: Configurando asset: $assetPath');
      await _audioPlayer!.setAsset(assetPath);

      // Configurar volume máximo e loop
      await _audioPlayer!.setVolume(1.0);
      await _audioPlayer!.setLoopMode(LoopMode.all);

      // Iniciar reprodução
      print('DEBUG: Iniciando reprodução do som');
      await _audioPlayer!.play();
      print('DEBUG: Som $soundFile iniciado em loop, estado do player: ${_audioPlayer!.playing}');
    } catch (e, stackTrace) {
      print('DEBUG: Erro em playAlarmSound para $sound: $e');
      print('DEBUG: StackTrace: $stackTrace');
    }
  }



  Future<void> initializeNotificationListeners() async {
    print('DEBUG: initializeNotificationListeners chamado');
    _actionChannel.setMethodCallHandler((call) async {
      print('DEBUG: MethodChannel chamado: method=${call.method}, arguments=${call.arguments}');
      print('DEBUG: Entrou no handler do _actionChannel');
      if (call.method == 'handleNotificationAction') {
        final id = call.arguments['id'] as int?;
        final payload = call.arguments['payload'] as String?;
        final actionId = call.arguments['actionId'] as String?;
        if (id != null && payload != null) {
          final response = NotificationResponse(
            id: id,
            payload: payload,
            actionId: actionId,
            notificationResponseType: NotificationResponseType.selectedNotification,
          );
          await handleNotificationResponse(response);
        } else {
          print('DEBUG: Argumentos inválidos no MethodChannel: id=$id, payload=$payload, actionId=$actionId');
        }
      }
    });

    // 🔹 Pré-carregar o AudioPlayer
    if (_audioPlayer == null) {
      _audioPlayer = AudioPlayer();
      try {
        await _audioPlayer!.setAsset('assets/sounds/malta.mp3');
        await _audioPlayer!.setLoopMode(LoopMode.all);
        await _audioPlayer!.setVolume(1.0);
        await _audioPlayer!.stop();
        print('DEBUG: AudioPlayer pré-carregado com malta.mp3');
      } catch (e) {
        print('DEBUG: Erro ao pré-carregar AudioPlayer com malta.mp3: $e');
      }
    }

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    final InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );

    try {
      // 🔹 Verificar detalhes de inicialização do app
      final notificationAppLaunchDetails = await _notificationsPlugin.getNotificationAppLaunchDetails();
      print('DEBUG: Verificando notificação de inicialização do app: didNotificationLaunchApp=${notificationAppLaunchDetails?.didNotificationLaunchApp ?? false}');
      if (notificationAppLaunchDetails != null && notificationAppLaunchDetails.didNotificationLaunchApp) {
        final response = notificationAppLaunchDetails.notificationResponse;
        if (response != null) {
          print('DEBUG: App iniciado por notificação: ID=${response.id}, Payload=${response.payload}, Action=${response.actionId}');
          await handleNotificationResponse(response);
        } else {
          print('DEBUG: Nenhum response encontrado em notificationAppLaunchDetails');
        }
      } else {
        print('DEBUG: App não foi iniciado por notificação');
      }

      await _notificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) async {
          print('DEBUG: Notificação recebida (foreground) - ID: ${response.id}, Payload: ${response.payload}, Action: ${response.actionId}');
          await handleNotificationResponse(response);
        },
        onDidReceiveBackgroundNotificationResponse: notificationBackgroundHandler,
      );
      print('DEBUG: FlutterLocalNotificationsPlugin inicializado com sucesso');
    } catch (e, stackTrace) {
      print('DEBUG: Erro ao inicializar FlutterLocalNotificationsPlugin: $e');
      print('DEBUG: StackTrace: $stackTrace');
    }
  }



  Future<void> stopAlarmSound() async {
    try {
      // 🔹 Inicializa apenas se necessário
      _audioPlayer ??= AudioPlayer();

      if (_audioPlayer!.playing) {
        print('DEBUG: Parando som do alarme');
        await _audioPlayer!.stop(); // Para imediatamente
      } else {
        print('DEBUG: Nenhum som tocando no momento');
      }

      // 🔹 Dispose opcional: só se realmente quiser liberar recursos
      // await _audioPlayer!.dispose();
      // _audioPlayer = AudioPlayer();

    } catch (e, stackTrace) {
      print('DEBUG: Erro ao parar o som do alarme: $e');
      print(stackTrace);
    }
  }



  @pragma('vm:entry-point')
  static Future<void> alarmCallback(int id) async {
    print('DEBUG: alarmCallback disparado! ID do alarme: $id');
    
    // Inicializar o plugin de notificações
    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = 
        FlutterLocalNotificationsPlugin();
    
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    
    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );
    
    await flutterLocalNotificationsPlugin.initialize(initializationSettings);
    
    // Recuperar dados do banco para este alarme
    final db = await openDatabase(
      join(await getDatabasesPath(), 'medialerta.db'),
    );
    
    // Buscar medicamentos que devem ser tomados agora
    final now = DateTime.now();
    final currentTime = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    
    final medications = await db.query(
      'medications',
      where: 'quantidade > 0 AND horarios LIKE ?',
      whereArgs: ['%$currentTime%'],
    );
    
    await db.close();
    
    if (medications.isEmpty) {
      print('DEBUG: Nenhum medicamento encontrado para este horário');
      return;
    }
    
    // Mostrar notificação
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'medication_reminders',
      'Lembretes de Medicamentos',
      channelDescription: 'Notificações para lembrar de tomar medicamentos',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('malta'),
    );
    
    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
    );
    
    await flutterLocalNotificationsPlugin.show(
      id,
      'Hora do Medicamento!',
      '${medications.length} medicamento(s) para tomar agora',
      notificationDetails,
      payload: 'medication_alert',
    );
    
    print('DEBUG: Notificação exibida com sucesso via alarmCallback');
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



  Future<void> scheduleAllMedicationAlarms() async {
    print('DEBUG: Iniciando scheduleAllMedicationAlarms');
    try {
      if (_database == null) {
        print('DEBUG: ERRO: Database não inicializado');
        return;
      }

      // DECLARAÇÃO MOVIDA PARA CÁ (corrige o erro)
      final DateTime now = DateTime.now();

      // Buscar medicamentos ativos (quantidade > 0)
      final medications = await _database!.query(
        'medications',
        where: 'quantidade > ?',
        whereArgs: [0],
      );

      print('DEBUG: Medicamentos ativos encontrados: ${medications.length}');

      // AGRUPAR medicamentos por horário
      final Map<String, List<Map<String, dynamic>>> medicationsByTime = {};
      final Set<int> activeAlarmIds = {}; // IDs que serão usados agora

      for (final med in medications) {
        final horarios = med['horarios'] as String?;
        if (horarios == null || horarios.isEmpty) {
          print('DEBUG: Medicamento ${med['nome']} sem horários, pulando');
          continue;
        }

        final listaHorarios = horarios.split(',').map((h) => h.trim()).toList();
        
        for (final horario in listaHorarios) {
          if (!medicationsByTime.containsKey(horario)) {
            medicationsByTime[horario] = [];
          }
          medicationsByTime[horario]!.add(med);

          // Calcular e guardar o ID do alarme ativo
          final parts = horario.split(':');
          if (parts.length == 2) {
            final hour = int.parse(parts[0]);
            final minute = int.parse(parts[1]);
            final alarmId = int.parse('${hour.toString().padLeft(2, '0')}${minute.toString().padLeft(2, '0')}');
            activeAlarmIds.add(alarmId);
          }
        }
      }

      print('DEBUG: Horários únicos encontrados: ${medicationsByTime.keys.toList()}');

      // PASSO 1: Cancelar todos os alarmes órfãos
      for (int hour = 0; hour < 24; hour++) {
        for (int minute = 0; minute < 60; minute++) {
          final alarmId = int.parse('${hour.toString().padLeft(2, '0')}${minute.toString().padLeft(2, '0')}');
          if (!activeAlarmIds.contains(alarmId)) {
            await cancelNotification(alarmId);
            print('DEBUG: ❌ Alarme órfão cancelado: ID $alarmId (${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')})');
          }
        }
      }

      if (medicationsByTime.isEmpty) {
        print('DEBUG: Nenhum medicamento ativo para agendar');
        return;
      }

      int alarmsScheduled = 0;

      // PASSO 2: Agendar os alarmes ativos
      for (final entry in medicationsByTime.entries) {
        final horario = entry.key;
        final meds = entry.value;

        try {
          final parts = horario.split(':');
          if (parts.length != 2) {
            print('DEBUG: Formato de horário inválido: $horario');
            continue;
          }

          final hour = int.parse(parts[0]);
          final minute = int.parse(parts[1]);

          DateTime scheduledTime = DateTime(now.year, now.month, now.day, hour, minute);

          if (scheduledTime.isBefore(now)) {
            scheduledTime = scheduledTime.add(const Duration(days: 1));
            print('DEBUG: ⚠️ Horário $horario já passou hoje, agendando para amanhã: $scheduledTime');
          } else {
            print('DEBUG: ✅ Horário $horario ainda não passou, agendando para hoje: $scheduledTime');
          }

          final medicationIds = meds.map((m) => m['id'].toString()).toList();
          final som = (meds.first['tipo_alarme'] as String? ?? 'malta').replaceAll('.mp3', '');
          final alarmId = int.parse('${hour.toString().padLeft(2, '0')}${minute.toString().padLeft(2, '0')}');
          final payload = '$horario|${medicationIds.join(',')}|$som';

          print('DEBUG: ===== AGENDANDO ALARME =====');
          print('DEBUG: Horário: $horario');
          print('DEBUG: Medicamentos: ${meds.map((m) => m['nome']).join(', ')}');
          print('DEBUG: IDs: $medicationIds');
          print('DEBUG: Payload: $payload');
          print('DEBUG: Som: $som');
          print('DEBUG: AlarmId: $alarmId');
          print('DEBUG: ================================');

          await scheduleNotification(
            id: alarmId,
            title: 'Hora do Medicamento',
            body: 'Toque para ver ${meds.length} medicamento${meds.length > 1 ? 's' : ''} das $horario',
            payload: payload,
            scheduledTime: scheduledTime,
            sound: som,
          );

          alarmsScheduled++;
          print('DEBUG: ✅ Alarme agendado para $horario com ${meds.length} medicamento(s)');
        } catch (e) {
          print('DEBUG: Erro ao agendar horário $horario: $e');
        }
      }

      print('DEBUG: Total de alarmes agendados: $alarmsScheduled');
      print('DEBUG: scheduleAllMedicationAlarms concluído');
    } catch (e, stackTrace) {
      print('DEBUG: Erro em scheduleAllMedicationAlarms: $e');
      print('DEBUG: StackTrace: $stackTrace');
    }
  }




  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    return await _notificationsPlugin.pendingNotificationRequests();
  }
}