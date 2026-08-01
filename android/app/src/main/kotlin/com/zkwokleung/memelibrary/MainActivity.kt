package com.zkwokleung.memelibrary

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.UUID

class MainActivity : FlutterActivity() {
    companion object {
        private const val METHOD_CHANNEL = "com.zkwokleung.memelibrary/platform"
        private const val EVENT_CHANNEL = "com.zkwokleung.memelibrary/incoming_shares"
    }

    /** Shares received before the Dart side asked for them (cold start). */
    private val pendingShares = mutableListOf<Map<String, Any?>>()
    private var eventSink: EventChannel.EventSink? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleShareIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleShareIntent(intent)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger

        MethodChannel(messenger, METHOD_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "clipboard.readImage" -> result.success(readClipboardImage())
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
            contentResolver.openInputStream(uri)?.use { input ->
                target.outputStream().use { output -> input.copyTo(output) }
            } ?: return null
            mapOf("path" to target.absolutePath, "mimeType" to contentResolver.getType(uri))
        } catch (e: Exception) {
            null
        }
    }

    private fun readClipboardImage(): Map<String, Any?>? {
        val clipboard = getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
        val clip = clipboard.primaryClip ?: return null
        for (i in 0 until clip.itemCount) {
            val uri = clip.getItemAt(i).uri ?: continue
            try {
                val bytes = contentResolver.openInputStream(uri)?.use { it.readBytes() } ?: continue
                if (bytes.isEmpty()) continue
                return mapOf("bytes" to bytes, "name" to uri.lastPathSegment)
            } catch (e: Exception) {
                // Try the next clip item.
            }
        }
        return null
    }

    /**
     * Puts an image on the clipboard as a FileProvider content URI, the
     * only clipboard payload other Android apps accept for images.
     */
    private fun writeClipboardImage(bytes: ByteArray, name: String?): Boolean {
        return try {
            val dir = File(cacheDir, "clipboard").apply { mkdirs() }
            dir.listFiles()?.forEach { it.delete() }
            val file = File(dir, name?.takeIf { it.isNotBlank() } ?: "meme.png")
            file.writeBytes(bytes)
            val uri = FileProvider.getUriForFile(this, "$packageName.fileprovider", file)
            val clipboard = getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
            clipboard.setPrimaryClip(ClipData.newUri(contentResolver, "Meme", uri))
            true
        } catch (e: Exception) {
            false
        }
    }
}
