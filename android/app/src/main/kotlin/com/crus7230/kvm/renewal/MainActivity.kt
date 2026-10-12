package com.crus7230.kvm.renewal

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.security.MessageDigest
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private val mediaWorker = Executors.newSingleThreadExecutor()
    private val expectedPackId = "r1-media-v3"
    private var installedPaths = emptySet<String>()
    private var updates: AppUpdateBridge? = null
    private var gameAudio: GameAudioBridge? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        updates = AppUpdateBridge(this, flutterEngine.dartExecutor.binaryMessenger)
        gameAudio = GameAudioBridge(this, flutterEngine.dartExecutor.binaryMessenger)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "kvm/retained_assets")
            .setMethodCallHandler { call, result ->
                if (call.method !in setOf("ensureInstalled", "downloadPack", "readAsset")) {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                mediaWorker.execute {
                    try {
                        check(call.argument<String>("packId") == expectedPackId)
                        val output: Any? = when (call.method) {
                            "ensureInstalled", "downloadPack" -> {
                                val entries = call.argument<List<Map<String, Any>>>("assets")
                                    ?: error("Missing media manifest")
                                val metadata = call.argument<Map<String, Any>>("download")
                                ensureInstalled(entries, call.method == "downloadPack", metadata)
                            }
                            else -> {
                                val path = call.argument<String>("path") ?: error("Missing media path")
                                check(installedPaths.contains(path)) { "Unregistered media path" }
                                safeFile(packDirectory(), path).readBytes()
                            }
                        }
                        runOnUiThread { result.success(output) }
                    } catch (error: Exception) {
                        // No reset or network download: preserve existing media on any failure.
                        runOnUiThread {
                            result.error("ASSET_PACK_UNAVAILABLE", "Install the full media APK to restore the asset pack.", null)
                        }
                    }
                }
            }
    }

    private fun packDirectory() = File(filesDir, "kvm_asset_packs/$expectedPackId")

    private fun safeFile(directory: File, path: String): File {
        check(Regex("assets/(legacy|expedition)/[a-z0-9-]+\\.png").matches(path)) { "Invalid media path" }
        val target = File(directory, path).canonicalFile
        check(target.path.startsWith(directory.canonicalPath + File.separator))
        return target
    }

    private fun matches(file: File, entry: Map<String, Any>): Boolean {
        if (!file.isFile || file.length() != (entry["bytes"] as Number).toLong()) return false
        val digest = MessageDigest.getInstance("SHA-256")
        file.inputStream().use { input ->
            val buffer = ByteArray(64 * 1024)
            while (true) {
                val count = input.read(buffer)
                if (count < 0) break
                digest.update(buffer, 0, count)
            }
        }
        val hex = digest.digest().joinToString("") { "%02x".format(it.toInt() and 0xff) }
        return hex.equals(entry["sha256"] as String, ignoreCase = true)
    }

    private fun ensureInstalled(entries: List<Map<String, Any>>, allowDownload: Boolean, metadata: Map<String, Any>?): Boolean {
        check(entries.size == 31 && entries.map { it["path"] }.toSet().size == 31)
        val target = packDirectory()
        if (entries.all { matches(safeFile(target, it["path"] as String), it) }) {
            installedPaths = entries.map { it["path"] as String }.toSet()
            return true
        }
        // Recover an interrupted rename before requiring media in the new APK.
        // Every recovered directory must match the complete expected manifest.
        val candidates = target.parentFile?.listFiles()?.filter {
            it.isDirectory && (it.name.startsWith("$expectedPackId-previous-") ||
                it.name.startsWith("$expectedPackId-candidate-"))
        } ?: emptyList()
        val recoverable = candidates.firstOrNull { directory ->
            entries.all { matches(safeFile(directory, it["path"] as String), it) }
        }
        if (recoverable != null) {
            commitPack(recoverable, target)
            installedPaths = entries.map { it["path"] as String }.toSet()
            return true
        }
        if (!allowDownload && !entries.all {
            try { assets.open("flutter_assets/${it["path"]}").use { }; true } catch (_: Exception) { false }
        }) return false
        // A new candidate is verified before touching the existing pack.
        val staging = File(filesDir, "kvm_asset_packs/$expectedPackId-candidate-${System.nanoTime()}")
        check(staging.mkdirs())
        try {
            if (allowDownload) {
                val downloadMetadata = metadata ?: error("Missing media download metadata")
                check(downloadMetadata["url"] == "https://github.com/Crus7230/kv-engpzl/releases/download/media-r1-v3/KVM-r1-media-v3.zip")
                RetainedPackDownloader.download(cacheDir, staging, entries, downloadMetadata, ::safeFile)
            } else {
                for (entry in entries) {
                    val path = entry["path"] as String
                    val file = safeFile(staging, path)
                    check(file.parentFile!!.mkdirs() || file.parentFile!!.isDirectory)
                    assets.open("flutter_assets/$path").use { input ->
                        file.outputStream().use { output -> input.copyTo(output) }
                    }
                    check(matches(file, entry)) { "Media hash mismatch" }
                }
            }
            check(entries.all { matches(safeFile(staging, it["path"] as String), it) })
            commitPack(staging, target)
            installedPaths = entries.map { it["path"] as String }.toSet()
            return true
        } finally {
            // Only our validated, generated candidate directory is disposable.
            if (staging.exists() && !entries.all { matches(safeFile(staging, it["path"] as String), it) }) {
                check(staging.canonicalPath.startsWith(target.parentFile!!.canonicalPath + File.separator))
                staging.deleteRecursively()
            }
        }
    }

    private fun commitPack(candidate: File, target: File) {
        if (target.exists()) {
            // Keep a recoverable previous pack; never delete user data.
            val backup = File(target.parentFile, "$expectedPackId-previous-${System.nanoTime()}")
            check(target.renameTo(backup))
            if (!candidate.renameTo(target)) {
                check(backup.renameTo(target))
                error("Could not commit media pack")
            }
        } else {
            check(candidate.renameTo(target))
        }
    }

    override fun onPause() {
        gameAudio?.setForeground(false)
        super.onPause()
    }

    override fun onResume() {
        super.onResume()
        gameAudio?.setForeground(true)
    }

    override fun onDestroy() {
        gameAudio?.dispose()
        updates?.dispose()
        mediaWorker.shutdown()
        super.onDestroy()
    }
}
