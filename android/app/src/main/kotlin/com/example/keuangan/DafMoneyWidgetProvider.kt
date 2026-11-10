package com.example.keuangan

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.widget.RemoteViews

class DafMoneyWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        val prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.dafmoney_widget).apply {
                val totalBalance = prefs.getString("total_balance", "Rp 0") ?: "Rp 0"
                val remainingBudget = prefs.getString("remaining_budget", "Rp 0") ?: "Rp 0"
                setTextViewText(R.id.total_balance, totalBalance)
                setTextViewText(R.id.remaining_budget, remainingBudget)
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
