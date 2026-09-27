import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

/// Live camera feed center-cropped ("cover") to the size it's given.
///
/// The same [CameraController] texture can be shown by several of these at
/// once, so the 9:16 and 16:9 previews are always frame-synchronous and
/// match the export crop exactly (both are center crops).
class CropPreview extends StatelessWidget {
  final CameraController controller;
  final BorderRadius borderRadius;
  final bool showGrid;
  final Color? borderColor;

  /// Called with the tap position normalized to the *full camera frame*
  /// (0..1), ready for `setFocusPoint`.
  final ValueChanged<Offset>? onFocusTap;
  final GestureScaleStartCallback? onScaleStart;
  final GestureScaleUpdateCallback? onScaleUpdate;

  const CropPreview({
    super.key,
    required this.controller,
    this.borderRadius = const BorderRadius.all(Radius.circular(10)),
    this.showGrid = false,
    this.borderColor,
    this.onFocusTap,
    this.onScaleStart,
    this.onScaleUpdate,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final previewSize = controller.value.previewSize;
        // previewSize is sensor-oriented (landscape); the app is portrait.
        final frameW = previewSize?.height ?? 9;
        final frameH = previewSize?.width ?? 16;

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: onFocusTap == null
              ? null
              : (d) => onFocusTap!(_toFrame(
                    d.localPosition,
                    constraints.biggest,
                    Size(frameW, frameH),
                  )),
          onScaleStart: onScaleStart,
          onScaleUpdate: onScaleUpdate,
          child: Container(
            foregroundDecoration: borderColor == null
                ? null
                : BoxDecoration(
                    borderRadius: borderRadius,
                    border: Border.all(color: borderColor!, width: 1),
                  ),
            child: ClipRRect(
              borderRadius: borderRadius,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  const ColoredBox(color: Colors.black),
                  FittedBox(
                    fit: BoxFit.cover,
                    clipBehavior: Clip.hardEdge,
                    child: SizedBox(
                      width: frameW,
                      height: frameH,
                      child: CameraPreview(controller),
                    ),
                  ),
                  if (showGrid)
                    const IgnorePointer(child: CustomPaint(painter: GridPainter())),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Maps a point in the (cropped) view to normalized full-frame coordinates.
  static Offset _toFrame(Offset local, Size view, Size frame) {
    final viewAspect = view.width / view.height;
    final frameAspect = frame.width / frame.height;
    double visibleW = 1, visibleH = 1;
    if (viewAspect > frameAspect) {
      visibleH = frameAspect / viewAspect; // top/bottom cropped
    } else {
      visibleW = viewAspect / frameAspect; // sides cropped
    }
    final u = (local.dx / view.width).clamp(0.0, 1.0);
    final v = (local.dy / view.height).clamp(0.0, 1.0);
    return Offset(
      0.5 + (u - 0.5) * visibleW,
      0.5 + (v - 0.5) * visibleH,
    );
  }

  @visibleForTesting
  static Offset toFrameForTest(Offset local, Size view, Size frame) =>
      _toFrame(local, view, frame);
}

/// Rule-of-thirds grid.
class GridPainter extends CustomPainter {
  const GridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.28)
      ..strokeWidth = 0.7;
    for (var i = 1; i < 3; i++) {
      final x = size.width * i / 3;
      final y = size.height * i / 3;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
