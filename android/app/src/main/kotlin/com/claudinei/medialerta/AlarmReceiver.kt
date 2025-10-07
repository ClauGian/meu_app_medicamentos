package com.claudinei.medialerta

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

class AlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        Log.d("MediAlerta", "🔔 AlarmReceiver acionado! Iniciando FullScreenAlarmActivity...")

        val fullIntent = Intent(context, FullScreenAlarmActivity::class.java).apply {
            putExtra("horario", intent?.getStringExtra("horario"))
            putStringArrayListExtra("medicationIds", intent?.getStringArrayListExtra("medicationIds"))
            putExtra("payload", intent?.getStringExtra("payload"))
            putExtra("title", intent?.getStringExtra("title"))
            putExtra("body", intent?.getStringExtra("body"))
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_EXCLUDE_FROM_RECENTS)
        }

        try {
            context.startActivity(fullIntent)
        } catch (e: Exception) {
            Log.e("MediAlerta", "Erro ao iniciar FullScreenAlarmActivity: ${e.message}")
        }
    }
}
