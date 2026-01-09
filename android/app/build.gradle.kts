plugins {
    id("com.android.application")
    // NOTE(rename): Firebase is initialized via DefaultFirebaseOptions in Dart.
    // The google-services plugin requires a matching client in google-services.json
    // for the new applicationId; re-enable it after downloading an updated
    // android/app/google-services.json for com.fairycraft.app.
    // id("com.google.gms.google-services")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}


android {
    namespace = "com.fairycraft.app"
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
        applicationId = "com.fairycraft.app"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
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
    // Firebase BoM — обязательно
    implementation(platform("com.google.firebase:firebase-bom:34.7.0"))

    // Здесь добавляете Firebase SDK, например:
    // implementation("com.google.firebase:firebase-analytics")
    // implementation("com.google.firebase:firebase-auth")
    // implementation("com.google.firebase:firebase-firestore")
}
