package com.claudinei.medialerta

import android.media.MediaPlayer
import android.os.Bundle
import android.view.WindowManager
import androidx.appcompat.app.AppCompatActivity
import android.widget.Button
import android.content.Intent
import android.util.Log

class FullScreenAlarmActivity : AppCompatActivity() {
    private var mediaPlayer: MediaPlayer? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        Log.d("MediAlerta", "onCreate de FullScreenAlarmActivity iniciado")
        setContentView(R.layout.activity_full_screen_alarm)

        Log.d("MediAlerta", "Configurando flags de janela para FullScreenAlarmActivity")
        window.addFlags(
            WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
            WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
            WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON or
            WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD
        )

        Log.d("MediAlerta", "Iniciando reprodução de som")
        playSound()

        val viewButton: Button = findViewById(R.id.view_button)
        val horario = intent.getStringExtra("horario") ?: "08:00"
        val medicationIds = intent.getStringArrayListExtra("medicationIds") ?: arrayListOf()
        val receivedPayload = intent.getStringExtra("payload")
        val title = intent.getStringExtra("title")
        val body = intent.getStringExtra("body")
        Log.d("MediAlerta", "FullScreenAlarmActivity recebida. Horário: $horario, IDs: $medicationIds, Payload: $receivedPayload, Título: $title, Corpo: $body")

        viewButton.setOnClickListener {
            Log.d("MediAlerta", "Botão 'Ver' clicado em FullScreenAlarmActivity")
            stopAndReleaseMediaPlayer()
            val intent = Intent(this, MainActivity::class.java).apply {
                putExtra("route", "medication_alert")
                putExtra("horario", horario)
                putStringArrayListExtra("medicationIds", ArrayList(medicationIds))
                addFlags(Intent.FLAG_ACTIVITY_REORDER_TO_FRONT or Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            Log.d("MediAlerta", "Redirecionando para MainActivity com: route=medication_alert, horario=$horario, medicationIds=$medicationIds")
            startActivity(intent)
            finish()
        }
    }

    private fun playSound() {
        try {
            Log.d("MediAlerta", "Tentando iniciar MediaPlayer")
            if (mediaPlayer == null) {
                mediaPlayer = MediaPlayer.create(this, R.raw.alarm)
                mediaPlayer?.setOnPreparedListener {
                    Log.d("MediAlerta", "MediaPlayer preparado, iniciando reprodução")
                    mediaPlayer?.isLooping = true
                    mediaPlayer?.start()
                }
                mediaPlayer?.setOnErrorListener { mp, what, extra ->
                    Log.e("MediAlerta", "Erro no MediaPlayer: what=$what, extra=$extra")
                    stopAndReleaseMediaPlayer()
                    true
                }
            }
        } catch (e: Exception) {
            Log.e("MediAlerta", "Erro ao iniciar MediaPlayer: ${e.message}")
            e.printStackTrace()
            stopAndReleaseMediaPlayer()
        }
    }

    private fun stopAndReleaseMediaPlayer() {
        try {
            if (mediaPlayer != null) {
                if (mediaPlayer?.isPlaying == true) {
                    mediaPlayer?.stop()
                    Log.d("MediAlerta", "MediaPlayer parado")
                }
                mediaPlayer?.reset()
                mediaPlayer?.release()
                mediaPlayer = null
                Log.d("MediAlerta", "MediaPlayer liberado em stopAndReleaseMediaPlayer")
            }
        } catch (e: Exception) {
            Log.e("MediAlerta", "Erro ao liberar MediaPlayer: ${e.message}")
        }
    }

    override fun onPause() {
        super.onPause()
        Log.d("MediAlerta", "onPause de FullScreenAlarmActivity chamado")
        stopAndReleaseMediaPlayer()
    }

    override fun onStop() {
        super.onStop()
        Log.d("MediAlerta", "onStop de FullScreenAlarmActivity chamado")
        stopAndReleaseMediaPlayer()
    }

    override fun onDestroy() {
        super.onDestroy()
        Log.d("MediAlerta", "onDestroy de FullScreenAlarmActivity chamado")
        stopAndReleaseMediaPlayer()
    }
}