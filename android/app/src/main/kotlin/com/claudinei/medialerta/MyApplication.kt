package com.claudinei.medialerta

import android.util.Log
import io.flutter.app.FlutterApplication
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugins.GeneratedPluginRegistrant

class MyApplication : FlutterApplication() {

    companion object {
        var isAlarmMode = false  // Flag para detectar se estamos vindo de um alarme
    }

    override fun onCreate() {
        super.onCreate()

        // Só pré-aquece o FlutterEngine quando NÃO estivermos vindo de um alarme
        if (!isAlarmMode) {
            val engine = FlutterEngine(this)
            GeneratedPluginRegistrant.registerWith(engine)
            engine.dartExecutor.executeDartEntrypoint(DartExecutor.DartEntrypoint.createDefault())
            FlutterEngineCache.getInstance().put("main", engine)
            Log.d("MediAlerta", "FlutterEngine pré-aquecida no MyApplication: $engine")
        } else {
            Log.d("MediAlerta", "Modo alarme ativo: pré-aquecimento do FlutterEngine ignorado")
        }
    }
}