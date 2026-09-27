package com.framefuse.app

import android.content.ContentValues
import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Matrix
import android.media.ExifInterface
import android.media.MediaMetadataRetriever
import android.media.MediaScannerConnection
import android.os.Build
import android.os.Environment
import android.os.PowerManager
import android.os.StatFs
import android.provider.MediaStore
import io.flutter.plugin.common.EventChannel
import java.io.File
import java.io.FileOutputStream

/** EXIF-aware dual crop of a captured photo. */
object PhotoCropper {

    /** Returns [portraitW, portraitH, landscapeW, landscapeH]. */
    fun crop(sourcePath: String, portraitOut: String, landscapeOut: String, quality: Int): List<Int> {
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeFile(sourcePath, bounds)
        require(bounds.outWidth > 0 && bounds.outHeight > 0) { "Unreadable image" }

        // Keep memory bounded on 50MP+ sensors.
        var sample = 1
        while ((bounds.outWidth / sample).toLong() * (bounds.outHeight / sample) > 24_000_000L) {
            sample *= 2
        }
        val decoded = BitmapFactory.decodeFile(
            sourcePath, BitmapFactory.Options().apply { inSampleSize = sample }
        ) ?: throw IllegalArgumentException("Failed to decode image")

        val upright = applyExifOrientation(decoded, sourcePath)
        try {
            val p = writeCrop(upright, 9.0 / 16.0, portraitOut, quality)
            val l = writeCrop(upright, 16.0 / 9.0, landscapeOut, quality)
            return listOf(p.first, p.second, l.first, l.second)
        } finally {
            upright.recycle()
        }
    }

    private fun writeCrop(src: Bitmap, aspect: Double, out: String, quality: Int): Pair<Int, Int> {
        val c = CropMath.pixelCrop(src.width, src.height, aspect)
        val cropped = Bitmap.createBitmap(src, c.left, c.top, c.width, c.height)
        File(out).parentFile?.mkdirs()
        FileOutputStream(out).use { cropped.compress(Bitmap.CompressFormat.JPEG, quality, it) }
        val size = cropped.width to cropped.height
        if (cropped !== src) cropped.recycle()
        return size
    }

    private fun applyExifOrientation(bitmap: Bitmap, path: String): Bitmap {
        val orientation = try {
            ExifInterface(path).getAttributeInt(
                ExifInterface.TAG_ORIENTATION, ExifInterface.ORIENTATION_NORMAL
            )
        } catch (_: Exception) {
            ExifInterface.ORIENTATION_NORMAL
        }
        val m = Matrix()
        when (orientation) {
            ExifInterface.ORIENTATION_ROTATE_90 -> m.postRotate(90f)
            ExifInterface.ORIENTATION_ROTATE_180 -> m.postRotate(180f)
            ExifInterface.ORIENTATION_ROTATE_270 -> m.postRotate(270f)
            ExifInterface.ORIENTATION_FLIP_HORIZONTAL -> m.postScale(-1f, 1f)
            ExifInterface.ORIENTATION_FLIP_VERTICAL -> m.postScale(1f, -1f)
            ExifInterface.ORIENTATION_TRANSPOSE -> { m.postRotate(90f); m.postScale(-1f, 1f) }
            ExifInterface.ORIENTATION_TRANSVERSE -> { m.postRotate(270f); m.postScale(-1f, 1f) }
            else -> return bitmap
        }
        val rotated = Bitmap.createBitmap(bitmap, 0, 0, bitmap.width, bitmap.height, m, true)
        if (rotated !== bitmap) bitmap.recycle()
        return rotated
    }
}

/** Copies finished files into the shared gallery (Movies/ or Pictures/FrameFuse). */
class GalleryExporter(private val context: Context) {

    companion object {
        const val ALBUM = "FrameFuse"
    }

    /** Returns the content URI (API 29+) or absolute path (API 26-28). */
    fun save(path: String, isVideo: Boolean, displayName: String): String {
        val src = File(path)
        require(src.exists()) { "File not found: $path" }
        val mime = if (isVideo) "video/mp4" else "image/jpeg"

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val resolver = context.contentResolver
            val collection = if (isVideo) {
                MediaStore.Video.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
            } else {
                MediaStore.Images.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
            }
            val dir = if (isVideo) Environment.DIRECTORY_MOVIES else Environment.DIRECTORY_PICTURES
            val values = ContentValues().apply {
                put(MediaStore.MediaColumns.DISPLAY_NAME, displayName)
                put(MediaStore.MediaColumns.MIME_TYPE, mime)
                put(MediaStore.MediaColumns.RELATIVE_PATH, "$dir/$ALBUM")
                put(MediaStore.MediaColumns.IS_PENDING, 1)
            }
            val uri = resolver.insert(collection, values)
                ?: throw IllegalStateException("MediaStore insert failed")
            try {
                resolver.openOutputStream(uri)?.use { out ->
                    src.inputStream().use { it.copyTo(out) }
                } ?: throw IllegalStateException("Cannot open output stream")
                values.clear()
                values.put(MediaStore.MediaColumns.IS_PENDING, 0)
                resolver.update(uri, values, null, null)
                return uri.toString()
            } catch (e: Exception) {
                resolver.delete(uri, null, null)
                throw e
            }
        } else {
            @Suppress("DEPRECATION")
            val base = Environment.getExternalStoragePublicDirectory(
                if (isVideo) Environment.DIRECTORY_MOVIES else Environment.DIRECTORY_PICTURES
            )
            val dir = File(base, ALBUM).apply { mkdirs() }
            var dest = File(dir, displayName)
            var i = 1
            while (dest.exists()) {
                dest = File(dir, "${displayName.substringBeforeLast('.')}_$i.${displayName.substringAfterLast('.')}")
                i++
            }
            src.copyTo(dest)
            MediaScannerConnection.scanFile(context, arrayOf(dest.absolutePath), arrayOf(mime), null)
            return dest.absolutePath
        }
    }
}

/** Evenly spaced JPEG frames for filmstrips and gallery thumbnails. */
object ThumbnailExtractor {
    fun extract(videoPath: String, count: Int, outDir: String, maxWidth: Int): List<String> {
        val retriever = MediaMetadataRetriever()
        val result = mutableListOf<String>()
        try {
            retriever.setDataSource(videoPath)
            val durationMs = retriever.extractMetadata(
                MediaMetadataRetriever.METADATA_KEY_DURATION
            )?.toLongOrNull() ?: 0L
            val dir = File(outDir).apply { mkdirs() }
            for (i in 0 until count.coerceAtLeast(1)) {
                val timeUs = if (count <= 1) 0L else (durationMs * 1000L * (2 * i + 1)) / (2L * count)
                val frame = retriever.getFrameAtTime(timeUs, MediaMetadataRetriever.OPTION_CLOSEST_SYNC)
                    ?: continue
                val scaled = if (frame.width > maxWidth) {
                    val h = (frame.height.toLong() * maxWidth / frame.width).toInt().coerceAtLeast(1)
                    Bitmap.createScaledBitmap(frame, maxWidth, h, true).also {
                        if (it !== frame) frame.recycle()
                    }
                } else frame
                val out = File(dir, "thumb_$i.jpg")
                FileOutputStream(out).use { scaled.compress(Bitmap.CompressFormat.JPEG, 80, it) }
                scaled.recycle()
                result.add(out.absolutePath)
            }
        } finally {
            retriever.release()
        }
        return result
    }
}

object StorageInfo {
    fun freeBytes(context: Context): Long = StatFs(context.filesDir.absolutePath).availableBytes
}

/**
 * Streams PowerManager thermal status (0 = none … 6 = shutdown) to Flutter.
 * Emits -1 on devices older than Android 10 where the API is unavailable.
 */
class ThermalMonitor(context: Context) : EventChannel.StreamHandler {
    private val powerManager = context.getSystemService(Context.POWER_SERVICE) as PowerManager
    private var listener: Any? = null

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            events.success(powerManager.currentThermalStatus)
            val l = PowerManager.OnThermalStatusChangedListener { status -> events.success(status) }
            powerManager.addThermalStatusListener(l)
            listener = l
        } else {
            events.success(-1)
        }
    }

    override fun onCancel(arguments: Any?) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            (listener as? PowerManager.OnThermalStatusChangedListener)?.let {
                powerManager.removeThermalStatusListener(it)
            }
        }
        listener = null
    }
}
