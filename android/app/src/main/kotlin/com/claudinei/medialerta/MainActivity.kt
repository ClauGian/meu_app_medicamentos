package com.claudinei.medialerta

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.os.Bundle
import android.util.Log
import android.content.Intent
import android.os.Handler
import android.os.Looper

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.claudinei.medialerta/navigation"
    private var flutterEngine: FlutterEngine? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        this.flutterEngine = flutterEngine
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "getInitialRoute") {
                Log.d("MediAlerta", "getInitialRoute chamado")
                result.success(null) // Não usaremos mais getInitialRoute
            } else {
                result.notImplemented()
            }
        }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.claudinei.medialerta/fullscreen").setMethodCallHandler { call, result ->
            if (call.method == "showFullScreenAlarm") {
                val body = call.argument<String>("body")
                Log.d("MediAlerta", "showFullScreenAlarm chamado com body: $body")
                val intent = Intent(this, FullScreenAlarmActivity::class.java).apply {
                    putExtra("body", body)
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                startActivity(intent)
                result.success(true)
            } else {
                result.notImplemented()
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleIntent(intent)
    }

    private fun handleIntent(intent: Intent) {
        val route = intent.getStringExtra("route")
        val horario = intent.getStringExtra("horario")
        val medicationIds = intent.getStringArrayListExtra("medicationIds") ?: arrayListOf()
        Log.d("MediAlerta", "handleIntent: route=$route, horario=$horario, medicationIds=$medicationIds")
        if (route == "medication_alert" && medicationIds.isNotEmpty()) {
            // Aguardar até que flutterEngine esteja inicializado
            Handler(Looper.getMainLooper()).postDelayed({
                flutterEngine?.let {
                    MethodChannel(it.dartExecutor.binaryMessenger, CHANNEL).invokeMethod(
                        "navigateToMedicationAlert",
                        mapOf(
                            "horario" to (horario ?: "08:00"),
                            "medicationIds" to medicationIds
                        )
                    )
                    Log.d("MediAlerta", "navigateToMedicationAlert invocado com horario=$horario, medicationIds=$medicationIds")
                } ?: Log.e("MediAlerta", "flutterEngine é nulo, não foi possível invocar navigateToMedicationAlert")
            }, 500) // Atraso de 500ms para garantir inicialização
        }
    }
}