import 'dart:io';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

/// Filmstrip trim control: cyan handles select [start]..[end], a white
/// playhead shows [position]. Dragging a handle scrubs to it; tapping the
/// strip seeks.
class TrimBar extends StatefulWidget {
  final Duration duration;
  final Duration start;
  final Duration end;
  final Duration position;
  final List<String> frames;
  final Duration minLength;
  final void Function(Duration start, Duration end) onTrimChanged;
  final void Function(Duration start, Duration end) onTrimEnd;
  final ValueChanged<Duration> onSeek;

  const TrimBar({
    super.key,
    required this.duration,
    required this.start,
    required this.end,
    required this.position,
    required this.frames,
    required this.onTrimChanged,
    required this.onTrimEnd,
    required this.onSeek,
    this.minLength = const Duration(seconds: 1),
  });

  static const double handleWidth = 14;
  static const double height = 46;

  @override
  State<TrimBar> createState() => _TrimBarState();
}

enum _Drag { none, start, end, playhead }

class _TrimBarState extends State<TrimBar> {
  _Drag _drag = _Drag.none;

  double _toX(Duration d, double trackWidth) {
    final total = widget.duration.inMilliseconds;
    if (total <= 0) return 0;
    return trackWidth * (d.inMilliseconds / total).clamp(0.0, 1.0);
  }

  Duration _toTime(double x, double trackWidth) {
    final total = widget.duration.inMilliseconds;
    final f = (x / trackWidth).clamp(0.0, 1.0);
    return Duration(milliseconds: (total * f).round());
  }

  @override
  Widget build(BuildContext context) {
    const hw = TrimBar.handleWidth;
    return LayoutBuilder(builder: (context, c) {
      final track = c.maxWidth - hw * 2;
      final sx = hw + _toX(widget.start, track);
      final ex = hw + _toX(widget.end, track);
      final px = hw + _toX(widget.position, track);
      final minGap = _toX(widget.minLength, track);

      void onDown(double x) {
        final dStart = (x - (sx - hw / 2)).abs();
        final dEnd = (x - (ex + hw / 2)).abs();
        if (dStart < 28 && dStart <= dEnd) {
          _drag = _Drag.start;
        } else if (dEnd < 28) {
          _drag = _Drag.end;
        } else {
          _drag = _Drag.playhead;
          _seek(x, track);
        }
      }

      void onMove(double x) {
        switch (_drag) {
          case _Drag.start:
            final t = _toTime((x - hw).clamp(0, ex - hw - minGap), track);
            widget.onTrimChanged(t, widget.end);
            widget.onSeek(t);
          case _Drag.end:
            final t = _toTime((x - hw).clamp(sx - hw + minGap, track), track);
            widget.onTrimChanged(widget.start, t);
            widget.onSeek(t);
          case _Drag.playhead:
            _seek(x, track);
          case _Drag.none:
            break;
        }
      }

      void onUp() {
        if (_drag == _Drag.start || _drag == _Drag.end) {
          widget.onTrimEnd(widget.start, widget.end);
        }
        _drag = _Drag.none;
      }

      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragStart: (d) => onDown(d.localPosition.dx),
        onHorizontalDragUpdate: (d) => onMove(d.localPosition.dx),
        onHorizontalDragEnd: (_) => onUp(),
        onTapDown: (d) => onDown(d.localPosition.dx),
        onTapUp: (_) => onUp(),
        child: SizedBox(
          height: TrimBar.height,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Filmstrip.
              Positioned(
                left: hw,
                right: hw,
                top: 3,
                bottom: 3,
                child: ClipRect(
                  child: ColoredBox(
                    color: AppColors.filmstrip,
                    child: Row(
                      children: [
                        for (final f in widget.frames)
                          Expanded(
                            child: Image.file(
                              File(f),
                              fit: BoxFit.cover,
                              height: double.infinity,
                              cacheHeight: 120,
                              gaplessPlayback: true,
                              errorBuilder: (_, _, _) => const SizedBox.shrink(),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              // Dim outside the selection.
              Positioned(
                left: hw,
                width: (sx - hw).clamp(0.0, double.infinity),
                top: 3,
                bottom: 3,
                child: const ColoredBox(color: Color(0xAA000000)),
              ),
              Positioned(
                left: ex,
                right: hw,
                top: 3,
                bottom: 3,
                child: const ColoredBox(color: Color(0xAA000000)),
              ),
              // Selection frame (top + bottom borders).
              Positioned(
                left: sx,
                width: (ex - sx).clamp(0.0, double.infinity),
                top: 0,
                bottom: 0,
                child: const DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.symmetric(
                      horizontal: BorderSide(color: AppColors.accent, width: 3),
                    ),
                  ),
                ),
              ),
              _handle(left: sx - hw, isStart: true),
              _handle(left: ex, isStart: false),
              // Playhead.
              Positioned(
                left: px - 1,
                top: -2,
                bottom: -2,
                width: 2,
                child: const DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.all(Radius.circular(1)),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  void _seek(double x, double track) =>
      widget.onSeek(_toTime(x - TrimBar.handleWidth, track));

  Widget _handle({required double left, required bool isStart}) {
    return Positioned(
      left: left,
      top: 0,
      bottom: 0,
      width: TrimBar.handleWidth,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.accent,
          borderRadius: BorderRadius.horizontal(
            left: isStart ? const Radius.circular(6) : Radius.zero,
            right: isStart ? Radius.zero : const Radius.circular(6),
          ),
        ),
        alignment: Alignment.center,
        child: Container(
          width: 2,
          height: 16,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(1),
          ),
        ),
      ),
    );
  }
}

/// "0:03" style formatting (m:ss, or h:mm:ss for long takes).
String formatClock(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes % 60;
  final s = (d.inSeconds % 60).toString().padLeft(2, '0');
  return h > 0 ? '$h:${m.toString().padLeft(2, '0')}:$s' : '$m:$s';
}
