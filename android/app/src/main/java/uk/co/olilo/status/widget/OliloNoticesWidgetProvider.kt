package uk.co.olilo.status.widget

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import androidx.compose.ui.graphics.toArgb
import kotlinx.serialization.json.Json
import uk.co.olilo.status.R
import uk.co.olilo.status.main.MainActivity
import uk.co.olilo.status.status.StatusPageSummary
import uk.co.olilo.status.status.formatRemoteDate
import uk.co.olilo.status.status.readableStatus
import uk.co.olilo.status.status.statusColor
import java.net.HttpURLConnection
import java.net.URL
import kotlin.concurrent.thread

class OliloNoticesWidgetProvider : AppWidgetProvider() {
    /** Refreshes every large notices widget instance when Android requests an update. */
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        appWidgetIds.forEach { appWidgetId -> refreshWidget(context, appWidgetManager, appWidgetId) }
    }

    /** Removes stored configuration for large widget instances that were deleted. */
    override fun onDeleted(context: Context, appWidgetIds: IntArray) {
        val editor = context.getSharedPreferences(WIDGET_PREFERENCES_NAME, Context.MODE_PRIVATE).edit()
        appWidgetIds.forEach { appWidgetId -> editor.remove(noticeTypeKey(appWidgetId)) }
        editor.apply()
    }

    companion object {
        val noticeTypes = listOf("Incidents", "Maintenance")
        private val json = Json { ignoreUnknownKeys = true }

        /** Persists whether a large widget should display incidents or maintenance. */
        fun saveNoticeType(context: Context, appWidgetId: Int, noticeType: String) {
            context.getSharedPreferences(WIDGET_PREFERENCES_NAME, Context.MODE_PRIVATE)
                .edit()
                .putString(noticeTypeKey(appWidgetId), noticeType)
                .apply()
        }

        /** Loads the selected notice type, fetches summary data, and updates the widget UI. */
        fun refreshWidget(context: Context, appWidgetManager: AppWidgetManager, appWidgetId: Int) {
            val noticeType = loadNoticeType(context, appWidgetId)
            updateWidget(
                context = context,
                appWidgetManager = appWidgetManager,
                appWidgetId = appWidgetId,
                noticeType = noticeType,
                notices = emptyList(),
                isLoading = true,
            )

            thread(name = "OliloNoticesWidgetRefresh") {
                val summary = fetchSummary()
                val notices = when (noticeType) {
                    "Maintenance" -> summary?.activeMaintenances?.map {
                        WidgetNotice(
                            title = it.name,
                            status = it.status,
                            detailStatus = it.status,
                            date = formatRemoteDate(it.updatedAt ?: it.start),
                        )
                    }.orEmpty()
                    else -> summary?.activeIncidents?.map {
                        WidgetNotice(
                            title = it.name,
                            status = it.status,
                            detailStatus = it.impact ?: it.status,
                            date = formatRemoteDate(it.updatedAt ?: it.started),
                        )
                    }.orEmpty()
                }

                updateWidget(
                    context = context,
                    appWidgetManager = appWidgetManager,
                    appWidgetId = appWidgetId,
                    noticeType = noticeType,
                    notices = notices,
                    isLoading = false,
                    didLoadSuccessfully = summary != null,
                )
            }
        }

        /** Writes current notice rows into the large widget RemoteViews. */
        private fun updateWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int,
            noticeType: String,
            notices: List<WidgetNotice>,
            isLoading: Boolean,
            didLoadSuccessfully: Boolean = true,
        ) {
            val accentColor = notices.firstOrNull()?.status?.let { statusColor(it).toArgb() }
                ?: if (noticeType == "Maintenance") 0xFF64B5F6.toInt() else 0xFF4CAF50.toInt()
            val statusText = when {
                isLoading -> "Loading"
                !didLoadSuccessfully -> "Unable to load status"
                notices.isEmpty() && noticeType == "Maintenance" -> "No planned maintenance"
                notices.isEmpty() -> "No active incidents"
                else -> activeNoticeSummary(notices.size, noticeType)
            }

            val views = RemoteViews(context.packageName, R.layout.olilo_notices_widget).apply {
                setTextViewText(R.id.notices_widget_type, noticeType)
                setTextViewText(R.id.notices_widget_count, if (isLoading) "-" else notices.size.toString())
                setTextViewText(R.id.notices_widget_updated, if (isLoading) "Loading" else "Now")
                setInt(R.id.notices_widget_count, "setTextColor", accentColor)
                setInt(R.id.notices_widget_timeline, "setColorFilter", accentColor)
                setContentDescription(
                    R.id.notices_widget_root,
                    "Olilo Status $noticeType widget. $statusText. Opens Olilo Status.",
                )
                setOnClickPendingIntent(R.id.notices_widget_root, launchAppIntent(context))
                removeAllViews(R.id.notices_widget_rows)
            }

            val rows = when {
                isLoading -> listOf(WidgetNotice("Loading status", "UNKNOWN", "Please wait", null))
                !didLoadSuccessfully -> listOf(WidgetNotice("Unable to load status", "UNKNOWN", "Try again later", null))
                notices.isEmpty() -> listOf(WidgetNotice(statusText, "OPERATIONAL", "Checked just now", null))
                else -> notices.take(4)
            }

            rows.forEach { notice ->
                views.addView(R.id.notices_widget_rows, noticeRowViews(context, notice, accentColor))
            }

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }

        /** Creates one RemoteViews row for the large notice widget list. */
        private fun noticeRowViews(context: Context, notice: WidgetNotice, accentColor: Int): RemoteViews {
            val detail = listOfNotNull(readableStatus(notice.detailStatus), notice.date)
                .filter { it.isNotBlank() }
                .joinToString(" - ")
            return RemoteViews(context.packageName, R.layout.olilo_notices_widget_row).apply {
                setTextViewText(R.id.notices_widget_row_title, notice.title)
                setTextViewText(R.id.notices_widget_row_detail, detail)
                setInt(R.id.notices_widget_row_dot, "setColorFilter", accentColor)
            }
        }

        /** Fetches the status summary used by the large widget, returning null on failure. */
        private fun fetchSummary(): StatusPageSummary? = runCatching {
            val connection = (URL(SUMMARY_URL).openConnection() as HttpURLConnection).apply {
                connectTimeout = 15_000
                readTimeout = 15_000
                requestMethod = "GET"
            }
            try {
                val body = connection.inputStream.bufferedReader().use { it.readText() }
                json.decodeFromString<StatusPageSummary>(body)
            } finally {
                connection.disconnect()
            }
        }.getOrNull()

        /** Builds the pending intent that opens the main app from the large widget. */
        private fun launchAppIntent(context: Context): PendingIntent {
            val intent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                putExtra(MainActivity.NOTIFICATION_TARGET_TAB, MainActivity.TAB_NOTICES)
            }
            return PendingIntent.getActivity(
                context,
                1,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
        }

        /** Loads a large widget's selected notice type, falling back to incidents. */
        private fun loadNoticeType(context: Context, appWidgetId: Int): String =
            context.getSharedPreferences(WIDGET_PREFERENCES_NAME, Context.MODE_PRIVATE)
                .getString(noticeTypeKey(appWidgetId), null)
                ?.takeIf { it in noticeTypes }
                ?: noticeTypes.first()

        /** Builds the preference key for a large widget notice type selection. */
        private fun noticeTypeKey(appWidgetId: Int): String = "notice_type_$appWidgetId"

        /** Describes non-empty notice counts without producing singular/plural mismatches. */
        private fun activeNoticeSummary(count: Int, noticeType: String): String = when (noticeType) {
            "Maintenance" -> "$count planned maintenance ${if (count == 1) "notice" else "notices"}"
            else -> "$count active ${if (count == 1) "incident" else "incidents"}"
        }

        private const val SUMMARY_URL = "https://status.olilo.co.uk/v3/summary.json"
        private const val WIDGET_PREFERENCES_NAME = "olilo_notices_widget_preferences"
    }
}

private data class WidgetNotice(
    val title: String,
    val status: String,
    val detailStatus: String,
    val date: String?,
)
