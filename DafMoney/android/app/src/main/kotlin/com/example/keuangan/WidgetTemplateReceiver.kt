package com.example.keuangan

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.widget.Toast
import es.antonborri.home_widget.HomeWidgetBackgroundIntent

/**
 * Perantara tombol template di widget: memberi umpan balik langsung (getar +
 * toast "Menyimpan...") lalu meneruskan ketukan ke Dart yang menyimpan di
 * latar belakang. Hasil akhirnya muncul sebagai notifikasi "Tersimpan ✓".
 */
class WidgetTemplateReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val i = intent.getIntExtra("i", 0)
        if (i <= 0) return

        val prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
        val note = prefs.getString("tpl_$i", "") ?: ""
        if (note.isEmpty()) return

        Toast.makeText(context, "Menyimpan \"$note\"…", Toast.LENGTH_SHORT).show()
        buzz(context)

        HomeWidgetBackgroundIntent
            .getBroadcast(context, Uri.parse("dafmoney://template?i=$i"))
            .send()
    }

    @Suppress("DEPRECATION")
    private fun buzz(context: Context) {
        try {
            val v = context.getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator ?: return
            if (Build.VERSION.SDK_INT >= 26) {
                v.vibrate(VibrationEffect.createOneShot(35, VibrationEffect.DEFAULT_AMPLITUDE))
            } else {
                v.vibrate(35)
            }
        } catch (_: Exception) {
        }
    }
}
