plugins {
    id("com.android.application")
    id("kotlin-android")

    // Flutter Gradle plugin
    id("dev.flutter.flutter-gradle-plugin")

    // Google Services plugin (Firebase için zorunlu)
    id("com.google.gms.google-services")
}

android {
    namespace = "com.example.mobil_proje"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.example.mobil_proje"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // Google Maps anahtarı depoya girmez: android/local.properties içindeki
        // MAPS_API_KEY değerinden okunur.
        val localProps = java.util.Properties()
        val localPropsFile = rootProject.file("local.properties")
        if (localPropsFile.exists()) {
            localPropsFile.inputStream().use { localProps.load(it) }
        }
        manifestPlaceholders["MAPS_API_KEY"] = localProps.getProperty("MAPS_API_KEY", "")
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Firebase BoM — sürüm yönetimini kolaylaştırır
    implementation(platform("com.google.firebase:firebase-bom:34.5.0"))

    // Firebase servisleri
    implementation("com.google.firebase:firebase-analytics")
    implementation("com.google.firebase:firebase-firestore")
    implementation("com.google.firebase:firebase-auth")
}
