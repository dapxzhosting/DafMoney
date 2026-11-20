package com.example.keuangan

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.VibrationEffect
import android.os.Vibrator
import android.speech.RecognizerIntent
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.view.inputmethod.EditorInfo
import android.widget.EditText
import android.widget.LinearLayout
import android.widget.TextView
import android.widget.Toast
import es.antonborri.home_widget.HomeWidgetBackgroundIntent

/**
 * Popup "Catat cepat" (native, tanpa membuka app). Muncul di atas app apa pun
 * dari: tombol aksesibilitas, tombol widget, Quick Settings Tile, atau menu
 * Bagikan. Penyimpanan dikerjakan Dart di latar belakang (home_widget).
 */
class QuickPopupActivity : Activity() {

    private var type = "expense"
    private lateinit var input: EditText
    private lateinit var tvExpense: TextView
    private lateinit var tvIncome: TextView

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.quick_popup)
        window.setSoftInputMode(
            WindowManager.LayoutParams.SOFT_INPUT_STATE_VISIBLE or
                WindowManager.LayoutParams.SOFT_INPUT_ADJUST_RESIZE
        )

        input = findViewById(R.id.et_text)
        tvExpense = findViewById(R.id.tv_expense)
        tvIncome = findViewById(R.id.tv_income)

        val shared = if (intent?.action == Intent.ACTION_SEND)
            intent.getStringExtra(Intent.EXTRA_TEXT) else null
        if (!shared.isNullOrBlank()) {
            type = guessType(shared)
            val s = summarize(shared)
            input.setText(s)
            input.setSelection(s.length)
        } else {
            type = intent?.getStringExtra(EXTRA_TYPE) ?: "expense"
        }

        findViewById<View>(R.id.root).setOnClickListener { finish() }
        findViewById<View>(R.id.card).setOnClickListener { }
        tvExpense.setOnClickListener { setType("expense") }
        tvIncome.setOnClickListener { setType("income") }
        findViewById<View>(R.id.btn_save).setOnClickListener { submit(input.text.toString()) }
        findViewById<View>(R.id.btn_mic).setOnClickListener { listen() }
        input.setOnEditorActionListener { _, actionId, _ ->
            if (actionId == EditorInfo.IME_ACTION_DONE) {
                submit(input.text.toString())
                true
            } else false
        }

        setType(type)
        buildChips()
        input.requestFocus()
    }

    private fun setType(t: String) {
        type = t
        val income = t == "income"
        tvExpense.setBackgroundResource(if (income) R.drawable.seg_off else R.drawable.seg_on)
        tvIncome.setBackgroundResource(if (income) R.drawable.seg_on else R.drawable.seg_off)
        input.hint = if (income) "mis. gaji 5jt" else "mis. makan siang 25rb"
        findViewById<View>(R.id.chip_scroll).visibility = if (income) View.GONE else View.VISIBLE
    }

    /** Template favorit (pengeluaran) dari riwayat; dibuat app saat dibuka. */
    private fun buildChips() {
        val prefs = getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
        val box = findViewById<LinearLayout>(R.id.chips)
        val dp = resources.displayMetrics.density
        var any = false
        for (i in 1..6) {
            val note = prefs.getString("tpl_$i", "") ?: ""
            if (note.isEmpty()) continue
            any = true
            val label = (prefs.getString("tpl_${i}_label", "") ?: "").ifEmpty { note }
            val chip = TextView(this).apply {
                text = label
                setTextColor(0xFFE2E8F0.toInt())
                textSize = 12f
                maxLines = 1
                setBackgroundResource(R.drawable.widget_chip)
                setPadding((12 * dp).toInt(), (7 * dp).toInt(), (12 * dp).toInt(), (7 * dp).toInt())
                setOnClickListener { type = "expense"; submit(note) }
            }
            val lp = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply { marginEnd = (8 * dp).toInt() }
            box.addView(chip, lp)
        }
        if (!any) findViewById<View>(R.id.chip_scroll).visibility = View.GONE
    }

    private fun submit(raw: String) {
        val text = raw.trim()
        if (text.isEmpty()) {
            Toast.makeText(this, "Tulis dulu, mis. kopi 15rb", Toast.LENGTH_SHORT).show()
            return
        }
        Toast.makeText(this, "Menyimpan \"$text\"…", Toast.LENGTH_SHORT).show()
        buzz()
        val uri = Uri.Builder()
            .scheme("dafmoney")
            .authority("save")
            .appendQueryParameter("type", type)
            .appendQueryParameter("text", text)
            .build()
        HomeWidgetBackgroundIntent.getBroadcast(this, uri).send()
        finish()
    }

    @Suppress("DEPRECATION")
    private fun listen() {
        val i = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
            putExtra(RecognizerIntent.EXTRA_LANGUAGE, "id-ID")
            putExtra(RecognizerIntent.EXTRA_PROMPT, "Ucapkan transaksi, mis. kopi 15 ribu")
        }
        try {
            startActivityForResult(i, REQ_SPEECH)
        } catch (e: ActivityNotFoundException) {
            Toast.makeText(this, "Pengenalan suara tidak tersedia di HP ini", Toast.LENGTH_LONG).show()
        }
    }

    @Suppress("DEPRECATION")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == REQ_SPEECH && resultCode == RESULT_OK) {
            val words = data?.getStringArrayListExtra(RecognizerIntent.EXTRA_RESULTS)?.firstOrNull()
            if (!words.isNullOrBlank()) {
                input.setText(words)
                input.setSelection(words.length)
            }
        }
    }

    @Suppress("DEPRECATION")
    private fun buzz() {
        try {
            val v = getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator ?: return
            if (Build.VERSION.SDK_INT >= 26) {
                v.vibrate(VibrationEffect.createOneShot(35, VibrationEffect.DEFAULT_AMPLITUDE))
            } else {
                v.vibrate(35)
            }
        } catch (_: Exception) {
        }
    }

    // --- teks yang dibagikan dari app lain (m-banking, e-wallet) ---

    private fun guessType(text: String): String {
        val t = text.lowercase()
        val income = listOf("diterima", "dana masuk", "menerima", "uang masuk")
        return if (income.any { t.contains(it) }) "income" else "expense"
    }

    private fun summarize(text: String): String {
        val t = text.trim()
        if (t.isEmpty()) return ""
        val rp = Regex("rp\\.?\\s*([\\d.,]+)", RegexOption.IGNORE_CASE)
        var best: Long? = null
        for (m in rp.findAll(t)) {
            val raw = m.groupValues[1].replace(Regex("[.,]\\d{1,2}$"), "")
            val v = raw.replace(Regex("[.,]"), "").toLongOrNull()
            if (v != null && (best == null || v > best!!)) best = v
        }
        if (best == null) return if (t.length > 60) t.substring(0, 60) else t
        var note = (t.lines().firstOrNull { it.isNotBlank() } ?: "")
            .replace(rp, "")
            .replace(Regex("\\d"), "")
            .replace(Regex("\\s+"), " ")
            .trim()
        if (note.length > 28) note = note.substring(0, 28).trim()
        if (note.isEmpty()) note = "Transaksi"
        return "$note $best"
    }

    companion object {
        const val EXTRA_TYPE = "type"
        private const val REQ_SPEECH = 77

        fun intentFor(context: Context, type: String): Intent =
            Intent(context, QuickPopupActivity::class.java).apply {
                putExtra(EXTRA_TYPE, type)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            }
    }
}
