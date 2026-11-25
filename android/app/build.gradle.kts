plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.abqariya.app"
    // compileSdk 36 (not flutter.compileSdkVersion): file_picker's
    // flutter_plugin_android_lifecycle dependency requires consumers to
    // compile against Android API 36+. Flutter 3.50.1's default is lower,
    // so the release build failed at :file_picker:checkReleaseAarMetadata.
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // Unique application id — matches the Play-free sideload identity.
        applicationId = "com.abqariya.app"
        // Minimum Android 5.0 (API 21): covers mid-range devices in Yemen.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // Signing is configured in CI via a release keystore.
            // Never commit a keystore or its passwords to the repo.
            // Debug signing is used only for local development builds.
            signingConfig = signingConfigs.getByName("debug")
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

dependencies {
    // No extra Android dependencies in v1 — offline only.
}
