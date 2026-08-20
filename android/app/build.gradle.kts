plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val releaseSigningEnvironment = mapOf(
    "ANDROID_KEYSTORE_PATH" to System.getenv("ANDROID_KEYSTORE_PATH"),
    "ANDROID_KEYSTORE_PASSWORD" to System.getenv("ANDROID_KEYSTORE_PASSWORD"),
    "ANDROID_KEY_ALIAS" to System.getenv("ANDROID_KEY_ALIAS"),
    "ANDROID_KEY_PASSWORD" to System.getenv("ANDROID_KEY_PASSWORD"),
)
val missingReleaseSigningEnvironment = releaseSigningEnvironment
    .filterValues { it.isNullOrBlank() }
    .keys
val hasReleaseSigning = missingReleaseSigningEnvironment.isEmpty()

fun releaseSigningValue(name: String): String =
    releaseSigningEnvironment[name]?.takeIf { it.isNotBlank() }
        ?: error("Release 构建缺少签名环境变量：$name")

// 所有 Release 任务在执行前验证签名，避免聚合 Gradle 任务意外回退为调试签名。
val validateReleaseSigning = tasks.register("validateReleaseSigning") {
    group = "verification"
    description = "验证 Android Release 构建所需的签名环境变量。"
    doLast {
        check(hasReleaseSigning) {
            "Release 构建缺少签名环境变量：" +
                missingReleaseSigningEnvironment.joinToString(", ")
        }
    }
}

tasks.configureEach {
    if (name != "validateReleaseSigning" &&
        name.contains("release", ignoreCase = true)) {
        dependsOn(validateReleaseSigning)
    }
}

android {
    namespace = "com.zhao.video.parse"
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
        applicationId = "com.zhao.video.parse"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // background_downloader 的原生任务调度最低支持 Android API 21。
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                storeFile = file(releaseSigningValue("ANDROID_KEYSTORE_PATH"))
                storePassword = releaseSigningValue("ANDROID_KEYSTORE_PASSWORD")
                keyAlias = releaseSigningValue("ANDROID_KEY_ALIAS")
                keyPassword = releaseSigningValue("ANDROID_KEY_PASSWORD")
                storeType = "jks"
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName(
                if (hasReleaseSigning) "release" else "debug",
            )
        }
    }
}

flutter {
    source = "../.."
}
