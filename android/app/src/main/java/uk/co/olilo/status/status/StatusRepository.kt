package uk.co.olilo.status.status

import android.text.Html
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.json.Json
import org.xmlpull.v1.XmlPullParser
import org.xmlpull.v1.XmlPullParserFactory
import java.net.HttpURLConnection
import java.net.URL
import java.time.LocalDateTime
import java.time.Month
import java.time.OffsetDateTime
import java.time.ZoneOffset
import java.time.format.DateTimeFormatter
import java.util.Locale

class StatusRepository {
    private val json = Json { ignoreUnknownKeys = true }

    /** Fetches the summary and component payloads used by the status screen. */
    suspend fun fetchStatus(): StatusScreenState = withContext(Dispatchers.IO) {
        val summary = json.decodeFromString<StatusPageSummary>(
            URL("https://status.olilo.co.uk/v3/summary.json").readText(),
        )
        val components = json.decodeFromString<ComponentsResponse>(
            URL("https://status.olilo.co.uk/v3/components.json").readText(),
        ).components

        StatusScreenState(
            summary = summary,
            components = components,
            incidents = summary.activeIncidents,
            maintenances = summary.activeMaintenances,
            isLoading = false,
            lastRefreshedMillis = System.currentTimeMillis(),
        )
    }

    /** Fetches active notices and historical Atom feed entries for the notices screen. */
    suspend fun fetchNotices(): NoticesScreenState = withContext(Dispatchers.IO) {
        val summary = json.decodeFromString<StatusPageSummary>(
            URL("https://status.olilo.co.uk/v3/summary.json").readText(),
        )
        val notices = AtomNoticeParser().parse(
            URL("https://status.olilo.co.uk/default/history.atom").readText(),
        )

        NoticesScreenState(
            activeIncidents = summary.activeIncidents,
            activeMaintenances = summary.activeMaintenances,
            notices = notices,
            isLoading = false,
            lastRefreshedMillis = System.currentTimeMillis(),
        )
    }
}

/** Reads the URL body with bounded timeouts and always closes the connection. */
private fun URL.readText(): String {
    val connection = (openConnection() as HttpURLConnection).apply {
        connectTimeout = 15_000
        readTimeout = 15_000
        requestMethod = "GET"
    }
    return try {
        connection.inputStream.bufferedReader().use { it.readText() }
    } finally {
        connection.disconnect()
    }
}

private class AtomNoticeParser {
    /** Parses Atom XML and returns notice entries sorted newest first. */
    fun parse(xml: String): List<StatusNotice> {
        val parser = XmlPullParserFactory.newInstance().newPullParser()
        parser.setInput(xml.reader())

        val entries = mutableListOf<Entry>()
        var entry: Entry? = null
        var currentTag = ""
        var event = parser.eventType

        while (event != XmlPullParser.END_DOCUMENT) {
            when (event) {
                XmlPullParser.START_TAG -> {
                    currentTag = parser.name.orEmpty()
                    if (currentTag == "entry") entry = Entry()
                    if (currentTag == "link" && entry != null) {
                        entry = entry.copy(link = parser.getAttributeValue(null, "href"))
                    }
                }
                XmlPullParser.TEXT, XmlPullParser.CDSECT -> {
                    val current = entry
                    val text = parser.text.orEmpty().trim()
                    if (current != null && text.isNotBlank()) {
                        entry = when (currentTag) {
                            "id" -> current.copy(id = current.id + text)
                            "title" -> current.copy(title = current.title + text)
                            "published" -> current.copy(published = current.published + text)
                            "updated" -> current.copy(updated = current.updated + text)
                            "content" -> current.copy(content = current.content + text)
                            else -> current
                        }
                    }
                }
                XmlPullParser.END_TAG -> {
                    if (parser.name == "entry") {
                        entry?.let(entries::add)
                        entry = null
                    }
                    currentTag = ""
                }
            }
            event = parser.nextToken()
        }

        return entries.map { makeNotice(it) }.sortedByDescending { it.published.orEmpty() }
    }

    /** Converts a parsed Atom entry into the app notice model. */
    private fun makeNotice(entry: Entry): StatusNotice {
        val text = entry.content.htmlToPlainText().normalizingWhitespace()
        val updates = parseUpdates(entry.content, entry.published.ifBlank { entry.updated })
        val updateTimestamps = updates.mapNotNull { it.timestamp }
        val kind = NoticeKind.from(valueAfter("Type:", text))
        val id = entry.link?.substringAfterLast('/') ?: entry.id

        return StatusNotice(
            id = id,
            title = entry.title.htmlToPlainText(),
            kind = kind,
            published = updateTimestamps.minOrNull() ?: entry.published.ifBlank { null },
            updated = updateTimestamps.maxOrNull() ?: entry.updated.ifBlank { null },
            link = entry.link,
            duration = valueAfter("Duration:", text),
            affectedComponents = valueAfter("Affected Components:", text),
            summary = updates.firstOrNull()?.message ?: text,
            updates = updates,
        )
    }

    /** Extracts the value following a known label in flattened notice text. */
    private fun valueAfter(label: String, text: String): String? {
        val start = text.indexOf(label)
        if (start == -1) return null
        val tail = text.substring(start + label.length)
        val stopLabels = listOf("Type:", "Duration:", "Affected Components:").filterNot { it == label }
        val labelStop = stopLabels.mapNotNull { stop ->
            tail.indexOf(stop).takeIf { it >= 0 }
        }.minOrNull()
        val dateStop = Regex("[A-Z][a-z]{2}\\s+\\d{1,2},").find(tail)?.range?.first
        val stop = listOfNotNull(labelStop, dateStop).minOrNull() ?: tail.length
        return tail.substring(0, stop).trim().ifBlank { null }
    }

    /** Extracts update rows from the notice HTML content. */
    private fun parseUpdates(html: String, referenceDate: String): List<NoticeUpdate> {
        val pattern = Regex(
            """<p>\s*<small>(.*?)</small>\s*<br\s*/?>\s*<strong>(.*?)</strong>\s*-\s*(.*?)</p>""",
            setOf(RegexOption.DOT_MATCHES_ALL),
        )
        return pattern.findAll(html).mapNotNull { match ->
            val timestamp = parseUpdateTimestamp(match.groupValues[1], referenceDate)
            val status = match.groupValues[2].htmlToPlainText().normalizingWhitespace()
            val message = match.groupValues[3]
                .htmlToPlainText()
                .normalizingWhitespace()
                .trimEnd('.')
            if (status.isBlank() || message.isBlank()) null else NoticeUpdate(timestamp, status, message)
        }.toList()
    }

    /** Parses the feed's update row timestamp, which omits the year. */
    private fun parseUpdateTimestamp(html: String, referenceDate: String): String? {
        val text = html.htmlToPlainText()
            .replace(",", "")
            .normalizingWhitespace()
        val match = Regex("""^([A-Za-z]{3})\s+(\d{1,2})\s+(\d{1,2}):(\d{2}):(\d{2})\s+GMT([+-]\d{1,2})$""")
            .matchEntire(text)
            ?: return null
        val referenceYear = runCatching { OffsetDateTime.parse(referenceDate).year }
            .getOrDefault(OffsetDateTime.now(ZoneOffset.UTC).year)
        val month = Month.entries.firstOrNull {
            it.getDisplayName(java.time.format.TextStyle.SHORT, Locale.US).equals(match.groupValues[1], ignoreCase = true)
        } ?: return null
        val offset = ZoneOffset.ofHours(match.groupValues[6].toInt())
        val dateTime = LocalDateTime.of(
            referenceYear,
            month,
            match.groupValues[2].toInt(),
            match.groupValues[3].toInt(),
            match.groupValues[4].toInt(),
            match.groupValues[5].toInt(),
        )
        return dateTime.atOffset(offset).format(DateTimeFormatter.ISO_OFFSET_DATE_TIME)
    }

    private data class Entry(
        val id: String = "",
        val title: String = "",
        val published: String = "",
        val updated: String = "",
        val link: String? = null,
        val content: String = "",
    )
}

/** Converts HTML content into readable plain text. */
private fun String.htmlToPlainText(): String =
    Html.fromHtml(this, Html.FROM_HTML_MODE_LEGACY).toString()

/** Trims blank lines and joins remaining lines with single newlines. */
private fun String.normalizingWhitespace(): String =
    lines().map { it.trim() }.filter { it.isNotEmpty() }.joinToString("\n")
