package com.framefuse.app

import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

/**
 * Platform channels between Flutter and FrameFuse's native media layer.
 *
 * - `com.framefuse/capabilities`: hardware capability probe
 * - `com.framefuse/media`: export (crop/trim), photo crop, gallery save,
 *   thumbnails, free space. Export progress is pushed back to Dart as
 *   `exportProgress` calls on the same channel.
 * - `com.framefuse/thermal`: thermal status event stream
 */
class NativeBridge(private val context: Context, messenger: BinaryMessenger) :
    MethodChannel.MethodCallHandler {

    companion object {
        private const val CHANNEL_CAPABILITIES = "com.framefuse/capabilities"
        private const val CHANNEL_MEDIA = "com.framefuse/media"
        private const val CHANNEL_THERMAL = "com.framefuse/thermal"
    }

    private val capabilitiesChannel = MethodChannel(messenger, CHANNEL_CAPABILITIES)
    private val mediaChannel = MethodChannel(messenger, CHANNEL_MEDIA)
    private val thermalChannel = EventChannel(messenger, CHANNEL_THERMAL)

    private val detector = DeviceCapabilityDetector(context)
    private val videoExporter = VideoExporter(context)
    private val galleryExporter = GalleryExporter(context)
    private val io: ExecutorService = Executors.newFixedThreadPool(2)
    private val main = Handler(Looper.getMainLooper())

    init {
        capabilitiesChannel.setMethodCallHandler(this)
        mediaChannel.setMethodCallHandler(this)
        thermalChannel.setStreamHandler(ThermalMonitor(context))
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getDeviceCapabilities" -> background(result) { detector.getCapabilities() }

            "getSdkInt" -> result.success(Build.VERSION.SDK_INT)

            "getFreeBytes" -> background(result) { StorageInfo.freeBytes(context) }

            "openUrl" -> {
                val url = call.argument<String>("url")
                if (url == null || !url.startsWith("https://")) {
                    result.error("bad_args", "https url required", null)
                    return
                }
                try {
                    context.startActivity(
                        Intent(Intent.ACTION_VIEW, Uri.parse(url))
                            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    )
                    result.success(true)
                } catch (e: ActivityNotFoundException) {
                    result.success(false)
                }
            }

            "exportVideo" -> {
                val id = call.argument<String>("id") ?: ""
                val input = call.argument<String>("input")
                val output = call.argument<String>("output")
                val aspect = call.argument<Double>("aspect")
                if (input == null || output == null || aspect == null) {
                    result.error("INVALID_ARGS", "input, output and aspect are required", null)
                    return
                }
                val startMs = (call.argument<Number>("startMs") ?: 0).toLong()
                val endMs = (call.argument<Number>("endMs") ?: 0).toLong()
                videoExporter.export(
                    input, output, aspect, startMs, endMs,
                    onProgress = { p ->
                        mediaChannel.invokeMethod(
                            "exportProgress", mapOf("id" to id, "progress" to p)
                        )
                    },
                    onComplete = { r ->
                        r.fold(
                            onSuccess = { result.success(it) },
                            onFailure = { result.error("EXPORT_FAILED", it.message, null) },
                        )
                    },
                )
            }

            "cancelExport" -> {
                videoExporter.cancel()
                result.success(true)
            }

            "probeVideo" -> {
                val path = call.argument<String>("path")
                    ?: return result.error("INVALID_ARGS", "path required", null)
                background(result) {
                    val info = videoExporter.probe(path)
                    mapOf(
                        "width" to info.width,
                        "height" to info.height,
                        "durationMs" to info.durationMs,
                    )
                }
            }

            "cropPhoto" -> {
                val source = call.argument<String>("source")
                val portrait = call.argument<String>("portrait")
                val landscape = call.argument<String>("landscape")
                val quality = call.argument<Int>("quality") ?: 95
                if (source == null || portrait == null || landscape == null) {
                    result.error("INVALID_ARGS", "source, portrait and landscape required", null)
                    return
                }
                background(result) { PhotoCropper.crop(source, portrait, landscape, quality) }
            }

            "saveToGallery" -> {
                val path = call.argument<String>("path")
                val isVideo = call.argument<Boolean>("isVideo") ?: true
                val name = call.argument<String>("displayName")
                if (path == null || name == null) {
                    result.error("INVALID_ARGS", "path and displayName required", null)
                    return
                }
                background(result) { galleryExporter.save(path, isVideo, name) }
            }

            "extractThumbnails" -> {
                val path = call.argument<String>("path")
                val outDir = call.argument<String>("outDir")
                val count = call.argument<Int>("count") ?: 8
                val maxWidth = call.argument<Int>("maxWidth") ?: 240
                if (path == null || outDir == null) {
                    result.error("INVALID_ARGS", "path and outDir required", null)
                    return
                }
                background(result) { ThumbnailExtractor.extract(path, count, outDir, maxWidth) }
            }

            else -> result.notImplemented()
        }
    }

    /** Runs [work] off the main thread and replies on the main thread. */
    private fun background(result: MethodChannel.Result, work: () -> Any?) {
        io.execute {
            try {
                val value = work()
                main.post { result.success(value) }
            } catch (e: Exception) {
                main.post { result.error("NATIVE_ERROR", e.message ?: e.toString(), null) }
            }
        }
    }

    fun cleanup() {
        videoExporter.cancel()
        capabilitiesChannel.setMethodCallHandler(null)
        mediaChannel.setMethodCallHandler(null)
        thermalChannel.setStreamHandler(null)
        io.shutdown()
    }
}
