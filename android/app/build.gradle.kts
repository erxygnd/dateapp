import org.gradle.api.GradleException
import java.util.Properties

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
val hasReleaseKeystore = keystorePropertiesFile.exists()

if (hasReleaseKeystore) {
    keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
}

fun releaseKeystoreProperty(name: String): String =
    keystoreProperties.getProperty(name)
        ?: throw GradleException("android/key.properties icinde '$name' eksik.")

android {
    namespace = "com.piyasa.app"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.piyasa.app"
        minSdk = flutter.minSdkVersion
        targetSdk = 35
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (hasReleaseKeystore) {
                keyAlias = releaseKeystoreProperty("keyAlias")
                keyPassword = releaseKeystoreProperty("keyPassword")
                storeFile = file(releaseKeystoreProperty("storeFile"))
                storePassword = releaseKeystoreProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

flutter {
    source = "../.."
}

tasks.matching { it.name == "assembleRelease" || it.name == "bundleRelease" }
    .configureEach {
        doFirst {
            if (!hasReleaseKeystore) {
                throw GradleException(
                    "Google Play release build icin android/key.properties ve upload keystore gerekli. " +
                        "Ornek icin android/key.properties.example dosyasina bak."
                )
            }
        }
    }
