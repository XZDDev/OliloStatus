import com.github.triplet.gradle.androidpublisher.ReleaseStatus

plugins {
    id("com.android.application")
    id("com.google.gms.google-services")
    id("org.jetbrains.kotlin.plugin.compose")
    id("org.jetbrains.kotlin.plugin.serialization")
    id("com.github.triplet.play")
}

// Release signing is driven by environment variables so the keystore never lives
// in the repo. CI (GitLab) decodes the keystore and sets these; if they are
// absent (a normal local build) the release type is simply left unsigned.
val keystorePath: String? = System.getenv("ANDROID_KEYSTORE_PATH")

android {
    namespace = "uk.co.olilo.status"
    compileSdk = 37

    defaultConfig {
        applicationId = "uk.co.olilo.status"
        minSdk = 33
        targetSdk = 37
        // Google Play requires a unique, ever-increasing versionCode per upload.
        // CI sets ANDROID_VERSION_CODE (the GitLab pipeline IID); local builds
        // fall back to 1.
        versionCode = (System.getenv("ANDROID_VERSION_CODE") ?: "1").toInt()
        versionName = "1.0.2"
    }

    signingConfigs {
        if (keystorePath != null) {
            create("release") {
                storeFile = file(keystorePath)
                storePassword = System.getenv("ANDROID_KEYSTORE_PASSWORD")
                keyAlias = System.getenv("ANDROID_KEY_ALIAS")
                keyPassword = System.getenv("ANDROID_KEY_PASSWORD")
            }
        }
    }

    buildTypes {
        release {
            if (keystorePath != null) {
                signingConfig = signingConfigs.getByName("release")
            }
        }
    }

    buildFeatures {
        compose = true
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
}

// Gradle Play Publisher. Service-account JSON resolves from, in order:
//   1. PLAY_SERVICE_ACCOUNT_JSON env var (set by CI) - a path to the JSON.
//   2. app/play-service-account.json - a local, git-ignored file you drop in.
// If neither exists the publishing tasks have no credentials (local builds that
// only assemble/bundle still work fine).
val playCredentials: File? =
    System.getenv("PLAY_SERVICE_ACCOUNT_JSON")?.let { file(it) }
        ?: layout.projectDirectory.file("play-service-account.json").asFile.takeIf { it.exists() }

play {
    playCredentials?.let { serviceAccountCredentials.set(it) }
    // Upload to the internal testing track, available to testers immediately.
    track.set("internal")
    releaseStatus.set(ReleaseStatus.COMPLETED)
    defaultToAppBundles.set(true)
}

dependencies {
    implementation(platform("androidx.compose:compose-bom:2026.06.00"))
    implementation(platform("com.google.firebase:firebase-bom:34.15.0"))
    implementation("androidx.activity:activity-compose:1.13.0")
    implementation("androidx.core:core-ktx:1.19.0")
    implementation("androidx.fragment:fragment:1.8.9")
    implementation("androidx.compose.material3:material3")
    implementation("androidx.compose.material:material-icons-extended")
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.ui:ui-tooling-preview")
    implementation("androidx.lifecycle:lifecycle-runtime-compose:2.11.0")
    implementation("androidx.lifecycle:lifecycle-viewmodel-compose:2.11.0")
    implementation("androidx.navigation:navigation-compose:2.9.8")
    implementation("com.google.firebase:firebase-messaging")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.11.0")
    implementation("org.jetbrains.kotlinx:kotlinx-serialization-json:1.11.0")

    debugImplementation("androidx.compose.ui:ui-tooling")
}
