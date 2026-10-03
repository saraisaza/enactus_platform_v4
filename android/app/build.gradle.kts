import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Firma de la versión de tienda.
//
// `android/key.properties` NO se versiona (está en `android/.gitignore`): vive
// solo en la máquina que compila y apunta a la llave de subida, que tampoco
// entra al repositorio. Ver docs/movil/PUBLICACION.md.
//
// Sin ese archivo, la versión release se firma con la llave de depuración.
// Google Play la rechaza, y eso es lo correcto: nunca se sube por accidente un
// paquete firmado con una llave que cualquiera puede regenerar.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    // El identificador NO se puede cambiar después de publicar en Google Play.
    namespace = "com.eduxaction.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.eduxaction.app"
        // Flutter 3.44 trae minSdk 24 y targetSdk 36. Google Play exige
        // targetSdk 36 para apps nuevas y actualizaciones desde el 31 de
        // agosto de 2026.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (keystorePropertiesFile.exists()) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            signingConfig =
                if (keystorePropertiesFile.exists()) {
                    signingConfigs.getByName("release")
                } else {
                    signingConfigs.getByName("debug")
                }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
