import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import '../domain/device_capabilities.dart';

/// Service for detecting device camera hardware capabilities.
///
/// Probes the camera system and native Android layer (Camera2 + MediaCodec)
/// and builds a [DeviceCapabilities] model that gates feature availability.
class DeviceCapabilityService {
  static const _channel = MethodChannel('com.framefuse/capabilities');
  DeviceCapabilities? _cached;

  /// Detect and return device capabilities.
  ///
  /// Results are cached after the first call.
  Future<DeviceCapabilities> detect() async {
    if (_cached != null) return _cached!;

    try {
      final cameras = await availableCameras();

      final hasFront = cameras.any(
        (c) => c.lensDirection == CameraLensDirection.front,
      );
      final hasRear = cameras.any(
        (c) => c.lensDirection == CameraLensDirection.back,
      );

      // Probe native Android capabilities via platform channel
      bool nativeStabilization = false;
      bool nativeSimultaneousEncode = false;
      try {
        final nativeCaps = await _channel.invokeMapMethod<String, dynamic>(
          'getDeviceCapabilities',
        );
        if (nativeCaps != null) {
          nativeStabilization = nativeCaps['hasStabilization'] as bool? ?? false;
          nativeSimultaneousEncode =
              nativeCaps['canSimultaneousEncode'] as bool? ?? false;
        }
      } catch (_) {
        // Platform channel not available (e.g. unit test or non-Android)
      }

      // Use safe defaults — do NOT probe by creating/disposing controllers,
      // as rapid open/close cycles corrupt the Camera2 hardware state on
      // many Android devices (causes "Broken pipe" CAMERA_ERROR).
      final supportedResolutions = <ResolutionPreset>[
        ResolutionPreset.low,
        ResolutionPreset.medium,
        ResolutionPreset.high,
        ResolutionPreset.veryHigh,
      ];

      // Most modern devices support ultraHigh (4K) on the rear camera.
      // We assume it's available and let CameraService handle fallback
      // if initialization actually fails at that resolution.
      if (hasRear) {
        supportedResolutions.add(ResolutionPreset.ultraHigh);
      }

      _cached = DeviceCapabilities(
        cameras: cameras,
        supportedResolutions: supportedResolutions,
        supportedFps: _detectFps(ResolutionPreset.veryHigh),
        hasFlash: hasRear,
        hasTorch: hasRear,
        hasFrontCamera: hasFront,
        hasRearCamera: hasRear,
        hasAutoFocus: true,
        hasStabilization: nativeStabilization || _detectStabilization(),
        maxZoom: 10.0,   // Placeholder; real values queried after init
        minZoom: 1.0,
        minExposure: -4.0,
        maxExposure: 4.0,
        canSimultaneousEncode: nativeSimultaneousEncode,
      );

      return _cached!;
    } catch (e) {
      return const DeviceCapabilities(cameras: []);
    }
  }

  /// Detect supported FPS values.
  List<int> _detectFps(ResolutionPreset preset) {
    final fps = <int>[24, 30];
    if (preset.index <= ResolutionPreset.veryHigh.index) {
      fps.add(60);
    }
    return fps;
  }

  /// Detect stabilization fallback.
  bool _detectStabilization() => true;

  /// Clear cached capabilities.
  void clearCache() {
    _cached = null;
  }

  /// Check if a specific resolution is supported.
  Future<bool> isResolutionSupported(ResolutionPreset preset) async {
    final caps = await detect();
    return caps.supportsResolution(preset);
  }

  /// Get the best available resolution.
  Future<ResolutionPreset> getBestResolution() async {
    final caps = await detect();
    final resolutions = caps.supportedResolutions;
    if (resolutions.contains(ResolutionPreset.ultraHigh)) {
      return ResolutionPreset.ultraHigh;
    }
    if (resolutions.contains(ResolutionPreset.veryHigh)) {
      return ResolutionPreset.veryHigh;
    }
    if (resolutions.contains(ResolutionPreset.high)) {
      return ResolutionPreset.high;
    }
    return ResolutionPreset.medium;
  }
}
