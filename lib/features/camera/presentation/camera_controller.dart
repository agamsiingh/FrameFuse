import 'dart:async';
import 'dart:ui';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../camera/data/camera_service.dart';
import '../../camera/data/device_capability_service.dart';
import '../../camera/domain/camera_config.dart';
import '../../camera/domain/camera_state.dart';
import '../../projects/domain/project.dart';
import '../../projects/presentation/library_controller.dart';
import '../../recording/data/recording_service.dart';
import '../../settings/data/settings_repository.dart';
import '../../settings/domain/app_settings.dart';
import '../../../shared/models/aspect_ratio.dart';

// ── Service Providers ────────────────────────────────────────────

final cameraServiceProvider = Provider<CameraService>((ref) {
  final service = CameraService();
  ref.onDispose(() => service.dispose());
  return service;
});

final capabilityServiceProvider = Provider<DeviceCapabilityService>((ref) {
  return DeviceCapabilityService();
});

final recordingServiceProvider = Provider<RecordingService>((ref) {
  final cameraService = ref.watch(cameraServiceProvider);
  final service = RecordingService(cameraService: cameraService);
  ref.onDispose(() => service.dispose());
  return service;
});

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return SettingsRepository();
});

// ── Settings Provider ────────────────────────────────────────────

/// Settings loaded before `runApp` (overridden in `main`), so the first frame
/// already sees persisted values and nothing has to re-initialize later.
final initialSettingsProvider = Provider<AppSettings>((ref) {
  return const AppSettings();
});

final settingsProvider =
    StateNotifierProvider<SettingsNotifier, AppSettings>((ref) {
  return SettingsNotifier(
    ref.watch(settingsRepositoryProvider),
    ref.watch(initialSettingsProvider),
  );
});

class SettingsNotifier extends StateNotifier<AppSettings> {
  final SettingsRepository _repo;

  SettingsNotifier(this._repo, AppSettings initial) : super(initial);

  Future<void> updateSettings(AppSettings Function(AppSettings) updater) async {
    state = updater(state);
    await _repo.save(state);
  }

  Future<void> setTheme(String mode) =>
      updateSettings((s) => s.copyWith(themeMode: mode));

  Future<void> setResolution(String resolution) =>
      updateSettings((s) => s.copyWith(defaultResolution: resolution));

  Future<void> setFps(int fps) =>
      updateSettings((s) => s.copyWith(defaultFps: fps));

  Future<void> toggleGrid() =>
      updateSettings((s) => s.copyWith(showGrid: !s.showGrid));

  Future<void> toggleAudio() =>
      updateSettings((s) => s.copyWith(enableAudio: !s.enableAudio));

  Future<void> setTimer(int seconds) =>
      updateSettings((s) => s.copyWith(timerSeconds: seconds));

  Future<void> setPreviewMode(PreviewMode mode) =>
      updateSettings((s) => s.copyWith(defaultPreviewMode: mode));
}

// ── Camera Provider ──────────────────────────────────────────────

final cameraProvider =
    StateNotifierProvider<CameraNotifier, CameraState>((ref) {
  // Settings are *read*, not watched: rebuilding the notifier would orphan
  // the open camera and leave the UI stuck on "initializing".
  final notifier = CameraNotifier(
    cameraService: ref.watch(cameraServiceProvider),
    capabilityService: ref.watch(capabilityServiceProvider),
    recordingService: ref.watch(recordingServiceProvider),
    library: ref.watch(libraryProvider.notifier),
    settings: ref.read(settingsProvider),
  );

  ref.listen<AppSettings>(settingsProvider, (previous, next) {
    notifier.applySettings(next);
  });

  return notifier;
});

class CameraNotifier extends StateNotifier<CameraState> {
  final CameraService _cameraService;
  final DeviceCapabilityService _capabilityService;
  final RecordingService _recordingService;
  final LibraryNotifier _library;
  AppSettings _settings;

  Timer? _recordingTimer;
  final Stopwatch _recordingStopwatch = Stopwatch();

  CameraNotifier({
    required CameraService cameraService,
    required DeviceCapabilityService capabilityService,
    required RecordingService recordingService,
    required LibraryNotifier library,
    required AppSettings settings,
  })  : _cameraService = cameraService,
        _capabilityService = capabilityService,
        _recordingService = recordingService,
        _library = library,
        _settings = settings,
        super(CameraState(
          config: CameraConfig(
            camera: const CameraDescription(
              name: 'placeholder',
              lensDirection: CameraLensDirection.back,
              sensorOrientation: 90,
            ),
            resolution: settings.resolutionPreset,
            fps: settings.defaultFps,
            enableAudio: settings.enableAudio,
            showGrid: settings.showGrid,
            previewMode: settings.defaultPreviewMode,
          ),
        ));

  /// Initialize the camera system.
  Future<void> initialize() async {
    if (state.status == CameraStatus.initializing) return;
    state = state.copyWith(
      status: CameraStatus.initializing,
      errorMessage: null,
    );

    try {
      final capabilities = await _capabilityService.detect();

      if (!capabilities.hasCamera) {
        state = state.copyWith(
          status: CameraStatus.error,
          errorMessage: 'No camera found on this device.',
        );
        return;
      }

      // Keep the lens the user had selected (e.g. after returning from the
      // background), otherwise use the default rear camera.
      final current = state.config.camera;
      final camera = capabilities.cameras.firstWhere(
        (c) => c.name == current.name,
        orElse: () => capabilities.defaultCamera!,
      );

      final config = state.config.copyWith(
        camera: camera,
        resolution: _settings.resolutionPreset,
        fps: _settings.defaultFps,
        enableAudio: _settings.enableAudio,
        showGrid: _settings.showGrid,
        zoom: 1.0,
      );

      state = state.copyWith(config: config, capabilities: capabilities);

      await _cameraService.initialize(config);
      await _refreshRanges();

      if (!mounted) return;
      state = state.copyWith(status: CameraStatus.ready, errorMessage: null);
    } catch (e) {
      debugPrint('CameraNotifier: init failed: $e');
      if (!mounted) return;
      state = state.copyWith(
        status: CameraStatus.error,
        errorMessage: _describeError(e),
      );
    }
  }

  /// Retry after an error.
  Future<void> retry() => initialize();

  /// Dismiss a non-fatal error message.
  void clearError() {
    if (state.hasError) return; // fatal errors stay until retried
    state = state.copyWith(errorMessage: null);
  }

  Future<void> _refreshRanges() async {
    final caps = state.capabilities;
    if (caps == null) return;
    final (minZoom, maxZoom) = await _cameraService.getZoomRange();
    final (minExp, maxExp) = await _cameraService.getExposureRange();
    state = state.copyWith(
      capabilities: caps.copyWith(
        minZoom: minZoom,
        maxZoom: maxZoom,
        minExposure: minExp,
        maxExposure: maxExp,
      ),
    );
  }

  /// React to persisted settings changes. Settings that affect the capture
  /// session require re-opening the camera (never while recording).
  Future<void> applySettings(AppSettings next) async {
    final prev = _settings;
    _settings = next;

    state = state.copyWith(
      config: state.config.copyWith(showGrid: next.showGrid),
    );

    final needsReinit = prev.resolutionPreset != next.resolutionPreset ||
        prev.defaultFps != next.defaultFps ||
        prev.enableAudio != next.enableAudio;
    if (needsReinit && state.isReady) {
      await initialize();
    }
  }

  /// Switch between front and rear cameras.
  Future<void> switchCamera() async {
    final caps = state.capabilities;
    if (caps == null || !state.isReady || state.isBusy) return;

    final nextCamera = state.config.isFrontCamera
        ? caps.rearCamera
        : caps.frontCamera;
    if (nextCamera == null) return;

    state = state.copyWith(status: CameraStatus.initializing);

    try {
      final newConfig = state.config.copyWith(
        camera: nextCamera,
        zoom: 1.0,
        flashMode: nextCamera.lensDirection == CameraLensDirection.front
            ? FlashMode.off
            : state.config.flashMode,
      );
      state = state.copyWith(config: newConfig);
      await _cameraService.switchCamera(newConfig);
      await _refreshRanges();
      state = state.copyWith(status: CameraStatus.ready, errorMessage: null);
    } catch (e) {
      state = state.copyWith(
        status: CameraStatus.error,
        errorMessage: 'Failed to switch camera.',
      );
    }
  }

  /// Toggle the torch (the only flash mode meaningful for video).
  Future<void> toggleFlash() async {
    if (state.config.isFrontCamera || !state.isInitialized) return;
    final nextMode =
        state.config.flashMode == FlashMode.torch ? FlashMode.off : FlashMode.torch;
    try {
      await _cameraService.setFlashMode(nextMode);
      state = state.copyWith(
        config: state.config.copyWith(flashMode: nextMode),
      );
    } catch (e) {
      debugPrint('CameraNotifier: flash not supported: $e');
    }
  }

  /// Set zoom level (clamped to the device range).
  Future<void> setZoom(double zoom) async {
    final caps = state.capabilities;
    final clamped = caps == null
        ? zoom
        : zoom.clamp(caps.minZoom, caps.maxZoom).toDouble();
    try {
      await _cameraService.setZoomLevel(clamped);
      state = state.copyWith(config: state.config.copyWith(zoom: clamped));
    } catch (_) {}
  }

  /// Set exposure offset.
  Future<void> setExposure(double offset) async {
    try {
      await _cameraService.setExposureOffset(offset);
      state = state.copyWith(config: state.config.copyWith(exposure: offset));
    } catch (_) {}
  }

  /// Set focus point (normalized 0-1 coordinates).
  Future<void> setFocusPoint(Offset point) =>
      _cameraService.setFocusPoint(point);

  /// Toggle grid.
  void toggleGrid() {
    state = state.copyWith(
      config: state.config.copyWith(showGrid: !state.config.showGrid),
    );
  }

  /// Switch capture mode.
  void setCaptureMode(CaptureMode mode) {
    if (state.isCapturingVideo) return;
    state = state.copyWith(captureMode: mode);
  }

  /// Set preview mode.
  void setPreviewMode(PreviewMode mode) {
    state = state.copyWith(config: state.config.copyWith(previewMode: mode));
  }

  /// Take a photo and store it (both crops) as a new take.
  Future<Take?> takePhoto() async {
    if (!state.isReady || state.isBusy) return null;

    state = state.copyWith(
      isBusy: true,
      isProcessing: true,
      processingMessage: 'Saving photo...',
      processingProgress: 0.0,
    );
    try {
      final source = await _recordingService.capturePhoto();
      return await _library.addPhotoTake(source);
    } catch (e) {
      debugPrint('CameraNotifier: photo failed: $e');
      if (mounted) state = state.copyWith(errorMessage: 'Failed to capture photo.');
      return null;
    } finally {
      if (mounted) {
        state = state.copyWith(
          isBusy: false,
          isProcessing: false,
          processingMessage: null,
        );
      }
    }
  }

  /// Start video recording.
  Future<void> startRecording() async {
    if (!state.isReady || state.isBusy) return;
    state = state.copyWith(isBusy: true, errorMessage: null);

    try {
      await _recordingService.startRecording();
      _recordingStopwatch
        ..reset()
        ..start();
      state = state.copyWith(
        status: CameraStatus.recording,
        recordingDuration: Duration.zero,
      );
      _startTicker();
    } catch (e) {
      debugPrint('CameraNotifier: start recording failed: $e');
      // The preview is still usable; report and stay ready.
      state = state.copyWith(errorMessage: 'Failed to start recording.');
    } finally {
      if (mounted) state = state.copyWith(isBusy: false);
    }
  }

  void _startTicker() {
    _recordingTimer?.cancel();
    _recordingTimer = Timer.periodic(const Duration(milliseconds: 250), (_) {
      final elapsed = Duration(seconds: _recordingStopwatch.elapsed.inSeconds);
      if (mounted && elapsed != state.recordingDuration) {
        state = state.copyWith(recordingDuration: elapsed);
      }
    });
  }

  /// Pause recording.
  Future<void> pauseRecording() async {
    if (!state.isRecording || state.isBusy) return;
    try {
      await _recordingService.pauseRecording();
      _recordingStopwatch.stop();
      state = state.copyWith(status: CameraStatus.paused);
    } catch (e) {
      debugPrint('CameraNotifier: pause failed: $e');
    }
  }

  /// Resume recording.
  Future<void> resumeRecording() async {
    if (!state.isPaused || state.isBusy) return;
    try {
      await _recordingService.resumeRecording();
      _recordingStopwatch.start();
      state = state.copyWith(status: CameraStatus.recording);
    } catch (e) {
      debugPrint('CameraNotifier: resume failed: $e');
    }
  }

  /// Stop recording and store the master clip as a new take.
  Future<Take?> stopRecording() async {
    if (!state.isCapturingVideo || state.isBusy) return null;
    _recordingTimer?.cancel();
    _recordingStopwatch.stop();

    state = state.copyWith(isBusy: true, status: CameraStatus.processing);

    try {
      final clip = await _recordingService.stopRecording();
      return await _library.addVideoTake(clip);
    } catch (e) {
      debugPrint('CameraNotifier: stop recording failed: $e');
      if (mounted) {
        state = state.copyWith(errorMessage: 'Failed to save recording.');
      }
      return null;
    } finally {
      if (mounted) {
        state = state.copyWith(
          status: _cameraService.isInitialized
              ? CameraStatus.ready
              : CameraStatus.disposed,
          isBusy: false,
          recordingDuration: Duration.zero,
        );
      }
    }
  }

  /// Release the camera (app backgrounded, or another screen is opened).
  ///
  /// Any running take is stopped and saved first. The state flips to
  /// `disposed` *before* the controller is torn down so no frame can build a
  /// preview on a dead controller; [beforeDispose] lets the UI wait for that
  /// frame.
  Future<Take?> release({Future<void> Function()? beforeDispose}) async {
    Take? saved;
    if (state.isCapturingVideo) {
      saved = await stopRecording();
    }
    if (mounted && !state.hasError) {
      state = state.copyWith(status: CameraStatus.disposed);
    }
    if (beforeDispose != null) await beforeDispose();
    await _cameraService.dispose();
    return saved;
  }

  /// App moved to the background.
  Future<Take?> onAppPaused({Future<void> Function()? beforeDispose}) =>
      release(beforeDispose: beforeDispose);

  /// App came back to the foreground: reopen the camera if we released it.
  Future<void> onAppResumed() async {
    if (state.status == CameraStatus.disposed ||
        state.status == CameraStatus.error ||
        state.status == CameraStatus.uninitialized) {
      await initialize();
    }
  }

  /// Get the camera controller for preview widget.
  CameraController? get controller => _cameraService.controller;

  String _describeError(Object e) {
    if (e is CameraException) {
      final code = e.code.toLowerCase();
      if (code.contains('permission') || code.contains('denied')) {
        return 'Camera permission is required.';
      }
      if (code.contains('inuse') || code.contains('in_use') ||
          code.contains('disabled')) {
        return 'The camera is being used by another app.';
      }
    }
    return 'Could not start the camera.';
  }

  @override
  void dispose() {
    _recordingTimer?.cancel();
    super.dispose();
  }
}

// ── Theme Provider ───────────────────────────────────────────────

final themeModeProvider = Provider<String>((ref) {
  return ref.watch(settingsProvider).themeMode;
});
