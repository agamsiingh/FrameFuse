import 'package:flutter_test/flutter_test.dart';
import 'package:frame_fuse/core/utils/file_utils.dart';

void main() {
  group('FileUtils', () {
    test('generateSessionId returns non-empty string', () {
      final id = FileUtils.generateSessionId();
      expect(id, isNotEmpty);
      expect(id.length, greaterThan(4));
    });

    test('generateTimestamp returns formatted string', () {
      final ts = FileUtils.generateTimestamp();
      expect(ts, isNotEmpty);
      // Should match yyyy-MM-dd_HH-mm-ss pattern
      expect(ts, matches(RegExp(r'\d{4}-\d{2}-\d{2}_\d{2}-\d{2}-\d{2}')));
    });

    test('photoFileName generates correct portrait name', () {
      final name = FileUtils.photoFileName(
        isPortrait: true,
        timestamp: '2026-09-20_14-32-10',
      );
      expect(name, '2026-09-20_14-32-10_portrait.jpg');
    });

    test('photoFileName generates correct landscape name', () {
      final name = FileUtils.photoFileName(
        isPortrait: false,
        timestamp: '2026-09-20_14-32-10',
      );
      expect(name, '2026-09-20_14-32-10_landscape.jpg');
    });

    test('videoFileName generates correct portrait name', () {
      final name = FileUtils.videoFileName(
        isPortrait: true,
        timestamp: '2026-09-20_14-35-20',
      );
      expect(name, '2026-09-20_14-35-20_portrait.mp4');
    });

    test('videoFileName generates correct landscape name', () {
      final name = FileUtils.videoFileName(
        isPortrait: false,
        timestamp: '2026-09-20_14-35-20',
      );
      expect(name, '2026-09-20_14-35-20_landscape.mp4');
    });

    test('masterVideoFileName generates correct name', () {
      final name = FileUtils.masterVideoFileName(
        timestamp: '2026-09-20_14-35-20',
      );
      expect(name, '2026-09-20_14-35-20_master.mp4');
    });

    test('session IDs are unique', () {
      final ids = List.generate(100, (_) => FileUtils.generateSessionId());
      expect(ids.toSet().length, ids.length);
    });
  });
}
