import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val releaseSigningProperties = Properties()
val releaseSigningPropertiesPath = System.getenv("ANDROID_SIGNING_PROPERTIES_FILE")
if (!releaseSigningPropertiesPath.isNullOrBlank()) {
    val propertiesFile = file(releaseSigningPropertiesPath)
    if (!propertiesFile.isFile) {
        throw GradleException("Android signing properties file does not exist")
    }
    propertiesFile.inputStream().use(releaseSigningProperties::load)
}
fun releaseSigningValue(environmentName: String, propertyName: String): String? =
    System.getenv(environmentName)?.takeIf { it.isNotBlank() }
        ?: releaseSigningProperties.getProperty(propertyName)?.takeIf { it.isNotBlank() }

val releaseSigningValues = mapOf(
    "ANDROID_KEYSTORE_PATH" to releaseSigningValue("ANDROID_KEYSTORE_PATH", "storeFile"),
    "ANDROID_KEYSTORE_PASSWORD" to releaseSigningValue("ANDROID_KEYSTORE_PASSWORD", "storePassword"),
    "ANDROID_KEY_ALIAS" to releaseSigningValue("ANDROID_KEY_ALIAS", "keyAlias"),
    "ANDROID_KEY_PASSWORD" to releaseSigningValue("ANDROID_KEY_PASSWORD", "keyPassword"),
)
val releaseBuildRequested = gradle.startParameter.taskNames.any {
    it.contains("release", ignoreCase = true)
}
if (releaseBuildRequested) {
    val missing = releaseSigningValues.filterValues { it.isNullOrBlank() }.keys
    if (missing.isNotEmpty()) {
        throw GradleException("Release signing configuration is missing: ${missing.joinToString()}")
    }
}

android {
    namespace = "com.campusmeow.acceptance.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.campusmeow.acceptance.app"
        manifestPlaceholders["gitCommit"] = System.getenv("GIT_COMMIT") ?: "unknown"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (releaseSigningValues.values.all { !it.isNullOrBlank() }) {
            create("release") {
                storeFile = file(releaseSigningValues.getValue("ANDROID_KEYSTORE_PATH")!!)
                storePassword = releaseSigningValues.getValue("ANDROID_KEYSTORE_PASSWORD")
                keyAlias = releaseSigningValues.getValue("ANDROID_KEY_ALIAS")
                keyPassword = releaseSigningValues.getValue("ANDROID_KEY_PASSWORD")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.findByName("release")
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
