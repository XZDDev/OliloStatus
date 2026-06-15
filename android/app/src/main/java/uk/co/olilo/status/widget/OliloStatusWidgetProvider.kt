package uk.co.olilo.status.widget

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import kotlinx.serialization.json.Json
import uk.co.olilo.status.status.ComponentsResponse
import uk.co.olilo.status.main.MainActivity
import uk.co.olilo.status.R
import uk.co.olilo.status.status.StatusComponent
import java.net.HttpURLConnection
import java.net.URL
import java.util.Locale
import kotlin.concurrent.thread

class OliloStatusWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        appWidgetIds.forEach { appWidgetId -> refreshWidget(context, appWidgetManager, appWidgetId) }
    }

    override fun onDeleted(context: Context, appWidgetIds: IntArray) {
        val editor = context.getSharedPreferences(WIDGET_PREFERENCES_NAME, Context.MODE_PRIVATE).edit()
        appWidgetIds.forEach { appWidgetId -> editor.remove(sourceKey(appWidgetId)) }
        editor.apply()
    }

    companion object {
        val sourceNames = listOf("Openreach", "CityFibre", "Freedom Fibre")
        private val json = Json { ignoreUnknownKeys = true }

        fun saveSource(context: Context, appWidgetId: Int, sourceName: String) {
            context.getSharedPreferences(WIDGET_PREFERENCES_NAME, Context.MODE_PRIVATE)
                .edit()
                .putString(sourceKey(appWidgetId), sourceName)
                .apply()
        }

        fun refreshWidget(context: Context, appWidgetManager: AppWidgetManager, appWidgetId: Int) {
            val sourceName = loadSource(context, appWidgetId)
            updateWidget(context, appWidgetManager, appWidgetId, "Loading", sourceName, null)

            thread(name = "OliloStatusWidgetRefresh") {
                val component = fetchWidgetComponent(sourceName)
                val isOnline = component?.status?.isWidgetOnline() == true
                val statusText =
                    if (component == null) "Unavailable" else if (isOnline) "Online" else "Offline"
                val sourceText = component?.name ?: sourceName
                updateWidget(
                    context,
                    appWidgetManager,
                    appWidgetId,
                    statusText,
                    sourceText,
                    isOnline
                )
            }
        }

        private fun updateWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int,
            statusText: String,
            sourceText: String,
            isOnline: Boolean?,
        ) {
            val statusColor = when (isOnline) {
                true -> 0xFF4CAF50.toInt()
                false -> 0xFFFF5252.toInt()
                null -> 0xFFBDB3C7.toInt()
            }
            val views = RemoteViews(context.packageName, R.layout.olilo_status_widget).apply {
                setTextViewText(R.id.widget_status, statusText)
                setTextViewText(R.id.widget_source, sourceText)
                setContentDescription(
                    R.id.widget_root,
                    "Olilo Status widget. $sourceText is $statusText. Opens Olilo Status.",
                )
                setContentDescription(R.id.widget_status_dot, "$sourceText status: $statusText")
                setContentDescription(R.id.widget_timeline, "$sourceText status timeline")
                setInt(R.id.widget_status_dot, "setColorFilter", statusColor)
                setInt(R.id.widget_timeline, "setColorFilter", statusColor)
                setOnClickPendingIntent(R.id.widget_root, launchAppIntent(context))
            }
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }

        private fun launchAppIntent(context: Context): PendingIntent {
            val intent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            return PendingIntent.getActivity(
                context,
                0,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
        }

        private fun fetchWidgetComponent(sourceName: String): StatusComponent? = runCatching {
            val connection = (URL(COMPONENTS_URL).openConnection() as HttpURLConnection).apply {
                connectTimeout = 15_000
                readTimeout = 15_000
                requestMethod = "GET"
            }
            try {
                val body = connection.inputStream.bufferedReader().use { it.readText() }
                json.decodeFromString<ComponentsResponse>(body)
                    .components
                    .firstOrNull { it.name == sourceName }
            } finally {
                connection.disconnect()
            }
        }.getOrNull()

        private fun loadSource(context: Context, appWidgetId: Int): String =
            context.getSharedPreferences(WIDGET_PREFERENCES_NAME, Context.MODE_PRIVATE)
                .getString(sourceKey(appWidgetId), null)
                ?.takeIf { it in sourceNames }
                ?: sourceNames.first()

        private fun sourceKey(appWidgetId: Int): String = "source_$appWidgetId"

        private fun String.isWidgetOnline(): Boolean = uppercase(Locale.UK).let { status ->
            status == "UP" || status == "OPERATIONAL"
        }

        private const val COMPONENTS_URL = "https://status.olilo.co.uk/v3/components.json"
        private const val WIDGET_PREFERENCES_NAME = "olilo_status_widget_preferences"
    }
}
