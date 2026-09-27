import 'dart:async';
import 'dart:ui';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import '../domain/camera_config.dart';
import '../domain/device_capabilities.dart';
import 'device_capability_service.dart';

/// Core camera service wrapping the Flutter camera controller.
///
/// Handles initialization, lifecycle, and provides a clean interface
/// for the presentation layer. Initialization and disposal are serialized
/// so overlapping lifecycle events can never open two controllers at once.
class CameraService {
  CameraController? _controller;
  final DeviceCapabilityService _capabilityService;

  /// Tail of the serialized init/dispose chain.
  Future<void> _lifecycleChain = Future.value();

  CameraService({DeviceCapabilityService? capabilityService})
      : _capabilityService = capabilityService ?? DeviceCapabilityService();

  /// Current camera controller (nullable before init).
  CameraController? get controller => _controller;

  /// Whether the camera is currently initialized.
  bool get isInitialized => _controller?.value.isInitialized ?? false;

  /// Whether currently recording.
  bool get isRecording => _controller?.value.isRecordingVideo ?? false;

  /// Resolution fallback order for graceful degradation.
  static const _fallbackResolutions = [
    ResolutionPreset.ultraHigh,
    ResolutionPreset.veryHigh,
    ResolutionPreset.high,
    ResolutionPreset.medium,
    ResolutionPreset.low,
  ];

  Future<T> _serialized<T>(Future<T> Function() action) {
    final completer = Completer<T>();
    _lifecycleChain = _lifecycleChain.then((_) async {
      try {
        completer.complete(await action());
      } catch (e, st) {
        completer.completeError(e, st);
      }
    });
    return completer.future;
  }

  /// Initialize the camera with the given configuration.
  ///
  /// If the requested resolution fails, automatically falls back to
  /// lower resolutions (and then drops the FPS request) to avoid crashes on
  /// devices that don't support high-res stream combinations.
  Future<void> initialize(CameraConfig config) =>
      _serialized(() => _initialize(config));

  Future<void> _initialize(CameraConfig config) async {
    await _dispose();

    final resolutionsToTry = <ResolutionPreset>[config.resolution];
    for (final fallback in _fallbackResolutions) {
      if (fallback.index < config.resolution.index &&
          !resolutionsToTry.contains(fallback)) {
        resolutionsToTry.add(fallback);
      }
    }

    Object? lastError;
    for (final resolution in resolutionsToTry) {
      // Try with the requested FPS first, then let the camera choose.
      for (final fps in <int?>{config.fps, null}) {
        final controller = CameraController(
          config.camera,
          resolution,
          enableAudio: config.enableAudio,
          fps: fps,
          imageFormatGroup: ImageFormatGroup.jpeg,
        );
        try {
          await controller.initialize();
          _controller = controller;

          if (resolution != config.resolution || fps != config.fps) {
            debugPrint(
              'CameraService: fell back to $resolution @ ${fps ?? 'auto'}fps',
            );
          }

          try {
            await controller.setFlashMode(
              config.flashMode == FlashMode.torch ? FlashMode.torch : FlashMode.off,
            );
            if (config.zoom != 1.0) {
              await controller.setZoomLevel(config.zoom);
            }
            if (config.exposure != 0.0) {
              await controller.setExposureOffset(config.exposure);
            }
          } catch (e) {
            debugPrint('CameraService: failed to apply initial settings: $e');
          }
          return;
        } catch (e) {
          debugPrint('CameraService: failed at $resolution/$fps: $e');
          lastError = e;
          try {
            await controller.dispose();
          } catch (_) {}
          // A permission error will not be fixed by a lower resolution.
          if (e is CameraException &&
              e.code.toLowerCase().contains('permission')) {
            rethrow;
          }
        }
      }
    }

    throw lastError ?? CameraException('init', 'All resolutions failed');
  }

  /// Switch to a different camera.
  Future<void> switchCamera(CameraConfig config) => initialize(config);

  /// Set flash mode.
  Future<void> setFlashMode(FlashMode mode) async {
    if (isInitialized) await _controller!.setFlashMode(mode);
  }

  /// Set zoom level.
  Future<void> setZoomLevel(double zoom) async {
    if (isInitialized) await _controller!.setZoomLevel(zoom);
  }

  /// Set exposure offset.
  Future<void> setExposureOffset(double offset) async {
    if (isInitialized) await _controller!.setExposureOffset(offset);
  }

  /// Set focus + exposure point.
  Future<void> setFocusPoint(Offset? point) async {
    if (!isInitialized) return;
    try {
      if (point != null) {
        await _controller!.setFocusPoint(point);
        await _controller!.setExposurePoint(point);
      }
      await _controller!.setFocusMode(FocusMode.auto);
    } catch (e) {
      debugPrint('CameraService: focus not supported: $e');
    }
  }

  /// Take a photo and return the file.
  Future<XFile> takePicture() async {
    if (!isInitialized) throw StateError('Camera not initialized');
    return _controller!.takePicture();
  }

  /// Start video recording.
  Future<void> startVideoRecording() async {
    if (!isInitialized) throw StateError('Camera not initialized');
    await _controller!.startVideoRecording();
  }

  /// Pause video recording.
  Future<void> pauseVideoRecording() async {
    if (_controller?.value.isRecordingVideo ?? false) {
      await _controller!.pauseVideoRecording();
    }
  }

  /// Resume video recording.
  Future<void> resumeVideoRecording() async {
    if (_controller?.value.isRecordingPaused ?? false) {
      await _controller!.resumeVideoRecording();
    }
  }

  /// Stop recording and return the video file.
  Future<XFile> stopVideoRecording() async {
    if (!(_controller?.value.isRecordingVideo ?? false)) {
      throw StateError('Not recording');
    }
    return _controller!.stopVideoRecording();
  }

  /// Get device capabilities.
  Future<DeviceCapabilities> getCapabilities() => _capabilityService.detect();

  /// Zoom range of the active controller.
  Future<(double min, double max)> getZoomRange() async {
    if (!isInitialized) return (1.0, 1.0);
    try {
      return (
        await _controller!.getMinZoomLevel(),
        await _controller!.getMaxZoomLevel(),
      );
    } catch (_) {
      return (1.0, 1.0);
    }
  }

  /// Exposure offset range of the active controller.
  Future<(double min, double max)> getExposureRange() async {
    if (!isInitialized) return (0.0, 0.0);
    try {
      return (
        await _controller!.getMinExposureOffset(),
        await _controller!.getMaxExposureOffset(),
      );
    } catch (_) {
      return (0.0, 0.0);
    }
  }

  /// Release the camera (e.g. when the app goes to the background).
  Future<void> dispose() => _serialized(_dispose);

  Future<void> _dispose() async {
    final controller = _controller;
    _controller = null;
    if (controller == null) return;
    try {
      if (controller.value.isRecordingVideo) {
        await controller.stopVideoRecording();
      }
    } catch (_) {}
    try {
      await controller.dispose();
    } catch (e) {
      debugPrint('CameraService: dispose failed: $e');
    }
  }
}
