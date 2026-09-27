package com.framefuse.app

import android.content.Context
import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CameraManager
import android.hardware.camera2.CameraMetadata
import android.media.MediaCodecInfo
import android.media.MediaCodecList
import android.media.MediaFormat
import android.os.Build
import android.os.PowerManager
import android.util.Size
import java.util.HashMap

/**
 * Detects device camera, encoder, and thermal hardware capabilities using Camera2 and MediaCodec.
 */
class DeviceCapabilityDetector(private val context: Context) {

    private val cameraManager: CameraManager by lazy {
        context.getSystemService(Context.CAMERA_SERVICE) as CameraManager
    }

    private val powerManager: PowerManager by lazy {
        context.getSystemService(Context.POWER_SERVICE) as PowerManager
    }

    /**
     * Gathers a comprehensive map of device capabilities to send to Flutter.
     */
    fun getCapabilities(): Map<String, Any> {
        val result = HashMap<String, Any>()

        try {
            val cameraIds = cameraManager.cameraIdList
            val camerasList = mutableListOf<Map<String, Any>>()

            var hasFront = false
            var hasRear = false
            var hasFlash = false
            var hasStabilization = false

            for (id in cameraIds) {
                val chars = cameraManager.getCameraCharacteristics(id)
                val facing = chars.get(CameraCharacteristics.LENS_FACING)

                val isBack = facing == CameraCharacteristics.LENS_FACING_BACK
                val isFront = facing == CameraCharacteristics.LENS_FACING_FRONT

                if (isBack) hasRear = true
                if (isFront) hasFront = true

                val flashAvailable = chars.get(CameraCharacteristics.FLASH_INFO_AVAILABLE) ?: false
                if (isBack && flashAvailable) hasFlash = true

                // Check optical/video stabilization
                val oisModes = chars.get(CameraCharacteristics.LENS_INFO_AVAILABLE_OPTICAL_STABILIZATION)
                val videoStabModes = chars.get(CameraCharacteristics.CONTROL_AVAILABLE_VIDEO_STABILIZATION_MODES)
                if ((oisModes != null && oisModes.isNotEmpty()) || 
                    (videoStabModes != null && videoStabModes.contains(CameraMetadata.CONTROL_VIDEO_STABILIZATION_MODE_ON))) {
                    hasStabilization = true
                }

                // Hardware level
                val hwLevel = when (chars.get(CameraCharacteristics.INFO_SUPPORTED_HARDWARE_LEVEL)) {
                    CameraCharacteristics.INFO_SUPPORTED_HARDWARE_LEVEL_LEGACY -> "LEGACY"
                    CameraCharacteristics.INFO_SUPPORTED_HARDWARE_LEVEL_LIMITED -> "LIMITED"
                    CameraCharacteristics.INFO_SUPPORTED_HARDWARE_LEVEL_FULL -> "FULL"
                    CameraCharacteristics.INFO_SUPPORTED_HARDWARE_LEVEL_3 -> "LEVEL_3"
                    else -> "EXTERNAL"
                }

                val camInfo = HashMap<String, Any>()
                camInfo["id"] = id
                camInfo["facing"] = if (isFront) "front" else if (isBack) "back" else "external"
                camInfo["hardwareLevel"] = hwLevel
                camInfo["flashAvailable"] = flashAvailable
                camInfo["stabilizationAvailable"] = hasStabilization

                camerasList.add(camInfo)
            }

            result["cameras"] = camerasList
            result["hasFrontCamera"] = hasFront
            result["hasRearCamera"] = hasRear
            result["hasFlash"] = hasFlash
            result["hasStabilization"] = hasStabilization

            // Encoder capabilities
            val encoderInfo = detectEncoderCapabilities()
            result["encoder"] = encoderInfo

            // Thermal state
            result["thermalStatus"] = getThermalStatusString()

        } catch (e: Exception) {
            result["error"] = e.message ?: "Unknown error detecting capabilities"
        }

        return result
    }

    private fun detectEncoderCapabilities(): Map<String, Any> {
        val info = HashMap<String, Any>()
        try {
            val codecList = MediaCodecList(MediaCodecList.REGULAR_CODECS)
            var supportsHevc = false
            var supportsAvc = false
            var maxInstances = 1
            var maxBitrate = 20_000_000 // default 20Mbps

            for (codecInfo in codecList.codecInfos) {
                if (!codecInfo.isEncoder) continue

                val types = codecInfo.supportedTypes
                for (type in types) {
                    if (type.equals(MediaFormat.MIMETYPE_VIDEO_HEVC, ignoreCase = true)) {
                        supportsHevc = true
                        val caps = codecInfo.getCapabilitiesForType(type)
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            maxInstances = maxOf(maxInstances, caps.maxSupportedInstances)
                        }
                    } else if (type.equals(MediaFormat.MIMETYPE_VIDEO_AVC, ignoreCase = true)) {
                        supportsAvc = true
                        val caps = codecInfo.getCapabilitiesForType(type)
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            maxInstances = maxOf(maxInstances, caps.maxSupportedInstances)
                        }
                    }
                }
            }

            info["supportsHevc"] = supportsHevc
            info["supportsAvc"] = supportsAvc
            info["maxConcurrentInstances"] = maxInstances
            info["maxBitrate"] = maxBitrate
        } catch (e: Exception) {
            info["error"] = e.message ?: "Encoder probe failed"
            info["maxConcurrentInstances"] = 1
        }
        return info
    }

    private fun getThermalStatusString(): String {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            when (powerManager.currentThermalStatus) {
                PowerManager.THERMAL_STATUS_NONE -> "NORMAL"
                PowerManager.THERMAL_STATUS_LIGHT -> "LIGHT"
                PowerManager.THERMAL_STATUS_MODERATE -> "MODERATE"
                PowerManager.THERMAL_STATUS_SEVERE -> "SEVERE"
                PowerManager.THERMAL_STATUS_CRITICAL -> "CRITICAL"
                PowerManager.THERMAL_STATUS_EMERGENCY -> "EMERGENCY"
                PowerManager.THERMAL_STATUS_SHUTDOWN -> "SHUTDOWN"
                else -> "UNKNOWN"
            }
        } else {
            "NORMAL"
        }
    }
}
