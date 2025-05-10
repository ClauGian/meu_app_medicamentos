import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:sqflite/sqflite.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'screens/full_screen_notification.dart'; // Importa a nova tela de notificação
import 'dart:typed_data';
import 'package:path/path.dart' as path;
import 'package:flutter/scheduler.dart' hide Priority;
import 'package:flutter_local_notifications/flutter_local_notifications.dart' as notifications;
import 'dart:async'; // Para usar Timer


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

// Função top-level para processar respostas de notificação
Future<void> handleNotificationResponse(NotificationResponse response) async {
  print('DEBUG: Processando notificação - ID: ${response.id}, Payload: ${response.payload}, Action: ${response.actionId}');
  if (response.payload != null && response.id != null) {
    if (_processedNotificationIds.contains(response.id)) {
      print('DEBUG: Notificação ID ${response.id} já processada, ignorando');
      return;
    }
    _processedNotificationIds.add(response.id!);
    try {
      print('DEBUG: Processando payload: ${response.payload}');
      final payloadParts = response.payload!.split('|');
      if (payloadParts.length >= 2) {
        final horario = payloadParts[0];
        final medicationIds = payloadParts[1].split(',');
        print('DEBUG: Navegando para FullScreenNotification com horario: $horario, medicationIds: $medicationIds');
        final navigatorState = NotificationService.navigatorKey.currentState;
        if (navigatorState != null) {
          print('DEBUG: NavigatorState disponível, estado do app: ${WidgetsBinding.instance.lifecycleState}');
          await Future.delayed(Duration(milliseconds: 500)); // Atraso para contexto
          SchedulerBinding.instance.scheduleFrameCallback((_) async {
            print('DEBUG: Executando navegação após frame');
            final database = await _initDatabase();
            await navigatorState.push(
              MaterialPageRoute(
                builder: (context) => FullScreenNotification(
                  horario: horario,
                  medicationIds: medicationIds,
                  database: database,
                ),
              ),
            );
            print('DEBUG: Navegação concluída');
          });
        } else {
          print('DEBUG: ERRO: NavigatorState é nulo, tentativa de navegação falhou');
        }
      } else {
        print('DEBUG: Payload antigo detectado, consultando medicamento com ID: ${response.payload}');
        final database = await _initDatabase();
        final medication = await database.query(
          'medications',
          where: 'id = ?',
          whereArgs: [response.payload],
        );

        if (medication.isNotEmpty) {
          print('DEBUG: Medicamento encontrado: $medication');
          final horario = (medication[0]['horarios'] as String).split(',')[0]; // Usa o primeiro horário
          print('DEBUG: Preparando navegação para FullScreenNotification com medicationId: ${response.payload}');
          final navigatorState = NotificationService.navigatorKey.currentState;
          if (navigatorState != null) {
            print('DEBUG: NavigatorState disponível, estado do app: ${WidgetsBinding.instance.lifecycleState}');
            await Future.delayed(Duration(milliseconds: 500)); // Atraso para contexto
            SchedulerBinding.instance.scheduleFrameCallback((_) async {
              print('DEBUG: Executando navegação após frame');
              await navigatorState.push(
                MaterialPageRoute(
                  builder: (context) => FullScreenNotification(
                    horario: horario,
                    medicationIds: [response.payload!],
                    database: database,
                  ),
                ),
              );
              print('DEBUG: Navegação concluída');
            });
          } else {
            print('DEBUG: ERRO: NavigatorState é nulo, tentativa de navegação falhou');
          }
        } else {
          print('DEBUG: ERRO: Nenhum medicamento encontrado para ID: ${response.payload}');
        }
      }
    } catch (e) {
      print('DEBUG: ERRO ao processar notificação: $e');
    } finally {
      // Limpar IDs processados após um tempo para evitar acúmulo
      Future.delayed(Duration(minutes: 1), () => _processedNotificationIds.remove(response.id));
    }
  } else {
    print('DEBUG: ERRO: Payload ou ID nulo - Payload: ${response.payload}, ID: ${response.id}');
  }
}




class NotificationService {  
  static final NotificationService _notificationService = NotificationService._internal();
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>(); // Chave para navegação
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

      bool? initialized = await _notificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: handleNotificationResponse,
        onDidReceiveBackgroundNotificationResponse: handleNotificationResponse,
      );
      print('DEBUG: FlutterLocalNotificationsPlugin inicializado: $initialized');
      if (initialized != true) {
        print('DEBUG: Falha ao inicializar FlutterLocalNotificationsPlugin');
        return;
      }

      final androidPlugin = _notificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        // Criar grupo de canais
        await androidPlugin.createNotificationChannelGroup(
          const AndroidNotificationChannelGroup(
            'medication_group',
            'Lembretes de Medicamentos',
            description: 'Grupo para lembretes de medicamentos',
          ),
        );
        print('DEBUG: Grupo de canais medication_group criado');

        // Criar canal único para notificações imediatas e agendadas
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
            groupId: 'medication_group', // Associa ao grupo criado
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
        additionalFlags: Int32List.fromList([4]), // Flag para repetir som (FLAG_INSISTENT)
      );
      final notificationDetails = NotificationDetails(android: androidDetails);

      // Adicionar sufixo ao payload para indicar que o fallback será usado
      final modifiedPayload = payload.isNotEmpty ? '$payload|fallback' : payload;

      await _notificationsPlugin.show(
        id,
        title,
        body,
        notificationDetails,
        payload: modifiedPayload, // Usar o payload modificado
      );
      // Fallback para exibir FullScreenNotification diretamente
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

    // Usar Timer para simular o agendamento
    Timer(Duration(milliseconds: delay), () async {
      print('DEBUG: Timer disparado, exibindo FullScreenNotification');
      AudioPlayer? player;
      try {
        // Tocar o som do alarme
        player = AudioPlayer();
        await player.setSource(AssetSource('sounds/$sound.mp3')); // Corrigido para sounds/
        await player.setVolume(1.0);
        await player.setReleaseMode(ReleaseMode.loop); // Repetir o som
        await player.resume();
        print('DEBUG: Som do alarme iniciado');
      } catch (e) {
        print('DEBUG: Erro ao tocar o som: $e');
        player = null; // Continuar mesmo se o som falhar
      }

      try {
        // Navegar diretamente para FullScreenNotification
        final navigatorState = navigatorKey.currentState;
        if (navigatorState != null && payload.isNotEmpty) {
          final payloadParts = payload.split('|');
          if (payloadParts.length >= 2) {
            final horario = payloadParts[0];
            final medicationIds = payloadParts[1].split(',');
            print('DEBUG: Navegando para FullScreenNotification com horario: $horario, medicationIds: $medicationIds');
            await Future.delayed(Duration(milliseconds: 500)); // Atraso para contexto
            SchedulerBinding.instance.scheduleFrameCallback((_) async {
              print('DEBUG: Executando navegação após frame');
              await navigatorState.push(
                MaterialPageRoute(
                  builder: (context) => FullScreenNotification(
                    horario: horario,
                    medicationIds: medicationIds,
                    database: _database!,
                    audioPlayer: player,
                  ),
                ),
              );
              print('DEBUG: Navegação concluída');
            });
          } else {
            print('DEBUG: ERRO: Payload inválido');
            if (player != null) await player.stop();
          }
        } else {
          print('DEBUG: ERRO: NavigatorState é nulo');
          if (player != null) await player.stop();
        }
      } catch (e) {
        print('DEBUG: Erro ao navegar para FullScreenNotification: $e');
        if (player != null) await player.stop();
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

