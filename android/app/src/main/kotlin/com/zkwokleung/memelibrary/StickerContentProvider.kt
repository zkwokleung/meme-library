package com.zkwokleung.memelibrary

import android.content.ContentProvider
import android.content.ContentValues
import android.content.UriMatcher
import android.content.res.AssetFileDescriptor
import android.database.Cursor
import android.database.MatrixCursor
import android.net.Uri
import android.os.ParcelFileDescriptor
import android.util.Log
import java.io.File
import org.json.JSONArray
import org.json.JSONObject

/**
 * Serves sticker packs to WhatsApp per its third-party sticker contract.
 *
 * WhatsApp queries this provider whenever it needs pack content —
 * including when this app's Flutter engine is not running — so everything
 * is read from the on-disk tree the exporter writes under
 * filesDir/sticker_packs (contents.json plus one directory per pack).
 */
class StickerContentProvider : ContentProvider() {
    companion object {
        private const val TAG = "MemeLibrary"
        private const val METADATA = 1
        private const val METADATA_SINGLE = 2
        private const val STICKERS = 3
        private const val STICKERS_ASSET = 4

        private val PACK_COLUMNS = arrayOf(
            "sticker_pack_identifier",
            "sticker_pack_name",
            "sticker_pack_publisher",
            "sticker_pack_icon",
            "android_play_store_link",
            "ios_app_store_link",
            "sticker_pack_publisher_email",
            "sticker_pack_publisher_website",
            "sticker_pack_privacy_policy_website",
            "sticker_pack_license_agreement_website",
            "image_data_version",
            "whatsapp_will_not_cache_stickers",
            "animated_sticker_pack",
        )

        private val STICKER_COLUMNS = arrayOf(
            "sticker_file_name",
            "sticker_emoji",
            "sticker_accessibility_text",
        )
    }

    private lateinit var authority: String
    private lateinit var uriMatcher: UriMatcher

    override fun onCreate(): Boolean {
        authority = "${context!!.packageName}.stickercontentprovider"
        uriMatcher = UriMatcher(UriMatcher.NO_MATCH).apply {
            addURI(authority, "metadata", METADATA)
            addURI(authority, "metadata/*", METADATA_SINGLE)
            addURI(authority, "stickers/*", STICKERS)
            addURI(authority, "stickers_asset/*/*", STICKERS_ASSET)
        }
        return true
    }

    override fun query(
        uri: Uri,
        projection: Array<String>?,
        selection: String?,
        selectionArgs: Array<String>?,
        sortOrder: String?,
    ): Cursor {
        val cursor = when (uriMatcher.match(uri)) {
            METADATA -> packCursor(null)
            METADATA_SINGLE -> packCursor(uri.lastPathSegment)
            STICKERS -> stickerCursor(uri.lastPathSegment)
            else -> throw IllegalArgumentException("Unknown uri: $uri")
        }
        cursor.setNotificationUri(context!!.contentResolver, uri)
        return cursor
    }

    override fun openAssetFile(uri: Uri, mode: String): AssetFileDescriptor? {
        if (uriMatcher.match(uri) != STICKERS_ASSET) return null
        val segments = uri.pathSegments
        if (segments.size != 3) return null
        val packDir = File(packsDir(), segments[1])
        val file = File(packDir, segments[2])
        // The path segments come from another process; never serve
        // anything that resolves outside the pack directory.
        if (!file.canonicalPath.startsWith(packDir.canonicalPath + File.separator)) {
            return null
        }
        if (!file.isFile) return null
        return AssetFileDescriptor(
            ParcelFileDescriptor.open(file, ParcelFileDescriptor.MODE_READ_ONLY),
            0,
            AssetFileDescriptor.UNKNOWN_LENGTH,
        )
    }

    override fun getType(uri: Uri): String = when (uriMatcher.match(uri)) {
        METADATA -> "vnd.android.cursor.dir/vnd.$authority.metadata"
        METADATA_SINGLE -> "vnd.android.cursor.item/vnd.$authority.metadata"
        STICKERS -> "vnd.android.cursor.dir/vnd.$authority.stickers"
        STICKERS_ASSET ->
            if (uri.lastPathSegment?.endsWith(".png") == true) "image/png" else "image/webp"
        else -> throw IllegalArgumentException("Unknown uri: $uri")
    }

    override fun insert(uri: Uri, values: ContentValues?): Uri =
        throw UnsupportedOperationException()

    override fun update(
        uri: Uri,
        values: ContentValues?,
        selection: String?,
        selectionArgs: Array<String>?,
    ): Int = throw UnsupportedOperationException()

    override fun delete(uri: Uri, selection: String?, selectionArgs: Array<String>?): Int =
        throw UnsupportedOperationException()

    private fun packsDir(): File = File(context!!.filesDir, "sticker_packs")

    /** Re-read per query so the provider always serves the latest export. */
    private fun manifestPacks(): JSONArray {
        return try {
            val file = File(packsDir(), "contents.json")
            if (!file.isFile) {
                JSONArray()
            } else {
                JSONObject(file.readText()).optJSONArray("sticker_packs") ?: JSONArray()
            }
        } catch (e: Exception) {
            Log.w(TAG, "Sticker manifest unreadable", e)
            JSONArray()
        }
    }

    private fun packCursor(identifier: String?): Cursor {
        val cursor = MatrixCursor(PACK_COLUMNS)
        val packs = manifestPacks()
        for (i in 0 until packs.length()) {
            val pack = packs.optJSONObject(i) ?: continue
            if (identifier != null && pack.optString("identifier") != identifier) continue
            cursor.addRow(
                arrayOf<Any>(
                    pack.optString("identifier"),
                    pack.optString("name"),
                    pack.optString("publisher"),
                    pack.optString("tray_image_file"),
                    pack.optString("android_play_store_link"),
                    pack.optString("ios_app_store_link"),
                    pack.optString("publisher_email"),
                    pack.optString("publisher_website"),
                    pack.optString("privacy_policy_website"),
                    pack.optString("license_agreement_website"),
                    pack.optString("image_data_version"),
                    if (pack.optBoolean("avoid_cache")) 1 else 0,
                    if (pack.optBoolean("animated_sticker_pack")) 1 else 0,
                )
            )
        }
        return cursor
    }

    private fun stickerCursor(identifier: String?): Cursor {
        val cursor = MatrixCursor(STICKER_COLUMNS)
        val packs = manifestPacks()
        for (i in 0 until packs.length()) {
            val pack = packs.optJSONObject(i) ?: continue
            if (pack.optString("identifier") != identifier) continue
            val stickers = pack.optJSONArray("stickers") ?: JSONArray()
            for (j in 0 until stickers.length()) {
                val sticker = stickers.optJSONObject(j) ?: continue
                val emojis = sticker.optJSONArray("emojis") ?: JSONArray()
                cursor.addRow(
                    arrayOf<Any>(
                        sticker.optString("image_file"),
                        (0 until emojis.length()).joinToString(",") { emojis.optString(it) },
                        sticker.optString("accessibility_text"),
                    )
                )
            }
        }
        return cursor
    }
}
