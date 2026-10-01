package app.whisper.messenger

import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageInfo
import android.content.pm.PackageInstaller
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.IntentCompat
import java.io.File
import java.security.MessageDigest

/**
 * Installs an update downloaded by the Dart side (see UpdateService), after
 * checking it on its own: same app, newer version, signed with the release
 * key. Android enforces the key too; checking first gives a clear error.
 *
 * Android 12+ skips the confirmation when this app is its own installer of
 * record (every update after the first one done here); otherwise Android
 * asks the user.
 */
object Updater {
    private const val ACTION = "app.whisper.messenger.INSTALL_STATUS"

    /** Install outcomes (`pending`, `success`, `failed`), for Dart. */
    @Volatile
    var onStatus: ((String, String?) -> Unit)? = null

    class Rejected(val code: String) : Exception(code)

    fun info(context: Context): Map<String, Any?> {
        val pm = context.packageManager
        val own = packageInfo(pm, context.packageName)
        return mapOf(
            "version" to own.versionName,
            "abis" to Build.SUPPORTED_ABIS.toList(),
            "installer" to installerOf(context),
        )
    }

    /** "Install unknown apps" granted to Whisper. */
    fun canInstall(context: Context): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.O ||
            context.packageManager.canRequestPackageInstalls()

    fun openInstallPermission(context: Context) {
        context.startActivity(
            Intent(
                Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                Uri.parse("package:${context.packageName}"),
            ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
        )
    }

    /** Throws [Rejected] unless [path] is a newer Whisper signed with [certSha256]. */
    fun check(context: Context, path: String, certSha256: String) {
        val pm = context.packageManager
        val archive = archiveInfo(pm, path) ?: throw Rejected("unreadable")
        if (archive.packageName != context.packageName) throw Rejected("not_ours")
        if (versionCode(archive) <= versionCode(packageInfo(pm, context.packageName))) {
            throw Rejected("not_newer")
        }
        val signers = signerDigests(archive)
        if (signers.isEmpty() || signers.any { it != certSha256.lowercase() }) {
            throw Rejected("bad_signature")
        }
    }

    /** Streams [path] into an install session; the outcome comes via [onStatus]. */
    fun install(context: Context, path: String) {
        val file = File(path)
        val installer = context.packageManager.packageInstaller
        val params = PackageInstaller.SessionParams(PackageInstaller.SessionParams.MODE_FULL_INSTALL).apply {
            setAppPackageName(context.packageName)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                setRequireUserAction(PackageInstaller.SessionParams.USER_ACTION_NOT_REQUIRED)
            }
        }
        val id = installer.createSession(params)
        installer.openSession(id).use { session ->
            file.inputStream().use { input ->
                session.openWrite("whisper.apk", 0, file.length()).use { out ->
                    input.copyTo(out)
                    session.fsync(out)
                }
            }
            val intent = Intent(context, InstallStatusReceiver::class.java).setAction(ACTION)
            // Mutable: the installer fills in the status extras.
            val flags = PendingIntent.FLAG_UPDATE_CURRENT or
                (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) PendingIntent.FLAG_MUTABLE else 0)
            session.commit(PendingIntent.getBroadcast(context, id, intent, flags).intentSender)
        }
    }

    private fun installerOf(context: Context): String? =
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                context.packageManager.getInstallSourceInfo(context.packageName).installingPackageName
            } else {
                @Suppress("DEPRECATION")
                context.packageManager.getInstallerPackageName(context.packageName)
            }
        } catch (_: Exception) {
            null
        }

    @Suppress("DEPRECATION")
    private fun packageInfo(pm: PackageManager, name: String): PackageInfo = pm.getPackageInfo(name, 0)

    @Suppress("DEPRECATION")
    private fun archiveInfo(pm: PackageManager, path: String): PackageInfo? =
        pm.getPackageArchiveInfo(
            path,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                PackageManager.GET_SIGNING_CERTIFICATES
            } else {
                PackageManager.GET_SIGNATURES
            },
        )

    @Suppress("DEPRECATION")
    private fun versionCode(info: PackageInfo): Long =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) info.longVersionCode else info.versionCode.toLong()

    @Suppress("DEPRECATION")
    private fun signerDigests(info: PackageInfo): List<String> {
        val signatures = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            info.signingInfo?.apkContentsSigners
        } else {
            info.signatures
        } ?: return emptyList()
        return signatures.map { sig ->
            MessageDigest.getInstance("SHA-256").digest(sig.toByteArray())
                .joinToString("") { "%02x".format(it) }
        }
    }
}

class InstallStatusReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val status = intent.getIntExtra(PackageInstaller.EXTRA_STATUS, PackageInstaller.STATUS_FAILURE)
        when (status) {
            PackageInstaller.STATUS_PENDING_USER_ACTION -> {
                // Android's own confirmation screen.
                IntentCompat.getParcelableExtra(intent, Intent.EXTRA_INTENT, Intent::class.java)?.let {
                    context.startActivity(it.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                }
                Updater.onStatus?.invoke("pending", null)
            }
            PackageInstaller.STATUS_SUCCESS -> Updater.onStatus?.invoke("success", null)
            else -> Updater.onStatus?.invoke(
                "failed",
                intent.getStringExtra(PackageInstaller.EXTRA_STATUS_MESSAGE),
            )
        }
    }
}
