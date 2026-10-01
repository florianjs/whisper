package com.florian.whisper

import android.content.ClipData
import android.content.ClipboardManager
import android.accessibilityservice.AccessibilityServiceInfo
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.PersistableBundle
import android.provider.Settings
import android.view.accessibility.AccessibilityManager
import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel

// FragmentActivity: required by androidx BiometricPrompt.
class MainActivity : FlutterFragmentActivity() {
    private val biometrics by lazy { BiometricVault(this) }

    /**
     * One engine for the process, not tied to this activity: when the user
     * leaves the app (back, swipe from recents), Dart keeps running under the
     * foreground service and messages still arrive.
     */
    override fun getCachedEngineId(): String {
        val cache = FlutterEngineCache.getInstance()
        if (cache.get(ENGINE_ID) == null) {
            val engine = FlutterEngine(applicationContext)
            engine.dartExecutor.executeDartEntrypoint(DartExecutor.DartEntrypoint.createDefault())
            cache.put(ENGINE_ID, engine)
        }
        return ENGINE_ID
    }

    override fun shouldDestroyEngineWithHost(): Boolean = false

    private var pendingResult: MethodChannel.Result? = null
    private var pendingSave: ByteArray? = null

    @Deprecated("Simple one-shot pickers; no ActivityResult registry needed.")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != SAVE_REQUEST && requestCode != OPEN_REQUEST) return
        val result = pendingResult ?: return
        pendingResult = null
        val uri = data?.data
        if (resultCode != RESULT_OK || uri == null) {
            pendingSave = null
            result.success(null) // cancelled
            return
        }
        try {
            if (requestCode == SAVE_REQUEST) {
                val bytes = pendingSave
                pendingSave = null
                contentResolver.openOutputStream(uri, "wt")!!.use { it.write(bytes) }
                result.success(true)
            } else {
                // Backups are a few MB at most; refuse absurd files.
                val bytes = contentResolver.openInputStream(uri)!!.use { input ->
                    input.readBytes().also { if (it.size > 512 * 1024 * 1024) error("too large") }
                }
                result.success(bytes)
            }
        } catch (e: Exception) {
            result.error("io", e.message, null)
        }
    }

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        // A new activity on the long-lived engine gets a fresh window: the
        // FLAG_SECURE Dart asked for earlier must hold from the first frame.
        applySecure()
        super.onCreate(savedInstanceState)
    }

    private fun applySecure() {
        if (secure) {
            window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
        } else {
            window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
        }
    }

    companion object {
        private const val ENGINE_ID = "whisper"
        private const val SAVE_REQUEST = 41
        private const val OPEN_REQUEST = 42

        /** Last FLAG_SECURE state requested by Dart, for the process. */
        @Volatile
        private var secure = false
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "whisper/files")
            .setMethodCallHandler { call, result ->
                // Storage Access Framework: the user picks where; the app
                // needs no storage permission and sees nothing else.
                when (call.method) {
                    "save" -> {
                        pendingSave = call.argument<ByteArray>("bytes")
                        pendingResult = result
                        startActivityForResult(
                            Intent(Intent.ACTION_CREATE_DOCUMENT)
                                .addCategory(Intent.CATEGORY_OPENABLE)
                                .setType("application/octet-stream")
                                .putExtra(Intent.EXTRA_TITLE, call.argument<String>("name")),
                            SAVE_REQUEST,
                        )
                    }
                    "open" -> {
                        pendingResult = result
                        startActivityForResult(
                            Intent(Intent.ACTION_OPEN_DOCUMENT)
                                .addCategory(Intent.CATEGORY_OPENABLE)
                                .setType("*/*"),
                            OPEN_REQUEST,
                        )
                    }
                    else -> result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "whisper/background")
            .setMethodCallHandler { call, result ->
                val title = call.argument<String>("title") ?: "Whisper"
                val text = call.argument<String>("text") ?: ""
                when (call.method) {
                    "start" -> {
                        Background.channels(applicationContext)
                        Background.requestPermission(this)
                        Background.start(applicationContext, title, text)
                    }
                    "stop" -> Background.stop(applicationContext)
                    "notify" -> {
                        Background.channels(applicationContext)
                        Background.showMessages(applicationContext, title, text)
                    }
                    "clear" -> Background.clearMessages(applicationContext)
                    else -> { result.notImplemented(); return@setMethodCallHandler }
                }
                result.success(null)
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "whisper/pt")
            .setMethodCallHandler { call, result ->
                val transport = call.argument<String>("transport")
                if (transport == null) {
                    result.error("bad_args", "expected a transport", null)
                    return@setMethodCallHandler
                }
                // IPtProxy start blocks while it binds: off the UI thread.
                Thread {
                    try {
                        val value: Any? = when (call.method) {
                            "start" -> PluggableTransports.start(
                                applicationContext,
                                transport,
                                call.argument<Map<String, String>>("params") ?: emptyMap(),
                            )
                            "stop" -> { PluggableTransports.stop(transport); null }
                            else -> { runOnUiThread { result.notImplemented() }; return@Thread }
                        }
                        runOnUiThread { result.success(value) }
                    } catch (e: Exception) {
                        runOnUiThread { result.error("pt_failed", e.message, null) }
                    }
                }.start()
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "whisper/secure")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "setSecure" -> {
                        secure = call.arguments as? Boolean == true
                        applySecure()
                        result.success(null)
                    }
                    "copySensitive" -> {
                        val text = call.arguments as? String
                        if (text == null) {
                            result.error("bad_args", "expected a string", null)
                            return@setMethodCallHandler
                        }
                        val clip = ClipData.newPlainText("", text)
                        // Hides the content from the Android 13+ clipboard preview.
                        clip.description.extras = PersistableBundle().apply {
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                                putBoolean(android.content.ClipDescription.EXTRA_IS_SENSITIVE, true)
                            } else {
                                putBoolean("android.content.extra.IS_SENSITIVE", true)
                            }
                        }
                        val cm = getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
                        cm.setPrimaryClip(clip)
                        result.success(null)
                    }
                    "enabledAccessibilityServices" -> {
                        // Apps that can read the screen through accessibility —
                        // the usual spyware route. Labels only, for the warning.
                        val am = getSystemService(Context.ACCESSIBILITY_SERVICE) as AccessibilityManager
                        val labels = am
                            .getEnabledAccessibilityServiceList(AccessibilityServiceInfo.FEEDBACK_ALL_MASK)
                            .mapNotNull { it.resolveInfo?.loadLabel(packageManager)?.toString() }
                            .distinct()
                        result.success(labels)
                    }
                    "openAccessibilitySettings" -> {
                        startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS))
                        result.success(null)
                    }
                    "biometricAvailable" -> result.success(biometrics.isAvailable())
                    "biometricStore" -> biometrics.store(
                        call.argument<String>("secret") ?: "",
                        call.argument<String>("title") ?: "",
                        call.argument<String>("cancel") ?: "",
                    ) { ok -> result.success(ok) }
                    "biometricRead" -> biometrics.read(
                        call.argument<String>("title") ?: "",
                        call.argument<String>("cancel") ?: "",
                    ) { secret -> result.success(secret) }
                    "biometricDelete" -> {
                        biometrics.delete()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
