import 'package:camera/camera.dart';

/// Camera-specific constants: resolutions, FPS, aspect ratios.
class CameraConstants {
  CameraConstants._();

  // ── Aspect Ratios ──────────────────────────────────────────────
  static const double portraitAspectRatio = 9.0 / 16.0; // 0.5625
  static const double landscapeAspectRatio = 16.0 / 9.0; // 1.7778

  // ── Portrait Resolutions (width × height for 9:16) ─────────────
  static const PortraitResolution portrait1080 = PortraitResolution(1080, 1920);
  static const PortraitResolution portrait4K = PortraitResolution(2160, 3840);

  // ── Landscape Resolutions (width × height for 16:9) ────────────
  static const LandscapeResolution landscape1080 = LandscapeResolution(1920, 1080);
  static const LandscapeResolution landscape4K = LandscapeResolution(3840, 2160);

  // ── FPS Options ────────────────────────────────────────────────
  static const List<int> supportedFpsList = [24, 30, 60];
  static const int defaultFps = 30;

  // ── Quality presets mapped to ResolutionPreset ──────────────────
  static const Map<String, ResolutionPreset> qualityPresets = {
    '720p': ResolutionPreset.high,
    '1080p': ResolutionPreset.veryHigh,
    '4K': ResolutionPreset.ultraHigh,
  };

  static const ResolutionPreset defaultPreset = ResolutionPreset.veryHigh;

  // ── Zoom ───────────────────────────────────────────────────────
  static const double minZoom = 1.0;
  static const double maxZoomCap = 10.0;

  // ── Exposure ───────────────────────────────────────────────────
  static const double exposureStep = 0.1;
}

/// Portrait resolution descriptor.
class PortraitResolution {
  final int width;
  final int height;
  const PortraitResolution(this.width, this.height);

  @override
  String toString() => '$width×$height';
}

/// Landscape resolution descriptor.
class LandscapeResolution {
  final int width;
  final int height;
  const LandscapeResolution(this.width, this.height);

  @override
  String toString() => '$width×$height';
}
