plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("org.jetbrains.kotlin.plugin.serialization")
    id("com.google.gms.google-services")
}

android {
    namespace = "net.gameble.app"
    compileSdk = 35

    defaultConfig {
        applicationId = "net.gameble.app"
        minSdk = 28
        targetSdk = 35
        versionCode = 1
        versionName = "1.0"
    }

    buildTypes {
        debug {
            buildConfigField("String", "ROOT_URL", "\"http://10.0.2.2:3000\"")
            manifestPlaceholders["usesCleartextTraffic"] = true
        }
        release {
            buildConfigField("String", "ROOT_URL", "\"https://gameble.net\"")
            manifestPlaceholders["usesCleartextTraffic"] = false
            isMinifyEnabled = false
        }
    }

    buildFeatures {
        buildConfig = true
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }
}

dependencies {
    implementation("dev.hotwire:core:1.3.2")
    implementation("dev.hotwire:navigation-fragments:1.3.2")
    implementation("androidx.browser:browser:1.8.0")
    implementation("com.google.android.material:material:1.12.0")
    implementation("org.jetbrains.kotlinx:kotlinx-serialization-json:1.7.3")
    implementation(platform("com.google.firebase:firebase-bom:33.7.0"))
    implementation("com.google.firebase:firebase-messaging")
}
