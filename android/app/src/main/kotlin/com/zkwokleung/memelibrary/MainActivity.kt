package com.zkwokleung.memelibrary

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.ImageDecoder
import android.net.Uri
import android.os.Bundle
import android.util.Log
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.IOException
import java.util.UUID

class MainActivity : FlutterActivity() {
    companion object {
        private const val TAG = "MemeLibrary"
        private const val METHOD_CHANNEL = "com.zkwokleung.memelibrary/platform"
        private const val EVENT_CHANNEL = "com.zkwokleung.memelibrary/incoming_shares"

        /** Mirrors ImageValidator.defaultMaxFileSizeBytes on the Dart side. */
        private const val MAX_IMPORT_BYTES = 25L * 1024 * 1024

        /** Mirrors ImageValidator.defaultMaxPixels on the Dart side. */
        private const val MAX_IMPORT_PIXELS = 50L * 1000 * 1000
    }

    /** Shares received before the Dart side asked for them (cold start). */
    private val pendingShares = mutableListOf<Map<String, Any?>>()
    private var eventSink: EventChannel.EventSink? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Orphans from a previous process that died before Dart consumed
        // its staged shares.
        File(cacheDir, "incoming_shares").listFiles()?.forEach { it.delete() }
        // Only a fresh launch carries a new share; a recreation would
        // re-deliver an intent that was already handled.
        if (savedInstanceState == null) {
            handleShareIntent(intent)
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        // Keep getIntent() current so a later recreation does not replay
        // the original launch intent.
        setIntent(intent)
        handleShareIntent(intent)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger

        MethodChannel(messenger, METHOD_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "clipboard.readImage" -> readClipboardImageWhenFocused(result)
                "clipboard.writeImage" -> {
                    val bytes = call.argument<ByteArray>("bytes")
                    val name = call.argument<String>("name")
                    result.success(bytes != null && writeClipboardImage(bytes, name))
                }
                "shares.takeInitial" -> {
                    val shares = pendingShares.toList()
                    pendingShares.clear()
                    result.success(shares)
                }
                "image.transcodeToJpeg" -> {
                    val path = call.argument<String>("path")
                    if (path == null) {
                        result.success(null)
                    } else {
                        // Decoding a 50 MP image is not main-thread work.
                        Thread {
                            val bytes = transcodeToJpeg(path)
                            runOnUiThread {
                                result.success(bytes?.let { mapOf("bytes" to it) })
                            }
                        }.start()
                    }
                }
                else -> result.notImplemented()
            }
        }

        EventChannel(messenger, EVENT_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                    if (pendingShares.isNotEmpty()) {
                        events?.success(pendingShares.toList())
                        pendingShares.clear()
                    }
                }

                override fun onCancel(arguments: Any?) {
                    eventSink = null
                }
            }
        )
    }

    /**
     * Copies ACTION_SEND / ACTION_SEND_MULTIPLE content into app-owned cache
     * files while the temporary URI grant is still valid, then hands the
     * staged paths to Dart.
     */
    private fun handleShareIntent(intent: Intent?) {
        if (intent == null) return
        val uris: List<Uri> = when (intent.action) {
            Intent.ACTION_SEND ->
                listOfNotNull(intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java))
            Intent.ACTION_SEND_MULTIPLE ->
                intent.getParcelableArrayListExtra(Intent.EXTRA_STREAM, Uri::class.java)
                    ?.filterNotNull() ?: emptyList()
            else -> return
        }
        val staged = uris.mapNotNull { stageSharedUri(it) }
        if (staged.isEmpty()) return

        val sink = eventSink
        if (sink != null) {
            sink.success(staged)
        } else {
            pendingShares.addAll(staged)
        }
    }

    private fun stageSharedUri(uri: Uri): Map<String, Any?>? {
        return try {
            val dir = File(cacheDir, "incoming_shares").apply { mkdirs() }
            val target = File(dir, UUID.randomUUID().toString())
            val copied = contentResolver.openInputStream(uri)?.use { input ->
                target.outputStream().use { output ->
                    copyCapped(input, output)
                }
            } ?: return null
            if (!copied) {
                target.delete()
                Log.w(TAG, "Dropped shared content over the size limit: $uri")
                return null
            }
            mapOf("path" to target.absolutePath, "mimeType" to contentResolver.getType(uri))
        } catch (e: Exception) {
            Log.w(TAG, "Could not stage shared content: $uri", e)
            null
        }
    }

    /**
     * Android only serves the clipboard to the window that currently has
     * input focus. When the read is triggered from a closing bottom
     * sheet, focus returns to the activity a few frames later — wait for
     * it (bounded) instead of failing.
     */
    private fun readClipboardImageWhenFocused(
        result: MethodChannel.Result,
        attempt: Int = 0,
    ) {
        if (hasWindowFocus() || attempt >= 20) {
            result.success(readClipboardImage())
        } else {
            window.decorView.postDelayed(
                { readClipboardImageWhenFocused(result, attempt + 1) },
                50,
            )
        }
    }

    private fun readClipboardImage(): Map<String, Any?>? {
        val clipboard = getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
        val clip = clipboard.primaryClip
        if (clip == null) {
            Log.w(TAG, "readClipboardImage: primaryClip is null (focus=${hasWindowFocus()})")
            return null
        }
        for (i in 0 until clip.itemCount) {
            val item = clip.getItemAt(i)
            val uri = item.uri
            if (uri == null) {
                // Never log clipboard content; the mime type is enough.
                Log.w(
                    TAG,
                    "readClipboardImage: item $i has no uri " +
                        "(mime=${clip.description.getMimeType(0)})",
                )
                continue
            }
            try {
                // Only image content, and never more than the validator
                // would accept: reading an arbitrary copied file into the
                // heap can OOM the app.
                val mime = contentResolver.getType(uri)
                if (mime != null && !mime.startsWith("image/")) {
                    Log.w(TAG, "readClipboardImage: skipping mime=$mime")
                    continue
                }
                val buffer = java.io.ByteArrayOutputStream()
                val complete = contentResolver.openInputStream(uri)?.use { input ->
                    copyCapped(input, buffer)
                } ?: continue
                if (!complete || buffer.size() == 0) continue
                return mapOf("bytes" to buffer.toByteArray(), "name" to uri.lastPathSegment)
            } catch (e: Exception) {
                Log.w(TAG, "readClipboardImage: item $i failed", e)
            }
        }
        return null
    }

    /**
     * Re-encodes a HEIF-family image as JPEG, or returns null when it
     * cannot be decoded or would breach the import limits.
     *
     * The Android photo picker hands back HEIC bytes verbatim and no
     * bundled Dart decoder can read them, so this is the only way a HEIC
     * photo enters the library. ImageDecoder applies the container
     * orientation itself, so the result is already upright and carries no
     * orientation tag.
     */
    private fun transcodeToJpeg(path: String): ByteArray? {
        return try {
            val file = File(path)
            if (!file.isFile || file.length() == 0L || file.length() > MAX_IMPORT_BYTES) {
                return null
            }
            val source = ImageDecoder.createSource(file)
            val bitmap = ImageDecoder.decodeBitmap(source) { decoder, info, _ ->
                // Bitmap.compress throws on HARDWARE bitmaps, which is
                // what ImageDecoder produces by default.
                decoder.allocator = ImageDecoder.ALLOCATOR_SOFTWARE
                decoder.isMutableRequired = false
                val pixels = info.size.width.toLong() * info.size.height
                if (pixels > MAX_IMPORT_PIXELS) {
                    throw IOException("declared pixel count $pixels over the limit")
                }
            }
            // HEIC can carry alpha and JPEG cannot, so a transparent source
            // composites onto black. Vanishingly rare for camera photos,
            // and a 12 MP PNG alternative would blow past the size cap.
            val out = ByteArrayOutputStream()
            val ok = bitmap.compress(Bitmap.CompressFormat.JPEG, 92, out)
            bitmap.recycle()
            if (!ok || out.size() == 0 || out.size() > MAX_IMPORT_BYTES) null else out.toByteArray()
        } catch (e: Exception) {
            // Never log image content; the failure alone is enough.
            Log.w(TAG, "transcodeToJpeg failed", e)
            null
        }
    }

    /**
     * Copies [input] to [output] up to [MAX_IMPORT_BYTES]; returns false
     * when the source exceeds the cap.
     */
    private fun copyCapped(input: java.io.InputStream, output: java.io.OutputStream): Boolean {
        val chunk = ByteArray(64 * 1024)
        var total = 0L
        while (true) {
            val read = input.read(chunk)
            if (read < 0) return true
            total += read
            if (total > MAX_IMPORT_BYTES) return false
            output.write(chunk, 0, read)
        }
    }

    /**
     * Puts an image on the clipboard as a FileProvider content URI, the
     * only clipboard payload other Android apps accept for images.
     */
    private fun writeClipboardImage(bytes: ByteArray, name: String?): Boolean {
        return try {
            // filesDir, not cacheDir: under storage pressure the system
            // purges cache while the ClipData URI still points at it,
            // breaking paste. Only the latest copy is kept.
            val dir = File(filesDir, "clipboard").apply { mkdirs() }
            dir.listFiles()?.forEach { it.delete() }
            val file = File(dir, name?.takeIf { it.isNotBlank() } ?: "meme.png")
            file.writeBytes(bytes)
            val uri = FileProvider.getUriForFile(this, "$packageName.fileprovider", file)
            val clipboard = getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
            clipboard.setPrimaryClip(ClipData.newUri(contentResolver, "Meme", uri))
            Log.w(TAG, "writeClipboardImage: set clip uri=$uri")
            true
        } catch (e: Exception) {
            Log.w(TAG, "writeClipboardImage failed", e)
            false
        }
    }
}
