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

// file_picker 8.x hardcodes `compileSdk 34` in its own build.gradle, but its
// flutter_plugin_android_lifecycle dependency requires compileSdk 36+
// (CI run #88 failed at :file_picker:checkReleaseAarMetadata).
// The app's own compileSdk = 36 does not propagate to plugin modules, so
// raise every Android library module to 36 here. This only widens the
// compile-time API surface; minSdk stays 21.
// (Root build.gradle.kts forces subprojects to evaluate after :app, so this
// hook is registered before :file_picker is evaluated.)
rootProject.subprojects {
    afterEvaluate {
        extensions.findByType<com.android.build.gradle.LibraryExtension>()?.let {
            it.compileSdk = 36
        }
    }
}
