// ---------------------------
// PROJECT-LEVEL build.gradle.kts
// (android/build.gradle.kts)
// ---------------------------

plugins {
    // Google Services Gradle Plugin (НЕ включаем автоматически)
      
    
}

// Репозитории для всех модулей
allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Настройка build-директорий
val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

// Все подпроекты должны зависеть от app-модуля
subprojects {
    project.evaluationDependsOn(":app")
}

// Команда "clean"
tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
