import 'camera_config.dart';
import 'device_capabilities.dart';

/// Camera operational state.
enum CameraStatus {
  uninitialized,
  initializing,
  ready,
  previewing,
  recording,
  paused,
  processing,
  error,
  disposed,
}

/// Capture mode.
enum CaptureMode {
  photo('Photo'),
  video('Video');

  final String label;
  const CaptureMode(this.label);
}

/// Sentinel used by [CameraState.copyWith] to distinguish "not passed"
/// from an explicit `null` for nullable fields.
const Object _unset = Object();

/// Comprehensive camera state.
class CameraState {
  final CameraStatus status;
  final CameraConfig config;
  final DeviceCapabilities? capabilities;
  final CaptureMode captureMode;
  final String? errorMessage;
  final Duration recordingDuration;
  final bool isProcessing;
  final double processingProgress;
  final String? processingMessage;

  /// True while a capture/start/stop operation is in flight. Used to ignore
  /// repeated shutter taps.
  final bool isBusy;

  const CameraState({
    this.status = CameraStatus.uninitialized,
    required this.config,
    this.capabilities,
    this.captureMode = CaptureMode.video,
    this.errorMessage,
    this.recordingDuration = Duration.zero,
    this.isProcessing = false,
    this.processingProgress = 0.0,
    this.processingMessage,
    this.isBusy = false,
  });

  bool get isInitialized =>
      status != CameraStatus.uninitialized &&
      status != CameraStatus.initializing &&
      status != CameraStatus.error &&
      status != CameraStatus.disposed;

  bool get isReady =>
      status == CameraStatus.ready || status == CameraStatus.previewing;
  bool get isRecording => status == CameraStatus.recording;
  bool get isPaused => status == CameraStatus.paused;
  bool get isCapturingVideo => isRecording || isPaused;
  bool get hasError => status == CameraStatus.error;
  bool get isPhotoMode => captureMode == CaptureMode.photo;
  bool get isVideoMode => captureMode == CaptureMode.video;

  /// Formatted recording duration (MM:SS).
  String get formattedDuration {
    final minutes = recordingDuration.inMinutes.toString().padLeft(2, '0');
    final seconds =
        (recordingDuration.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  CameraState copyWith({
    CameraStatus? status,
    CameraConfig? config,
    DeviceCapabilities? capabilities,
    CaptureMode? captureMode,
    Object? errorMessage = _unset,
    Duration? recordingDuration,
    bool? isProcessing,
    double? processingProgress,
    Object? processingMessage = _unset,
    bool? isBusy,
  }) {
    return CameraState(
      status: status ?? this.status,
      config: config ?? this.config,
      capabilities: capabilities ?? this.capabilities,
      captureMode: captureMode ?? this.captureMode,
      errorMessage: identical(errorMessage, _unset)
          ? this.errorMessage
          : errorMessage as String?,
      recordingDuration: recordingDuration ?? this.recordingDuration,
      isProcessing: isProcessing ?? this.isProcessing,
      processingProgress: processingProgress ?? this.processingProgress,
      processingMessage: identical(processingMessage, _unset)
          ? this.processingMessage
          : processingMessage as String?,
      isBusy: isBusy ?? this.isBusy,
    );
  }
}
