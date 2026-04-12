import com.android.build.gradle.BaseExtension

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    configurations.all {
        resolutionStrategy {
            force("androidx.browser:browser:1.8.0")
            force("androidx.activity:activity:1.8.2")
            force("androidx.activity:activity-ktx:1.8.2")
            force("androidx.fragment:fragment:1.6.2")
            force("androidx.fragment:fragment-ktx:1.6.2")
            force("androidx.lifecycle:lifecycle-common:2.6.2")
            force("androidx.lifecycle:lifecycle-runtime:2.6.2")
            force("androidx.lifecycle:lifecycle-runtime-ktx:2.6.2")
            force("androidx.lifecycle:lifecycle-viewmodel:2.6.2")
            force("androidx.lifecycle:lifecycle-viewmodel-ktx:2.6.2")
            force("androidx.core:core:1.12.0")
            force("androidx.core:core-ktx:1.12.0")
            force("androidx.window:window:1.1.0")
            force("androidx.window:window-java:1.1.0")
            force("androidx.annotation:annotation:1.7.1")
            force("androidx.annotation:annotation-jvm:1.7.1")
            force("org.jetbrains.kotlin:kotlin-stdlib:2.1.0")
            force("org.jetbrains.kotlin:kotlin-stdlib-jdk8:2.1.0")
            force("org.jetbrains.kotlin:kotlin-stdlib-jdk7:2.1.0")
        }
    }
    afterEvaluate {
        val android = project.extensions.findByName("android")
        if (android != null) {
            try {
                // Forzamos el SDK 34 para todos los plugins
                val androidExtension = android as? com.android.build.gradle.BaseExtension
                androidExtension?.compileSdkVersion(34)
                
                // Si el plugin no tiene namespace, le asignamos uno único basado en su nombre
                if (androidExtension?.namespace == null) {
                    val ns = "com.pizzeria_miguelangelo.${project.name.replace("-", "_")}"
                    androidExtension?.namespace = ns
                }
                
                // --- SOLUCION AGP 8 + Plugins Viejos ---
                // Eliminamos el atributo 'package' del manifest si existe para evitar conflictos con el namespace
                project.tasks.configureEach {
                    if (name.contains("Manifest")) {
                        doFirst {
                            try {
                                val possiblePaths = listOf("src/main/AndroidManifest.xml", "android/src/main/AndroidManifest.xml")
                                for (p in possiblePaths) {
                                    val manifestFile = project.file(p)
                                    if (manifestFile.exists()) {
                                        val content = manifestFile.readText()
                                        if (content.contains("package=\"")) {
                                            val newContent = content.replace(Regex("package=\"[^\"]*\""), " ")
                                            manifestFile.writeText(newContent)
                                            println("Stripped 'package' from $p in lib ${project.name}")
                                        }
                                    }
                                }
                            } catch (e: Exception) {
                                // Ignorar si falla el acceso a archivos de cache
                            }
                        }
                    }
                }
            } catch (e: Exception) {
                // Silenciamos errores menores de configuración
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
