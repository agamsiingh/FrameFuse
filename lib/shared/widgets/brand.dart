import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

/// FrameFuse mark: the dual-frame camera icon.
class FrameFuseLogo extends StatelessWidget {
  final double width;
  final double? height;
  final BorderRadius? borderRadius;

  const FrameFuseLogo({
    super.key,
    this.width = 104,
    this.height,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final h = height ?? width;
    final radius = borderRadius ?? BorderRadius.circular(width * 0.22);
    return Container(
      width: width,
      height: h,
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: width * 0.15,
            offset: Offset(0, width * 0.06),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Image.asset(
          'assets/images/framefuse_logo.jpeg',
          width: width,
          height: h,
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}


/// Small crown used to mark premium features.
class CrownIcon extends StatelessWidget {
  final double size;
  final Color color;
  const CrownIcon({super.key, this.size = 12, this.color = AppColors.accent});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size * 0.8,
      child: CustomPaint(painter: _CrownPainter(color)),
    );
  }
}

class _CrownPainter extends CustomPainter {
  final Color color;
  const _CrownPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final paint = Paint()..color = color;
    final path = Path()
      ..moveTo(0, h * 0.22)
      ..lineTo(w * 0.28, h * 0.55)
      ..lineTo(w * 0.5, h * 0.05)
      ..lineTo(w * 0.72, h * 0.55)
      ..lineTo(w, h * 0.22)
      ..lineTo(w * 0.88, h * 0.78)
      ..lineTo(w * 0.12, h * 0.78)
      ..close();
    canvas.drawPath(path, paint);
    canvas.drawRect(Rect.fromLTRB(w * 0.12, h * 0.85, w * 0.88, h), paint);
  }

  @override
  bool shouldRepaint(covariant _CrownPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// Wraps [child] with a crown in its top-right corner.
class CrownBadge extends StatelessWidget {
  final Widget child;
  final double crownSize;
  final Offset offset;
  const CrownBadge({
    super.key,
    required this.child,
    this.crownSize = 12,
    this.offset = const Offset(4, -4),
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned(
          right: -offset.dx,
          top: offset.dy,
          child: CrownIcon(size: crownSize),
        ),
      ],
    );
  }
}

/// Portrait + landscape frames with swap arrows (layout toggle).
class LayoutSwapIcon extends StatelessWidget {
  final double size;
  final Color color;
  const LayoutSwapIcon({super.key, this.size = 24, this.color = AppColors.accent});

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _SwapPainter(color)),
    );
  }
}

class _SwapPainter extends CustomPainter {
  final Color color;
  const _SwapPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final u = size.width / 24;
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2 * u
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawRRect(
      RRect.fromLTRBR(2 * u, 2 * u, 11 * u, 10 * u, Radius.circular(2 * u)),
      p,
    );
    canvas.drawRRect(
      RRect.fromLTRBR(13 * u, 14 * u, 22 * u, 22 * u, Radius.circular(2 * u)),
      p,
    );
    // Top-right arrow (clockwise), bottom-left arrow.
    final a1 = Path()
      ..moveTo(14 * u, 3 * u)
      ..quadraticBezierTo(20 * u, 3 * u, 20 * u, 9 * u);
    canvas.drawPath(a1, p);
    canvas.drawPath(
      Path()
        ..moveTo(17.5 * u, 7 * u)
        ..lineTo(20 * u, 9.5 * u)
        ..lineTo(22.5 * u, 7 * u),
      p,
    );
    final a2 = Path()
      ..moveTo(10 * u, 21 * u)
      ..quadraticBezierTo(4 * u, 21 * u, 4 * u, 15 * u);
    canvas.drawPath(a2, p);
    canvas.drawPath(
      Path()
        ..moveTo(1.5 * u, 17 * u)
        ..lineTo(4 * u, 14.5 * u)
        ..lineTo(6.5 * u, 17 * u),
      p,
    );
  }

  @override
  bool shouldRepaint(covariant _SwapPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// Onboarding pager dots.
class PageDots extends StatelessWidget {
  final int count;
  final int index;
  const PageDots({super.key, required this.count, required this.index});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i == index ? AppColors.accent : AppColors.dotInactive,
            ),
          ),
      ],
    );
  }
}

/// Translucent dark capsule used for on-preview status labels.
class OverlayPill extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  const OverlayPill({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          color: const Color(0xB3232428),
          borderRadius: BorderRadius.circular(6),
        ),
        child: DefaultTextStyle.merge(
          style: const TextStyle(
            color: Colors.white,
            fontSize: 9,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.2,
          ),
          child: child,
        ),
      ),
    );
  }
}

/// "Coming soon" feedback for locked premium features.
void showComingSoon(BuildContext context, String feature) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      content: Row(
        children: [
          const CrownIcon(size: 16),
          const SizedBox(width: 10),
          Expanded(child: Text('$feature — Coming Soon')),
        ],
      ),
      duration: const Duration(seconds: 2),
    ),
  );
}

/// Stylised sunset scene used by onboarding to illustrate "one take,
/// both formats". Painted, so crops of the same scene line up exactly.
class SunsetScenePainter extends CustomPainter {
  /// Visible part of the 16:9 scene, in scene units (0..1 on both axes).
  final Rect window;
  const SunsetScenePainter({this.window = const Rect.fromLTWH(0, 0, 1, 1)});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    // Map scene space (0..1 × 0..1) through the window onto the canvas.
    final sx = size.width / window.width;
    final sy = size.height / window.height;
    canvas.scale(sx, sy);
    canvas.translate(-window.left, -window.top);

    const horizon = 0.52;
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, 1, horizon),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF6E8FB5), Color(0xFFB9A7A6), Color(0xFFF2A457)],
          stops: [0, 0.6, 1],
        ).createShader(const Rect.fromLTWH(0, 0, 1, horizon)),
    );
    // Scene units are 16:9 (x spans 16/9 of y), so round shapes need
    // their height scaled to stay circular on screen.
    const k = 16 / 9;
    Rect round(Offset c, double r) =>
        Rect.fromCenter(center: c, width: r * 2, height: r * 2 * k);

    // Sun glow.
    final sun = round(const Offset(0.36, horizon - 0.015), 0.09);
    canvas.drawOval(
      sun,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0xFFFFF3C4), Color(0x00FFB347)],
        ).createShader(sun),
    );
    // Water.
    canvas.drawRect(
      const Rect.fromLTWH(0, horizon, 1, 1 - horizon),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFE6A06A), Color(0xFF4F6E8E), Color(0xFF2B3E55)],
        ).createShader(const Rect.fromLTWH(0, horizon, 1, 1 - horizon)),
    );
    // Far shore.
    canvas.drawRect(
      const Rect.fromLTWH(0, horizon - 0.006, 1, 0.012),
      Paint()..color = const Color(0xFF3A3A40),
    );
    // Near shore (bottom-right path).
    canvas.drawPath(
      Path()
        ..moveTo(0.55, 1)
        ..quadraticBezierTo(0.8, 0.78, 1, 0.66)
        ..lineTo(1, 1)
        ..close(),
      Paint()..color = const Color(0xFF6B6259),
    );
    // Tree silhouette, top right.
    final tree = Paint()..color = const Color(0xFF2A2621);
    canvas.drawRect(const Rect.fromLTWH(0.955, 0.2, 0.02, 0.55), tree);
    for (final c in const [
      Offset(0.93, 0.18),
      Offset(0.99, 0.12),
      Offset(0.86, 0.27),
      Offset(0.97, 0.3),
    ]) {
      canvas.drawOval(round(c, 0.05), tree);
    }
    // Person (centered subject).
    final coat = Paint()..color = const Color(0xFFE9E1D6);
    final skirt = Paint()..color = const Color(0xFF5A2A22);
    final hair = Paint()..color = const Color(0xFF231A16);
    canvas.drawPath(
      Path()
        ..moveTo(0.455, 0.72)
        ..lineTo(0.545, 0.72)
        ..lineTo(0.565, 0.98)
        ..lineTo(0.435, 0.98)
        ..close(),
      skirt,
    );
    canvas.drawRRect(
      RRect.fromLTRBR(0.44, 0.52, 0.56, 0.74, const Radius.circular(0.03)),
      coat,
    );
    canvas.drawOval(const Rect.fromLTWH(0.465, 0.42, 0.07, 0.2), hair);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant SunsetScenePainter oldDelegate) =>
      oldDelegate.window != window;
}
