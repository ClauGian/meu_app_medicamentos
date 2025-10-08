package com.claudinei.medialerta

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.plugins.GeneratedPluginRegistrant
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val NAVIGATION_CHANNEL = "com.claudinei.medialerta/navigation"
    private val FULLSCREEN_CHANNEL = "com.claudinei.medialerta/fullscreen"
    private var initialRouteData: Map<String, Any?> = mapOf(
        "route" to null,
        "horario" to null,
        "medicationIds" to arrayListOf<String>(),
        "payload" to null,
        "notificationId" to -1
    )
    private var initialIntent: Intent? = null


    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        Log.d("MediAlerta", "onCreate chamado, intent inicial: $intent, extras: ${intent.extras}")

        // Armazenar o Intent inicial
        initialIntent = intent

        // Configurar a engine e processar o intent imediatamente
        configureFlutterEngine(flutterEngine ?: FlutterEngine(this).also {
            FlutterEngineCache.getInstance().put("main", it)
            Log.d("MediAlerta", "Nova FlutterEngine criada e armazenada no cache: $it")
        })
        handleIntent(initialIntent)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        GeneratedPluginRegistrant.registerWith(flutterEngine)
        FlutterEngineCache.getInstance().put("main", flutterEngine)
        Log.d("MediAlerta", "configureFlutterEngine iniciado, flutterEngine=$flutterEngine")

        // Canal de navegação
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, NAVIGATION_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getInitialRoute" -> result.success(initialRouteData)
                "openMedicationAlert" -> {
                    val args = call.arguments as? Map<String, Any>
                    initialRouteData = mapOf(
                        "route" to args?.get("route"),
                        "horario" to args?.get("horario"),
                        "medicationIds" to (args?.get("medicationIds") as? ArrayList<String> ?: arrayListOf()),
                        "payload" to args?.get("payload"),
                        "notificationId" to (args?.get("notificationId") as? Int ?: -1)
                    )
                    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, NAVIGATION_CHANNEL)
                        .invokeMethod("navigateToMedicationAlert", initialRouteData)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        // Canal FullScreen
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, FULLSCREEN_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                // Abrir FullScreen imediatamente
                "showFullScreenAlarm" -> {
                    val args = call.arguments as? Map<String, Any>
                    val horario = args?.get("horario") as? String
                    val medicationIds = args?.get("medicationIds") as? ArrayList<String>
                    val payload = args?.get("payload") as? String
                    val title = args?.get("title") as? String
                    val body = args?.get("body") as? String

                    val intent = Intent(this, FullScreenAlarmActivity::class.java).apply {
                        putExtra("horario", horario)
                        putStringArrayListExtra("medicationIds", medicationIds)
                        putExtra("payload", payload)
                        putExtra("title", title)
                        putExtra("body", body)
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
                    }
                    startActivity(intent)
                    result.success(true)
                }

                // Agendar FullScreen para depois de X segundos (funciona em background)
                "scheduleFullScreen" -> {
                    val args = call.arguments as? Map<String, Any>
                    val horario = args?.get("horario") as? String ?: "08:00"
                    val medicationIds = args?.get("medicationIds") as? ArrayList<String> ?: arrayListOf()
                    val payload = args?.get("payload") as? String
                    val title = args?.get("title") as? String
                    val body = args?.get("body") as? String
                    val delaySeconds = (args?.get("delaySeconds") as? Int) ?: 0

                    val alarmTime = System.currentTimeMillis() + delaySeconds * 1000L
                    val alarmIntent = Intent(this, AlarmReceiver::class.java).apply {
                        putExtra("horario", horario)
                        putStringArrayListExtra("medicationIds", medicationIds)
                        putExtra("payload", payload)
                        putExtra("title", title)
                        putExtra("body", body)
                    }

                    val pendingIntent = PendingIntent.getBroadcast(
                        this,
                        0,
                        alarmIntent,
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                    )

                    val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        alarmManager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, alarmTime, pendingIntent)
                    } else {
                        alarmManager.setExact(AlarmManager.RTC_WAKEUP, alarmTime, pendingIntent)
                    }

                    Log.d("MediAlerta", "✅ Agendamento da FullScreen feito para $delaySeconds segundos depois via BroadcastReceiver")
                    result.success(true)
                }

                else -> result.notImplemented()
            }
        }

        Log.d("MediAlerta", "configureFlutterEngine finalizado - canais registrados")
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        Log.d("MediAlerta", "onNewIntent chamado, novo intent: ${intent?.toString()}, extras: ${intent?.extras?.toString()}")
        handleIntent(intent)
    }

    private fun handleIntent(intent: Intent?) {
        val route = intent?.getStringExtra("route")
        val horario = intent?.getStringExtra("horario")
        val medicationIds = intent?.getStringArrayListExtra("medicationIds") ?: arrayListOf()
        val payload = intent?.getStringExtra("payload")
        val notificationId = intent?.getIntExtra("notificationId", -1)

        Log.d("MediAlerta", "handleIntent chamado com route=$route, horario=$horario, medicationIds=$medicationIds, payload=$payload, notificationId=$notificationId")

        initialRouteData = if (route != null && horario != null && medicationIds.isNotEmpty()) {
            mapOf(
                "route" to route,
                "horario" to horario,
                "medicationIds" to medicationIds,
                "payload" to payload,
                "notificationId" to notificationId
            )
        } else {
            mapOf(
                "route" to null,
                "horario" to null,
                "medicationIds" to arrayListOf<String>(),
                "payload" to null,
                "notificationId" to -1
            )
        }

        Log.d("MediAlerta", "initialRouteData configurado: $initialRouteData")

        val engine = flutterEngine ?: run {
            Log.w("MediAlerta", "flutterEngine é null, tentando recuperar do FlutterEngineCache")
            FlutterEngineCache.getInstance().get("main")?.also {
                Log.d("MediAlerta", "FlutterEngine recuperado do cache: $it")
            } ?: run {
                Log.e("MediAlerta", "Falha ao recuperar FlutterEngine do cache")
                return
            }
        }

        MethodChannel(engine.dartExecutor.binaryMessenger, NAVIGATION_CHANNEL)
            .invokeMethod("navigateToMedicationAlert", initialRouteData)
        Log.d("MediAlerta", "navigateToMedicationAlert invocado com initialRouteData=$initialRouteData")
    }
}
