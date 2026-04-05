plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    namespace = "com.mipedido.pizzeria"
    compileSdk = 34
    ndkVersion = flutter.ndkVersion
    buildToolsVersion = "34.0.0"

    buildFeatures {
        buildConfig = true
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        namespace = "com.mipedido.pizzeria"
        applicationId = "com.mipedido.pizzeria"
        minSdk = flutter.minSdkVersion
        targetSdk = 34
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    flavorDimensions += "app"
    productFlavors {
        create("admin") {
            dimension = "app"
            applicationId = "com.pizzeriagonzalo.admin"
            resValue("string", "app_name", "Admin Gonzalo")
        }
        create("cliente") {
            dimension = "app"
            applicationId = "com.pizzeriagonzalo.cliente"
            resValue("string", "app_name", "Pizzería Gonzalo")
        }
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
