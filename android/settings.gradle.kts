pluginManagement {
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            file("local.properties").inputStream().use { properties.load(it) }
            val flutterSdkPath = properties.getProperty("flutter.sdk")
            require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
            flutterSdkPath
        }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.9.1" apply false
    id("org.jetbrains.kotlin.android") version "2.1.0" apply false
}

include(":app")

// #region agent log
@Suppress("SwallowedException")
run {
    val logFile = settingsDir.toPath().resolve("../../../debug-60a80f.log").normalize().toFile()
    fun esc(s: String) = s.replace("\\", "\\\\").replace("\"", "\\\"").replace("\n", " ")
    fun probe(label: String, urlStr: String): String {
        return try {
            val c = java.net.URL(urlStr).openConnection() as java.net.HttpURLConnection
            c.instanceFollowRedirects = true
            c.connectTimeout = 12000
            c.readTimeout = 12000
            c.requestMethod = "HEAD"
            val code = c.responseCode
            c.disconnect()
            "${label}_ok:$code"
        } catch (e: Exception) {
            "${label}_err:${esc(e.javaClass.simpleName)}:${esc(e.message ?: "")}"
        }
    }
    val ts = System.currentTimeMillis()
    val rGoogle = probe("google", "https://dl.google.com/dl/android/maven2/com/android/tools/build/gradle/8.9.1/gradle-8.9.1.pom")
    val rRepo1 = probe("repo1", "https://repo1.maven.org/maven2/de/mannodermaus/gradle/plugins/android-junit5/1.7.1.1/android-junit5-1.7.1.1.pom")
    val rApache = probe("apache", "https://repo.maven.apache.org/maven2/de/mannodermaus/gradle/plugins/android-junit5/1.7.1.1/android-junit5-1.7.1.1.pom")
    val rPluginPortal =
        probe(
            "plugin_portal",
            "https://plugins.gradle.org/m2/de/mannodermaus/gradle/plugins/android-junit5/1.7.1.1/android-junit5-1.7.1.1.pom",
        )
    val data =
        """{"google":"${esc(rGoogle)}","repo1":"${esc(rRepo1)}","repo_maven_apache":"${esc(rApache)}","plugin_portal":"${esc(rPluginPortal)}"}"""
    val line =
        """{"sessionId":"60a80f","timestamp":$ts,"location":"android/settings.gradle.kts","message":"gradle_maven_probe","data":$data,"runId":"pre-fix","hypothesisId":"H1,H4"}"""
    try {
        logFile.parentFile?.mkdirs()
        logFile.appendText(line + "\n")
    } catch (_: Exception) {
    }
}
// #endregion
