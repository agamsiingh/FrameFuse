import 'dart:async';
import 'dart:io';
import '../../camera/data/camera_service.dart';
import '../../../core/utils/file_utils.dart';
import '../domain/recording_session.dart';

/// A finished master recording (full sensor frame, before cropping).
class RecordedClip {
  final String path;
  final Duration duration;

  const RecordedClip({required this.path, required this.duration});
}

/// Service managing the recording lifecycle:
/// start → pause → resume → stop (master clip).
///
/// Cropping into the two deliverables happens later, at export time, so a
/// take is available for review the moment recording stops.
class RecordingService {
  final CameraService _cameraService;
  final Stopwatch _stopwatch = Stopwatch();
  RecordingSession? _currentSession;

  RecordingService({required CameraService cameraService})
      : _cameraService = cameraService;

  RecordingSession? get currentSession => _currentSession;
  Duration get currentDuration => _stopwatch.elapsed;

  /// Capture a full-frame photo. Returns the temporary source path.
  Future<String> capturePhoto() async {
    final xFile = await _cameraService.takePicture();
    return xFile.path;
  }

  /// Start video recording.
  Future<void> startRecording() async {
    await _cameraService.startVideoRecording();
    _stopwatch
      ..reset()
      ..start();
    _currentSession = RecordingSession(
      sessionId: FileUtils.generateSessionId(),
      timestamp: FileUtils.generateTimestamp(),
      startTime: DateTime.now(),
      status: RecordingSessionStatus.recording,
    );
  }

  /// Pause recording.
  Future<void> pauseRecording() async {
    await _cameraService.pauseVideoRecording();
    _stopwatch.stop();
    _currentSession =
        _currentSession?.copyWith(status: RecordingSessionStatus.paused);
  }

  /// Resume recording.
  Future<void> resumeRecording() async {
    await _cameraService.resumeVideoRecording();
    _stopwatch.start();
    _currentSession =
        _currentSession?.copyWith(status: RecordingSessionStatus.recording);
  }

  /// Stop recording and return the master clip.
  Future<RecordedClip> stopRecording() async {
    final xFile = await _cameraService.stopVideoRecording();
    _stopwatch.stop();
    final duration = _stopwatch.elapsed;
    _currentSession = _currentSession?.copyWith(
      endTime: DateTime.now(),
      masterFilePath: xFile.path,
      status: RecordingSessionStatus.stopped,
      duration: duration,
    );
    return RecordedClip(path: xFile.path, duration: duration);
  }

  /// Cancel the current recording without keeping it.
  Future<void> cancelRecording() async {
    _stopwatch.stop();
    if (_cameraService.isRecording) {
      try {
        final file = await _cameraService.stopVideoRecording();
        await File(file.path).delete();
      } catch (_) {}
    }
    _currentSession = null;
  }

  void dispose() {
    _stopwatch.stop();
  }
}
