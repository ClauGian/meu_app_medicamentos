package com.claudinei.medialerta

import android.media.MediaPlayer
import android.os.Bundle
import android.view.WindowManager
import androidx.appcompat.app.AppCompatActivity
import android.widget.Button
import android.content.Intent
import android.view.View
import android.util.Log // Importar Log para logs de depuração
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.plugin.common.MethodChannel

class FullScreenAlarmActivity : AppCompatActivity() {
    private var mediaPlayer: MediaPlayer? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_full_screen_alarm)

        window.addFlags(
            WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
            WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
            WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON or
            WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD
        )

        playSound()

        val viewButton: Button = findViewById(R.id.view_button)

        // CORREÇÃO AQUI: Obter 'horario' e 'medicationIds' diretamente dos extras do Intent
        // Estes são os dados que a MainActivity está enviando de forma explícita.
        val horario = intent.getStringExtra("horario") ?: "08:00"
        val medicationIds = intent.getStringArrayListExtra("medicationIds") ?: arrayListOf()

        // O 'payload' completo também pode ser útil para depuração, mas não é usado para parsear novamente 'horario' e 'medicationIds'
        val receivedPayload = intent.getStringExtra("payload")
        Log.d("MediAlerta", "FullScreenAlarmActivity recebida. Horário: $horario, IDs: $medicationIds, Payload Recebido: $receivedPayload")


        viewButton.setOnClickListener {
            stopAndReleaseMediaPlayer()
            val intent = Intent(this, MainActivity::class.java).apply {
                putExtra("route", "medication_alert")
                putExtra("horario", horario)
                putStringArrayListExtra("medicationIds", ArrayList(medicationIds))
                addFlags(Intent.FLAG_ACTIVITY_REORDER_TO_FRONT)
            }
            Log.d("MediAlerta", "Redirecionando para MainActivity com: route=medication_alert, horario=$horario, medicationIds=$medicationIds")
            startActivity(intent)
            finish()
        }
    }

    private fun playSound() {
        try {
            if (mediaPlayer == null) {
                mediaPlayer = MediaPlayer.create(this, R.raw.alarm)
                mediaPlayer?.setOnPreparedListener {
                    mediaPlayer?.isLooping = true
                    mediaPlayer?.start()
                    Log.d("MediAlerta", "MediaPlayer iniciado em playSound após preparo")
                }
                mediaPlayer?.setOnErrorListener { mp, what, extra ->
                    Log.e("MediAlerta", "Erro no MediaPlayer: what=$what, extra=$extra")
                    stopAndReleaseMediaPlayer()
                    true
                }
            }
        } catch (e: Exception) {
            e.printStackTrace()
            Log.e("MediAlerta", "Erro ao iniciar MediaPlayer: $e")
            stopAndReleaseMediaPlayer()
        }
    }

    private fun stopAndReleaseMediaPlayer() {
        try {
            if (mediaPlayer != null) {
                if (mediaPlayer?.isPlaying == true) {
                    mediaPlayer?.stop()
                }
                mediaPlayer?.reset()
                mediaPlayer?.release()
                mediaPlayer = null
                Log.d("MediAlerta", "MediaPlayer liberado em stopAndReleaseMediaPlayer")
            }
        } catch (e: Exception) {
            Log.e("MediAlerta", "Erro ao liberar MediaPlayer: $e")
        }
    }

    override fun onPause() {
        super.onPause()
        stopAndReleaseMediaPlayer()
        Log.d("MediAlerta", "MediaPlayer liberado em onPause")
    }

    override fun onStop() {
        super.onStop()
        stopAndReleaseMediaPlayer()
        Log.d("MediAlerta", "MediaPlayer liberado em onStop")
    }

    override fun onDestroy() {
        super.onDestroy()
        stopAndReleaseMediaPlayer()
        Log.d("MediAlerta", "MediaPlayer liberado em onDestroy")
    }
}