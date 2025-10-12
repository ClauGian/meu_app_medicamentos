package com.claudinei.medialerta

import android.media.AudioAttributes
import android.media.MediaPlayer
import android.os.Build
import android.os.Bundle
import android.view.WindowManager
import android.widget.Button
import android.content.Intent
import android.app.AlarmManager
import android.app.PendingIntent
import android.util.Log
import androidx.appcompat.app.AppCompatActivity

class FullScreenAlarmActivity : AppCompatActivity() {
    private var mediaPlayer: MediaPlayer? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        Log.d("MediAlerta", "onCreate de FullScreenAlarmActivity iniciado")
        setContentView(R.layout.activity_full_screen_alarm)

        // Flags para tela acesa e desbloqueio
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        } else {
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
            )
        }
        window.addFlags(
            WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON or
            WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD
        )

        // Inicia som do alarme
        playSound()

        val horario = intent.getStringExtra("horario") ?: "08:00"
        val medicationIds = intent.getStringArrayListExtra("medicationIds") ?: arrayListOf()
        val receivedPayload = intent.getStringExtra("payload")
        val title = intent.getStringExtra("title") ?: "Alerta de Medicação"
        val body = intent.getStringExtra("body") ?: "É hora de tomar seu medicamento."

        Log.d("MediAlerta", "FullScreenAlarmActivity recebida. Horário: $horario, IDs: $medicationIds")

        // Botão Ver
        val viewButton: Button = findViewById(R.id.view_button)
        viewButton.setOnClickListener {
            Log.d("MediAlerta", "Botão 'Ver' clicado")
            stopAndReleaseMediaPlayer()
            val intent = Intent(this, MainActivity::class.java).apply {
                putExtra("route", "medication_alert")
                putExtra("horario", horario)
                putStringArrayListExtra("medicationIds", ArrayList(medicationIds))
                // Usar apenas FLAG_ACTIVITY_SINGLE_TOP para reutilizar a MainActivity existente
                addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_REORDER_TO_FRONT)
            }
            startActivity(intent)
            finish()
        }

        // Botão Adiar
        val snoozeButton: Button = findViewById(R.id.snooze_button)
        snoozeButton.setOnClickListener {
            Log.d("MediAlerta", "Botão 'Adiar' clicado")
            stopAndReleaseMediaPlayer()
            adiarAlarme(horario, medicationIds, receivedPayload, title, body, 0) // segundos serão tratados abaixo
            finish()
        }
    }

    private fun playSound() {
        try {
            if (mediaPlayer == null) {
                mediaPlayer = MediaPlayer.create(this, R.raw.alarm)
                mediaPlayer?.setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_ALARM)
                        .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                        .build()
                )
                mediaPlayer?.isLooping = true
                mediaPlayer?.start()
                Log.d("MediAlerta", "MediaPlayer iniciado e em loop")
            }
        } catch (e: Exception) {
            Log.e("MediAlerta", "Erro ao iniciar MediaPlayer: ${e.message}")
            stopAndReleaseMediaPlayer()
        }
    }

    private fun stopAndReleaseMediaPlayer() {
        try {
            mediaPlayer?.let {
                if (it.isPlaying) it.stop()
                it.reset()
                it.release()
                mediaPlayer = null
                Log.d("MediAlerta", "MediaPlayer liberado")
            }
        } catch (e: Exception) {
            Log.e("MediAlerta", "Erro ao liberar MediaPlayer: ${e.message}")
        }
    }

    private fun adiarAlarme(horario: String, medicationIds: ArrayList<String>, payload: String?, title: String, body: String, segundos: Int) {
        val alarmTime = System.currentTimeMillis() + segundos * 1000L
        val alarmIntent = Intent(this, FullScreenAlarmActivity::class.java).apply {
            putExtra("horario", horario)
            putStringArrayListExtra("medicationIds", medicationIds)
            putExtra("payload", payload)
            putExtra("title", title)
            putExtra("body", body)
        }

        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            alarmIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val alarmManager = getSystemService(ALARM_SERVICE) as AlarmManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            alarmManager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, alarmTime, pendingIntent)
        } else {
            alarmManager.setExact(AlarmManager.RTC_WAKEUP, alarmTime, pendingIntent)
        }
        Log.d("MediAlerta", "Alarme adiado em $segundos segundos")
    }


    override fun onStop() {
        super.onStop()
        Log.d("MediAlerta", "onStop chamado")
        stopAndReleaseMediaPlayer()
    }

    override fun onDestroy() {
        super.onDestroy()
        Log.d("MediAlerta", "onDestroy chamado")
        stopAndReleaseMediaPlayer()
    }
}
