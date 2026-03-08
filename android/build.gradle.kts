allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

// Note: evaluationDependsOn(":app") removed — it caused afterEvaluate to fire
// after projects were already evaluated, breaking the compileSdk override below.

subprojects {
    afterEvaluate {
        val androidLib = extensions.findByType(com.android.build.gradle.LibraryExtension::class.java)
        if (androidLib != null) {
            // Fix for libraries not specifying namespace (AGP 8.0+ requirement)
            if (androidLib.namespace == null) {
                androidLib.namespace = project.group.toString()
            }
            // Force compileSdk >= 36 so plugins like isar_flutter_libs
            // (which need android:attr/lStar from API 31+) build correctly.
            if ((androidLib.compileSdk ?: 0) < 36) {
                androidLib.compileSdk = 36
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
