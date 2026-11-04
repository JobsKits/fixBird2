plugins { kotlin("jvm") version "2.2.20" }
repositories { mavenCentral() }
dependencies { implementation("org.json:json:20180813") }
kotlin {
    sourceSets.main {
        kotlin.srcDirs("../../../../代码/前端/移动端/Android/app/src/main/java", ".")
        kotlin.include("com/jobs/repair/Repository.kt", "com/jobs/repair/DemoStore.kt", "com/jobs/repair/Forms.kt", "ContractChecks.kt")
    }
}
tasks.register<JavaExec>("contractChecks") {
    classpath = sourceSets.main.get().runtimeClasspath
    mainClass.set("com.jobs.repair.ContractChecksKt")
}
