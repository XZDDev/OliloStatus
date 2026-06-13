package uk.co.olilo.status.notifications

import android.content.Context
import com.google.firebase.messaging.FirebaseMessaging
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.withContext
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import java.net.HttpURLConnection
import java.net.URL
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException

/**
 * Entry point for opting a device in/out of push notifications and keeping the
 * backend in sync. All methods are safe to call from a coroutine.
 *
 * Typical usage from the UI (after the user grants the POST_NOTIFICATIONS
 * runtime permission on Android 13+):
 *
 *     lifecycleScope.launch { OliloNotifications.enable(context) }
 */
object OliloNotifications {
    /** Base URL of the notifications backend (no trailing slash). */
    const val BASE_URL = "https://notifications.example.com"

    /**
     * Shared secret sent as `x-api-key`. Leave null if the backend has no
     * API_KEY configured. A key shipped in the app only deters casual abuse.
     */
    val API_KEY: String? = null

    private val json = Json { encodeDefaults = true }

    /** Request the FCM token and register this device with the backend. */
    suspend fun enable(context: Context) {
        NotificationStore.setEnabled(context, true)
        val token = fetchToken()
        NotificationStore.saveToken(context, token)
        register(context, token)
    }

    /** Stop delivery to this device. */
    suspend fun disable(context: Context) {
        NotificationStore.setEnabled(context, false)
        val token = NotificationStore.token(context) ?: return
        send("DELETE", "api/devices/$token", PlatformBody())
    }

    /** Persist and push updated preferences if the device is registered. */
    suspend fun updatePreferences(context: Context, preferences: NotificationPreferences) {
        NotificationStore.savePreferences(context, preferences)
        if (!NotificationStore.isEnabled(context)) return
        val token = NotificationStore.token(context) ?: return
        send("PATCH", "api/devices/$token/preferences", PreferencesBody(preferences = preferences))
    }

    /** Called by the messaging service when FCM rotates the token. */
    suspend fun register(context: Context, token: String) {
        NotificationStore.saveToken(context, token)
        if (!NotificationStore.isEnabled(context)) return
        send(
            "POST",
            "api/devices/register",
            RegisterBody(
                token = token,
                preferences = NotificationStore.preferences(context),
                locale = java.util.Locale.getDefault().toLanguageTag(),
                appVersion = appVersion(context),
            ),
        )
    }

    // region HTTP

    @Serializable
    private data class RegisterBody(
        val token: String,
        val platform: String = "android",
        val preferences: NotificationPreferences,
        val locale: String,
        val appVersion: String,
    )

    @Serializable
    private data class PreferencesBody(
        val platform: String = "android",
        val preferences: NotificationPreferences,
    )

    @Serializable
    private data class PlatformBody(val platform: String = "android")

    private suspend inline fun <reified T> send(method: String, path: String, body: T) =
        withContext(Dispatchers.IO) {
            val connection = (URL("$BASE_URL/$path").openConnection() as HttpURLConnection).apply {
                requestMethod = method
                connectTimeout = 15_000
                readTimeout = 15_000
                doOutput = true
                setRequestProperty("Content-Type", "application/json")
                API_KEY?.let { setRequestProperty("x-api-key", it) }
            }
            try {
                connection.outputStream.use { it.write(json.encodeToString(body).toByteArray()) }
                val code = connection.responseCode
                check(code in 200..299) { "backend responded $code for $method $path" }
            } finally {
                connection.disconnect()
            }
        }

    // endregion

    /** Bridge FCM's Task-based token API into a coroutine. */
    private suspend fun fetchToken(): String = suspendCancellableCoroutine { cont ->
        FirebaseMessaging.getInstance().token
            .addOnSuccessListener { token -> cont.resume(token) }
            .addOnFailureListener { error -> cont.resumeWithException(error) }
    }

    private fun appVersion(context: Context): String =
        runCatching {
            context.packageManager.getPackageInfo(context.packageName, 0).versionName ?: "unknown"
        }.getOrDefault("unknown")
}
