package com.example.keuangan

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.android.FlutterActivityLaunchConfigs.BackgroundMode
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Layar mini "Catat cepat" (transparan, tampil di atas app lain).
 * Dibuka dari tombol widget, Quick Settings Tile, atau menu Bagikan.
 * UI-nya Flutter (entrypoint `quickAddMain`), tanpa membuka app utama.
 */
class QuickAddActivity : FlutterActivity() {

    override fun getDartEntrypointFunctionName(): String = "quickAddMain"

    override fun getBackgroundMode(): BackgroundMode = BackgroundMode.transparent

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getArgs" -> result.success(
                        mapOf(
                            "type" to (intent.getStringExtra(EXTRA_TYPE) ?: "expense"),
                            "text" to sharedText(),
                        )
                    )
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
