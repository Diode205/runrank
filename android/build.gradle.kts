allprojects {
    repositories {
        google()
        mavenCentral()
    }

    // Force Java 17 compilation for all modules (including plugins)
    tasks.withType<JavaCompile>().configureEach {
        sourceCompatibility = "17"
        targetCompatibility = "17"
        // Suppress "obsolete options" and "deprecated API" warnings
        options.compilerArgs.addAll(listOf("-Xlint:-options", "-Xlint:-deprecation"))
    }
}

// Reactively configure Android modules as they are loaded
subprojects {
    plugins.withType<com.android.build.gradle.BasePlugin> {
        val android = project.extensions.getByName("android") as com.android.build.gradle.BaseExtension
        android.compileOptions {
            sourceCompatibility = JavaVersion.VERSION_17
            targetCompatibility = JavaVersion.VERSION_17
        }
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
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
