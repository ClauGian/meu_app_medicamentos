package com.claudinei.medialerta

import android.media.MediaPlayer
import android.os.Bundle
import android.widget.Button
import android.widget.TextView
import androidx.appcompat.app.AppCompatActivity
import android.content.Intent
import android.view.WindowManager

class FullScreenAlarmActivity : AppCompatActivity() {
    private var mediaPlayer: MediaPlayer? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Configurar flags para tela cheia, mesmo com a tela bloqueada
        window.addFlags(
            WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
            WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
            WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON
        )

        // Layout atualizado
        setContentView(R.layout.activity_full_screen_alarm)

        // Obter dados do intent
        val title = intent.getStringExtra("notification_title") ?: "Hora do Medicamento"
        val payload = intent.getStringExtra("notification_body") ?: "08:00|1,2"

        // Configurar o texto da tela
        findViewById<TextView>(R.id.alarm_title).text = title

        // Configurar botão "Ver"
        findViewById<Button>(R.id.dismiss_button).setOnClickListener {
            stopSound()

            // Extrair horario e medicationIds do payload
            val payloadParts = payload.split("|")
            val horario = if (payloadParts.isNotEmpty()) payloadParts[0] else "08:00"
            val medicationIds = if (payloadParts.size > 1) payloadParts[1] else ""

            // Navegar para MainActivity com parâmetros para MedicationAlertScreen
            val intent = Intent(this, MainActivity::class.java).apply {
                putExtra("route", "medication_alert")
                putExtra("horario", horario)
                putExtra("medicationIds", medicationIds)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            }
            startActivity(intent)
            finish()
        }

        // Tocar o som
        playSound()
    }

    private fun playSound() {
        try {
            mediaPlayer = MediaPlayer.create(this, R.raw.alarm)
            mediaPlayer?.isLooping = true
            mediaPlayer?.start()
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun stopSound() {
        try {
            mediaPlayer?.stop()
            mediaPlayer?.release()
            mediaPlayer = null
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        stopSound()
    }
}