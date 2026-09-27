import 'dart:io';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/brand.dart';

/// Red record button with the cyan ring. Morphs to a rounded square while
/// recording.
class RecordButton extends StatelessWidget {
  final bool isRecording;
  final bool enabled;
  final VoidCallback onTap;
  final double size;

  const RecordButton({
    super.key,
    required this.isRecording,
    required this.enabled,
    required this.onTap,
    this.size = 56,
  });

  @override
  Widget build(BuildContext context) {
    final inner = isRecording ? size * 0.42 : size - 7;
    return Semantics(
      button: true,
      label: isRecording ? 'Stop recording' : 'Record',
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 150),
          opacity: enabled ? 1 : 0.5,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.accent, width: 2.2),
            ),
            alignment: Alignment.center,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeInOut,
              width: inner,
              height: inner,
              decoration: BoxDecoration(
                color: AppColors.record,
                borderRadius: BorderRadius.circular(isRecording ? 6 : inner / 2),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// White photo shutter (secondary capture).
class PhotoButton extends StatelessWidget {
  final bool enabled;
  final VoidCallback onTap;
  const PhotoButton({super.key, required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Take photo',
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: Opacity(
          opacity: enabled ? 1 : 0.5,
          child: Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              border: Border.all(color: const Color(0xFF8A8A8E), width: 2.4),
            ),
          ),
        ),
      ),
    );
  }
}

/// A plain 44×44 icon hit target.
class BarIcon extends StatelessWidget {
  final Widget icon;
  final VoidCallback? onTap;
  final String tooltip;
  final bool premium;

  /// Tighter hit box for the dense top bar.
  final bool compact;

  const BarIcon({
    super.key,
    required this.icon,
    required this.onTap,
    required this.tooltip,
    this.premium = false,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    Widget child = icon;
    if (premium) {
      child = CrownBadge(crownSize: 10, offset: const Offset(5, -5), child: icon);
    }
    return Tooltip(
      message: tooltip,
      child: InkResponse(
        onTap: onTap,
        radius: 22,
        child: SizedBox(
          width: compact ? 34 : 40,
          height: 44,
          child: Center(child: child),
        ),
      ),
    );
  }
}

/// Last-take thumbnail (or a gallery glyph when there are no takes yet).
class LastTakeButton extends StatelessWidget {
  final String? thumbnailPath;
  final VoidCallback onTap;
  const LastTakeButton({super.key, required this.thumbnailPath, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final path = thumbnailPath;
    final hasThumb = path != null && File(path).existsSync();
    return BarIcon(
      tooltip: 'Last take',
      onTap: onTap,
      icon: hasThumb
          ? ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: Image.file(
                File(path),
                key: ValueKey(path),
                width: 28,
                height: 28,
                fit: BoxFit.cover,
                cacheWidth: 84,
                errorBuilder: (_, _, _) => const _GalleryGlyph(),
              ),
            )
          : const _GalleryGlyph(),
    );
  }
}

class _GalleryGlyph extends StatelessWidget {
  const _GalleryGlyph();

  @override
  Widget build(BuildContext context) {
    return const Icon(Icons.photo_library, color: Colors.white, size: 22);
  }
}

/// "Single Lens" / "Front/Back 👑" capture-mode pills.
class LensModeSelector extends StatelessWidget {
  final VoidCallback onFrontBackTap;
  const LensModeSelector({super.key, required this.onFrontBackTap});

  @override
  Widget build(BuildContext context) {
    const label = TextStyle(
      fontSize: 10.5,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.6,
    );
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          height: 26,
          padding: const EdgeInsets.symmetric(horizontal: 17),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFF1D9CAB),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Text(
            'Single Lens',
            style: label.copyWith(color: const Color(0xFF002230)),
          ),
        ),
        const SizedBox(width: 6),
        InkWell(
          onTap: onFrontBackTap,
          borderRadius: BorderRadius.circular(13),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            child: Row(
              children: [
                Text('Front/Back', style: label.copyWith(color: Colors.white)),
                const SizedBox(width: 6),
                const CrownIcon(size: 11),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Zoom presets ("1×", "2") straddling the bottom edge of the 16:9 preview.
class ZoomChips extends StatelessWidget {
  final double zoom;
  final double minZoom;
  final double maxZoom;
  final ValueChanged<double> onSelect;

  const ZoomChips({
    super.key,
    required this.zoom,
    required this.minZoom,
    required this.maxZoom,
    required this.onSelect,
  });

  List<double> get presets => [
        if (minZoom < 0.95) double.parse(minZoom.toStringAsFixed(1)),
        1.0,
        if (maxZoom >= 2) 2.0,
        if (maxZoom >= 5) 5.0,
      ];

  @override
  Widget build(BuildContext context) {
    final values = presets;
    // The active preset is the closest one at or below the current zoom.
    var active = values.first;
    for (final v in values) {
      if (zoom >= v - 0.05) active = v;
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final v in values)
          GestureDetector(
            onTap: () => onSelect(v),
            child: Container(
              width: 32,
              height: 32,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              alignment: Alignment.center,
              decoration: v == active
                  ? const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xA6303840),
                    )
                  : null,
              child: Text(
                v == active ? _label(zoom, v) : _short(v),
                style: TextStyle(
                  color: v == active ? AppColors.accent : Colors.white,
                  fontSize: v == active ? 10.5 : 9.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
      ],
    );
  }

  static String _short(double v) =>
      v < 1 ? '.${(v * 10).round()}' : v.toStringAsFixed(0);

  static String _label(double zoom, double preset) {
    if ((zoom - preset).abs() < 0.05) {
      return '${preset < 1 ? _short(preset) : preset.toStringAsFixed(0)}×';
    }
    return '${zoom.toStringAsFixed(1)}×';
  }
}
