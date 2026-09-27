import 'package:camera/camera.dart';
import '../../../shared/models/aspect_ratio.dart';

/// Camera configuration for a recording session.
class CameraConfig {
  final CameraDescription camera;
  final ResolutionPreset resolution;
  final int fps;
  final bool enableAudio;
  final FlashMode flashMode;
  final bool enableStabilization;
  final bool showGrid;
  final PreviewMode previewMode;
  final double zoom;
  final double exposure;

  const CameraConfig({
    required this.camera,
    this.resolution = ResolutionPreset.veryHigh,
    this.fps = 30,
    this.enableAudio = true,
    this.flashMode = FlashMode.off,
    this.enableStabilization = true,
    this.showGrid = false,
    this.previewMode = PreviewMode.dual,
    this.zoom = 1.0,
    this.exposure = 0.0,
  });

  CameraConfig copyWith({
    CameraDescription? camera,
    ResolutionPreset? resolution,
    int? fps,
    bool? enableAudio,
    FlashMode? flashMode,
    bool? enableStabilization,
    bool? showGrid,
    PreviewMode? previewMode,
    double? zoom,
    double? exposure,
  }) {
    return CameraConfig(
      camera: camera ?? this.camera,
      resolution: resolution ?? this.resolution,
      fps: fps ?? this.fps,
      enableAudio: enableAudio ?? this.enableAudio,
      flashMode: flashMode ?? this.flashMode,
      enableStabilization: enableStabilization ?? this.enableStabilization,
      showGrid: showGrid ?? this.showGrid,
      previewMode: previewMode ?? this.previewMode,
      zoom: zoom ?? this.zoom,
      exposure: exposure ?? this.exposure,
    );
  }

  /// Human-readable resolution label.
  String get resolutionLabel {
    switch (resolution) {
      case ResolutionPreset.low:
        return '360p';
      case ResolutionPreset.medium:
        return '480p';
      case ResolutionPreset.high:
        return '720p';
      case ResolutionPreset.veryHigh:
        return '1080p';
      case ResolutionPreset.ultraHigh:
        return '4K';
      case ResolutionPreset.max:
        return 'Max';
    }
  }

  /// Whether this is the front camera.
  bool get isFrontCamera => camera.lensDirection == CameraLensDirection.front;
}
