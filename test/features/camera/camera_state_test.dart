import 'package:flutter_test/flutter_test.dart';
import 'package:camera/camera.dart';
import 'package:frame_fuse/features/camera/domain/camera_state.dart';
import 'package:frame_fuse/features/camera/domain/camera_config.dart';

void main() {
  final testCamera = const CameraDescription(
    name: 'test_back',
    lensDirection: CameraLensDirection.back,
    sensorOrientation: 90,
  );

  group('CameraState', () {
    test('initial state is uninitialized', () {
      final state = CameraState(
        config: CameraConfig(camera: testCamera),
      );
      expect(state.status, CameraStatus.uninitialized);
      expect(state.isInitialized, isFalse);
      expect(state.isRecording, isFalse);
      expect(state.captureMode, CaptureMode.video);
    });

    test('isReady returns true for ready and previewing status', () {
      var state = CameraState(
        config: CameraConfig(camera: testCamera),
        status: CameraStatus.ready,
      );
      expect(state.isReady, isTrue);

      state = state.copyWith(status: CameraStatus.previewing);
      expect(state.isReady, isTrue);
    });

    test('isRecording returns true only when recording', () {
      var state = CameraState(
        config: CameraConfig(camera: testCamera),
        status: CameraStatus.recording,
      );
      expect(state.isRecording, isTrue);
      expect(state.isPaused, isFalse);
    });

    test('formattedDuration formats correctly', () {
      var state = CameraState(
        config: CameraConfig(camera: testCamera),
        recordingDuration: const Duration(minutes: 2, seconds: 35),
      );
      expect(state.formattedDuration, '02:35');
    });

    test('formattedDuration handles zero', () {
      var state = CameraState(
        config: CameraConfig(camera: testCamera),
        recordingDuration: Duration.zero,
      );
      expect(state.formattedDuration, '00:00');
    });

    test('copyWith preserves unmodified fields', () {
      final state = CameraState(
        config: CameraConfig(camera: testCamera),
        status: CameraStatus.ready,
        captureMode: CaptureMode.video,
      );

      final updated = state.copyWith(status: CameraStatus.recording);
      expect(updated.status, CameraStatus.recording);
      expect(updated.captureMode, CaptureMode.video);
      expect(updated.config.camera, testCamera);
    });
    test('copyWith keeps nullable messages unless explicitly cleared', () {
      final state = CameraState(
        config: CameraConfig(camera: testCamera),
        errorMessage: 'boom',
        processingMessage: 'working',
      );
      final touched = state.copyWith(isBusy: true);
      expect(touched.errorMessage, 'boom');
      expect(touched.processingMessage, 'working');

      final cleared = state.copyWith(errorMessage: null, processingMessage: null);
      expect(cleared.errorMessage, isNull);
      expect(cleared.processingMessage, isNull);
    });

    test('error and disposed states are not initialized', () {
      final base = CameraState(config: CameraConfig(camera: testCamera));
      expect(base.copyWith(status: CameraStatus.error).isInitialized, isFalse);
      expect(base.copyWith(status: CameraStatus.disposed).isInitialized, isFalse);
      expect(base.copyWith(status: CameraStatus.ready).isInitialized, isTrue);
      expect(base.copyWith(status: CameraStatus.paused).isCapturingVideo, isTrue);
    });
  });

  group('CameraConfig', () {
    test('isFrontCamera detects front camera', () {
      final frontCamera = const CameraDescription(
        name: 'front',
        lensDirection: CameraLensDirection.front,
        sensorOrientation: 270,
      );
      final config = CameraConfig(camera: frontCamera);
      expect(config.isFrontCamera, isTrue);
    });

    test('isFrontCamera detects rear camera', () {
      final config = CameraConfig(camera: testCamera);
      expect(config.isFrontCamera, isFalse);
    });

    test('resolutionLabel maps correctly', () {
      expect(
        CameraConfig(
          camera: testCamera,
          resolution: ResolutionPreset.veryHigh,
        ).resolutionLabel,
        '1080p',
      );
      expect(
        CameraConfig(
          camera: testCamera,
          resolution: ResolutionPreset.ultraHigh,
        ).resolutionLabel,
        '4K',
      );
    });
  });
}
