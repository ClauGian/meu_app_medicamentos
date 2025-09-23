package com.claudinei.medialerta

import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.graphics.BitmapFactory
import android.graphics.Color
import android.media.AudioAttributes
import android.media.AudioManager
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import android.util.Log
import androidx.core.app.NotificationCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.plugins.GeneratedPluginRegistrant
import io.flutter.plugin.common.MethodChannel
import java.util.ArrayList
import android.os.Bundle

class MainActivity : FlutterActivity() {
    private val NAVIGATION_CHANNEL = "com.claudinei.medialerta/navigation"
    private val FULLSCREEN_CHANNEL = "com.claudinei.medialerta/fullscreen"
    private val DEVICE_CHANNEL = "com.claudinei.medialerta/device"
    private val NOTIFICATION_CHANNEL = "com.claudinei.medialerta/notification"
    private val ACTION_CHANNEL = "com.claudinei.medialerta/notification_actions"
    private var initialRouteData: Map<String, Any?> = mapOf(
        "route" to null,
        "horario" to null,
        "medicationIds" to arrayListOf<String>(),
        "payload" to null,
        "notificationId" to -1
    )
    private var notificationActionReceiver: BroadcastReceiver? = null


    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        Log.d("MediAlerta", "onCreate chamado, intent inicial: ${intent?.toString()}, extras: ${intent?.extras?.toString()}")
        createNotificationChannel()
        handleIntent(intent)
    }

    private fun createNotificationChannel() {
        // Canal v2 já criado no configureFlutterEngine; v3 removido para evitar duplicata
        Log.d("MediAlerta", "createNotificationChannel chamado - v2 já configurado")
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        GeneratedPluginRegistrant.registerWith(flutterEngine)
        FlutterEngineCache.getInstance().put("main", flutterEngine)
        Log.d("MediAlerta", "configureFlutterEngine iniciado, flutterEngine=$flutterEngine")

        // ✅ REGISTRO DO BROADCASTRECEIVER - UMA VEZ SÓ, FORA DE QUALQUER METHODCHANNEL
        notificationActionReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context, intent: Intent) {
                if (intent.action == "com.claudinei.medialerta.NOTIFICATION_ACTION") {
                    val notificationId = intent.getIntExtra("notificationId", -1)
                    val payload = intent.getStringExtra("payload")
                    val actionId = intent.getStringExtra("actionId")
                    Log.d("MediAlerta", "✅ BroadcastReceiver: Recebido NOTIFICATION_ACTION - id: $notificationId, payload: $payload, actionId: $actionId")
                    
                    // ✅ VERIFICA SE O FLUTTER ENGINE ESTÁ DISPONÍVEL
                    flutterEngine?.let {
                        try {
                            MethodChannel(it.dartExecutor.binaryMessenger, ACTION_CHANNEL).invokeMethod(
                                "handleNotificationAction",
                                mapOf(
                                    "id" to notificationId,
                                    "payload" to payload,
                                    "actionId" to actionId
                                )
                            )
                            Log.d("MediAlerta", "✅ Método handleNotificationAction invocado com sucesso")
                        } catch (e: Exception) {
                            Log.e("MediAlerta", "❌ Erro ao invocar handleNotificationAction: ${e.message}", e)
                        }
                    } ?: run {
                        Log.w("MediAlerta", "⚠️ FlutterEngine não disponível para processar NOTIFICATION_ACTION")
                    }
                }
            }
        }
        
        // ✅ REGISTRA O RECEIVER UMA VEZ SÓ
        try {
            registerReceiver(notificationActionReceiver, IntentFilter("com.claudinei.medialerta.NOTIFICATION_ACTION"))
            Log.d("MediAlerta", "✅ BroadcastReceiver registrado para NOTIFICATION_ACTION")
        } catch (e: Exception) {
            Log.e("MediAlerta", "❌ Erro ao registrar BroadcastReceiver: ${e.message}", e)
        }

        // REGISTRO IMEDIATO DO CANAL DE NAVEGAÇÃO (com when para getInitialRoute e openMedicationAlert)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, NAVIGATION_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getInitialRoute" -> {
                    Log.d("MediAlerta", "getInitialRoute chamado, initialRouteData=$initialRouteData")
                    result.success(initialRouteData)
                }
                "openMedicationAlert" -> {
                    val args = call.arguments as? Map<String, Any>
                    val route = args?.get("route") as? String ?: "medication_alert"
                    val horario = args?.get("horario") as? String
                    val medicationIds = args?.get("medicationIds") as? ArrayList<String> ?: arrayListOf()
                    val payload = args?.get("payload") as? String
                    val notificationId = args?.get("notificationId") as? Int ?: -1
                    Log.d("MediAlerta", "openMedicationAlert chamado - route=$route, horario=$horario, medicationIds=$medicationIds, payload=$payload, notificationId=$notificationId")
                    
                    // Atualiza initialRouteData para forçar navegação no Flutter
                    initialRouteData = mapOf(
                        "route" to route,
                        "horario" to horario,
                        "medicationIds" to medicationIds,
                        "payload" to payload,
                        "notificationId" to notificationId
                    )
                    
                    // Invoca navigateToMedicationAlert no Flutter para navegar imediatamente
                    try {
                        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, NAVIGATION_CHANNEL).invokeMethod(
                            "navigateToMedicationAlert",
                            initialRouteData
                        )
                        Log.d("MediAlerta", "Navegação para MedicationAlert via openMedicationAlert invocada com sucesso")
                        result.success(true)
                    } catch (e: Exception) {
                        Log.e("MediAlerta", "Erro ao invocar navigateToMedicationAlert: ${e.message}", e)
                        result.error("NAVIGATION_ERROR", "Falha ao navegar: ${e.message}", null)
                    }
                }
                else -> result.notImplemented()
            }
        }
        Log.d("MediAlerta", "Canal de navegação registrado com sucesso")

        // REGISTRO IMEDIATO DO CANAL DEVICE (para resolver MissingPlugin para bateria)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, DEVICE_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "isInDozeMode" -> {
                    val powerManager = getSystemService(POWER_SERVICE) as PowerManager
                    val isInDoze = powerManager.isDeviceIdleMode
                    Log.d("MediAlerta", "isInDozeMode chamado, resultado: $isInDoze")
                    result.success(isInDoze)
                }
                "isIgnoringBatteryOptimizations" -> {
                    val powerManager = getSystemService(POWER_SERVICE) as PowerManager
                    val packageName = packageName
                    val isIgnoring = powerManager.isIgnoringBatteryOptimizations(packageName)
                    Log.d("MediAlerta", "isIgnoringBatteryOptimizations chamado, resultado: $isIgnoring")
                    result.success(isIgnoring)
                }
                "requestBatteryOptimizationsExemption" -> {
                    try {
                        val powerManager = getSystemService(POWER_SERVICE) as PowerManager
                        val packageName = packageName
                        if (!powerManager.isIgnoringBatteryOptimizations(packageName)) {
                            val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                                data = Uri.parse("package:$packageName")
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            startActivity(intent)
                            Log.d("MediAlerta", "Solicitação de isenção de otimizações de bateria iniciada")
                            result.success(true)
                        } else {
                            Log.d("MediAlerta", "Isenção de otimizações de bateria já concedida")
                            result.success(true)
                        }
                    } catch (e: Exception) {
                        Log.e("MediAlerta", "Erro ao solicitar isenção de otimizações de bateria: ${e.message}", e)
                        result.error("BATTERY_OPTIMIZATION_ERROR", "Falha ao solicitar isenção: ${e.message}", null)
                    }
                }
                else -> result.notImplemented()
            }
        }
        Log.d("MediAlerta", "Canal device registrado com sucesso")

        // Criar canal de notificação (corrigido: vibração simples para parar som rápido)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                "medication_channel_v3",
                "Lembrete de Medicamento",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Canal para lembretes de medicamentos com som nativo"
                enableLights(true)
                lightColor = Color.BLUE
                enableVibration(true)
                vibrationPattern = longArrayOf(0, 1000)
                setSound(
                    Uri.parse("android.resource://${packageName}/raw/malta"),
                    AudioAttributes.Builder()
                        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .setUsage(AudioAttributes.USAGE_ALARM)
                        .setFlags(AudioAttributes.FLAG_AUDIBILITY_ENFORCED) // Forçar som mesmo em modo silencioso
                        .build()
                )
                setBypassDnd(true) // Ignorar modo "Não Perturbe"
                setShowBadge(true)
                Log.d("MediAlerta", "Canal de notificação medication_channel_v3 configurado com som malta e USAGE_ALARM")
            }
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannel(channel)
            Log.d("MediAlerta", "Canal de notificação medication_channel_v3 criado")
        }

        // ✅ METHODCHANNEL DE NOTIFICAÇÃO - SEM BroadcastReceiver aqui!
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.claudinei.medialerta/notification").setMethodCallHandler { call, result ->
            Log.d("MediAlerta", "MethodChannel com.claudinei.medialerta/notification chamado: method=${call.method}, arguments=${call.arguments}")
            when (call.method) {
                "createSnoozePendingIntent" -> {
                    val notificationId = call.argument<Int>("notificationId") ?: -1
                    val payload = call.argument<String>("payload")
                    Log.d("MediAlerta", "createSnoozePendingIntent chamado - notificationId: $notificationId, payload: $payload")
                    try {
                        val snoozeIntent = Intent(context, SnoozeActionReceiver::class.java).apply {
                            action = "com.claudinei.medialerta.SNOOZE_ACTION"
                            putExtra("notificationId", notificationId)
                            putExtra("payload", payload)
                            putExtra("action_id", "snooze_action")
                        }
                        val pendingIntent = PendingIntent.getBroadcast(
                            context,
                            notificationId,
                            snoozeIntent,
                            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                        )
                        Log.d("MediAlerta", "PendingIntent criado com sucesso para snooze_action")
                        result.success(pendingIntent)
                    } catch (e: Exception) {
                        Log.e("MediAlerta", "Erro ao criar PendingIntent: ${e.message}", e)
                        result.error("PENDING_INTENT_ERROR", "Falha ao criar PendingIntent: ${e.message}", null)
                    }
                }
                "showNotification" -> {
                    val id = call.argument<Int>("id") ?: -1
                    val title = call.argument<String>("title") ?: "Hora do Medicamento"
                    val body = call.argument<String>("body") ?: "Toque para ver os medicamentos"
                    val sound = call.argument<String>("sound") ?: "malta"
                    val payload = call.argument<String>("payload")
                    Log.d("MediAlerta", "showNotification chamado - id: $id, title: $title, body: $body, sound: $sound, payload: $payload")

                    try {
                        // Verificar se o arquivo de som existe
                        val soundUri = Uri.parse("android.resource://${context.packageName}/raw/$sound")
                        try {
                            context.contentResolver.openInputStream(soundUri)?.close()
                            Log.d("MediAlerta", "Arquivo de som $sound encontrado em raw")
                        } catch (e: Exception) {
                            Log.e("MediAlerta", "Arquivo de som $sound não encontrado em raw: ${e.message}")
                        }

                        // Configurar o volume do canal STREAM_ALARM
                        val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
                        audioManager.setStreamVolume(
                            AudioManager.STREAM_ALARM,
                            audioManager.getStreamMaxVolume(AudioManager.STREAM_ALARM),
                            0
                        )
                        Log.d("MediAlerta", "Volume configurado para STREAM_ALARM com volume máximo")

                        // Criar PendingIntent para view_action
                        val viewIntent = Intent(context, MainActivity::class.java).apply {
                            action = "com.claudinei.medialerta.VIEW_ACTION"
                            putExtra("notificationId", id)
                            putExtra("payload", payload)
                            putExtra("action_id", "view_action")
                            addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
                        }
                        val viewPendingIntent = PendingIntent.getActivity(
                            context,
                            id,
                            viewIntent,
                            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                        )

                        // Criar PendingIntent para snooze_action
                        val snoozeIntent = Intent(context, SnoozeActionReceiver::class.java).apply {
                            action = "com.claudinei.medialerta.SNOOZE_ACTION"
                            putExtra("notificationId", id)
                            putExtra("payload", payload)
                            putExtra("action_id", "snooze_action")
                            putExtra("title", title)
                            putExtra("body", body)
                            putExtra("sound", sound)
                        }
                        val snoozePendingIntent = PendingIntent.getBroadcast(
                            context,
                            id + 1000,
                            snoozeIntent,
                            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                        )

                        // Criar notificação
                        val notification = NotificationCompat.Builder(context, "medication_channel_v3")
                            .setContentTitle(title)
                            .setContentText(body)
                            .setSmallIcon(R.mipmap.ic_launcher)
                            .setLargeIcon(BitmapFactory.decodeResource(context.resources, R.mipmap.ic_launcher))
                            .setPriority(NotificationCompat.PRIORITY_MAX)
                            .setSound(soundUri, AudioManager.STREAM_ALARM)
                            .setVibrate(longArrayOf(0, 1000))
                            .setLights(Color.BLUE, 1000, 500)
                            .setAutoCancel(false)
                            .setOngoing(true)
                            .setOnlyAlertOnce(false) // Permitir som em cada exibição
                            .setCategory(NotificationCompat.CATEGORY_ALARM)
                            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
                            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
                            .addAction(0, "Ver", viewPendingIntent)
                            .addAction(0, "Adiar 15 minutos", snoozePendingIntent)
                            .setFullScreenIntent(viewPendingIntent, true)
                            .build()

                        // Exibir notificação
                        val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                        notificationManager.notify(id, notification)
                        Log.d("MediAlerta", "✅ Notificação exibida com sucesso no Android - id: $id")
                        result.success(true)
                    } catch (e: Exception) {
                        Log.e("MediAlerta", "❌ Erro ao exibir notificação: ${e.message}", e)
                        result.error("NOTIFICATION_ERROR", "Falha ao exibir notificação: ${e.message}", null)
                    }
                }
                "scheduleNotification" -> {
                    val id = call.argument<Int>("id") ?: -1
                    val title = call.argument<String>("title") ?: "Hora do Medicamento"
                    val body = call.argument<String>("body") ?: "Toque para ver os medicamentos"
                    val sound = call.argument<String>("sound") ?: "malta"
                    val payload = call.argument<String>("payload")
                    val scheduledTime = call.argument<Long>("scheduledTime") ?: 0L
                    Log.d("MediAlerta", "scheduleNotification chamado - id: $id, title: $title, body: $body, sound: $sound, payload: $payload, scheduledTime: $scheduledTime")

                    try {
                        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
                        val intent = Intent(context, SnoozeActionReceiver::class.java).apply {
                            action = "com.claudinei.medialerta.SHOW_NOTIFICATION"
                            putExtra("notificationId", id)
                            putExtra("title", title)
                            putExtra("body", body)
                            putExtra("sound", sound)
                            putExtra("payload", payload)
                        }
                        val pendingIntent = PendingIntent.getBroadcast(
                            context,
                            id + 2000,
                            intent,
                            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                        )

                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            alarmManager.setExactAndAllowWhileIdle(
                                AlarmManager.RTC_WAKEUP,
                                scheduledTime,
                                pendingIntent
                            )
                        } else {
                            alarmManager.setExact(
                                AlarmManager.RTC_WAKEUP,
                                scheduledTime,
                                pendingIntent
                            )
                        }
                        Log.d("MediAlerta", "✅ Notificação agendada com sucesso para $scheduledTime - id: $id")
                        result.success(true)
                    } catch (e: Exception) {
                        Log.e("MediAlerta", "❌ Erro ao agendar notificação: ${e.message}", e)
                        result.error("SCHEDULE_ERROR", "Falha ao agendar notificação: ${e.message}", null)
                    }
                }
                else -> result.notImplemented()
            }
            // ✅ NÃO HÁ MAIS BroadcastReceiver aqui - já foi registrado acima!
        }
        Log.d("MediAlerta", "Canal de notificação registrado com sucesso")

        // Placeholder para FULLSCREEN_CHANNEL (seu código original)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, FULLSCREEN_CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "showFullScreenAlarm") {
                val args = call.arguments as? Map<String, Any>
                val horario = args?.get("horario") as? String
                val medicationIds = args?.get("medicationIds") as? ArrayList<String>
                val payload = args?.get("payload") as? String
                val title = args?.get("title") as? String
                val body = args?.get("body") as? String
                Log.d("MediAlerta", "showFullScreenAlarm chamado do Flutter. Horário: $horario, IDs: $medicationIds, Payload: $payload, Título: $title, Corpo: $body")
                try {
                    val alarmIntent = Intent(this, FullScreenAlarmActivity::class.java).apply {
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_EXCLUDE_FROM_RECENTS)
                        putExtra("horario", horario)
                        putExtra("medicationIds", medicationIds)
                        putExtra("payload", payload)
                        putExtra("title", title)
                        putExtra("body", body)
                    }
                    startActivity(alarmIntent)
                    Log.d("MediAlerta", "Intent para FullScreenAlarmActivity disparado com sucesso")
                    result.success(true)
                } catch (e: Exception) {
                    Log.e("MediAlerta", "Erro ao disparar FullScreenAlarmActivity: ${e.message}", e)
                    result.error("FULLSCREEN_ERROR", "Falha ao iniciar FullScreenAlarmActivity: ${e.message}", null)
                }
            } else {
                result.notImplemented()
            }
        }

        // Placeholder para ACTION_CHANNEL (seu código original)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, ACTION_CHANNEL).setMethodCallHandler { call, result ->
            Log.d("MediAlerta", "MethodChannel $ACTION_CHANNEL chamado: method=${call.method}, arguments=${call.arguments}")
            result.notImplemented()
        }
        
        Log.d("MediAlerta", "✅ configureFlutterEngine finalizado - todos os canais registrados") // <-- Fechamento do configureFlutterEngine
 
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, DEVICE_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "isInDozeMode" -> {
                    val powerManager = getSystemService(POWER_SERVICE) as PowerManager
                    val isInDoze = powerManager.isDeviceIdleMode
                    Log.d("MediAlerta", "isInDozeMode chamado, resultado: $isInDoze")
                    result.success(isInDoze)
                }
                "isIgnoringBatteryOptimizations" -> {
                    val powerManager = getSystemService(POWER_SERVICE) as PowerManager
                    val packageName = packageName
                    val isIgnoring = powerManager.isIgnoringBatteryOptimizations(packageName)
                    Log.d("MediAlerta", "isIgnoringBatteryOptimizations chamado, resultado: $isIgnoring")
                    result.success(isIgnoring)
                }
                "requestBatteryOptimizationsExemption" -> {
                    try {
                        val powerManager = getSystemService(POWER_SERVICE) as PowerManager
                        val packageName = packageName
                        if (!powerManager.isIgnoringBatteryOptimizations(packageName)) {
                            val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                                data = Uri.parse("package:$packageName")
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            startActivity(intent)
                            Log.d("MediAlerta", "Solicitação de isenção de otimizações de bateria iniciada")
                            result.success(true)
                        } else {
                            Log.d("MediAlerta", "Isenção de otimizações de bateria já concedida")
                            result.success(true)
                        }
                    } catch (e: Exception) {
                        Log.e("MediAlerta", "Erro ao solicitar isenção de otimizações de bateria: ${e.message}", e)
                        result.error("BATTERY_OPTIMIZATION_ERROR", "Falha ao solicitar isenção: ${e.message}", null)
                    }
                }
                "setAudioModeToAlarm" -> {
                    try {
                        val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
                        audioManager.setStreamVolume(
                            AudioManager.STREAM_ALARM,
                            audioManager.getStreamMaxVolume(AudioManager.STREAM_ALARM),
                            0
                        )
                        Log.d("MediAlerta", "Volume configurado para STREAM_ALARM com volume máximo")
                        result.success(true)
                    } catch (e: Exception) {
                        Log.e("MediAlerta", "Erro ao configurar volume para STREAM_ALARM: ${e.message}", e)
                        result.error("AUDIO_ERROR", "Falha ao configurar volume: ${e.message}", null)
                    }
                }
                else -> result.notImplemented()
            }
        }
        Log.d("MediAlerta", "Canal device registrado com sucesso")
    }



    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        Log.d("MediAlerta", "onNewIntent chamado, novo intent: ${intent?.toString()}, extras: ${intent?.extras?.toString()}")
        handleIntent(intent)
    }

    override fun onDestroy() {
        super.onDestroy()
        try {
            notificationActionReceiver?.let {
                unregisterReceiver(it)
                Log.d("MediAlerta", "BroadcastReceiver unregistered no onDestroy")
            }
        } catch (e: IllegalArgumentException) {
            // Ignora se já foi unregistered ou não registrado
            Log.d("MediAlerta", "Receiver já unregistered ou não encontrado")
        } catch (e: Exception) {
            Log.e("MediAlerta", "Erro ao unregister receiver: ${e.message}", e)
        }
    }

    private fun handleIntent(intent: Intent?) {
        val route = intent?.getStringExtra("route")
        val horario = intent?.getStringExtra("horario")
        val medicationIds = intent?.getStringArrayListExtra("medicationIds") ?: arrayListOf()
        val payload = intent?.getStringExtra("payload")
        val notificationId = intent?.getIntExtra("notificationId", -1)
        val actionId = intent?.getStringExtra("action_id") // Padrão do flutter_local_notifications
        val alternativeActionId = intent?.getStringExtra("org.radarbase.fcm.action") // Possível chave alternativa
        val clickAction = intent?.getStringExtra("click_action") // Outra possível chave

        // 🔹 Logar todas as chaves e valores do Intent para depuração
        val extras = intent?.extras
        Log.d("MediAlerta", "handleIntent: Intent extras: ${extras?.keySet()?.joinToString(", ") ?: "nenhum"}")
        if (extras != null) {
            for (key in extras.keySet()) {
                Log.d("MediAlerta", "handleIntent: Extra key=$key, value=${extras.get(key)}")
            }
        }
        Log.d("MediAlerta", "handleIntent: route=$route, horario=$horario, medicationIds=$medicationIds, payload=$payload, notificationId=$notificationId, actionId=$actionId, alternativeActionId=$alternativeActionId, clickAction=$clickAction")

        // NOVA ADIÇÃO: Cancelar a notificação imediatamente se for "view_action" para parar o som nativo
        if (actionId == "view_action" && notificationId != -1) {
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.cancel(notificationId!!)
            Log.d("MediAlerta", "Notificação cancelada imediatamente no handleIntent para id=$notificationId (view_action)")
            
            // NOVA ADIÇÃO: Forçar stop do som nativo via AudioManager
            val audioManager = getSystemService(Context.AUDIO_SERVICE) as android.media.AudioManager
            audioManager.adjustStreamVolume(android.media.AudioManager.STREAM_NOTIFICATION, android.media.AudioManager.ADJUST_MUTE, 0)
            Log.d("MediAlerta", "Som de notificação mutado via AudioManager para id=$notificationId")
        }

        // 🔹 Passar actionId para o Flutter via MethodChannel
        if (notificationId != -1 && (actionId != null || alternativeActionId != null || clickAction != null)) {
            flutterEngine?.let {
                MethodChannel(it.dartExecutor.binaryMessenger, ACTION_CHANNEL).invokeMethod(
                    "handleNotificationAction",
                    mapOf(
                        "id" to notificationId,
                        "payload" to payload,
                        "actionId" to (actionId ?: alternativeActionId ?: clickAction)
                    )
                )
            }
        }

        initialRouteData = if (route != null && horario != null && medicationIds.isNotEmpty()) {
            mapOf(
                "route" to route,
                "horario" to horario,
                "medicationIds" to medicationIds,
                "payload" to payload,
                "notificationId" to notificationId
            )
        } else if (payload != null && payload.contains("|") && (actionId != "snooze_action" && alternativeActionId != "snooze_action" && clickAction != "snooze_action")) {
            val payloadParts = payload.split("|")
            if (payloadParts.size >= 2) {
                val payloadHorario = payloadParts[0]
                val payloadMedicationIds = payloadParts[1].split(",").filter { it.isNotEmpty() }
                Log.d("MediAlerta", "Payload processado: horario=$payloadHorario, medicationIds=$payloadMedicationIds")
                mapOf(
                    "route" to "medication_alert",
                    "horario" to payloadHorario,
                    "medicationIds" to payloadMedicationIds,
                    "payload" to payload,
                    "notificationId" to notificationId
                )
            } else {
                Log.d("MediAlerta", "Payload inválido: $payload")
                mapOf(
                    "route" to null,
                    "horario" to null,
                    "medicationIds" to arrayListOf<String>(),
                    "payload" to null,
                    "notificationId" to -1
                )
            }
        } else {
            mapOf(
                "route" to null,
                "horario" to null,
                "medicationIds" to arrayListOf<String>(),
                "payload" to null,
                "notificationId" to -1
            )
        }

        if (actionId == null || actionId == "view_action" || alternativeActionId == null || alternativeActionId == "view_action" || clickAction == null || clickAction == "view_action") {
            flutterEngine?.let {
                MethodChannel(it.dartExecutor.binaryMessenger, NAVIGATION_CHANNEL).invokeMethod(
                    "navigateToMedicationAlert",
                    initialRouteData
                )
            }
        }
    }
}