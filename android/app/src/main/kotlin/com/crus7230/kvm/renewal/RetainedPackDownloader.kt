package com.crus7230.kvm.renewal

import java.io.File
import java.net.HttpURLConnection
import java.net.URL
import java.security.MessageDigest
import java.util.zip.ZipInputStream

/** Bounded HTTPS download into a private candidate, never over an active pack. */
object RetainedPackDownloader {
    fun download(
        cacheDir: File, candidate: File, entries: List<Map<String, Any>>,
        metadata: Map<String, Any>, safeFile: (File, String) -> File,
    ) {
        val initialUrl = metadata["url"] as String
        check(initialUrl in setOf(
            "https://github.com/Crus7230/kv-engpzl/releases/download/media-audio-v1/KVM-audio-v1.zip",
            "https://github.com/Crus7230/kv-engpzl/releases/download/media-r1-v3/KVM-r1-media-v3.zip",
        ))
        check((metadata["bytes"] as Number).toLong() in 1..32_000_000)
        check(Regex("[a-fA-F0-9]{64}").matches(metadata["sha256"] as String))
        val archive = File(cacheDir, "kvm-pack-${System.nanoTime()}.zip")
        try {
            var url = URL(initialUrl)
            var connection: HttpURLConnection? = null
            for (redirect in 0..4) {
                check(url.protocol == "https" && url.host in setOf("github.com", "release-assets.githubusercontent.com", "objects.githubusercontent.com") && url.port == -1 && url.userInfo == null)
                val next = url.openConnection() as HttpURLConnection
                next.instanceFollowRedirects = false
                next.connectTimeout = 15000; next.readTimeout = 15000
                next.setRequestProperty("User-Agent", "KVM-retained-packs-v1")
                try {
                    val code = next.responseCode
                    if (code in 300..399) {
                        url = URL(url, next.getHeaderField("Location") ?: error("Missing redirect"))
                        next.disconnect(); continue
                    }
                    check(code == 200); connection = next; break
                } catch (error: Exception) { next.disconnect(); throw error }
            }
            val source = connection ?: error("Too many redirects")
            try {
                source.inputStream.use { input -> archive.outputStream().use { output ->
                    val buffer = ByteArray(65536); var bytes = 0L
                    while (true) {
                        val size = input.read(buffer); if (size < 0) break
                        bytes += size; check(bytes <= (metadata["bytes"] as Number).toLong())
                        output.write(buffer, 0, size)
                    }
                } }
            } finally { source.disconnect() }
            check(matches(archive, metadata))
            val expected = entries.associateBy { it["path"] as String }
            check(expected.size == entries.size)
            val seen = mutableSetOf<String>()
            ZipInputStream(archive.inputStream()).use { zip ->
                while (true) {
                    val entry = zip.nextEntry ?: break
                    if (entry.isDirectory) { zip.closeEntry(); continue }
                    val manifest = expected[entry.name] ?: error("Unexpected ZIP entry")
                    check(seen.add(entry.name))
                    val file = safeFile(candidate, entry.name)
                    check(file.parentFile!!.mkdirs() || file.parentFile!!.isDirectory)
                    file.outputStream().use { output ->
                        val buffer = ByteArray(65536); var bytes = 0L
                        while (true) {
                            val size = zip.read(buffer); if (size < 0) break
                            bytes += size; check(bytes <= (manifest["bytes"] as Number).toLong())
                            output.write(buffer, 0, size)
                        }
                    }
                    check(matches(file, manifest)); zip.closeEntry()
                }
            }
            check(seen == expected.keys)
        } finally { archive.delete() } // Only this generated cache file.
    }

    private fun matches(file: File, metadata: Map<String, Any>): Boolean {
        if (!file.isFile || file.length() != (metadata["bytes"] as Number).toLong()) return false
        val digest = MessageDigest.getInstance("SHA-256")
        file.inputStream().use { input ->
            val buffer = ByteArray(65536)
            while (true) { val size = input.read(buffer); if (size < 0) break; digest.update(buffer, 0, size) }
        }
        val hash = digest.digest().joinToString("") { "%02x".format(it.toInt() and 255) }
        return hash.equals(metadata["sha256"] as String, ignoreCase = true)
    }
}
