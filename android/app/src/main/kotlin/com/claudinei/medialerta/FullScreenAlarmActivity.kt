package com.claudinei.medialerta

import android.media.MediaPlayer
import android.os.Bundle
import android.view.WindowManager
import androidx.appcompat.app.AppCompatActivity
import android.widget.Button
import android.content.Intent
import android.view.View

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
        val payload = intent.getStringExtra("body") ?: "08:00|1,2"
        val parts = payload.split("|")
        val horario = if (parts.isNotEmpty()) parts[0] else "08:00"
        val medicationIds = if (parts.size > 1) parts[1].split(",").filter { it.isNotEmpty() } else emptyList()

        viewButton.setOnClickListener {
            val intent = Intent(this, MainActivity::class.java).apply {
                setFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK)
                putExtra("route", "medication_alert")
                putExtra("horario", horario)
                putStringArrayListExtra("medicationIds", ArrayList(medicationIds))
            }
            android.util.Log.d("MediAlerta", "Payload sendo passado: horario=$horario, medicationIds=$medicationIds")
            mediaPlayer?.stop()
            mediaPlayer?.release()
            mediaPlayer = null
            startActivity(intent)
            finish()
        }
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

    override fun onDestroy() {
        super.onDestroy()
        mediaPlayer?.stop()
        mediaPlayer?.release()
        mediaPlayer = null
    }
}