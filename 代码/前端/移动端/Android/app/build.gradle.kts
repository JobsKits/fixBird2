plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
}
android {
    namespace = "com.jobs.repair"
    compileSdk = 35
    defaultConfig {
        applicationId = "com.jobs.woodpecker.v38"
        minSdk = 26
        targetSdk = 35
        versionCode = 38
        versionName = "3.8.0"
        testInstrumentationRunner = "android.test.InstrumentationTestRunner"
    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions { jvmTarget = "17" }
    buildTypes {
        release { isMinifyEnabled = false }
    }
    lint { abortOnError = true }
}
