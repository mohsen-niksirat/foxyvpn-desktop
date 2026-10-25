import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// The release key, from android/key.properties (never in Git: CI writes it
// from the repository's secrets). storeFile, storePassword, keyAlias,
// keyPassword.
val releaseKey = Properties().apply {
    val file = rootProject.file("key.properties")
    if (file.exists()) file.inputStream().use { load(it) }
}

android {
    namespace = "com.arman.firefoxvpn"
    compileSdk = flutter.compileSdkVersion
    // The NDK installed here (Flutter's default, 28.x, is not).
    ndkVersion = "30.0.16248370"

    // The native libraries (the Go core, Flutter's engine, the app's code)
    // are compressed inside the APK, as zip files are: a third of the
    // download (33 MB to about 14 MB for arm64). Android unpacks them when it
    // installs the app, which takes a little more room on the phone. The
    // files themselves do not change.
    packaging {
        jniLibs {
            useLegacyPackaging = true
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.arman.firefoxvpn"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // The core's aar is built for API 24 (gomobile bind -androidapi 24).
        minSdk = maxOf(24, flutter.minSdkVersion)
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (!releaseKey.isEmpty) {
                storeFile = file(releaseKey.getProperty("storeFile"))
                storePassword = releaseKey.getProperty("storePassword")
                keyAlias = releaseKey.getProperty("keyAlias")
                keyPassword = releaseKey.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            // Signed with the release key; without key.properties (a fork,
            // a machine without the key) with the debug key, which cannot
            // update an installed release.
            signingConfig = signingConfigs.getByName(if (releaseKey.isEmpty) "debug" else "release")
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
    // The Go core: `gomobile bind -target=android -androidapi 24
    // -o app/android/app/libs/core.aar ./mobile` in core/ (see app/README.md).
    implementation(files("libs/core.aar"))
}
