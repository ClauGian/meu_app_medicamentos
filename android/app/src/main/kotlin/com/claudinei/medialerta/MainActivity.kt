package com.claudinei.medialerta

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.plugin.common.MethodChannel
import android.os.Bundle
import android.util.Log
import android.content.Intent

class MainActivity : FlutterActivity() {
    private val NAVIGATION_CHANNEL = "com.claudinei.medialerta/navigation"
    private val FULLSCREEN_CHANNEL = "com.claudinei.medialerta/fullscreen"

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

                val alarmIntent = Intent(this, FullScreenAlarmActivity::class.java).apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    putExtra("horario", horario)
                    putExtra("medicationIds", medicationIds)
                    putExtra("payload", payload)
                    putExtra("title", title)
                    putExtra("body", body)
                }
                startActivity(alarmIntent)
                result.success(true)
            } else {
                result.notImplemented()
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