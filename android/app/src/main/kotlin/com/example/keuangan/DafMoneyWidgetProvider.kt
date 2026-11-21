package com.example.keuangan

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.view.View
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

                setOnClickPendingIntent(R.id.btn_expense, quickAdd(context, "expense", 1))
                setOnClickPendingIntent(R.id.btn_income, quickAdd(context, "income", 2))

                val slots = listOf(R.id.tpl_1, R.id.tpl_2, R.id.tpl_3)
                var any = false
                slots.forEachIndexed { index, viewId ->
                    val i = index + 1
                    val note = prefs.getString("tpl_$i", "") ?: ""
                    val label = prefs.getString("tpl_${i}_label", "") ?: ""
                    if (note.isNotEmpty()) {
                        any = true
                        setViewVisibility(viewId, View.VISIBLE)
                        setTextViewText(viewId, label.ifEmpty { note })
                        setOnClickPendingIntent(
                            viewId,
                            PendingIntent.getBroadcast(
                                context, 100 + i,
                                Intent(context, WidgetTemplateReceiver::class.java)
                                    .putExtra("i", i),
                                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
                            )
                        )
                    } else {
                        setViewVisibility(viewId, View.GONE)
                    }
                }
                setViewVisibility(R.id.tpl_row, if (any) View.VISIBLE else View.GONE)
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }

    private fun quickAdd(context: Context, type: String, code: Int): PendingIntent =
        PendingIntent.getActivity(
            context, code, QuickPopupActivity.intentFor(context, type),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
}
