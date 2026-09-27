import 'dart:ui' as ui;

/// Abstract framing strategy interface.
///
/// Allows plugging in different framing algorithms (center crop, face-detection,
/// subject-tracking) without modifying the camera engine.
abstract class FramingStrategy {
  /// Returns the crop rectangle for the portrait output within the source frame.
  ui.Rect getPortraitCropRect({
    required int sourceWidth,
    required int sourceHeight,
  });

  /// Returns the crop rectangle for the landscape output within the source frame.
  ui.Rect getLandscapeCropRect({
    required int sourceWidth,
    required int sourceHeight,
  });

  /// Optional: called each frame with metadata for dynamic strategies.
  void onFrameUpdate(FrameMetadata metadata) {}

  /// Strategy name for display.
  String get name;
}

/// Metadata passed to framing strategies per frame.
class FrameMetadata {
  final int width;
  final int height;
  final int timestamp;
  final List<DetectedFace>? faces;
  final List<DetectedSubject>? subjects;

  const FrameMetadata({
    required this.width,
    required this.height,
    required this.timestamp,
    this.faces,
    this.subjects,
  });
}

/// Placeholder for future face detection integration.
class DetectedFace {
  final ui.Rect boundingBox;
  final double confidence;

  const DetectedFace({required this.boundingBox, required this.confidence});
}

/// Placeholder for future subject detection integration.
class DetectedSubject {
  final ui.Rect boundingBox;
  final double confidence;
  final String? label;

  const DetectedSubject({
    required this.boundingBox,
    required this.confidence,
    this.label,
  });
}

/// Default center-based framing strategy.
///
/// Centers both portrait and landscape crops in the middle of the frame.
/// This is the v1 implementation — AI-based strategies can be swapped in later.
class CenterFramingStrategy implements FramingStrategy {
  @override
  String get name => 'Center';

  @override
  ui.Rect getPortraitCropRect({
    required int sourceWidth,
    required int sourceHeight,
  }) {
    const targetAspect = 9.0 / 16.0;
    final sourceAspect = sourceWidth / sourceHeight;

    double cropWidth, cropHeight;

    if (sourceAspect > targetAspect) {
      cropHeight = sourceHeight.toDouble();
      cropWidth = cropHeight * targetAspect;
    } else {
      cropWidth = sourceWidth.toDouble();
      cropHeight = cropWidth / targetAspect;
    }

    return ui.Rect.fromLTWH(
      (sourceWidth - cropWidth) / 2.0,
      (sourceHeight - cropHeight) / 2.0,
      cropWidth,
      cropHeight,
    );
  }

  @override
  ui.Rect getLandscapeCropRect({
    required int sourceWidth,
    required int sourceHeight,
  }) {
    const targetAspect = 16.0 / 9.0;
    final sourceAspect = sourceWidth / sourceHeight;

    double cropWidth, cropHeight;

    if (sourceAspect > targetAspect) {
      cropHeight = sourceHeight.toDouble();
      cropWidth = cropHeight * targetAspect;
    } else {
      cropWidth = sourceWidth.toDouble();
      cropHeight = cropWidth / targetAspect;
    }

    return ui.Rect.fromLTWH(
      (sourceWidth - cropWidth) / 2.0,
      (sourceHeight - cropHeight) / 2.0,
      cropWidth,
      cropHeight,
    );
  }

  @override
  void onFrameUpdate(FrameMetadata metadata) {
    // No-op for center crop. AI strategies would update tracking here.
  }
}
