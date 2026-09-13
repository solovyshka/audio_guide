plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
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
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.solovyshka.audio_guide"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = maxOf(26, flutter.minSdkVersion)
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
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

val repoRoot = rootProject.projectDir.resolve("../..")

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
