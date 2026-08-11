plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

import java.io.File

// Release signing reads from env vars (set in CI from GitHub secrets).
// Falls back to debug signing when absent, so `flutter run --release`
// and local builds keep working without a keystore.
fun releaseKeystore(): File? {
    val path = System.getenv("STUDYFLOW_KEYSTORE_PATH")
    if (path.isNullOrBlank()) return null
    val f = File(path)
    return if (f.exists()) f else null
}

fun envOrNull(name: String): String? = System.getenv(name)?.takeIf { it.isNotBlank() }

android {
    namespace = "ai.studyflow.studyflow_mobile"
    // flutter_secure_storage requires SDK 37; pin above the Flutter default.
    compileSdk = 37
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "ai.studyflow.studyflow_mobile"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        val keystore = releaseKeystore()
        val storePass = envOrNull("STUDYFLOW_KEYSTORE_PASSWORD")
        val alias = envOrNull("STUDYFLOW_KEY_ALIAS")
        val keyPass = envOrNull("STUDYFLOW_KEY_PASSWORD")
        if (keystore != null && storePass != null && alias != null && keyPass != null) {
            create("release") {
                storeFile = keystore
                storePassword = storePass
                keyAlias = alias
                keyPassword = keyPass
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.findByName("release") ?: signingConfigs.getByName("debug")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
