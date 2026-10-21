plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.compose)
}

android {
    // Uppercase namespace/applicationId is intentional (matches the other platform app IDs).
    namespace = "com.tsubuzaki.WoooshGo"
    compileSdk = 37

    defaultConfig {
        applicationId = "com.tsubuzaki.WoooshGo"
        minSdk = 26
        targetSdk = 37
        // CI passes both (.github/workflows/android-internal.yml); Play rejects a
        // versionCode it has already seen.
        versionCode = (project.findProperty("wooosh.versionCode") ?: "1").toString().toInt()
        versionName = (project.findProperty("wooosh.versionName") ?: "0.1").toString()
        // Play Console → App integrity → Google Cloud project. 0 leaves Play
        // Integrity off, so the device is admitted as Unverified (PROTOCOL.md §9.2).
        buildConfigField(
            "long",
            "PLAY_CLOUD_PROJECT_NUMBER",
            (project.findProperty("wooosh.playCloudProjectNumber")?.toString()?.takeIf { it.isNotBlank() } ?: "0") + "L",
        )
    }

    // The upload key, not the app signing key: Play App Signing re-signs for
    // distribution. Absent locally, so release builds there stay unsigned.
    val uploadKeystore = providers.environmentVariable("WOOOSH_UPLOAD_KEYSTORE").orNull
    signingConfigs {
        if (uploadKeystore != null) {
            create("upload") {
                storeFile = file(uploadKeystore)
                storePassword = providers.environmentVariable("WOOOSH_UPLOAD_KEYSTORE_PASSWORD").get()
                keyAlias = providers.environmentVariable("WOOOSH_UPLOAD_KEY_ALIAS").get()
                keyPassword = providers.environmentVariable("WOOOSH_UPLOAD_KEY_PASSWORD").get()
            }
        }
    }

    buildTypes {
        debug {
            isDebuggable = true
        }
        release {
            if (uploadKeystore != null) {
                signingConfig = signingConfigs.getByName("upload")
            }
            isMinifyEnabled = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
    buildFeatures {
        compose = true
        buildConfig = true
    }
    lint {
        // Keep the intentionally uppercase package/applicationId out of lint noise.
        disable += listOf("PackageName", "PackageNaming")
    }
    packaging {
        resources {
            excludes += "/META-INF/{AL2.0,LGPL2.1}"
        }
    }
}

kotlin {
    jvmToolchain(17)
}

dependencies {
    implementation(libs.kotlinx.coroutines.android)

    implementation(libs.core.ktx)
    implementation(libs.lifecycle.runtime.ktx)
    implementation(libs.lifecycle.runtime.compose)
    implementation(libs.lifecycle.viewmodel.compose)

    implementation(libs.datastore.preferences)

    implementation(libs.play.integrity)

    // UniFFI bindings for wooosh-core (generated Kotlin in src/main/java/uniffi/,
    // libwooosh_core.so in src/main/jniLibs/) call the library through JNA.
    implementation(variantOf(libs.jna) { artifactType("aar") })

    implementation(libs.zxing.core)
    implementation(libs.zxing.android.embedded)

    implementation(libs.activity.compose)
    implementation(platform(libs.compose.bom))
    implementation(libs.compose.ui)
    implementation(libs.compose.material.icons.extended)
    implementation(libs.material3)
}
