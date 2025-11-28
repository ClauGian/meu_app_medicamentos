package com.claudinei.medialerta

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

class AlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        Log.d("MediAlerta", "🔔 AlarmReceiver acionado! Iniciando FullScreenAlarmActivity...")

        val horario = intent?.getStringExtra("horario")
        val medicationIds = intent?.getStringArrayListExtra("medicationIds")
        val payload = intent?.getStringExtra("payload")
        val title = intent?.getStringExtra("title")
        val body = intent?.getStringExtra("body")
        
        // Extrair o som do payload (formato: "horario|ids|sound")
        val sound = if (payload != null && payload.contains("|")) {
            val parts = payload.split("|")
            if (parts.size >= 3) parts[2] else "malta"
        } else {
            "malta"
        }

        Log.d("MediAlerta", "Som extraído do payload: $sound")

        val fullIntent = Intent(context, FullScreenAlarmActivity::class.java).apply {
            putExtra("horario", horario)
            putStringArrayListExtra("medicationIds", medicationIds)
            putExtra("payload", payload)
            putExtra("title", title)
            putExtra("body", body)
            putExtra("sound", sound)  // <- ADICIONAR ESTA LINHA
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_EXCLUDE_FROM_RECENTS)
        }

        try {
            context.startActivity(fullIntent)
        } catch (e: Exception) {
            Log.e("MediAlerta", "Erro ao iniciar FullScreenAlarmActivity: ${e.message}")
        }
    }
}
