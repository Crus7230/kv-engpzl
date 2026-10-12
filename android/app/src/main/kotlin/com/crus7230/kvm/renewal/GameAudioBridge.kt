package com.crus7230.kvm.renewal

import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.media.MediaPlayer
import android.media.SoundPool
import android.os.Build
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.security.MessageDigest
import java.util.concurrent.Executors

/** Retained, hash-verified audio is independent of the PNG pack and save epoch. */
class GameAudioBridge(private val activity: MainActivity, messenger: BinaryMessenger) {
    private val channel = MethodChannel(messenger, "kvm/audio")
    private val worker = Executors.newSingleThreadExecutor()
    private val attributes = AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_GAME)
        .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC).build()
    private val manager = activity.getSystemService(AudioManager::class.java)
    private var pool: SoundPool? = null
    private val soundIds = mutableMapOf<String, Int>()
    private val loadedSounds = mutableSetOf<Int>()
    private var player: MediaPlayer? = null
    private var currentPath: String? = null
    private var prepared = false
    private var active = false
    private var foreground = true
    private var focused = false
    private var volume = .45f
    private var disposed = false
    private var available = false
    private var preparing = false
    private var entries = emptyList<Map<String, Any>>()
    private var download = emptyMap<String, Any>()
    private val packId = "audio-v1"
    private val focusListener = AudioManager.OnAudioFocusChangeListener { change ->
        focused = change == AudioManager.AUDIOFOCUS_GAIN
        if (focused) resumeMusic() else {
            player?.takeIf { prepared && it.isPlaying }?.pause()
            pool?.autoPause()
        }
    }
    private var focusRequest: AudioFocusRequest? = null

    init {
        channel.setMethodCallHandler { call, result ->
            try {
                check(!disposed)
                when (call.method) {
                    "initialize" -> {
                        check(call.argument<String>("packId") == packId)
                        check(call.argument<Number>("manifestVersion")?.toInt() == 1)
                        entries = call.argument<List<Map<String, Any>>>("assets") ?: error("Missing manifest")
                        download = call.argument<Map<String, Any>>("download") ?: error("Missing download metadata")
                        validateManifest()
                        prepare(result, false)
                    }
                    "download" -> prepare(result, true)
                    "music" -> {
                        volume = (call.argument<Number>("volume")?.toFloat() ?: .45f).coerceIn(0f, 1f)
                        active = call.argument<Boolean>("active") == true
                        setMusic(call.argument<String>("path"))
                        if (active && foreground && available) requestFocus() else pausePlayback()
                        result.success(null)
                    }
                    "effect" -> {
                        val id = soundIds[call.argument<String>("sound")]
                        if (active && foreground && focused && id != null && loadedSounds.contains(id)) {
                            val gain = (call.argument<Number>("volume")?.toFloat() ?: .65f).coerceIn(0f, 1f)
                            pool?.play(id, gain, gain, 1, 0, 1f)
                        }
                        result.success(null)
                    }
                    "unlock" -> { if (active && foreground && available) requestFocus(); result.success(null) }
                    "suspend" -> { active = false; pausePlayback(); result.success(null) }
                    "dispose" -> { dispose(); result.success(null) }
                    else -> result.notImplemented()
                }
            } catch (_: Exception) {
                result.error("AUDIO_UNAVAILABLE", "Audio operation unavailable. Progress is unchanged.", null)
            }
        }
    }

    private fun directory() = File(activity.filesDir, "kvm_asset_packs/$packId")
    private fun safeFile(dir: File, path: String): File {
        check(Regex("assets/audio/(intro|bgm0[123])\\.mp3|assets/audio/(select|swap|pop|special)\\.wav").matches(path))
        val target = File(dir, path).canonicalFile
        check(target.path.startsWith(dir.canonicalPath + File.separator))
        return target
    }
    private fun validateManifest() {
        check(entries.size == 8 && entries.map { it["path"] }.toSet().size == 8)
        for (entry in entries) {
            safeFile(directory(), entry["path"] as String)
            check((entry["bytes"] as Number).toLong() in 1..8_000_000)
            check(Regex("[a-fA-F0-9]{64}").matches(entry["sha256"] as String))
        }
        check((download["bytes"] as Number).toLong() in 1..24_000_000)
        check(Regex("[a-fA-F0-9]{64}").matches(download["sha256"] as String))
        check(download["url"] == "https://github.com/Crus7230/kv-engpzl/releases/download/media-audio-v1/KVM-audio-v1.zip")
    }
    private fun digest(file: File): String {
        val digest = MessageDigest.getInstance("SHA-256")
        file.inputStream().use { input ->
            val buffer = ByteArray(65536)
            while (true) { val size = input.read(buffer); if (size < 0) break; digest.update(buffer, 0, size) }
        }
        return digest.digest().joinToString("") { "%02x".format(it.toInt() and 255) }
    }
    private fun matches(file: File, entry: Map<String, Any>) = file.isFile &&
        file.length() == (entry["bytes"] as Number).toLong() &&
        digest(file).equals(entry["sha256"] as String, ignoreCase = true)
    private fun valid(dir: File) = entries.all { matches(safeFile(dir, it["path"] as String), it) }

    private fun prepare(result: MethodChannel.Result, allowDownload: Boolean) {
        check(!preparing && entries.isNotEmpty())
        preparing = true
        worker.execute {
            try {
                val ready = ensureInstalled(allowDownload)
                activity.runOnUiThread {
                    preparing = false
                    if (!disposed && ready) { available = true; loadSounds() }
                    result.success(!disposed && ready)
                }
            } catch (_: Exception) {
                activity.runOnUiThread {
                    preparing = false
                    result.error("AUDIO_PACK_UNAVAILABLE", "Could not verify audio pack. Retry or continue silently.", null)
                }
            }
        }
    }
    private fun ensureInstalled(allowDownload: Boolean): Boolean {
        val target = directory()
        if (valid(target)) return true
        val recoverable = target.parentFile?.listFiles()?.firstOrNull {
            it.isDirectory && (it.name.startsWith("$packId-candidate-") || it.name.startsWith("$packId-previous-")) && valid(it)
        }
        if (recoverable != null) { commit(recoverable, target); return true }
        // Logic-only APKs intentionally have no embedded audio. No automatic
        // network use: the user explicitly requests a one-time download.
        if (!allowDownload) {
            val allEmbedded = entries.all {
                try { activity.assets.open("flutter_assets/${it["path"]}").use { }; true } catch (_: Exception) { false }
            }
            if (!allEmbedded) return false
        }
        val candidate = File(target.parentFile, "$packId-candidate-${System.nanoTime()}")
        check(candidate.mkdirs())
        try {
            if (allowDownload) RetainedPackDownloader.download(activity.cacheDir, candidate, entries, download, ::safeFile) else {
                for (entry in entries) {
                    val file = safeFile(candidate, entry["path"] as String)
                    check(file.parentFile!!.mkdirs() || file.parentFile!!.isDirectory)
                    activity.assets.open("flutter_assets/${entry["path"]}").use { input ->
                        file.outputStream().use { input.copyTo(it) }
                    }
                }
            }
            check(valid(candidate))
            commit(candidate, target)
            return true
        } finally {
            // Only our incomplete generated candidate is disposable. A fully
            // verified candidate survives a failed rename for next-start recovery.
            if (candidate.exists() && !valid(candidate)) {
                check(candidate.canonicalPath.startsWith(target.parentFile!!.canonicalPath + File.separator))
                candidate.deleteRecursively()
            }
        }
    }
    private fun commit(candidate: File, target: File) {
        if (!target.exists()) { check(candidate.renameTo(target)); return }
        val previous = File(target.parentFile, "$packId-previous-${System.nanoTime()}")
        check(target.renameTo(previous))
        if (!candidate.renameTo(target)) { check(previous.renameTo(target)); error("Commit failed") }
    }
    private fun loadSounds() {
        if (pool != null) return
        pool = SoundPool.Builder().setMaxStreams(6).setAudioAttributes(attributes).build().also { soundPool ->
            soundPool.setOnLoadCompleteListener { _, id, status -> if (status == 0) loadedSounds.add(id) }
            for (id in listOf("select", "swap", "pop", "special")) {
                soundIds[id] = soundPool.load(safeFile(directory(), "assets/audio/$id.wav").path, 1)
            }
        }
    }
    private fun setMusic(path: String?) {
        if (path != null) check(entries.any { it["path"] == path } && path.endsWith(".mp3"))
        if (path == currentPath) { player?.setVolume(volume, volume); return }
        player?.release(); player = null; prepared = false; currentPath = path
        if (path == null || !available) return
        player = MediaPlayer().also { next ->
            next.setAudioAttributes(attributes)
            next.setDataSource(safeFile(directory(), path).path)
            next.isLooping = true
            next.setVolume(volume, volume)
            next.setOnPreparedListener {
                if (player === it && !disposed) { prepared = true; resumeMusic() }
            }
            next.setOnErrorListener { failed, _, _ ->
                if (player === failed) { prepared = false; currentPath = null; player = null }
                failed.release(); true
            }
            next.prepareAsync()
        }
    }
    @Suppress("DEPRECATION")
    private fun requestFocus() {
        if (focused) { resumeMusic(); return }
        val result = if (Build.VERSION.SDK_INT >= 26) {
            val request = focusRequest ?: AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN)
                .setAudioAttributes(attributes).setOnAudioFocusChangeListener(focusListener)
                .setWillPauseWhenDucked(true).build().also { focusRequest = it }
            manager.requestAudioFocus(request)
        } else manager.requestAudioFocus(focusListener, AudioManager.STREAM_MUSIC, AudioManager.AUDIOFOCUS_GAIN)
        focused = result == AudioManager.AUDIOFOCUS_REQUEST_GRANTED
        resumeMusic()
    }
    private fun resumeMusic() {
        if (!disposed && active && foreground && focused && prepared) player?.start()
    }
    @Suppress("DEPRECATION")
    private fun pausePlayback() {
        player?.takeIf { prepared && it.isPlaying }?.pause()
        pool?.autoPause()
        if (Build.VERSION.SDK_INT >= 26) focusRequest?.let { manager.abandonAudioFocusRequest(it) }
        else manager.abandonAudioFocus(focusListener)
        focused = false
    }
    fun setForeground(value: Boolean) {
        foreground = value
        if (!value) { active = false; pausePlayback() }
        // Flutter explicitly resumes once its lifecycle is resumed.
    }
    fun dispose() {
        if (disposed) return
        disposed = true; active = false; pausePlayback()
        player?.release(); player = null
        pool?.release(); pool = null
        loadedSounds.clear(); soundIds.clear()
        channel.setMethodCallHandler(null)
        worker.shutdown()
    }
}
