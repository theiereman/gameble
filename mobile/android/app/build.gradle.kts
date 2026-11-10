plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("org.jetbrains.kotlin.plugin.serialization")
}

// Push needs the Firebase project's google-services.json; the app builds and runs without it.
if (file("google-services.json").exists()) {
    apply(plugin = "com.google.gms.google-services")
}

val debugRootUrl = (findProperty("gamebleRootUrl") as String?) ?: "http://10.0.2.2:3000"
val releaseRootUrl = (findProperty("gamebleRootUrl") as String?) ?: "https://gameble.net"
val releaseKeystore = System.getenv("ANDROID_KEYSTORE_FILE")

android {
    namespace = "net.gameble.app"
    compileSdk = 36

    defaultConfig {
        applicationId = "net.gameble.app"
        minSdk = 28
        targetSdk = 36
        versionCode = (findProperty("gamebleVersionCode") as String?)?.toInt() ?: 1
        versionName = (findProperty("gamebleVersionName") as String?) ?: "1.0"
    }

    signingConfigs {
        if (releaseKeystore != null) {
            create("release") {
                storeFile = file(releaseKeystore)
                storePassword = System.getenv("ANDROID_KEYSTORE_PASSWORD")
                keyAlias = System.getenv("ANDROID_KEY_ALIAS")
                keyPassword = System.getenv("ANDROID_KEY_PASSWORD")
            }
        }
    }

    buildTypes {
        debug {
            buildConfigField("String", "ROOT_URL", "\"$debugRootUrl\"")
            manifestPlaceholders["usesCleartextTraffic"] = debugRootUrl.startsWith("http:")
        }
        release {
            buildConfigField("String", "ROOT_URL", "\"$releaseRootUrl\"")
            manifestPlaceholders["usesCleartextTraffic"] = false
            isMinifyEnabled = false
            if (releaseKeystore != null) signingConfig = signingConfigs.getByName("release")
        }
    }

    packaging {
        resources.excludes += "META-INF/versions/9/OSGI-INF/MANIFEST.MF"
    }

    buildFeatures {
        buildConfig = true
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
}

kotlin {
    compilerOptions {
        jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
    }
}

dependencies {
    implementation("dev.hotwire:core:1.3.2")
    implementation("dev.hotwire:navigation-fragments:1.3.2")
    implementation("androidx.browser:browser:1.8.0")
    implementation("androidx.swiperefreshlayout:swiperefreshlayout:1.1.0")
    implementation("com.google.android.material:material:1.12.0")
    implementation("org.jetbrains.kotlinx:kotlinx-serialization-json:1.8.1")
    implementation(platform("com.google.firebase:firebase-bom:33.7.0"))
    implementation("com.google.firebase:firebase-messaging")
}
