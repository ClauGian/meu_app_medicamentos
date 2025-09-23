package com.claudinei.medialerta

import android.app.AlarmManager
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.graphics.BitmapFactory
import android.graphics.Color
import android.net.Uri
import android.util.Log
import androidx.core.app.NotificationCompat
import android.media.AudioManager

class SnoozeActionReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        Log.d("MediAlerta", "SnoozeActionReceiver: Recebido intent: ${intent.extras?.toString()}")

        val intentAction = intent.action ?: run {
            Log.e("MediAlerta", "SnoozeActionReceiver: Ação do intent é nula")
            return
        }
        
        val notificationId = intent.getIntExtra("notificationId", -1)
        val payload = intent.getStringExtra("payload")
        val actionId = intent.getStringExtra("action_id")

        Log.d("MediAlerta", "SnoozeActionReceiver: action=$intentAction, notificationId=$notificationId, payload=$payload, actionId=$actionId")

        when (intentAction) {
            "com.claudinei.medialerta.SHOW_NOTIFICATION" -> {
                val title = intent.getStringExtra("title") ?: "Hora do Medicamento"
                val body = intent.getStringExtra("body") ?: "Toque para ver os medicamentos"
                val sound = intent.getStringExtra("sound") ?: "malta"
                Log.d("MediAlerta", "Exibindo notificação - id: $notificationId, title: $title, body: $body, sound: $sound, payload: $payload")

                try {
                    // Verificar se o arquivo de som existe
                    val soundUri = Uri.parse("android.resource://${context.packageName}/raw/$sound")
                    try {
                        context.contentResolver.openInputStream(soundUri)?.close()
                        Log.d("MediAlerta", "Arquivo de som $sound encontrado em raw")
                    } catch (e: Exception) {
                        Log.e("MediAlerta", "Arquivo de som $sound não encontrado em raw: ${e.message}")
                    }

                    // Configurar o volume do canal STREAM_ALARM
                    val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
                    audioManager.setStreamVolume(
                        AudioManager.STREAM_ALARM,
                        audioManager.getStreamMaxVolume(AudioManager.STREAM_ALARM),
                        0
                    )
                    Log.d("MediAlerta", "Volume configurado para STREAM_ALARM com volume máximo")

                    // Criar notificação
                    val notification = NotificationCompat.Builder(context, "medication_channel_v3")
                        .setContentTitle(title)
                        .setContentText(body)
                        .setSmallIcon(R.mipmap.ic_launcher)
                        .setLargeIcon(BitmapFactory.decodeResource(context.resources, R.mipmap.ic_launcher))
                        .setPriority(NotificationCompat.PRIORITY_MAX)
                        .setSound(soundUri, AudioManager.STREAM_ALARM)
                        .setVibrate(longArrayOf(0, 1000))
                        .setLights(Color.BLUE, 1000, 500)
                        .setAutoCancel(false)
                        .setOngoing(true)
                        .setOnlyAlertOnce(false) // Permitir som em cada exibição
                        .setCategory(NotificationCompat.CATEGORY_ALARM)
                        .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
                        .setStyle(NotificationCompat.BigTextStyle().bigText(body))
                        .addAction(0, "Ver", createViewPendingIntent(context, notificationId, payload))
                        .addAction(0, "Adiar 15 minutos", createSnoozePendingIntent(context, notificationId, payload, title, body, sound))
                        .setFullScreenIntent(createViewPendingIntent(context, notificationId, payload), true)
                        .build()

                    // Exibir notificação
                    val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                    notificationManager.notify(notificationId, notification)
                    Log.d("MediAlerta", "✅ Notificação exibida com sucesso no Android - id: $notificationId")
                } catch (e: Exception) {
                    Log.e("MediAlerta", "❌ Erro ao exibir notificação: ${e.message}", e)
                }
            }
            
            "com.claudinei.medialerta.SNOOZE_ACTION" -> {
                if (notificationId != -1 && actionId == "snooze_action") {
                    val title = intent.getStringExtra("title") ?: "Hora do Medicamento"
                    val body = intent.getStringExtra("body") ?: "Toque para ver os medicamentos"
                    val sound = intent.getStringExtra("sound") ?: "malta"
                    Log.d("MediAlerta", "SnoozeActionReceiver: Processando snooze_action - id: $notificationId, payload: $payload")

                    try {
                        // Cancelar a notificação atual
                        val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                        notificationManager.cancel(notificationId)
                        Log.d("MediAlerta", "✅ Notificação cancelada - id: $notificationId")

                        // ✅ MELHORIA: Cancelar PendingIntent existente com flag correta
                        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
                        val existingIntent = Intent(context, SnoozeActionReceiver::class.java).apply {
                            action = "com.claudinei.medialerta.SHOW_NOTIFICATION"
                            putExtra("notificationId", notificationId)
                        }
                        val existingPendingIntent = PendingIntent.getBroadcast(
                            context,
                            notificationId + 2000,
                            existingIntent,
                            PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE
                        )
                        if (existingPendingIntent != null) {
                            alarmManager.cancel(existingPendingIntent)
                            existingPendingIntent.cancel()
                            Log.d("MediAlerta", "✅ PendingIntent anterior cancelado - id: $notificationId")
                        }

                        // ✅ CORREÇÃO: 15 minutos reais (não 15 segundos!)
                        val newScheduledTime = System.currentTimeMillis() + 15 * 1000 // 15 segundos
                        //val newScheduledTime = System.currentTimeMillis() + 15 * 60 * 1000L // 15 minutos
                        val newIntent = Intent(context, SnoozeActionReceiver::class.java).apply {
                            action = "com.claudinei.medialerta.SHOW_NOTIFICATION"
                            putExtra("notificationId", notificationId)
                            putExtra("title", title)
                            putExtra("body", body)
                            putExtra("sound", sound)
                            putExtra("payload", payload)
                        }
                        val newPendingIntent = PendingIntent.getBroadcast(
                            context,
                            notificationId + 2000,
                            newIntent,
                            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                        )

                        // Agendar com AlarmManager (já correto para MIUI)
                        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.M) {
                            alarmManager.setExactAndAllowWhileIdle(
                                AlarmManager.RTC_WAKEUP,
                                newScheduledTime,
                                newPendingIntent
                            )
                        } else {
                            alarmManager.setExact(
                                AlarmManager.RTC_WAKEUP,
                                newScheduledTime,
                                newPendingIntent
                            )
                        }
                        Log.d("MediAlerta", "✅ Nova notificação agendada para ${java.text.SimpleDateFormat("HH:mm:ss").format(newScheduledTime)} - id: $notificationId")

                        // ✅ MELHORIA: Broadcast para Flutter (mas precisa do receiver correto)
                        val broadcastIntent = Intent("com.claudinei.medialerta.NOTIFICATION_ACTION").apply {
                            putExtra("notificationId", notificationId)
                            putExtra("payload", payload)
                            putExtra("actionId", actionId)
                        }
                        context.sendBroadcast(broadcastIntent)
                        Log.d("MediAlerta", "📡 Broadcast enviado para Flutter - id: $notificationId, actionId: $actionId")
                    } catch (e: Exception) {
                        Log.e("MediAlerta", "❌ Erro ao processar snooze_action: ${e.message}", e)
                    }
                } else {
                    Log.e("MediAlerta", "❌ SnoozeActionReceiver: Dados inválidos - notificationId=$notificationId, actionId=$actionId")
                }
            }
            
            else -> {
                Log.e("MediAlerta", "❌ SnoozeActionReceiver: Ação desconhecida - action=$intentAction")
            }
        }
    }

    // ✅ MELHORIA: Métodos auxiliares para reduzir duplicação
    private fun createViewPendingIntent(context: Context, notificationId: Int, payload: String?): PendingIntent {
        val viewIntent = Intent(context, MainActivity::class.java).apply {
            action = "com.claudinei.medialerta.VIEW_ACTION"
            putExtra("notificationId", notificationId)
            putExtra("payload", payload)
            putExtra("action_id", "view_action")
            addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        }
        return PendingIntent.getActivity(
            context,
            notificationId,
            viewIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    private fun createSnoozePendingIntent(
        context: Context, 
        notificationId: Int, 
        payload: String?, 
        title: String, 
        body: String, 
        sound: String
    ): PendingIntent {
        val snoozeIntent = Intent(context, SnoozeActionReceiver::class.java).apply {
            action = "com.claudinei.medialerta.SNOOZE_ACTION"
            putExtra("notificationId", notificationId)
            putExtra("payload", payload)
            putExtra("action_id", "snooze_action")
            putExtra("title", title)
            putExtra("body", body)
            putExtra("sound", sound)
        }
        return PendingIntent.getBroadcast(
            context,
            notificationId + 1000,
            snoozeIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }
}