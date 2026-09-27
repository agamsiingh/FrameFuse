import 'recording_session.dart';

/// State for the recording feature.
class RecordingState {
  final RecordingSession? currentSession;
  final RecordingSession? lastSession;
  final bool isProcessing;
  final double processingProgress;
  final String? processingMessage;
  final String? errorMessage;

  const RecordingState({
    this.currentSession,
    this.lastSession,
    this.isProcessing = false,
    this.processingProgress = 0.0,
    this.processingMessage,
    this.errorMessage,
  });

  bool get isRecording =>
      currentSession?.status == RecordingSessionStatus.recording;
  bool get isPaused =>
      currentSession?.status == RecordingSessionStatus.paused;
  bool get hasResult => lastSession?.isComplete ?? false;

  RecordingState copyWith({
    RecordingSession? currentSession,
    RecordingSession? lastSession,
    bool? isProcessing,
    double? processingProgress,
    String? processingMessage,
    String? errorMessage,
  }) {
    return RecordingState(
      currentSession: currentSession ?? this.currentSession,
      lastSession: lastSession ?? this.lastSession,
      isProcessing: isProcessing ?? this.isProcessing,
      processingProgress: processingProgress ?? this.processingProgress,
      processingMessage: processingMessage,
      errorMessage: errorMessage,
    );
  }
}
