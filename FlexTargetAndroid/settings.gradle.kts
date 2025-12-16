pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

dependencyResolutionManagement {
  repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
  repositories {
    // mirror first (example: Alibaba / TUNA)
    maven {
      url = uri("https://maven.aliyun.com/repository/central")
    }
    google()
    mavenCentral()
  }
}

rootProject.name = "FlexTarget"
include(":app")
