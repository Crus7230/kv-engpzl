package com.crus7230.kvm.renewal

import android.content.ClipData
import android.content.Intent
import android.content.pm.PackageInfo
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.net.URL
import java.security.MessageDigest
import java.util.concurrent.Executors
import javax.net.ssl.HttpsURLConnection

class UpdateApkProvider : FileProvider()

/** Optional public update channel. Never touches progress or retained media. */
class AppUpdateBridge(private val activity: MainActivity, messenger: BinaryMessenger) {
    private val worker = Executors.newSingleThreadExecutor()
    private val channel = MethodChannel(messenger, "kvm/app_updates")
    private var pending: PendingApk? = null

    private data class PendingApk(val file: File, val code: Long, val version: String, val digest: String, val bytes: Long)

    init {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "check" -> background(result) {
                    val json = connection("https://api.github.com/repos/Crus7230/kv-engpzl/releases?per_page=20", metadata = true).useConnection { response ->
                        response.inputStream.use { input ->
                            val buffer = java.io.ByteArrayOutputStream()
                            val block = ByteArray(8192)
                            while (true) {
                                val count = input.read(block)
                                if (count < 0) break
                                check(buffer.size() + count <= 1024 * 1024) { "Oversized metadata" }
                                buffer.write(block, 0, count)
                            }
                            buffer.toString("UTF-8")
                        }
                    }
                    mapOf("versionCode" to code(installed()), "releasesJson" to json)
                }
                "download" -> background(result) {
                    val name = call.argument<String>("versionName") ?: error("Missing version")
                    val nextCode = call.argument<Number>("versionCode")?.toLong() ?: error("Missing code")
                    val url = call.argument<String>("downloadUrl") ?: error("Missing URL")
                    val digest = call.argument<String>("sha256") ?: error("Missing digest")
                    val bytes = call.argument<Number>("bytes")?.toLong() ?: error("Missing size")
                    check(Regex("[0-9]+\\.[0-9]+\\.[0-9]+").matches(name))
                    check(nextCode > code(installed()) && Regex("[a-f0-9]{64}").matches(digest))
                    check(bytes in 1..150L * 1024 * 1024)
                    val parsed = Uri.parse(url)
                    val prefix = "/Crus7230/kv-engpzl/releases/download/"
                    check(parsed.scheme == "https" && parsed.host == "github.com" && parsed.port == -1 &&
                        parsed.userInfo == null && parsed.query == null && parsed.fragment == null)
                    check(parsed.path == "${prefix}v$name-r1-alpha/KVM-R1-$name-alpha.apk" ||
                        parsed.path == "${prefix}v$name/KVM-R1-$name-alpha.apk")
                    val directory = File(activity.cacheDir, "kvm_updates")
                    check(directory.isDirectory || directory.mkdirs())
                    val candidate = File(directory, "candidate-${System.nanoTime()}.part")
                    pending = null
                    try {
                        // Reuse a previously verified download after installer cancellation.
                        val retained = directory.listFiles()?.firstOrNull { file ->
                            file.name.startsWith("verified-$nextCode-") && file.extension == "apk" &&
                                runCatching { verify(PendingApk(file, nextCode, name, digest, bytes)) }.isSuccess
                        }
                        if (retained != null) {
                            pending = PendingApk(retained, nextCode, name, digest, bytes)
                            return@background null
                        }
                        connection(url, metadata = false).useConnection { response ->
                            check(response.contentLengthLong <= bytes || response.contentLengthLong == -1L)
                            response.inputStream.use { input ->
                                candidate.outputStream().use { output ->
                                    val block = ByteArray(64 * 1024)
                                    val deadline = System.nanoTime() + 180_000_000_000L
                                    var received = 0L
                                    while (true) {
                                        check(!Thread.currentThread().isInterrupted && System.nanoTime() < deadline) { "Download timed out" }
                                        val count = input.read(block)
                                        if (count < 0) break
                                        received += count
                                        check(received <= bytes) { "Oversized APK" }
                                        output.write(block, 0, count)
                                    }
                                    check(received == bytes) { "Incomplete APK" }
                                }
                            }
                        }
                        val apk = PendingApk(candidate, nextCode, name, digest, bytes)
                        verify(apk)
                        val ready = File(directory, "verified-$nextCode-${System.nanoTime()}.apk")
                        check(candidate.renameTo(ready))
                        pending = apk.copy(file = ready)
                        // At most one verified APK remains. Only generated cache files
                        // matching our exact naming contract are eligible for cleanup.
                        directory.listFiles()?.filter { file ->
                            file != ready && Regex("verified-[0-9]+-[0-9]+\\.apk").matches(file.name)
                        }?.forEach { it.delete() }
                    } finally {
                        // Disposable file generated by this download, never a save/asset path.
                        if (candidate.exists()) candidate.delete()
                    }
                    null
                }
                "install" -> {
                    val apk = pending
                    if (apk == null) result.error("UPDATE_NOT_READY", "Download the APK first.", null)
                    else worker.execute {
                        try {
                            verify(apk)
                            activity.runOnUiThread {
                                if (!activity.isDestroyed) {
                                    try {
                                        if (Build.VERSION.SDK_INT >= 26 && !activity.packageManager.canRequestPackageInstalls()) {
                                            result.success("permissionRequired")
                                        } else {
                                            val uri = FileProvider.getUriForFile(activity, "${activity.packageName}.updates", apk.file)
                                            val intent = Intent(Intent.ACTION_VIEW).apply {
                                                setDataAndType(uri, "application/vnd.android.package-archive")
                                                clipData = ClipData.newRawUri("KVM update", uri)
                                                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                                            }
                                            activity.startActivity(intent)
                                            result.success("launched")
                                        }
                                    } catch (_: Exception) {
                                        result.error("UPDATE_INSTALL_FAILED", "Could not open Android installer.", null)
                                    }
                                }
                            }
                        } catch (_: Exception) {
                            activity.runOnUiThread { if (!activity.isDestroyed) result.error("UPDATE_INVALID", "APK validation failed.", null) }
                        }
                    }
                }
                "openInstallPermission" -> {
                    try {
                        if (Build.VERSION.SDK_INT >= 26) {
                            activity.startActivity(Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES, Uri.parse("package:${activity.packageName}")))
                        }
                        result.success(null)
                    } catch (_: Exception) {
                        result.error("UPDATE_PERMISSION_FAILED", "Could not open install settings.", null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun background(result: MethodChannel.Result, operation: () -> Any?) {
        worker.execute {
            try {
                val value = operation()
                activity.runOnUiThread { if (!activity.isDestroyed) result.success(value) }
            } catch (_: Exception) {
                activity.runOnUiThread { if (!activity.isDestroyed) result.error("UPDATE_UNAVAILABLE", "Update check or download failed.", null) }
            }
        }
    }

    @Suppress("DEPRECATION")
    private fun installed(): PackageInfo = activity.packageManager.getPackageInfo(activity.packageName, signingFlags())

    private fun signingFlags() = if (Build.VERSION.SDK_INT >= 28) PackageManager.GET_SIGNING_CERTIFICATES else PackageManager.GET_SIGNATURES

    @Suppress("DEPRECATION")
    private fun code(info: PackageInfo) = if (Build.VERSION.SDK_INT >= 28) info.longVersionCode else info.versionCode.toLong()

    @Suppress("DEPRECATION")
    private fun signers(info: PackageInfo): Set<String> {
        val signatures = if (Build.VERSION.SDK_INT >= 28) info.signingInfo?.apkContentsSigners else info.signatures
        return signatures?.map { signature ->
            MessageDigest.getInstance("SHA-256").digest(signature.toByteArray()).joinToString("") { "%02x".format(it.toInt() and 0xff) }
        }?.toSet() ?: emptySet()
    }

    @Suppress("DEPRECATION")
    private fun verify(apk: PendingApk) {
        check(apk.file.isFile && apk.file.length() == apk.bytes)
        val digest = MessageDigest.getInstance("SHA-256")
        apk.file.inputStream().use { input ->
            val block = ByteArray(64 * 1024)
            while (true) {
                val count = input.read(block)
                if (count < 0) break
                digest.update(block, 0, count)
            }
        }
        check(digest.digest().joinToString("") { "%02x".format(it.toInt() and 0xff) } == apk.digest)
        val archive = activity.packageManager.getPackageArchiveInfo(apk.file.path, signingFlags()) ?: error("Invalid APK")
        val current = installed()
        check(archive.packageName == activity.packageName && code(archive) == apk.code && archive.versionName == apk.version)
        check(apk.code > code(current)) { "Not a newer APK" }
        val currentSigners = signers(current)
        check(currentSigners.isNotEmpty() && signers(archive) == currentSigners) { "Signing certificate mismatch" }
    }

    private fun connection(initial: String, metadata: Boolean): HttpsURLConnection {
        var url = URL(initial)
        repeat(6) {
            check(url.protocol == "https" && url.userInfo == null && url.port == -1)
            check(url.host in setOf("api.github.com", "github.com", "release-assets.githubusercontent.com", "objects.githubusercontent.com"))
            val response = url.openConnection() as HttpsURLConnection
            response.instanceFollowRedirects = false
            response.connectTimeout = if (metadata) 2000 else 15000
            response.readTimeout = if (metadata) 2500 else 15000
            response.setRequestProperty("User-Agent", "KVM-Renewal-Android")
            response.setRequestProperty("Accept", if (metadata) "application/vnd.github+json" else "application/octet-stream")
            response.setRequestProperty("Accept-Encoding", "identity")
            try {
                val status = response.responseCode
                if (status == 200) return response
                if (status in listOf(301, 302, 303, 307, 308)) {
                    val location = response.getHeaderField("Location") ?: error("Missing redirect")
                    url = URL(url, location)
                } else error("Unexpected HTTP status")
            } catch (error: Exception) {
                response.disconnect()
                throw error
            }
            response.disconnect()
        }
        error("Too many redirects")
    }

    private inline fun <T> HttpsURLConnection.useConnection(block: (HttpsURLConnection) -> T): T = try { block(this) } finally { disconnect() }

    fun dispose() {
        channel.setMethodCallHandler(null)
        worker.shutdownNow()
    }
}
