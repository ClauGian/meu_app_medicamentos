package com.claudinei.medialerta

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.Intent
import com.claudinei.medialerta.FullScreenAlarmActivity

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.claudinei.medialerta/fullscreen").setMethodCallHandler { call, result ->
            if (call.method == "showFullScreenAlarm") {
                val title = call.argument<String>("title") ?: "Hora do Medicamento"
                val body = call.argument<String>("body") ?: "Toque para ver os medicamentos"
                val intent = Intent(this, FullScreenAlarmActivity::class.java).apply {
                    putExtra("notification_title", title)
                    putExtra("notification_body", body)
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                startActivity(intent)
                result.success(true)
            } else {
                result.notImplemented()
            }
        }
    }
}
