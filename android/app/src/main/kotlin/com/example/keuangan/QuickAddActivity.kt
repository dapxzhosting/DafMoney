package com.example.keuangan

import android.content.Intent
import android.os.Handler
import android.os.Looper
import android.widget.Toast
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class QuickAddActivity : FlutterActivity() {

    override fun getDartEntrypointFunctionName(): String = "quickAddMain"

    private var dartReady = false
    private val handler = Handler(Looper.getMainLooper())

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        handler.postDelayed({
            if (!dartReady && !isFinishing) {
                Toast.makeText(
                    this,
                    "Catat cepat gagal dimuat. Coba buka DafMoney sekali dulu.",
                    Toast.LENGTH_LONG
                ).show()
                finish()
            }
        }, 8000)
    }

    override fun onDestroy() {
        handler.removeCallbacksAndMessages(null)
        super.onDestroy()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getArgs" -> {
                        dartReady = true
                        result.success(
                        mapOf(
                            "type" to (intent.getStringExtra(EXTRA_TYPE) ?: "expense"),
                            "text" to sharedText(),
                        )
                        )
                    }
                    "close" -> {
                        finish()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun sharedText(): String {
        if (intent?.action != Intent.ACTION_SEND) return ""
        return intent.getStringExtra(Intent.EXTRA_TEXT) ?: ""
    }

    companion object {
        const val CHANNEL = "dafmoney/quick_add"
        const val EXTRA_TYPE = "type"

        fun intentFor(context: android.content.Context, type: String): Intent =
            Intent(context, QuickAddActivity::class.java).apply {
                putExtra(EXTRA_TYPE, type)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            }
    }
}
