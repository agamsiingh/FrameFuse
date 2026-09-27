package com.framefuse.app

import android.content.Context
import android.media.MediaMetadataRetriever
import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.annotation.OptIn
import androidx.media3.common.MediaItem
import androidx.media3.common.MimeTypes
import androidx.media3.common.util.UnstableApi
import androidx.media3.effect.Crop
import androidx.media3.effect.Presentation
import androidx.media3.transformer.Composition
import androidx.media3.transformer.EditedMediaItem
import androidx.media3.transformer.Effects
import androidx.media3.transformer.ExportException
import androidx.media3.transformer.ExportResult
import androidx.media3.transformer.ProgressHolder
import androidx.media3.transformer.Transformer
import java.io.File
import kotlin.math.roundToInt

/**
 * Renders one aspect-ratio output (center crop + optional trim) from the
 * master recording using AndroidX Media3 Transformer.
 *
 * Transformer must be driven from a thread with a Looper; everything here
 * runs on the main thread and the heavy lifting happens inside Media3.
 * Only one export runs at a time (hardware codec instances are limited).
 */
@OptIn(UnstableApi::class)
class VideoExporter(private val context: Context) {

    companion object {
        private const val TAG = "VideoExporter"
        private const val PROGRESS_INTERVAL_MS = 200L
    }

    private val mainHandler = Handler(Looper.getMainLooper())
    private var transformer: Transformer? = null
    private var progressPoller: Runnable? = null
    private var pendingCompletion: ((Result<String>) -> Unit)? = null
    private var pendingOutput: String? = null

    val isBusy: Boolean get() = transformer != null

    /** Display (rotation-applied) size of a video file. */
    data class VideoInfo(val width: Int, val height: Int, val durationMs: Long)

    fun probe(path: String): VideoInfo {
        val retriever = MediaMetadataRetriever()
        try {
            retriever.setDataSource(path)
            val w = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_WIDTH)?.toIntOrNull() ?: 0
            val h = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_HEIGHT)?.toIntOrNull() ?: 0
            val rotation = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_ROTATION)?.toIntOrNull() ?: 0
            val duration = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)?.toLongOrNull() ?: 0L
            return if (rotation % 180 != 0) VideoInfo(h, w, duration) else VideoInfo(w, h, duration)
        } finally {
            retriever.release()
        }
    }

    /**
     * Exports [inputPath] center-cropped to [targetAspect] (width / height)
     * into [outputPath], optionally trimmed to [startMs, endMs].
     */
    fun export(
        inputPath: String,
        outputPath: String,
        targetAspect: Double,
        startMs: Long,
        endMs: Long,
        onProgress: (Int) -> Unit,
        onComplete: (Result<String>) -> Unit,
    ) {
        if (isBusy) {
            onComplete(Result.failure(IllegalStateException("An export is already running")))
            return
        }

        val info = try {
            probe(inputPath)
        } catch (e: Exception) {
            onComplete(Result.failure(e))
            return
        }
        if (info.width <= 0 || info.height <= 0) {
            onComplete(Result.failure(IllegalArgumentException("Unreadable video: $inputPath")))
            return
        }

        val crop = CropMath.centerCrop(info.width, info.height, targetAspect)
        File(outputPath).parentFile?.mkdirs()
        File(outputPath).delete()

        val clipping = MediaItem.ClippingConfiguration.Builder().apply {
            if (startMs > 0) setStartPositionMs(startMs)
            if (endMs > 0 && endMs < info.durationMs) setEndPositionMs(endMs)
        }.build()

        val mediaItem = MediaItem.Builder()
            .setUri(android.net.Uri.fromFile(File(inputPath)))
            .setClippingConfiguration(clipping)
            .build()

        val videoEffects = listOf(
            Crop(crop.left, crop.right, crop.bottom, crop.top),
            // Pin an exact, even output size (encoders reject odd dimensions).
            Presentation.createForWidthAndHeight(
                crop.outWidth, crop.outHeight, Presentation.LAYOUT_STRETCH_TO_FIT
            ),
        )

        val edited = EditedMediaItem.Builder(mediaItem)
            .setEffects(Effects(emptyList(), videoEffects))
            .build()

        val t = Transformer.Builder(context)
            .setVideoMimeType(MimeTypes.VIDEO_H264)
            .addListener(object : Transformer.Listener {
                override fun onCompleted(composition: Composition, exportResult: ExportResult) {
                    finish()
                    onProgress(100)
                    onComplete(Result.success(outputPath))
                }

                override fun onError(
                    composition: Composition,
                    exportResult: ExportResult,
                    exportException: ExportException,
                ) {
                    Log.e(TAG, "Export failed: ${exportException.errorCodeName}", exportException)
                    finish()
                    File(outputPath).delete()
                    onComplete(Result.failure(exportException))
                }
            })
            .build()

        transformer = t
        pendingCompletion = onComplete
        pendingOutput = outputPath
        try {
            t.start(edited, outputPath)
        } catch (e: Exception) {
            finish()
            onComplete(Result.failure(e))
            return
        }

        val holder = ProgressHolder()
        val poller = object : Runnable {
            override fun run() {
                val current = transformer ?: return
                if (current.getProgress(holder) == Transformer.PROGRESS_STATE_AVAILABLE) {
                    onProgress(holder.progress)
                }
                mainHandler.postDelayed(this, PROGRESS_INTERVAL_MS)
            }
        }
        progressPoller = poller
        mainHandler.post(poller)
    }

    /** Cancels the running export; its caller receives a failure. */
    fun cancel() {
        val t = transformer ?: return
        val completion = pendingCompletion
        val output = pendingOutput
        t.cancel() // Media3 does not invoke listener callbacks on cancel.
        finish()
        output?.let { File(it).delete() }
        completion?.invoke(Result.failure(java.util.concurrent.CancellationException("Export cancelled")))
    }

    private fun finish() {
        progressPoller?.let { mainHandler.removeCallbacks(it) }
        progressPoller = null
        transformer = null
        pendingCompletion = null
        pendingOutput = null
    }
}

/** Center-crop geometry shared by video and photo pipelines. */
object CropMath {
    /**
     * Crop in Media3 NDC coordinates (-1..1, y up) plus the even-sized
     * output resolution in pixels.
     */
    data class NdcCrop(
        val left: Float, val right: Float, val bottom: Float, val top: Float,
        val outWidth: Int, val outHeight: Int,
    )

    data class PixelCrop(val left: Int, val top: Int, val width: Int, val height: Int)

    fun pixelCrop(srcW: Int, srcH: Int, targetAspect: Double): PixelCrop {
        val srcAspect = srcW.toDouble() / srcH
        return if (srcAspect > targetAspect) {
            val w = (srcH * targetAspect).roundToInt().coerceIn(1, srcW)
            PixelCrop((srcW - w) / 2, 0, w, srcH)
        } else {
            val h = (srcW / targetAspect).roundToInt().coerceIn(1, srcH)
            PixelCrop(0, (srcH - h) / 2, srcW, h)
        }
    }

    fun centerCrop(srcW: Int, srcH: Int, targetAspect: Double): NdcCrop {
        val px = pixelCrop(srcW, srcH, targetAspect)
        val halfW = px.width.toFloat() / srcW
        val halfH = px.height.toFloat() / srcH
        return NdcCrop(
            -halfW, halfW, -halfH, halfH,
            even(px.width), even(px.height),
        )
    }

    private fun even(v: Int): Int = (v / 2 * 2).coerceAtLeast(2)
}
