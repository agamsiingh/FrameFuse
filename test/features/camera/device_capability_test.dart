import 'package:flutter_test/flutter_test.dart';
import 'package:camera/camera.dart';
import 'package:frame_fuse/features/camera/domain/device_capabilities.dart';

void main() {
  group('DeviceCapabilities', () {
    final backCamera = const CameraDescription(
      name: 'back',
      lensDirection: CameraLensDirection.back,
      sensorOrientation: 90,
    );
    final frontCamera = const CameraDescription(
      name: 'front',
      lensDirection: CameraLensDirection.front,
      sensorOrientation: 270,
    );

    test('hasCamera returns true when cameras exist', () {
      final caps = DeviceCapabilities(cameras: [backCamera]);
      expect(caps.hasCamera, isTrue);
    });

    test('hasCamera returns false when no cameras', () {
      const caps = DeviceCapabilities(cameras: []);
      expect(caps.hasCamera, isFalse);
    });

    test('defaultCamera prefers rear camera', () {
      final caps = DeviceCapabilities(cameras: [frontCamera, backCamera]);
      expect(caps.defaultCamera, backCamera);
    });

    test('defaultCamera falls back to front camera', () {
      final caps = DeviceCapabilities(cameras: [frontCamera]);
      expect(caps.defaultCamera, frontCamera);
    });

    test('supports4K detects ultraHigh preset', () {
      final caps = DeviceCapabilities(
        cameras: [backCamera],
        supportedResolutions: [
          ResolutionPreset.high,
          ResolutionPreset.veryHigh,
          ResolutionPreset.ultraHigh,
        ],
      );
      expect(caps.supports4K, isTrue);
    });

    test('supports4K returns false without ultraHigh', () {
      final caps = DeviceCapabilities(
        cameras: [backCamera],
        supportedResolutions: [
          ResolutionPreset.high,
          ResolutionPreset.veryHigh,
        ],
      );
      expect(caps.supports4K, isFalse);
    });

    test('supports60Fps detects 60fps', () {
      final caps = DeviceCapabilities(
        cameras: [backCamera],
        supportedFps: [24, 30, 60],
      );
      expect(caps.supports60Fps, isTrue);
    });

    test('frontCamera returns correct camera', () {
      final caps = DeviceCapabilities(cameras: [backCamera, frontCamera]);
      expect(caps.frontCamera, frontCamera);
    });

    test('rearCamera returns correct camera', () {
      final caps = DeviceCapabilities(cameras: [backCamera, frontCamera]);
      expect(caps.rearCamera, backCamera);
    });

    test('summary includes supported features', () {
      final caps = DeviceCapabilities(
        cameras: [backCamera],
        supportedResolutions: [ResolutionPreset.ultraHigh],
        supportedFps: [30, 60],
        hasStabilization: true,
      );
      expect(caps.summary, contains('4K'));
      expect(caps.summary, contains('60fps'));
      expect(caps.summary, contains('OIS'));
    });

    test('copyWith preserves unchanged fields', () {
      final caps = DeviceCapabilities(
        cameras: [backCamera],
        hasFlash: true,
        maxZoom: 5.0,
      );
      final updated = caps.copyWith(maxZoom: 8.0);
      expect(updated.maxZoom, 8.0);
      expect(updated.hasFlash, isTrue);
      expect(updated.cameras, [backCamera]);
    });
  });
}
