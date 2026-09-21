package app.adpocket.yan

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.graphics.BitmapFactory
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * Home-screen widget: today's revenue, delta vs yesterday, sparkline and
 * impressions / clicks. All values are pre-formatted by the Dart side and
 * stored through the home_widget plugin; this class only paints them.
 */
class AdPocketWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        for (widgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.adpocket_widget).apply {
                setTextViewText(R.id.widget_title, widgetData.getString("title", "AdPocket"))
                setTextViewText(R.id.widget_updated, widgetData.getString("updated", "") ?: "")
                setTextViewText(R.id.widget_revenue, widgetData.getString("revenue", "—") ?: "—")
                setTextViewText(R.id.widget_delta, widgetData.getString("delta", "") ?: "")
                setTextViewText(R.id.widget_stats, widgetData.getString("stats", "") ?: "")

                val positive = widgetData.getBoolean("delta_positive", true)
                val neutral = widgetData.getBoolean("delta_neutral", false)
                setTextColor(
                    R.id.widget_delta,
                    when {
                        neutral -> 0xFFB8C4D6.toInt()
                        positive -> 0xFF34C759.toInt()
                        else -> 0xFFFF5A5F.toInt()
                    },
                )

                val chartPath = widgetData.getString("sparkline", null)
                val bitmap = chartPath?.let { BitmapFactory.decodeFile(it) }
                if (bitmap != null) {
                    setImageViewBitmap(R.id.widget_chart, bitmap)
                    setViewVisibility(R.id.widget_chart, View.VISIBLE)
                } else {
                    setViewVisibility(R.id.widget_chart, View.GONE)
                }

                setOnClickPendingIntent(
                    R.id.widget_root,
                    HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java),
                )
                // Refresh button: runs the Dart background callback without opening the app.
                setOnClickPendingIntent(
                    R.id.widget_refresh,
                    HomeWidgetBackgroundIntent.getBroadcast(context, Uri.parse("adpocket://widget/refresh")),
                )
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
