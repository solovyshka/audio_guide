import java.io.File
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val repoRoot = rootProject.projectDir.resolve("../..")
val keyProperties = Properties()
val keyPropertiesFile = rootProject.file("key.properties")
if (keyPropertiesFile.exists()) {
    keyPropertiesFile.inputStream().use { keyProperties.load(it) }
}

android {
    namespace = "com.solovyshka.audio_guide"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_21
        targetCompatibility = JavaVersion.VERSION_21
    }

    defaultConfig {
        applicationId = "com.solovyshka.audio_guide"
        minSdk = maxOf(26, flutter.minSdkVersion)
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (keyPropertiesFile.exists()) {
            create("release") {
                val store = keyProperties.getProperty("storeFile")
                storeFile = File(store)
                storePassword = keyProperties.getProperty("storePassword")
                keyAlias = keyProperties.getProperty("keyAlias")
                keyPassword = keyProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig =
                signingConfigs.findByName("release") ?: signingConfigs.getByName("debug")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_21
    }
}

flutter {
    source = "../.."
}

fun copyApksToRepo(fromDir: java.io.File, fatName: String) {
    if (!fromDir.exists()) {
        return
    }
    fromDir.listFiles { file -> file.extension == "apk" }?.forEach { apk ->
        val name = when {
            apk.name == "app-release.apk" || apk.name == "app-release-unsigned.apk" -> fatName
            apk.name.startsWith("app-") -> apk.name.replaceFirst("app-", "audio_guide-")
            else -> apk.name
        }
        apk.copyTo(repoRoot.resolve(name), overwrite = true)
    }
}

afterEvaluate {
    tasks.findByName("assembleRelease")?.doLast {
        copyApksToRepo(layout.buildDirectory.dir("outputs/apk/release").get().asFile, "audio_guide.apk")
        copyApksToRepo(rootProject.projectDir.resolve("../build/app/outputs/flutter-apk"), "audio_guide.apk")
    }
    tasks.findByName("assembleDebug")?.doLast {
        copyApksToRepo(layout.buildDirectory.dir("outputs/apk/debug").get().asFile, "audio_guide-debug.apk")
    }
}
