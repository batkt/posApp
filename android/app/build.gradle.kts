import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(keystorePropertiesFile.inputStream())
}

repositories {
    flatDir {
        dirs("libs")
    }
}

android {
    namespace = "mn.posease.mobile.terminal.pos"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    packaging {
        jniLibs {
            // PAX DAL (DeviceConfig) expects extracted .so files under app nativeLibraryDir.
            useLegacyPackaging = true
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "mn.posease.mobile.terminal.pos"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        externalNativeBuild {
            cmake {
                arguments("-DANDROID_SUPPORT_FLEXIBLE_PAGE_SIZES=ON")
            }
            ndkBuild {
                arguments("APP_LDFLAGS+=-Wl,-z,max-page-size=16384")
            }
        }
    }

    packaging {
        jniLibs {
            useLegacyPackaging = true
        }
    }

    signingConfigs {
        if (keystorePropertiesFile.exists()) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storePassword = keystoreProperties["storePassword"] as String
                storeFile =
                    rootProject.file(keystoreProperties["storeFile"] as String)
            }
        }
    }

    buildTypes {
        debug {
            // Same signing key as release (when android/key.properties is present) so a
            // debug build can always install over a release build already on a device,
            // and vice versa, without "App not installed" signature-mismatch errors.
            // Falls back to the auto-generated per-machine debug keystore only when
            // key.properties isn't present (e.g. a dev machine without the shared key).
            signingConfig =
                signingConfigs.findByName("release")
                    ?: signingConfigs.getByName("debug")
        }
        release {
            // Play Store requires a release-signed App Bundle — use android/key.properties
            // + upload-keystore.jks (see android/key.properties.example).
            signingConfig =
                signingConfigs.findByName("debug")
                    ?: signingConfigs.getByName("release")
            // signingConfig =
            //     signingConfigs.findByName("release")
            //         ?: signingConfigs.getByName("debug")
            // When you enable isMinifyEnabled = true, PAX/Neptune needs these keeps (see proguard-rules.pro).
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }

}

flutter {
    source = "../.."
}

dependencies {
    // Load vendor SDKs dropped into android/app/libs (e.g. PAX NeptuneLite .aar/.jar)
    implementation(fileTree(mapOf("dir" to "libs", "include" to listOf("*.jar", "*.aar"))))
}
