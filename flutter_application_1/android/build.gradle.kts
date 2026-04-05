import com.android.build.gradle.LibraryExtension 

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
    project.evaluationDependsOn(":app")
}

// 🌟 FIX: ఇక్కడ "app" కాకపోతేనే (if condition బయట పెట్టాం) చెక్ చేయమని రాశాం!
subprojects {
    if (project.name != "app") {
        project.afterEvaluate {
            if (project.hasProperty("android")) {
                project.extensions.configure<LibraryExtension>("android") {
                    if (namespace == null) {
                        namespace = project.group.toString()
                    }
                }
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}