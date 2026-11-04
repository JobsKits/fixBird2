pluginManagement {
    resolutionStrategy { eachPlugin { if (requested.id.id == "org.jetbrains.kotlin.jvm") useModule("org.jetbrains.kotlin:kotlin-gradle-plugin:${requested.version}") } }
    repositories { mavenCentral(); gradlePluginPortal() }
}
rootProject.name = "AndroidContractChecks"
