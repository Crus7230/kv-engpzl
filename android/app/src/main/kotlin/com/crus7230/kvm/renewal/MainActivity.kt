package com.crus7230.kvm.renewal

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.security.MessageDigest
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private val mediaWorker = Executors.newSingleThreadExecutor()
    private val expectedPackId = "r1-media-v2"
    private var installedPaths = emptySet<String>()
    private var updates: AppUpdateBridge? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        updates = AppUpdateBridge(this, flutterEngine.dartExecutor.binaryMessenger)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "kvm/retained_assets")
            .setMethodCallHandler { call, result ->
                if (call.method != "ensureInstalled" && call.method != "readAsset") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                mediaWorker.execute {
                    try {
                        check(call.argument<String>("packId") == expectedPackId)
                        val output: Any? = when (call.method) {
                            "ensureInstalled" -> {
                                val entries = call.argument<List<Map<String, Any>>>("assets")
                                    ?: error("Missing media manifest")
                                ensureInstalled(entries)
                                null
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
        check(Regex("assets/legacy/[a-z0-9-]+\\.png").matches(path)) { "Invalid media path" }
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

    private fun ensureInstalled(entries: List<Map<String, Any>>) {
        check(entries.size == 6 && entries.map { it["path"] }.toSet().size == 6)
        val target = packDirectory()
        if (entries.all { matches(safeFile(target, it["path"] as String), it) }) {
            installedPaths = entries.map { it["path"] as String }.toSet()
            return
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
            return
        }
        // A new candidate is verified before touching the existing pack.
        val staging = File(filesDir, "kvm_asset_packs/$expectedPackId-candidate-${System.nanoTime()}")
        check(staging.mkdirs())
        try {
            for (entry in entries) {
                val path = entry["path"] as String
                val file = safeFile(staging, path)
                check(file.parentFile!!.mkdirs() || file.parentFile!!.isDirectory)
                assets.open("flutter_assets/$path").use { input ->
                    file.outputStream().use { output -> input.copyTo(output) }
                }
                check(matches(file, entry)) { "Media hash mismatch" }
            }
            commitPack(staging, target)
            installedPaths = entries.map { it["path"] as String }.toSet()
        } finally {
            // Only our validated, generated candidate directory is disposable.
            if (staging.exists()) staging.deleteRecursively()
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

    override fun onDestroy() {
        updates?.dispose()
        mediaWorker.shutdown()
        super.onDestroy()
    }
}
