package uk.co.olilo.status.notifications

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import androidx.annotation.RequiresPermission
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import uk.co.olilo.status.main.MainActivity
import uk.co.olilo.status.R

/**
 * Receives FCM token rotations and incoming pushes. Registered in the manifest
 * (see Backend/CLIENTS.md for the exact `<service>` snippet).
 */
class OliloMessagingService : FirebaseMessagingService() {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)

    /** Re-registers the rotated FCM token with the backend. */
    @Deprecated("Deprecated in Java")
    override fun onNewToken(token: String) {
        // Re-register so the backend always has the device's current token.
        scope.launch { OliloNotifications.register(applicationContext, token) }
    }

    /** Displays an incoming push notification when notifications are enabled. */
    override fun onMessageReceived(message: RemoteMessage) {
        ensureChannel(this)

        // Prefer the notification block; fall back to data-only payloads.
        val title = message.notification?.title ?: message.data["title"] ?: getString(R.string.app_name)
        val body = message.notification?.body ?: message.data["body"].orEmpty()

        if (NotificationManagerCompat.from(this).areNotificationsEnabled()) {
            showNotification(title, body)
        }
    }

    /** Builds and posts a notification that opens the notices tab. */
    @RequiresPermission(android.Manifest.permission.POST_NOTIFICATIONS)
    private fun showNotification(title: String, body: String) {
        val intent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra(MainActivity.NOTIFICATION_TARGET_TAB, MainActivity.TAB_NOTICES)
        }
        val pending = PendingIntent.getActivity(
            this,
            0,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setAutoCancel(true)
            .setContentIntent(pending)
            .build()

        NotificationManagerCompat.from(this).notify(body.hashCode(), notification)
    }

    companion object {
        const val CHANNEL_ID = "olilo_status"

        /** Creates the Android notification channel if it does not already exist. */
        fun ensureChannel(context: Context) {
            val manager = context.getSystemService(NotificationManager::class.java)
            if (manager.getNotificationChannel(CHANNEL_ID) != null) return
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Olilo Status",
                NotificationManager.IMPORTANCE_DEFAULT,
            ).apply { description = "Incidents, maintenance and component alerts" }
            manager.createNotificationChannel(channel)
        }
    }
}
