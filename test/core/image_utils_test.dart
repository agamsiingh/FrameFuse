import 'dart:ui' as ui;
import 'package:flutter_test/flutter_test.dart';
import 'package:frame_fuse/core/utils/image_utils.dart';

void main() {
  group('ImageUtils.centerCropRect', () {
    test('landscape source → portrait crop (center)', () {
      // 1920×1080 source → 9:16 crop
      final rect = ImageUtils.portraitCropRect(
        sourceWidth: 1920,
        sourceHeight: 1080,
      );
      expect(rect.width, closeTo(607.5, 0.1)); // 1080 * 9/16
      expect(rect.height, closeTo(1080, 0.1));
      expect(rect.left, closeTo((1920 - 607.5) / 2, 0.1));
      expect(rect.top, closeTo(0, 0.1));
    });

    test('landscape source → landscape crop (full width)', () {
      // 1920×1080 is already 16:9
      final rect = ImageUtils.landscapeCropRect(
        sourceWidth: 1920,
        sourceHeight: 1080,
      );
      expect(rect.width, closeTo(1920, 0.1));
      expect(rect.height, closeTo(1080, 0.1));
    });

    test('square source → portrait crop', () {
      final rect = ImageUtils.portraitCropRect(
        sourceWidth: 1000,
        sourceHeight: 1000,
      );
      // Should crop width: 1000 * 9/16 = 562.5
      expect(rect.width, closeTo(562.5, 0.1));
      expect(rect.height, closeTo(1000, 0.1));
    });

    test('square source → landscape crop', () {
      final rect = ImageUtils.landscapeCropRect(
        sourceWidth: 1000,
        sourceHeight: 1000,
      );
      // Should crop height: 1000 / (16/9) = 562.5
      expect(rect.width, closeTo(1000, 0.1));
      expect(rect.height, closeTo(562.5, 0.1));
    });

    test('crop rect is centered', () {
      final rect = ImageUtils.centerCropRect(
        sourceWidth: 2000,
        sourceHeight: 2000,
        targetAspectRatio: 2.0,
      );
      // Width = 2000, height = 1000
      expect(rect.left, closeTo(0, 0.1));
      expect(rect.top, closeTo(500, 0.1));
    });
  });

  group('ImageUtils.fitScale', () {
    test('calculates correct fit scale', () {
      final scale = ImageUtils.fitScale(
        const ui.Size(1920, 1080),
        const ui.Size(400, 300),
      );
      expect(scale, closeTo(400 / 1920, 0.001));
    });
  });

  group('ImageUtils.coverScale', () {
    test('calculates correct cover scale', () {
      final scale = ImageUtils.coverScale(
        const ui.Size(1920, 1080),
        const ui.Size(400, 300),
      );
      expect(scale, closeTo(300 / 1080, 0.001));
    });
  });
}
