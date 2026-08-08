plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.android)
    alias(libs.plugins.kotlin.compose)
    alias(libs.plugins.kotlin.serialization)
}

// The alarm tones ship in the iOS target as CamelCase .wav files. Android raw
// resources must be lowercase, so they are copied and renamed into a generated
// res folder at build time instead of being duplicated in the repository.
val alarmSoundResDir = layout.buildDirectory.dir("generated/alarmSoundRes")

val copyAlarmSounds = tasks.register<Copy>("copyAlarmSounds") {
    from(rootProject.layout.projectDirectory.dir("../RainyClock")) {
        include("*.wav")
        exclude("AlarmTone.wav") // iOS-only stand-in for the system alarm tone.
    }
    into(alarmSoundResDir.map { it.dir("raw") })
    rename { name ->
        "sound_" + name.removeSuffix(".wav")
            .replace(Regex("([a-z0-9])([A-Z])"), "$1_$2")
            .lowercase() + ".wav"
    }
}

android {
    namespace = "com.shukaihu.rainyclock"
    compileSdk = 35

    defaultConfig {
        applicationId = "com.shukaihu.rainyclock"
        minSdk = 26
        targetSdk = 35
        versionCode = 1
        versionName = "1.0.0"

        manifestPlaceholders["admobAppId"] = providers.gradleProperty("admobAppId")
            .getOrElse("ca-app-pub-3940256099942544~3347511713")
        buildConfigField(
            "String",
            "ADMOB_BANNER_AD_UNIT_ID",
            "\"${providers.gradleProperty("admobBannerAdUnitId").getOrElse("")}\""
        )

        // Google Maps Platform key (Maps SDK + Routes API). Empty disables the
        // route preview and midpoint weather sampling; the rain decision then
        // falls back to the home/work endpoints.
        val mapsApiKey = providers.gradleProperty("mapsApiKey").getOrElse("")
        manifestPlaceholders["mapsApiKey"] = mapsApiKey
        buildConfigField("String", "MAPS_API_KEY", "\"$mapsApiKey\"")
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            isShrinkResources = true
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

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    // The provider is derived from the task so Gradle tracks the producer and
    // orders resource merging after the copy.
    sourceSets["main"].res.srcDir(copyAlarmSounds.map { it.destinationDir.parentFile!! })
}

kotlin {
    jvmToolchain(17)
}

tasks.named("preBuild") {
    dependsOn(copyAlarmSounds)
}

dependencies {
    implementation(libs.androidx.core.ktx)
    implementation(libs.androidx.activity.compose)
    implementation(platform(libs.androidx.compose.bom))
    implementation(libs.androidx.compose.ui)
    implementation(libs.androidx.compose.ui.tooling.preview)
    implementation(libs.androidx.compose.material3)
    implementation(libs.androidx.compose.material.icons)
    implementation(libs.androidx.lifecycle.runtime.ktx)
    implementation(libs.androidx.lifecycle.viewmodel.compose)
    implementation(libs.androidx.work.runtime.ktx)
    implementation(libs.kotlinx.serialization.json)
    implementation(libs.kotlinx.coroutines.android)
    implementation(libs.play.services.ads)
    implementation(libs.play.services.maps)
    implementation(libs.maps.compose)
    implementation(libs.user.messaging.platform)

    testImplementation(libs.junit)
}
