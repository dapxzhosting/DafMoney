package com.example.keuangan

import android.accessibilityservice.AccessibilityButtonController
import android.accessibilityservice.AccessibilityService
import android.os.Build
import android.view.accessibility.AccessibilityEvent

/**
 * Layanan Aksesibilitas "Catat cepat": hanya memberi TOMBOL AKSESIBILITAS
 * (tombol melayang / di bilah navigasi / pintasan volume) yang membuka popup
 * catat cepat di atas app apa pun. Tidak membaca isi layar sama sekali.
 */
class QuickAddAccessibilityService : AccessibilityService() {

    private var callback: AccessibilityButtonController.AccessibilityButtonCallback? = null

    override fun onServiceConnected() {
        super.onServiceConnected()
        if (Build.VERSION.SDK_INT >= 26) {
            val cb = object : AccessibilityButtonController.AccessibilityButtonCallback() {
                override fun onClicked(controller: AccessibilityButtonController) {
                    openPopup()
                }
            }
            callback = cb
            accessibilityButtonController.registerAccessibilityButtonCallback(cb)
        }
    }

    private fun openPopup() {
        startActivity(QuickPopupActivity.intentFor(this, "expense"))
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        // Sengaja kosong: layanan ini tidak memproses isi layar.
    }

    override fun onInterrupt() {}

    override fun onDestroy() {
        if (Build.VERSION.SDK_INT >= 26) {
            callback?.let { accessibilityButtonController.unregisterAccessibilityButtonCallback(it) }
        }
        super.onDestroy()
    }
}
