package uk.co.olilo.status.status

import android.content.Context
import androidx.compose.ui.graphics.Color
import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.time.format.FormatStyle
import java.util.Locale

val oliloPurple = Color(0xFFB347FF)
val oliloBlue = Color(0xFF2985FF)
val oliloRed = Color(0xFFFF4052)
val oliloGreen = Color(0xFF2EC771)
val oliloOrange = Color(0xFFFF8C2E)
val oliloBackgroundTop = Color(0xFF050108)
val oliloBackgroundMid = Color(0xFF210A3D)
val oliloBackgroundBottom = Color(0xFF4D147A)

data class OliloThemeColors(
    val top: Color,
    val mid: Color,
    val bottom: Color,
)

enum class OliloTheme(
    val displayName: String,
    val accentColor: Color,
    val backgroundColors: OliloThemeColors,
) {
    OliloPurple(
        "Olilo Purple",
        oliloPurple,
        OliloThemeColors(oliloBackgroundTop, oliloBackgroundMid, oliloBackgroundBottom),
    ),
    OliloBlue(
        "Olilo Blue",
        oliloBlue,
        OliloThemeColors(Color(0xFF050108), Color(0xFF081740), Color(0xFF0D387A)),
    ),
    OliloRed(
        "Olilo Red",
        oliloRed,
        OliloThemeColors(Color(0xFF050108), Color(0xFF38070F), Color(0xFF7A1420)),
    ),
    OliloGreen(
        "Olilo Green",
        oliloGreen,
        OliloThemeColors(Color(0xFF050108), Color(0xFF082819), Color(0xFF0A5733)),
    ),
    OliloOrange(
        "Olilo Orange",
        oliloOrange,
        OliloThemeColors(Color(0xFF050108), Color(0xFF381904), Color(0xFF853809)),
    );
}

private const val APPEARANCE_PREFERENCES_NAME = "appearance_preferences"
private const val SELECTED_THEME_KEY = "selected_olilo_theme"

/** Loads the selected app-wide appearance theme. */
fun loadOliloTheme(context: Context): OliloTheme {
    val rawValue = context.getSharedPreferences(APPEARANCE_PREFERENCES_NAME, Context.MODE_PRIVATE)
        .getString(SELECTED_THEME_KEY, null)
    return OliloTheme.entries.firstOrNull { it.name == rawValue } ?: OliloTheme.OliloPurple
}

/** Persists the selected app-wide appearance theme. */
fun saveOliloTheme(context: Context, theme: OliloTheme) {
    context.getSharedPreferences(APPEARANCE_PREFERENCES_NAME, Context.MODE_PRIVATE)
        .edit()
        .putString(SELECTED_THEME_KEY, theme.name)
        .apply()
}

/** Maps backend status strings to numeric severity for sorting and summaries. */
fun statusSeverity(status: String): Int = when (status.uppercase(Locale.UK)) {
    "UP", "OPERATIONAL", "RESOLVED", "COMPLETED" -> 0
    "UNDERMAINTENANCE", "MONITORING", "NOTSTARTEDYET" -> 1
    "HASISSUES", "HAS_ISSUES", "DEGRADEDPERFORMANCE", "DEGRADED_PERFORMANCE", "IDENTIFIED" -> 2
    "PARTIALOUTAGE", "PARTIAL_OUTAGE", "INVESTIGATING" -> 3
    "MAJOROUTAGE", "MAJOR_OUTAGE" -> 4
    else -> 2
}

/** Chooses the display color associated with a backend status string. */
fun statusColor(status: String, themeColor: Color = oliloPurple): Color = when (status.uppercase(Locale.UK)) {
    "UP", "OPERATIONAL", "RESOLVED", "COMPLETED" -> themeColor
    "UNDERMAINTENANCE", "MONITORING", "NOTSTARTEDYET" -> Color(0xFF64B5F6)
    "HASISSUES", "HAS_ISSUES", "DEGRADEDPERFORMANCE", "DEGRADED_PERFORMANCE", "IDENTIFIED" -> Color(0xFFFFB74D)
    "PARTIALOUTAGE", "PARTIAL_OUTAGE", "INVESTIGATING" -> Color(0xFFFFE066)
    "MAJOROUTAGE", "MAJOR_OUTAGE" -> Color(0xFFFF5252)
    else -> Color(0xFFBDB3C7)
}

/** Converts backend status identifiers into readable user-facing text. */
fun readableStatus(status: String): String = when (status.uppercase(Locale.UK)) {
    "UP" -> "Up"
    "OPERATIONAL" -> "Operational"
    "HASISSUES", "HAS_ISSUES" -> "Has issues"
    "UNDERMAINTENANCE" -> "Under maintenance"
    "DEGRADEDPERFORMANCE", "DEGRADED_PERFORMANCE" -> "Degraded performance"
    "PARTIALOUTAGE", "PARTIAL_OUTAGE" -> "Partial outage"
    "MAJOROUTAGE", "MAJOR_OUTAGE" -> "Major outage"
    "INVESTIGATING" -> "Investigating"
    "IDENTIFIED" -> "Identified"
    "MONITORING" -> "Monitoring"
    "RESOLVED" -> "Resolved"
    "NOTSTARTEDYET" -> "Not started yet"
    "COMPLETED" -> "Completed"
    else -> status.replace('_', ' ')
        .lowercase(Locale.UK)
        .replaceFirstChar { if (it.isLowerCase()) it.titlecase(Locale.UK) else it.toString() }
}

/** Formats an ISO-8601 date from the status API for the local timezone. */
fun formatRemoteDate(value: String?): String? {
    if (value.isNullOrBlank()) return null
    return runCatching {
        val formatter = DateTimeFormatter.ofLocalizedDateTime(FormatStyle.MEDIUM, FormatStyle.SHORT)
        Instant.parse(value).atZone(ZoneId.systemDefault()).format(formatter)
    }.getOrElse { value }
}

/** Formats an epoch millisecond timestamp as a local time string. */
fun formatTime(millis: Long?): String? {
    if (millis == null) return null
    val formatter = DateTimeFormatter.ofLocalizedTime(FormatStyle.SHORT)
    return Instant.ofEpochMilli(millis).atZone(ZoneId.systemDefault()).format(formatter)
}

/** Groups raw status components into the app's display categories. */
fun groupedComponents(components: List<StatusComponent>): List<StatusComponentGroup> {
    return componentCategories.mapNotNull { category ->
        val includedIds = mutableSetOf<String>()
        val children = category.componentNames.flatMap { componentName ->
            val parent = components.firstOrNull { it.name.equals(componentName, ignoreCase = true) }
                ?: return@flatMap emptyList()
            listOf(parent) + components
                .filter { child ->
                    child.group?.id == parent.id || child.group?.name.equals(parent.name, ignoreCase = true)
                }
                .sortedBy { it.name }
        }.filter { includedIds.add(it.id) }

        if (children.isEmpty()) {
            null
        } else {
            StatusComponentGroup(
                id = category.id,
                name = category.title,
                description = null,
                parent = null,
                children = children,
            )
        }
    }
}

private data class ComponentCategory(
    val id: String,
    val title: String,
    val componentNames: List<String>,
)

private val componentCategories = listOf(
    ComponentCategory(
        id = "network",
        title = "Network",
        componentNames = listOf("Openreach", "Freedom Fibre", "CityFibre", "MS3", "Telehouse North"),
    ),
    ComponentCategory(
        id = "website",
        title = "Website",
        componentNames = listOf("Prosumer Website", "Consumer Website", "Terminal", "API"),
    ),
    ComponentCategory(
        id = "connections",
        title = "Connections",
        componentNames = listOf("3rd Party"),
    ),
)
