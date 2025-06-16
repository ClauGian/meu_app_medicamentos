package com.claudinei.medialerta

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.os.Bundle
import android.util.Log
import android.content.Intent

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.claudinei.medialerta/navigation"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Canal de navegação
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.claudinei.medialerta/navigation").setMethodCallHandler { call, result ->
            if (call.method == "getInitialRoute") {
                val route = intent.getStringExtra("route")
                val horario = intent.getStringExtra("horario")
                val medicationIds = intent.getStringArrayListExtra("medicationIds") ?: arrayListOf()
                Log.d("MediAlerta", "MainActivity: route=$route, horario=$horario, medicationIds=$medicationIds")
                
                if (route == "medication_alert") {
                    result.success(mapOf(
                        "route" to route,
                        "horario" to (horario ?: "08:00"),
                        "medicationIds" to medicationIds
                    ))
                } else {
                    result.success(null)
                }
            } else {
                result.notImplemented()
            }
        }
        // Canal para fullscreen
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
        val route = intent.getStringExtra("route")
        val horario = intent.getStringExtra("horario")
        val medicationIds = intent.getStringArrayListExtra("medicationIds") ?: arrayListOf()
        Log.d("MediAlerta", "onCreate: route=$route, horario=$horario, medicationIds=$medicationIds")
    }
}