plugins {
    id("com.android.library") version "8.1.4"
    id("org.jetbrains.kotlin.android") version "1.9.22"
}

group = "com.vibegrowth"
version = "2.1.0"

android {
    namespace = "com.vibegrowth.sdk"
    compileSdk = 34

    defaultConfig {
        minSdk = 21
        buildConfigField("String", "SDK_VERSION", "\"1.0.0\"")
    }

    buildFeatures {
        buildConfig = true
    }

    testOptions {
        unitTests.isIncludeAndroidResources = true
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_1_8
        targetCompatibility = JavaVersion.VERSION_1_8
    }

    kotlinOptions {
        jvmTarget = "1.8"
    }
}

dependencies {
    implementation("com.android.installreferrer:installreferrer:2.2")
    implementation("com.google.android.gms:play-services-ads-identifier:18.0.1")
    compileOnly("com.android.billingclient:billing-ktx:7.1.1")
    testImplementation("androidx.test:core:1.5.0")
    testImplementation("junit:junit:4.13.2")
    testImplementation("org.json:json:20240303")
    testImplementation("com.android.billingclient:billing-ktx:7.1.1")
    testImplementation("io.mockk:mockk:1.13.9")
}
