import 'dart:math' as math;
import 'dart:ui' as ui;

/// Utility for computing crop rectangles for dual-output framing.
class ImageUtils {
  ImageUtils._();

  /// Calculates the center crop rectangle for a given target aspect ratio
  /// from a source image of [sourceWidth] × [sourceHeight].
  ///
  /// Returns a [ui.Rect] in source coordinates.
  static ui.Rect centerCropRect({
    required int sourceWidth,
    required int sourceHeight,
    required double targetAspectRatio,
  }) {
    final sourceAspect = sourceWidth / sourceHeight;

    double cropWidth, cropHeight;

    if (sourceAspect > targetAspectRatio) {
      // Source is wider than target → crop sides
      cropHeight = sourceHeight.toDouble();
      cropWidth = cropHeight * targetAspectRatio;
    } else {
      // Source is taller than target → crop top/bottom
      cropWidth = sourceWidth.toDouble();
      cropHeight = cropWidth / targetAspectRatio;
    }

    final left = (sourceWidth - cropWidth) / 2.0;
    final top = (sourceHeight - cropHeight) / 2.0;

    return ui.Rect.fromLTWH(left, top, cropWidth, cropHeight);
  }

  /// Calculates a portrait (9:16) center crop from a source.
  static ui.Rect portraitCropRect({
    required int sourceWidth,
    required int sourceHeight,
  }) {
    return centerCropRect(
      sourceWidth: sourceWidth,
      sourceHeight: sourceHeight,
      targetAspectRatio: 9.0 / 16.0,
    );
  }

  /// Calculates a landscape (16:9) center crop from a source.
  static ui.Rect landscapeCropRect({
    required int sourceWidth,
    required int sourceHeight,
  }) {
    return centerCropRect(
      sourceWidth: sourceWidth,
      sourceHeight: sourceHeight,
      targetAspectRatio: 16.0 / 9.0,
    );
  }

  /// Returns the scale factor needed to fit [sourceSize] into [targetSize]
  /// while maintaining aspect ratio.
  static double fitScale(ui.Size sourceSize, ui.Size targetSize) {
    return math.min(
      targetSize.width / sourceSize.width,
      targetSize.height / sourceSize.height,
    );
  }

  /// Returns the scale factor for cover-fit (fill target, may crop).
  static double coverScale(ui.Size sourceSize, ui.Size targetSize) {
    return math.max(
      targetSize.width / sourceSize.width,
      targetSize.height / sourceSize.height,
    );
  }
}
