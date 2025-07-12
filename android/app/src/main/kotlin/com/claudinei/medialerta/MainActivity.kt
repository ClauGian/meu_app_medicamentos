package com.claudinei.medialerta

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.os.Bundle
import android.util.Log
import android.content.Intent

class MainActivity : FlutterActivity() {
    private val NAVIGATION_CHANNEL = "com.claudinei.medialerta/navigation"
    private val FULLSCREEN_CHANNEL = "com.claudinei.medialerta/fullscreen"

    private var flutterEngine: FlutterEngine? = null
    // Esta variável manterá os dados do intent inicial que lançou ou retomou a atividade.
    // Ela deve persistir até que um novo intent chegue ou a atividade seja destruída.
    private var initialRouteData: Map<String, Any?>? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        Log.d("MediAlerta", "onCreate chamado, intent inicial: ${intent.extras?.toString()}")
        // Lida com o intent inicial quando a atividade é criada pela primeira vez.
        // Isso irá popular initialRouteData.
        handleIntent(intent)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        this.flutterEngine = flutterEngine
        Log.d("MediAlerta", "configureFlutterEngine iniciado, flutterEngine=$flutterEngine")

        // Não há necessidade de re-manipular o intent ou verificar por nulo aqui.
        // onCreate ou onNewIntent garantem que initialRouteData seja definido.

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, NAVIGATION_CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "getInitialRoute") {
                Log.d("MediAlerta", "getInitialRoute chamado, initialRouteData=$initialRouteData")
                // Retorna o initialRouteData atual. NÃO o defina como null aqui.
                // O FutureBuilder do Flutter consumirá isso.
                val routeData = initialRouteData ?: mapOf(
                    "route" to null,
                    "horario" to null,
                    "medicationIds" to arrayListOf<String>()
                )
                result.success(routeData)
            } else {
                result.notImplemented()
            }
        }

        // Configura o FULLSCREEN_CHANNEL para exibir o alarme em tela cheia a partir do Flutter
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
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK)
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
        Log.d("MediAlerta", "onNewIntent chamado, novo intent: ${intent.extras?.toString()}")
        // Quando um novo intent chega (ex: do FullScreenAlarmActivity), atualiza initialRouteData.
        handleIntent(intent)
    }

    private fun handleIntent(intent: Intent) {
    // Recupera dados do intent
    val route = intent.getStringExtra("route")
    val horario = intent.getStringExtra("horario")
    val medicationIds = intent.getStringArrayListExtra("medicationIds") ?: arrayListOf()
    val payload = intent.getStringExtra("payload")
    val notificationId = intent.getIntExtra("notificationId", -1)

    Log.d("MediAlerta", "handleIntent: route=$route, horario=$horario, medicationIds=$medicationIds, payload=$payload, notificationId=$notificationId")

    // Se o payload estiver presente (vindo da notificação nativa ou FullScreenAlarmActivity), extrair horario e medicationIds
    if (payload != null && payload.contains("|")) {
        val payloadParts = payload.split("|")
        if (payloadParts.size >= 2) {
        val payloadHorario = payloadParts[0]
        val payloadMedicationIds = payloadParts[1].split(",").filter { it.isNotEmpty() }
        Log.d("MediAlerta", "Payload processado: horario=$payloadHorario, medicationIds=$payloadMedicationIds")

        initialRouteData = mapOf(
            "route" to "medication_alert",
            "horario" to payloadHorario,
            "medicationIds" to payloadMedicationIds
        )
        } else {
        Log.d("MediAlerta", "Payload inválido: $payload")
        initialRouteData = mapOf(
            "route" to route,
            "horario" to horario,
            "medicationIds" to medicationIds
        )
        }
    } else {
        initialRouteData = mapOf(
        "route" to route,
        "horario" to horario,
        "medicationIds" to medicationIds
        )
    }

    // Chamar getInitialRoute se o FlutterEngine estiver inicializado
    flutterEngine?.let {
        Log.d("MediAlerta", "flutterEngine inicializado, invocando getInitialRoute")
        MethodChannel(it.dartExecutor.binaryMessenger, NAVIGATION_CHANNEL).invokeMethod(
        "getInitialRoute",
        initialRouteData
        )
    } ?: run {
        Log.d("MediAlerta", "flutterEngine não inicializado, adiando getInitialRoute")
    }
    }
}