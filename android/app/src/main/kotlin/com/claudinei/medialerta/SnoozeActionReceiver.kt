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
                    // Criar PendingIntent para view_action
                    val viewIntent = Intent(context, MainActivity::class.java).apply {
                        action = "com.claudinei.medialerta.VIEW_ACTION"
                        putExtra("notificationId", notificationId)
                        putExtra("payload", payload)
                        putExtra("action_id", "view_action")
                        addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
                    }
                    val viewPendingIntent = PendingIntent.getActivity(
                        context,
                        notificationId,
                        viewIntent,
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                    )

                    // Criar PendingIntent para snooze_action
                    val snoozeIntent = Intent(context, SnoozeActionReceiver::class.java).apply {
                        action = "com.claudinei.medialerta.SNOOZE_ACTION"
                        putExtra("notificationId", notificationId)
                        putExtra("payload", payload)
                        putExtra("action_id", "snooze_action")
                        putExtra("title", title)
                        putExtra("body", body)
                        putExtra("sound", sound)
                    }
                    val snoozePendingIntent = PendingIntent.getBroadcast(
                        context,
                        notificationId + 1000,
                        snoozeIntent,
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                    )

                    // Criar notificação
                    val notification = NotificationCompat.Builder(context, "medication_channel_v3")
                        .setContentTitle(title)
                        .setContentText(body)
                        .setSmallIcon(R.mipmap.ic_launcher)
                        .setLargeIcon(BitmapFactory.decodeResource(context.resources, R.mipmap.ic_launcher))
                        .setPriority(NotificationCompat.PRIORITY_MAX)
                        .setSound(Uri.parse("android.resource://${context.packageName}/raw/$sound"))
                        .setVibrate(longArrayOf(1000, 1000))
                        .setLights(Color.BLUE, 1000, 500)
                        .setAutoCancel(false)
                        .setOngoing(true)
                        .setCategory(NotificationCompat.CATEGORY_ALARM)
                        .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
                        .setStyle(NotificationCompat.BigTextStyle().bigText(body))
                        .addAction(0, "Ver", viewPendingIntent)
                        .addAction(0, "Adiar 15 minutos", snoozePendingIntent)
                        .setFullScreenIntent(viewPendingIntent, true)
                        .build()

                    // Exibir notificação
                    val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                    notificationManager.notify(notificationId, notification)
                    Log.d("MediAlerta", "Notificação exibida com sucesso no Android - id: $notificationId")
                } catch (e: Exception) {
                    Log.e("MediAlerta", "Erro ao exibir notificação: ${e.message}", e)
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
                        Log.d("MediAlerta", "Notificação cancelada - id: $notificationId")

                        // Cancelar qualquer PendingIntent existente para evitar múltiplos disparos
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
                        existingPendingIntent?.let {
                            alarmManager.cancel(it)
                            it.cancel()
                            Log.d("MediAlerta", "PendingIntent anterior cancelado - id: $notificationId")
                        }

                        // Agendar nova notificação para 15 minutos depois
                        val newScheduledTime = System.currentTimeMillis() + 15 * 1000 // 15 segundos em milissegundos
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

                        // Agendar com AlarmManager
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
                        Log.d("MediAlerta", "Nova notificação agendada para $newScheduledTime - id: $notificationId")

                        // Enviar broadcast para o Flutter processar quando voltar ao primeiro plano
                        val broadcastIntent = Intent("com.claudinei.medialerta.NOTIFICATION_ACTION").apply {
                            putExtra("notificationId", notificationId)
                            putExtra("payload", payload)
                            putExtra("actionId", actionId)
                        }
                        context.sendBroadcast(broadcastIntent)
                        Log.d("MediAlerta", "Broadcast enviado para Flutter - id: $notificationId, payload: $payload, actionId: $actionId")
                    } catch (e: Exception) {
                        Log.e("MediAlerta", "Erro ao processar snooze_action: ${e.message}", e)
                    }
                } else {
                    Log.e("MediAlerta", "SnoozeActionReceiver: Dados inválidos - notificationId=$notificationId, actionId=$actionId")
                }
            }
            else -> {
                Log.e("MediAlerta", "SnoozeActionReceiver: Ação desconhecida - action=$intentAction")
            }
        }
    }
}