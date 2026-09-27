import 'package:camera/camera.dart';

/// Represents the device's camera hardware capabilities.
class DeviceCapabilities {
  final List<CameraDescription> cameras;
  final List<ResolutionPreset> supportedResolutions;
  final List<int> supportedFps;
  final bool hasFlash;
  final bool hasTorch;
  final bool hasFrontCamera;
  final bool hasRearCamera;
  final bool hasAutoFocus;
  final bool hasStabilization;
  final double maxZoom;
  final double minZoom;
  final double minExposure;
  final double maxExposure;
  final bool canSimultaneousEncode;
  final String? deviceModel;

  const DeviceCapabilities({
    required this.cameras,
    this.supportedResolutions = const [
      ResolutionPreset.low,
      ResolutionPreset.medium,
      ResolutionPreset.high,
      ResolutionPreset.veryHigh,
    ],
    this.supportedFps = const [30],
    this.hasFlash = false,
    this.hasTorch = false,
    this.hasFrontCamera = false,
    this.hasRearCamera = false,
    this.hasAutoFocus = true,
    this.hasStabilization = false,
    this.maxZoom = 1.0,
    this.minZoom = 1.0,
    this.minExposure = 0.0,
    this.maxExposure = 0.0,
    this.canSimultaneousEncode = false,
    this.deviceModel,
  });

  /// Check if a specific resolution is supported.
  bool supportsResolution(ResolutionPreset preset) =>
      supportedResolutions.contains(preset);

  /// Check if 4K recording is supported.
  bool get supports4K => supportsResolution(ResolutionPreset.ultraHigh);

  /// Check if 60fps is supported.
  bool get supports60Fps => supportedFps.contains(60);

  /// Whether the device has any camera at all.
  bool get hasCamera => cameras.isNotEmpty;

  /// Get the default camera (rear if available, else front).
  CameraDescription? get defaultCamera {
    final rear = cameras.where(
      (c) => c.lensDirection == CameraLensDirection.back,
    );
    if (rear.isNotEmpty) return rear.first;
    return cameras.isNotEmpty ? cameras.first : null;
  }

  /// Get front camera.
  CameraDescription? get frontCamera {
    final front = cameras.where(
      (c) => c.lensDirection == CameraLensDirection.front,
    );
    return front.isNotEmpty ? front.first : null;
  }

  /// Get rear camera.
  CameraDescription? get rearCamera {
    final rear = cameras.where(
      (c) => c.lensDirection == CameraLensDirection.back,
    );
    return rear.isNotEmpty ? rear.first : null;
  }

  /// Human-readable capability summary.
  String get summary {
    final parts = <String>[];
    if (supports4K) parts.add('4K');
    if (supports60Fps) parts.add('60fps');
    if (hasStabilization) parts.add('OIS');
    if (canSimultaneousEncode) parts.add('Dual Encode');
    return parts.isEmpty ? 'Basic' : parts.join(' · ');
  }

  DeviceCapabilities copyWith({
    List<CameraDescription>? cameras,
    List<ResolutionPreset>? supportedResolutions,
    List<int>? supportedFps,
    bool? hasFlash,
    bool? hasTorch,
    bool? hasFrontCamera,
    bool? hasRearCamera,
    bool? hasAutoFocus,
    bool? hasStabilization,
    double? maxZoom,
    double? minZoom,
    double? minExposure,
    double? maxExposure,
    bool? canSimultaneousEncode,
    String? deviceModel,
  }) {
    return DeviceCapabilities(
      cameras: cameras ?? this.cameras,
      supportedResolutions: supportedResolutions ?? this.supportedResolutions,
      supportedFps: supportedFps ?? this.supportedFps,
      hasFlash: hasFlash ?? this.hasFlash,
      hasTorch: hasTorch ?? this.hasTorch,
      hasFrontCamera: hasFrontCamera ?? this.hasFrontCamera,
      hasRearCamera: hasRearCamera ?? this.hasRearCamera,
      hasAutoFocus: hasAutoFocus ?? this.hasAutoFocus,
      hasStabilization: hasStabilization ?? this.hasStabilization,
      maxZoom: maxZoom ?? this.maxZoom,
      minZoom: minZoom ?? this.minZoom,
      minExposure: minExposure ?? this.minExposure,
      maxExposure: maxExposure ?? this.maxExposure,
      canSimultaneousEncode: canSimultaneousEncode ?? this.canSimultaneousEncode,
      deviceModel: deviceModel ?? this.deviceModel,
    );
  }
}
