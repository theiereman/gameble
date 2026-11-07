package net.gameble.app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage

class PushService : FirebaseMessagingService() {
    override fun onMessageReceived(message: RemoteMessage) {
        val notification = message.notification ?: return
        val open = Intent(this, MainActivity::class.java)
            .putExtra(PATH_EXTRA, message.data["path"])
            .addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
        val tap = PendingIntent.getActivity(this, message.hashCode(), open, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)

        val shown = NotificationCompat.Builder(this, CHANNEL)
            .setSmallIcon(android.R.drawable.stat_notify_chat)
            .setContentTitle(notification.title)
            .setContentText(notification.body)
            .setContentIntent(tap)
            .setAutoCancel(true)
            .build()
        runCatching { NotificationManagerCompat.from(this).notify(message.hashCode(), shown) }
    }

    override fun onNewToken(token: String) = Unit

    companion object {
        const val PATH_EXTRA = "path"
        private const val CHANNEL = "game"

        fun createChannel(context: Context) {
            val channel = NotificationChannel(CHANNEL, context.getString(R.string.notification_channel), NotificationManager.IMPORTANCE_DEFAULT)
            context.getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
        }
    }
}
