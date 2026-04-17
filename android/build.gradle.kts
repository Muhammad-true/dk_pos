allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Подпроекты-плагины (например audioplayers_android) объявляют свой buildscript;
// без gradlePluginPortal() classpath может не находить артефакты, опубликованные на Plugin Portal.
subprojects {
    buildscript {
        repositories {
            gradlePluginPortal()
            google()
            mavenCentral()
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
