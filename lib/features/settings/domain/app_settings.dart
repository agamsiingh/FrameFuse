import 'package:camera/camera.dart';
import '../../../shared/models/aspect_ratio.dart';

/// App settings model.
class AppSettings {
  // Recording
  final String defaultResolution;
  final int defaultFps;
  final String videoQuality;
  final bool enableStabilization;
  final bool enableAudio;
  final bool autoSave;

  // Framing
  final bool showPortraitGuide;
  final bool showLandscapeGuide;
  final bool showGrid;
  final bool showSafeZones;
  final PreviewMode defaultPreviewMode;

  // Storage
  final String savePath;
  final bool autoCleanup;

  // Appearance
  final String themeMode; // 'light', 'dark', 'system'

  // Timer
  final int timerSeconds; // 0 = off, 3, 5, 10

  // Onboarding
  final bool onboardingComplete;
  final String? shootFrequency; // answer from the onboarding question
  final bool firstTakeHintShown;

  const AppSettings({
    this.defaultResolution = '1080p',
    this.defaultFps = 30,
    this.videoQuality = 'High',
    this.enableStabilization = true,
    this.enableAudio = true,
    this.autoSave = true,
    this.showPortraitGuide = true,
    this.showLandscapeGuide = true,
    this.showGrid = false,
    this.showSafeZones = false,
    this.defaultPreviewMode = PreviewMode.dual,
    this.savePath = '',
    this.autoCleanup = false,
    this.themeMode = 'dark',
    this.timerSeconds = 0,
    this.onboardingComplete = false,
    this.shootFrequency,
    this.firstTakeHintShown = false,
  });

  /// Short label for the resolution quick toggle ("HD", "FHD", "4K").
  String get resolutionBadge {
    switch (defaultResolution) {
      case '720p':
        return 'HD';
      case '4K':
        return '4K';
      default:
        return 'FHD';
    }
  }

  /// Approximate master-recording bytes per second, used for the
  /// "time left" estimate (H.264 bitrates CameraX typically selects).
  int get estimatedBytesPerSecond {
    final mbps = switch (defaultResolution) {
      '720p' => 10.0,
      '4K' => 48.0,
      _ => 20.0,
    };
    final fpsFactor = defaultFps >= 60 ? 1.5 : 1.0;
    // + 256 kbps audio.
    return ((mbps * fpsFactor + 0.256) * 1000000 / 8).round();
  }

  /// Map resolution string to ResolutionPreset.
  ResolutionPreset get resolutionPreset {
    switch (defaultResolution) {
      case '720p':
        return ResolutionPreset.high;
      case '1080p':
        return ResolutionPreset.veryHigh;
      case '4K':
        return ResolutionPreset.ultraHigh;
      default:
        return ResolutionPreset.veryHigh;
    }
  }

  AppSettings copyWith({
    String? defaultResolution,
    int? defaultFps,
    String? videoQuality,
    bool? enableStabilization,
    bool? enableAudio,
    bool? autoSave,
    bool? showPortraitGuide,
    bool? showLandscapeGuide,
    bool? showGrid,
    bool? showSafeZones,
    PreviewMode? defaultPreviewMode,
    String? savePath,
    bool? autoCleanup,
    String? themeMode,
    int? timerSeconds,
    bool? onboardingComplete,
    String? shootFrequency,
    bool? firstTakeHintShown,
  }) {
    return AppSettings(
      defaultResolution: defaultResolution ?? this.defaultResolution,
      defaultFps: defaultFps ?? this.defaultFps,
      videoQuality: videoQuality ?? this.videoQuality,
      enableStabilization: enableStabilization ?? this.enableStabilization,
      enableAudio: enableAudio ?? this.enableAudio,
      autoSave: autoSave ?? this.autoSave,
      showPortraitGuide: showPortraitGuide ?? this.showPortraitGuide,
      showLandscapeGuide: showLandscapeGuide ?? this.showLandscapeGuide,
      showGrid: showGrid ?? this.showGrid,
      showSafeZones: showSafeZones ?? this.showSafeZones,
      defaultPreviewMode: defaultPreviewMode ?? this.defaultPreviewMode,
      savePath: savePath ?? this.savePath,
      autoCleanup: autoCleanup ?? this.autoCleanup,
      themeMode: themeMode ?? this.themeMode,
      timerSeconds: timerSeconds ?? this.timerSeconds,
      onboardingComplete: onboardingComplete ?? this.onboardingComplete,
      shootFrequency: shootFrequency ?? this.shootFrequency,
      firstTakeHintShown: firstTakeHintShown ?? this.firstTakeHintShown,
    );
  }
}
