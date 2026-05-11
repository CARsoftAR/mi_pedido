plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    namespace = "com.pizzeria.negocio"
    // 34+: permisos y visibilidad de medios Android 13/14; no bajar compileSdk si fallan adjuntos.
    compileSdk = 34
    ndkVersion = flutter.ndkVersion
    buildToolsVersion = "34.0.0"

    buildFeatures {
        buildConfig = true
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        namespace = "com.pizzeria.negocio"
        applicationId = "com.pizzeria.negocio"
        minSdk = flutter.minSdkVersion
        targetSdk = 34
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    flavorDimensions += "app"
    productFlavors {
        create("admin") {
            dimension = "app"
            applicationId = "com.pizzeria.negocio"
            resValue("string", "app_name", "Admin Gonzalo")
        }
        create("cliente") {
            dimension = "app"
            applicationId = "com.mipedido.pizzeria"
            resValue("string", "app_name", "Pizzería Miguel Angel")
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }

    applicationVariants.all {
        val variant = this
        variant.outputs.all {
            val outputImpl = this as com.android.build.gradle.internal.api.BaseVariantOutputImpl
            if (variant.flavorName == "admin") {
                outputImpl.outputFileName = "negocio.apk"
            } else if (variant.flavorName == "cliente") {
                outputImpl.outputFileName = "cliente.apk"
            }
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.3")
}
