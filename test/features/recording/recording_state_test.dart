import 'package:flutter_test/flutter_test.dart';
import 'package:frame_fuse/features/recording/domain/recording_session.dart';

void main() {
  group('RecordingSession', () {
    test('initial session is idle', () {
      final session = RecordingSession(
        sessionId: 'abc123',
        timestamp: '2026-09-20_14-35-20',
        startTime: DateTime.now(),
      );
      expect(session.status, RecordingSessionStatus.idle);
      expect(session.isComplete, isFalse);
    });

    test('isComplete requires both paths', () {
      final session = RecordingSession(
        sessionId: 'abc123',
        timestamp: '2026-09-20_14-35-20',
        startTime: DateTime.now(),
        portraitFilePath: '/path/to/portrait.mp4',
        landscapeFilePath: '/path/to/landscape.mp4',
      );
      expect(session.isComplete, isTrue);
    });

    test('isComplete is false with only portrait', () {
      final session = RecordingSession(
        sessionId: 'abc123',
        timestamp: '2026-09-20_14-35-20',
        startTime: DateTime.now(),
        portraitFilePath: '/path/to/portrait.mp4',
      );
      expect(session.isComplete, isFalse);
    });

    test('copyWith updates status', () {
      final session = RecordingSession(
        sessionId: 'abc123',
        timestamp: '2026-09-20_14-35-20',
        startTime: DateTime.now(),
      );
      final updated = session.copyWith(
        status: RecordingSessionStatus.recording,
      );
      expect(updated.status, RecordingSessionStatus.recording);
      expect(updated.sessionId, 'abc123');
    });
  });
}
