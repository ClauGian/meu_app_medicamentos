import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:sqflite/sqflite.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'screens/full_screen_notification.dart';
import 'dart:typed_data';
import 'package:path/path.dart' as path;
import 'package:flutter/scheduler.dart' hide Priority;
import 'package:flutter_local_notifications/flutter_local_notifications.dart' as notifications;
import 'dart:async';
import 'package:timezone/timezone.dart' as tz;

// Conjunto global para rastrear IDs de notificações processadas
final _processedNotificationIds = <int>{};

// Função top-level para inicializar o banco de dados
Future<Database> _initDatabase() async {
  final dbPath = await getDatabasesPath();
  final pathName = path.join(dbPath, 'medications.db');
  final database = await openDatabase(
    pathName,
    version: 3,
    onCreate: (db, version) async {
      await db.execute('CREATE TABLE medications (id INTEGER PRIMARY KEY AUTOINCREMENT, nome TEXT NOT NULL, quantidade INTEGER NOT NULL, dosagem_diaria INTEGER NOT NULL, tipo_medicamento TEXT, frequencia TEXT, horarios TEXT, startDate TEXT, isContinuous INTEGER, foto_embalagem TEXT, skip_count INTEGER, cuidador_id TEXT)');
      await db.execute('CREATE TABLE IF NOT EXISTS users(id INTEGER PRIMARY KEY, name TEXT, phone TEXT, date TEXT)');
      await db.execute('CREATE TABLE IF NOT EXISTS caregivers(id INTEGER PRIMARY KEY, name TEXT, phone TEXT)');
      print("DEBUG: Criação das tabelas concluída.");
    },
    onUpgrade: (db, oldVersion, newVersion) async {
      if (oldVersion < 2) {
        await db.execute('ALTER TABLE medications RENAME TO medications_old');
        await db.execute('CREATE TABLE medications (id INTEGER PRIMARY KEY AUTOINCREMENT, nome TEXT NOT NULL, quantidade INTEGER NOT NULL, dosagem_diaria INTEGER NOT NULL, tipo_medicamento TEXT, frequencia TEXT, horarios TEXT, startDate TEXT, isContinuous INTEGER, foto_embalagem TEXT, skip_count INTEGER, cuidador_id TEXT)');
        await db.execute('INSERT INTO medications (id, nome, quantidade, dosagem_diaria, tipo_medicamento, frequencia, horarios, startDate, isContinuous, foto_embalagem, skip_count, cuidador_id) SELECT id, nome, COALESCE(quantidade, 0), COALESCE(dosagem_diaria, 0), tipo_medicamento, frequencia, horarios, startDate, isContinuous, foto_embalagem, skip_count, cuidador_id FROM medications_old');
        await db.execute('DROP TABLE medications_old');
        print("DEBUG: Migração para versão 2 concluída.");
      }
      if (oldVersion < 3) {
        await db.execute('ALTER TABLE users ADD COLUMN date TEXT');
        print("DEBUG: Coluna date adicionada à tabela users.");
      }
    },
  );
  if (!database.isOpen) {
    throw Exception("Erro: Banco de dados não está aberto.");
  }
  print("openDatabase concluído: $database");
  return database;
}

@pragma('vm:entry-point')
void notificationBackgroundHandler(NotificationResponse response) {
  NotificationService.handleNotificationResponse(response);
}


class NotificationService {
  static final NotificationService _notificationService = NotificationService._internal();
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  // ignore: non_constant_identifier_names
  static bool _isFullScreenNotificationOpen = false;
  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  Database? _database;

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

      print('DEBUG: Registrando callbacks para FlutterLocalNotificationsPlugin');
      bool? initialized = await _notificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: handleNotificationResponse,
        onDidReceiveBackgroundNotificationResponse: notificationBackgroundHandler,
      );
      print('DEBUG: FlutterLocalNotificationsPlugin inicializado: $initialized');
      if (initialized != true) {
        print('DEBUG: Falha ao inicializar FlutterLocalNotificationsPlugin');
        return;
      }

      final androidPlugin = _notificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        await androidPlugin.createNotificationChannelGroup(
          const AndroidNotificationChannelGroup(
            'medication_group',
            'Lembretes de Medicamentos',
            description: 'Grupo para lembretes de medicamentos',
          ),
        );
        print('DEBUG: Grupo de canais medication_group criado');

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
            showBadge: true,
            groupId: 'medication_group',
          ),
        );
        print('DEBUG: Canal de notificação medication_channel criado');

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
      }
      print('DEBUG: NotificationService inicializado com sucesso');
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
      print('DEBUG: ERRO: Payload ou ID nulo - Payload: ${response.payload}, ID: ${response.id}');
      return;
    }

    if (_processedNotificationIds.contains(response.id)) {
      print('DEBUG: Notificação ID ${response.id} já processada, ignorando');
      return;
    }
    _processedNotificationIds.add(response.id!);

    // Cancelar a notificação nativa imediatamente para parar o som do sistema
    try {
      await _notificationService._notificationsPlugin.cancel(response.id!);
      await _notificationService._notificationsPlugin.cancelAll();
      print('DEBUG: Notificação nativa ID ${response.id} e todas as notificações canceladas');
      // Verificar notificações pendentes após cancelamento
      final pendingNotifications = await _notificationService._notificationsPlugin.pendingNotificationRequests();
      print('DEBUG: Notificações pendentes após cancelamento: ${pendingNotifications.length}');
    } catch (e) {
      print('DEBUG: Erro ao cancelar notificações: $e');
    }

    try {
      // Dar mais tempo para o app inicializar
      await Future.delayed(const Duration(milliseconds: 2000));

      // Inicializar o banco de dados
      print('DEBUG: Inicializando banco de dados');
      final database = await _initDatabase();
      print('DEBUG: Banco de dados inicializado');

      // Processar o payload
      final payloadParts = response.payload!.split('|');
      if (payloadParts.length < 2) {
        print('DEBUG: ERRO: Payload inválido: ${response.payload}');
        return;
      }
      final horario = payloadParts[0];
      final medicationIds = payloadParts[1].split(',');
      print('DEBUG: Payload processado - Horario: $horario, MedicationIds: $medicationIds');

      // Criar AudioPlayer para gerenciar o som
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

      // Aguardar o NavigatorState com timeout
      print('DEBUG: Aguardando NavigatorState');
      const maxAttempts = 50; // 5 segundos
      int attempts = 0;
      NavigatorState? navigatorState;
      while (navigatorState == null && attempts < maxAttempts) {
        navigatorState = navigatorKey.currentState;
        if (navigatorState == null) {
          print('DEBUG: NavigatorState nulo, aguardando 100ms (tentativa ${attempts + 1}/$maxAttempts)');
          await Future.delayed(const Duration(milliseconds: 100));
          attempts++;
        }
      }

      if (navigatorState == null) {
        print('DEBUG: ERRO: NavigatorState nulo após $maxAttempts tentativas');
        if (audioPlayer != null) {
          await audioPlayer.stop();
          print('DEBUG: AudioPlayer parado devido a NavigatorState nulo');
        }
        return;
      }

      // Navegar para FullScreenNotification
      print('DEBUG: Navegando para FullScreenNotification');
      _isFullScreenNotificationOpen = true;
      try {
        await navigatorState.push(
          MaterialPageRoute(
            builder: (context) => FullScreenNotification(
              horario: horario,
              medicationIds: medicationIds,
              database: database,
              audioPlayer: audioPlayer,
              onClose: () {
                _isFullScreenNotificationOpen = false;
                if (audioPlayer != null) {
                  audioPlayer!.stop();
                  print('DEBUG: AudioPlayer parado no onClose');
                }
                try {
                  _notificationService._notificationsPlugin.cancel(response.id!);
                  print('DEBUG: Notificação nativa ID ${response.id} cancelada no onClose');
                } catch (e) {
                  print('DEBUG: Erro ao cancelar notificação no onClose: $e');
                }
              },
            ),
          ),
        );
        print('DEBUG: Navegação concluída');
      } catch (e) {
        print('DEBUG: Erro durante navegação: $e');
        _isFullScreenNotificationOpen = false;
        if (audioPlayer != null) {
          await audioPlayer.stop();
          print('DEBUG: AudioPlayer parado devido a erro de navegação');
        }
      }
    } catch (e) {
      print('DEBUG: ERRO ao processar notificação: $e');
      _isFullScreenNotificationOpen = false;
    } finally {
      Future.delayed(const Duration(minutes: 1), () => _processedNotificationIds.remove(response.id));
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
        priority: notifications.Priority.max,
        playSound: false,
        showWhen: true,
        visibility: NotificationVisibility.public,
        enableVibration: true,
        enableLights: true,
        autoCancel: true,
        ongoing: false,
        fullScreenIntent: false, // Desativar fullScreenIntent
        timeoutAfter: null,
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

      if (navigatorKey.currentState != null && payload.isNotEmpty) {
        final payloadParts = payload.split('|');
        if (payloadParts.length >= 2) {
          final horario = payloadParts[0];
          final medicationIds = payloadParts[1].split(',');
          print('DEBUG: Fallback - Navegando para FullScreenNotification com horario: $horario, medicationIds: $medicationIds');
          await navigatorKey.currentState!.push(
            MaterialPageRoute(
              builder: (context) => FullScreenNotification(
                horario: horario,
                medicationIds: medicationIds,
                database: _database!,
                onClose: () {
                  _isFullScreenNotificationOpen = false;
                  print('DEBUG: FullScreenNotification fechada');
                },
              ),
            ),
          );
          print('DEBUG: Navegação de fallback concluída');
        }
      }
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

    // Agendar notificação nativa sempre
    try {
      final androidDetails = AndroidNotificationDetails(
        'medication_channel',
        'Lembrete de Medicamento',
        channelDescription: 'Notificações para lembretes de medicamentos',
        importance: Importance.max,
        priority: notifications.Priority.max,
        sound: RawResourceAndroidNotificationSound(sound),
        playSound: true,
        showWhen: true,
        visibility: NotificationVisibility.public,
        enableVibration: true,
        enableLights: true,
        autoCancel: false,
        ongoing: true,
        fullScreenIntent: true,
        timeoutAfter: null,
        category: AndroidNotificationCategory.alarm,
        additionalFlags: Int32List.fromList([4]),
      );
      final notificationDetails = NotificationDetails(android: androidDetails);

      final localTimezone = tz.getLocation('America/Sao_Paulo');
      final tzScheduledTime = tz.TZDateTime.from(scheduledTime, localTimezone);

      await _notificationsPlugin.zonedSchedule(
        id,
        title,
        body ?? 'Você tem medicamentos para tomar',
        tzScheduledTime,
        notificationDetails,
        payload: payload,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      );
      print('DEBUG: Notificação nativa agendada com zonedSchedule');
    } catch (e) {
      print('DEBUG: Erro ao agendar notificação nativa: $e');
    }

    // Timer para navegação direta se o app estiver em primeiro plano
    Timer(Duration(milliseconds: delay), () async {
      print('DEBUG: Timer disparado');
      if (_isFullScreenNotificationOpen) {
        print('DEBUG: FullScreenNotification já aberta, ignorando nova navegação');
        return;
      }

      if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
        // Cancelar a notificação nativa se o app estiver em primeiro plano
        try {
          await _notificationsPlugin.cancel(id);
          print('DEBUG: Notificação nativa ID $id cancelada porque o app está em primeiro plano');
        } catch (e) {
          print('DEBUG: Erro ao cancelar notificação nativa: $e');
        }

        AudioPlayer? player;
        try {
          player = AudioPlayer();
          await player.setSource(AssetSource('sounds/$sound.mp3'));
          await player.setVolume(1.0);
          await player.setReleaseMode(ReleaseMode.loop);
          await player.resume();
          print('DEBUG: Som do alarme iniciado');
        } catch (e) {
          print('DEBUG: Erro ao tocar o som: $e');
          player = null;
        }

        try {
          final navigatorState = navigatorKey.currentState;
          if (navigatorState != null) {
            final payloadParts = payload.split('|');
            if (payloadParts.length >= 2) {
              final horario = payloadParts[0];
              final medicationIds = payloadParts[1].split(',');
              print('DEBUG: Navegando para FullScreenNotification com horario: $horario, medicationIds: $medicationIds');
              _isFullScreenNotificationOpen = true;
              await Future.delayed(Duration(milliseconds: 500));
              SchedulerBinding.instance.scheduleFrameCallback((_) async {
                print('DEBUG: Executando navegação após frame');
                await navigatorState.push(
                  MaterialPageRoute(
                    builder: (context) => FullScreenNotification(
                      horario: horario,
                      medicationIds: medicationIds,
                      database: _database!,
                      audioPlayer: player,
                      onClose: () {
                        _isFullScreenNotificationOpen = false;
                        if (player != null) {
                          player.stop();
                          print('DEBUG: Som do alarme parado');
                        }
                        try {
                          _notificationsPlugin.cancel(id);
                          print('DEBUG: Notificação nativa ID $id cancelada após fechar FullScreenNotification');
                        } catch (e) {
                          print('DEBUG: Erro ao cancelar notificação nativa: $e');
                        }
                      },
                    ),
                  ),
                );
                print('DEBUG: Navegação concluída');
              });
            } else {
              print('DEBUG: ERRO: Payload inválido');
              if (player != null) {
                await player.stop();
                print('DEBUG: Som do alarme parado devido a payload inválido');
              }
            }
          } else {
            print('DEBUG: ERRO: NavigatorState nulo');
            if (player != null) {
              await player.stop();
              print('DEBUG: Som do alarme parado devido a NavigatorState nulo');
            }
          }
        } catch (e) {
          print('DEBUG: Erro ao navegar para FullScreenNotification: $e');
          _isFullScreenNotificationOpen = false;
          if (player != null) {
            await player.stop();
            print('DEBUG: Som do alarme parado devido a erro');
          }
        }
      } else {
        print('DEBUG: App não está em primeiro plano, contando com notificação nativa');
      }
    });

    print('DEBUG: Agendamento configurado com sucesso');
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