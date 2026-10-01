import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing key, kept out of the repo: android/key.properties gives
// its path and alias; passwords come from the environment (scripts/release.sh
// asks for them), so they never sit on disk. Without it, release builds use
// the debug key: fine for `flutter run --release`, refused by the release
// script.
val signing = Properties().apply {
    val file = rootProject.file("key.properties")
    if (file.exists()) FileInputStream(file).use { load(it) }
}

android {
    namespace = "app.whisper.messenger"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // Final: changing it after the first release makes a different app.
        applicationId = "app.whisper.messenger"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (!signing.isEmpty) {
                storeFile = file(signing.getProperty("storeFile"))
                keyAlias = signing.getProperty("keyAlias")
                storePassword = System.getenv("WHISPER_STORE_PASSWORD")
                keyPassword = System.getenv("WHISPER_KEY_PASSWORD")
                    ?: System.getenv("WHISPER_STORE_PASSWORD")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName(
                if (signing.isEmpty) "debug" else "release",
            )
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // BiometricPrompt with CryptoObject (Keystore key gated by biometrics).
    implementation("androidx.biometric:biometric:1.1.0")
    // NotificationCompat (background delivery notifications).
    implementation("androidx.core:core-ktx:1.13.1")
    // Snowflake / obfs4 / meek pluggable transports for Tor (task 12).
    implementation("com.netzarchitekten:IPtProxy:5.5.1")
}
