package com.claudinei.medialerta

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.plugin.common.MethodChannel
import android.os.Bundle
import android.util.Log
import android.content.Intent
import android.os.PowerManager
import android.provider.Settings

class MainActivity : FlutterActivity() {
    private val NAVIGATION_CHANNEL = "com.claudinei.medialerta/navigation"
    private val FULLSCREEN_CHANNEL = "com.claudinei.medialerta/fullscreen"
    private val DEVICE_CHANNEL = "com.claudinei.medialerta/device"

    private var flutterEngine: FlutterEngine? = null
    private var initialRouteData: Map<String, Any?>? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        Log.d("MediAlerta", "onCreate chamado, intent inicial: ${intent.extras?.toString()}")
        handleIntent(intent)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        this.flutterEngine = flutterEngine
        FlutterEngineCache.getInstance().put("main", flutterEngine)
        Log.d("MediAlerta", "configureFlutterEngine iniciado, flutterEngine=$flutterEngine")

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, NAVIGATION_CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "getInitialRoute") {
                Log.d("MediAlerta", "getInitialRoute chamado, initialRouteData=$initialRouteData")
                result.success(initialRouteData)
            } else {
                result.notImplemented()
            }
        }

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
                                data = android.net.Uri.parse("package:$packageName")
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
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        Log.d("MediAlerta", "onNewIntent chamado, novo intent: ${intent.extras?.toString()}")
        handleIntent(intent)
        flutterEngine?.let {
            MethodChannel(it.dartExecutor.binaryMessenger, NAVIGATION_CHANNEL).invokeMethod(
                "navigateToMedicationAlert",
                initialRouteData
            )
        }
    }

    private fun handleIntent(intent: Intent?) {
        val route = intent?.getStringExtra("route")
        val horario = intent?.getStringExtra("horario")
        val medicationIds = intent?.getStringArrayListExtra("medicationIds") ?: arrayListOf()
        val payload = intent?.getStringExtra("payload")
        val notificationId = intent?.getIntExtra("notificationId", -1)

        Log.d("MediAlerta", "handleIntent: route=$route, horario=$horario, medicationIds=$medicationIds, payload=$payload, notificationId=$notificationId")

        initialRouteData = if (route != null && horario != null && medicationIds.isNotEmpty()) {
            mapOf(
                "route" to route,
                "horario" to horario,
                "medicationIds" to medicationIds,
                "payload" to payload,
                "notificationId" to notificationId
            )
        } else if (payload != null && payload.contains("|")) {
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
    }
}