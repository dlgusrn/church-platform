package kr.churchapp.church_app

import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

class MainActivity : FlutterActivity() {
    private val channelName = "church_app/secure_storage"
    private val keyAlias = "church_app_tokens"
    private val preferencesName = "encrypted_tokens"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "read" -> result.success(read(call.argument<String>("key")!!))
                        "write" -> {
                            write(
                                call.argument<String>("key")!!,
                                call.argument<String>("value")!!,
                            )
                            result.success(null)
                        }
                        "deleteAll" -> {
                            preferences().edit().clear().apply()
                            result.success(null)
                        }
                        else -> result.notImplemented()
                    }
                } catch (error: Exception) {
                    result.error("secure_storage", error.message, null)
                }
            }
    }

    private fun preferences() = getSharedPreferences(preferencesName, MODE_PRIVATE)

    private fun write(key: String, value: String) {
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.ENCRYPT_MODE, secretKey())
        val encrypted = cipher.doFinal(value.toByteArray(Charsets.UTF_8))
        val payload = cipher.iv + encrypted
        preferences().edit().putString(key, Base64.encodeToString(payload, Base64.NO_WRAP)).apply()
    }

    private fun read(key: String): String? {
        val encoded = preferences().getString(key, null) ?: return null
        val payload = Base64.decode(encoded, Base64.NO_WRAP)
        if (payload.size <= 12) return null
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(
            Cipher.DECRYPT_MODE,
            secretKey(),
            GCMParameterSpec(128, payload.copyOfRange(0, 12)),
        )
        return String(cipher.doFinal(payload.copyOfRange(12, payload.size)), Charsets.UTF_8)
    }

    private fun secretKey(): SecretKey {
        val keyStore = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        (keyStore.getKey(keyAlias, null) as? SecretKey)?.let { return it }
        val generator = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore")
        generator.init(
            KeyGenParameterSpec.Builder(
                keyAlias,
                KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT,
            )
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                .build(),
        )
        return generator.generateKey()
    }
}
