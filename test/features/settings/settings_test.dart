import 'package:flutter_test/flutter_test.dart';
import 'package:frame_fuse/features/settings/domain/app_settings.dart';
import 'package:frame_fuse/shared/models/aspect_ratio.dart';
import 'package:camera/camera.dart';

void main() {
  group('AppSettings', () {
    test('default settings have correct values', () {
      const settings = AppSettings();
      expect(settings.defaultResolution, '1080p');
      expect(settings.defaultFps, 30);
      expect(settings.enableAudio, isTrue);
      expect(settings.enableStabilization, isTrue);
      expect(settings.showPortraitGuide, isTrue);
      expect(settings.showLandscapeGuide, isTrue);
      expect(settings.showGrid, isFalse);
      expect(settings.themeMode, 'dark');
      expect(settings.timerSeconds, 0);
      expect(settings.defaultPreviewMode, PreviewMode.dual);
    });

    test('resolutionPreset maps correctly', () {
      const settings1080 = AppSettings(defaultResolution: '1080p');
      expect(settings1080.resolutionPreset, ResolutionPreset.veryHigh);

      const settings4K = AppSettings(defaultResolution: '4K');
      expect(settings4K.resolutionPreset, ResolutionPreset.ultraHigh);

      const settings720 = AppSettings(defaultResolution: '720p');
      expect(settings720.resolutionPreset, ResolutionPreset.high);
    });

    test('copyWith preserves unchanged fields', () {
      const settings = AppSettings(
        defaultResolution: '4K',
        enableAudio: false,
        themeMode: 'light',
      );

      final updated = settings.copyWith(showGrid: true);
      expect(updated.showGrid, isTrue);
      expect(updated.defaultResolution, '4K');
      expect(updated.enableAudio, isFalse);
      expect(updated.themeMode, 'light');
    });
  });

  group('OutputAspectRatio', () {
    test('portrait has correct values', () {
      expect(OutputAspectRatio.portrait.isPortrait, isTrue);
      expect(OutputAspectRatio.portrait.isLandscape, isFalse);
      expect(OutputAspectRatio.portrait.widthRatio, 9);
      expect(OutputAspectRatio.portrait.heightRatio, 16);
    });

    test('landscape has correct values', () {
      expect(OutputAspectRatio.landscape.isPortrait, isFalse);
      expect(OutputAspectRatio.landscape.isLandscape, isTrue);
      expect(OutputAspectRatio.landscape.widthRatio, 16);
      expect(OutputAspectRatio.landscape.heightRatio, 9);
    });
  });

  group('PreviewMode', () {
    test('has three modes', () {
      expect(PreviewMode.values.length, 3);
      expect(PreviewMode.dual.label, 'Dual Preview');
      expect(PreviewMode.portrait.label, 'Portrait Only');
      expect(PreviewMode.landscape.label, 'Landscape Only');
    });
  });
}
