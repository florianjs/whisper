package app.whisper.messenger

import android.content.Context
import android.os.Build
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyPermanentlyInvalidatedException
import android.security.keystore.KeyProperties
import android.util.Base64
import androidx.biometric.BiometricManager
import androidx.biometric.BiometricManager.Authenticators.BIOMETRIC_STRONG
import androidx.biometric.BiometricPrompt
import androidx.core.content.ContextCompat
import androidx.fragment.app.FragmentActivity
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/**
 * One secret slot gated by strong biometrics.
 *
 * The AES key lives in the Android Keystore, requires a biometric
 * authentication for *every* use (via a CryptoObject — not a mere yes/no
 * callback that root could fake), and is invalidated by the OS as soon as a
 * new fingerprint/face is enrolled. Only the ciphertext is kept in prefs.
 */
class BiometricVault(private val activity: FragmentActivity) {
    private companion object {
        const val KEY_ALIAS = "whisper_biometric_kek"
        const val PREFS = "whisper_biometric"
        const val SLOT = "slot"
    }

    private val prefs get() = activity.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    fun isAvailable(): Boolean =
        BiometricManager.from(activity).canAuthenticate(BIOMETRIC_STRONG) ==
            BiometricManager.BIOMETRIC_SUCCESS

    fun store(secret: String, title: String, cancel: String, done: (Boolean) -> Unit) {
        val cipher = try {
            deleteKey()
            Cipher.getInstance("AES/GCM/NoPadding").apply {
                init(Cipher.ENCRYPT_MODE, createKey())
            }
        } catch (e: Exception) {
            done(false); return
        }
        authenticate(cipher, title, cancel) { authed ->
            if (authed == null) { done(false); return@authenticate }
            val ct = authed.doFinal(secret.toByteArray(Charsets.UTF_8))
            val blob = authed.iv + ct
            prefs.edit().putString(SLOT, Base64.encodeToString(blob, Base64.NO_WRAP)).apply()
            done(true)
        }
    }

    fun read(title: String, cancel: String, done: (String?) -> Unit) {
        val blob = prefs.getString(SLOT, null)?.let { Base64.decode(it, Base64.NO_WRAP) }
        if (blob == null || blob.size < 13) { done(null); return }
        val cipher = try {
            val key = loadKey() ?: run { done(null); return }
            Cipher.getInstance("AES/GCM/NoPadding").apply {
                init(Cipher.DECRYPT_MODE, key, GCMParameterSpec(128, blob, 0, 12))
            }
        } catch (e: KeyPermanentlyInvalidatedException) {
            // New biometric enrolled: this shortcut is gone, PIN required.
            delete(); done(null); return
        } catch (e: Exception) {
            done(null); return
        }
        authenticate(cipher, title, cancel) { authed ->
            done(authed?.let {
                try {
                    String(it.doFinal(blob, 12, blob.size - 12), Charsets.UTF_8)
                } catch (e: Exception) { null }
            })
        }
    }

    fun delete() {
        prefs.edit().remove(SLOT).apply()
        deleteKey()
    }

    private fun authenticate(
        cipher: Cipher,
        title: String,
        cancel: String,
        done: (Cipher?) -> Unit,
    ) {
        val prompt = BiometricPrompt(
            activity,
            ContextCompat.getMainExecutor(activity),
            object : BiometricPrompt.AuthenticationCallback() {
                override fun onAuthenticationSucceeded(result: BiometricPrompt.AuthenticationResult) {
                    done(result.cryptoObject?.cipher)
                }
                override fun onAuthenticationError(code: Int, msg: CharSequence) = done(null)
            },
        )
        val info = BiometricPrompt.PromptInfo.Builder()
            .setTitle(title)
            .setNegativeButtonText(cancel)
            .setAllowedAuthenticators(BIOMETRIC_STRONG)
            .build()
        prompt.authenticate(info, BiometricPrompt.CryptoObject(cipher))
    }

    private fun keyStore() = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }

    private fun loadKey(): SecretKey? = keyStore().getKey(KEY_ALIAS, null) as? SecretKey

    private fun deleteKey() {
        val ks = keyStore()
        if (ks.containsAlias(KEY_ALIAS)) ks.deleteEntry(KEY_ALIAS)
    }

    private fun createKey(): SecretKey {
        val spec = KeyGenParameterSpec.Builder(
            KEY_ALIAS,
            KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT,
        )
            .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
            .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
            .setKeySize(256)
            .setUserAuthenticationRequired(true)
            .setInvalidatedByBiometricEnrollment(true)
            .apply {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                    // Every use needs a fresh strong-biometric auth.
                    setUserAuthenticationParameters(0, KeyProperties.AUTH_BIOMETRIC_STRONG)
                }
            }
            .build()
        return KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore")
            .apply { init(spec) }
            .generateKey()
    }
}
