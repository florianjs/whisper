package com.florian.whisper

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import androidx.core.app.ActivityCompat
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat

/**
 * Background delivery without Google push: a foreground service keeps the
 * process (and so the Flutter engine, Tor and the relay connections) alive,
 * like Briar. Notifications never carry a name or message text.
 */
object Background {
    private const val CONNECTION_CHANNEL = "connection"
    private const val MESSAGES_CHANNEL = "messages"
    const val CONNECTION_ID = 1
    private const val MESSAGES_ID = 2

    fun channels(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val nm = context.getSystemService(NotificationManager::class.java)
        nm.createNotificationChannel(
            NotificationChannel(CONNECTION_CHANNEL, "Connection", NotificationManager.IMPORTANCE_MIN).apply {
                setShowBadge(false)
            }
        )
        nm.createNotificationChannel(
            NotificationChannel(MESSAGES_CHANNEL, "Messages", NotificationManager.IMPORTANCE_HIGH)
        )
    }

    private fun openApp(context: Context): PendingIntent {
        val intent = Intent(context, MainActivity::class.java)
            .addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        return PendingIntent.getActivity(context, 0, intent, PendingIntent.FLAG_IMMUTABLE)
    }

    fun connectionNotification(context: Context, title: String, text: String): Notification =
        NotificationCompat.Builder(context, CONNECTION_CHANNEL)
            .setSmallIcon(R.drawable.ic_stat_whisper)
            .setContentTitle(title)
            .setContentText(text)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_MIN)
            .setContentIntent(openApp(context))
            .build()

    fun showMessages(context: Context, title: String, text: String) {
        if (!canNotify(context)) return
        val n = NotificationCompat.Builder(context, MESSAGES_CHANNEL)
            .setSmallIcon(R.drawable.ic_stat_whisper)
            .setContentTitle(title)
            .setContentText(text)
            .setAutoCancel(true)
            .setOnlyAlertOnce(false)
            // Generic text anyway; still keep it off the lock screen's details.
            .setVisibility(NotificationCompat.VISIBILITY_PRIVATE)
            .setContentIntent(openApp(context))
            .build()
        NotificationManagerCompat.from(context).notify(MESSAGES_ID, n)
    }

    fun clearMessages(context: Context) {
        NotificationManagerCompat.from(context).cancel(MESSAGES_ID)
    }

    fun canNotify(context: Context): Boolean =
        Build.VERSION.SDK_INT < 33 ||
            ContextCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS) ==
            PackageManager.PERMISSION_GRANTED

    fun requestPermission(activity: MainActivity) {
        if (Build.VERSION.SDK_INT >= 33 && !canNotify(activity)) {
            ActivityCompat.requestPermissions(activity, arrayOf(Manifest.permission.POST_NOTIFICATIONS), 7)
        }
    }

    fun start(context: Context, title: String, text: String) {
        val intent = Intent(context, KeepAliveService::class.java)
            .putExtra("title", title)
            .putExtra("text", text)
        ContextCompat.startForegroundService(context, intent)
    }

    fun stop(context: Context) {
        context.stopService(Intent(context, KeepAliveService::class.java))
    }
}

class KeepAliveService : Service() {
    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Background.channels(this)
        val n = Background.connectionNotification(
            this,
            intent?.getStringExtra("title") ?: "Whisper",
            intent?.getStringExtra("text") ?: "",
        )
        if (Build.VERSION.SDK_INT >= 34) {
            startForeground(Background.CONNECTION_ID, n, ServiceInfo.FOREGROUND_SERVICE_TYPE_REMOTE_MESSAGING)
        } else {
            startForeground(Background.CONNECTION_ID, n)
        }
        // Restarted by Android after a kill: the engine isn't, so there is
        // nothing to keep alive — don't come back empty.
        return START_NOT_STICKY
    }
}
