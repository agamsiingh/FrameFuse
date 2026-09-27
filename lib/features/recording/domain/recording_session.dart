/// Recording session model.
class RecordingSession {
  final String sessionId;
  final String timestamp;
  final DateTime startTime;
  final DateTime? endTime;
  final String? masterFilePath;
  final String? portraitFilePath;
  final String? landscapeFilePath;
  final RecordingSessionStatus status;
  final Duration duration;

  const RecordingSession({
    required this.sessionId,
    required this.timestamp,
    required this.startTime,
    this.endTime,
    this.masterFilePath,
    this.portraitFilePath,
    this.landscapeFilePath,
    this.status = RecordingSessionStatus.idle,
    this.duration = Duration.zero,
  });

  bool get isComplete =>
      portraitFilePath != null && landscapeFilePath != null;

  RecordingSession copyWith({
    String? sessionId,
    String? timestamp,
    DateTime? startTime,
    DateTime? endTime,
    String? masterFilePath,
    String? portraitFilePath,
    String? landscapeFilePath,
    RecordingSessionStatus? status,
    Duration? duration,
  }) {
    return RecordingSession(
      sessionId: sessionId ?? this.sessionId,
      timestamp: timestamp ?? this.timestamp,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      masterFilePath: masterFilePath ?? this.masterFilePath,
      portraitFilePath: portraitFilePath ?? this.portraitFilePath,
      landscapeFilePath: landscapeFilePath ?? this.landscapeFilePath,
      status: status ?? this.status,
      duration: duration ?? this.duration,
    );
  }
}

/// Status of a recording session.
enum RecordingSessionStatus {
  idle,
  recording,
  paused,
  stopped,
  processing,
  complete,
  error,
}
