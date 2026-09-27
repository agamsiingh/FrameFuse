import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';
import '../../../core/platform/native_media_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../projects/domain/project.dart';
import '../../projects/presentation/library_controller.dart';
import 'widgets/trim_bar.dart';

/// Post-capture review for one take.
///
/// Both formats are previewed live as center crops of the single master
/// video (one player → always in sync, no rendering needed). Trimming is
/// non-destructive; the 9:16 and 16:9 files are rendered on Save & Export
/// (or Share) with the chosen trim.
class ReviewScreen extends ConsumerStatefulWidget {
  const ReviewScreen({super.key});

  @override
  ConsumerState<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends ConsumerState<ReviewScreen> {
  String? _takeId;
  VideoPlayerController? _player;
  Size? _displaySize;
  String? _loadError;
  List<String> _frames = const [];

  // Live trim while dragging (persisted on release).
  Duration? _dragStart;
  Duration? _dragEnd;

  bool _working = false;
  double _progress = 0;
  String _progressMessage = '';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_takeId != null) return;
    final args = ModalRoute.of(context)?.settings.arguments;
    _takeId = args is String ? args : null;
    final take = _takeId == null ? null : ref.read(takeProvider(_takeId!));
    if (take != null && take.isVideo) {
      _initVideo(take, reloadFrames: false);
      // Filmstrip loads independently of the (slower) player start.
      ref.read(libraryProvider.notifier).filmstrip(take).then((frames) {
        if (mounted) setState(() => _frames = frames);
      });
    }
  }

  Future<void> _initVideo(Take take, {bool reloadFrames = true}) async {
    final native = ref.read(nativeMediaProvider);
    final library = ref.read(libraryProvider.notifier);
    try {
      // Poster geometry first, so the thumbnail can stand in immediately.
      if (_displaySize == null) {
        final info = await native.probeVideo(take.masterPath);
        if (mounted && info != null) {
          setState(() => _displaySize = Size(info.width.toDouble(), info.height.toDouble()));
        }
      }
      if (!await File(take.masterPath).exists()) {
        throw const NativeMediaException('The recording file is missing.');
      }
      final player = VideoPlayerController.file(File(take.masterPath));
      await player.initialize();
      await player.setLooping(false);
      await player.seekTo(take.effectiveStart);
      player.addListener(_onTick);
      if (!mounted) {
        await player.dispose();
        return;
      }
      setState(() {
        _player = player;
        _displaySize ??= _fallbackSize(player.value);
      });
      if (reloadFrames) {
        final frames = await library.filmstrip(take);
        if (mounted) setState(() => _frames = frames);
      }
    } catch (e) {
      if (mounted) setState(() => _loadError = e.toString());
    }
  }

  static Size _fallbackSize(VideoPlayerValue v) {
    final quarter = v.rotationCorrection % 180 != 0;
    return quarter ? Size(v.size.height, v.size.width) : v.size;
  }

  /// Keep playback inside the trim range.
  void _onTick() {
    final player = _player;
    final take = _take;
    if (player == null || take == null || !mounted) return;
    final end = _dragEnd ?? take.effectiveEnd;
    if (player.value.isPlaying && player.value.position >= end) {
      player.pause();
      player.seekTo(_dragStart ?? take.effectiveStart);
    }
    setState(() {});
  }

  @override
  void dispose() {
    _player?.removeListener(_onTick);
    _player?.dispose();
    super.dispose();
  }

  Take? get _take => _takeId == null ? null : ref.read(takeProvider(_takeId!));

  // ── Actions ────────────────────────────────────────────────────

  Future<void> _togglePlay() async {
    final player = _player;
    final take = _take;
    if (player == null || take == null) return;
    if (player.value.isPlaying) {
      await player.pause();
    } else {
      final pos = player.value.position;
      if (pos < take.effectiveStart || pos >= take.effectiveEnd - const Duration(milliseconds: 100)) {
        await player.seekTo(take.effectiveStart);
      }
      await player.play();
    }
  }

  /// Runs a render/export job. The preview player is released first so the
  /// exporter can use the hardware decoder (many phones only have one or
  /// two), then reloaded afterwards.
  Future<void> _runWithProgress(Future<void> Function() job) async {
    if (_working) return;
    setState(() {
      _working = true;
      _progress = 0;
      _progressMessage = 'Preparing...';
    });
    final hadPlayer = _player != null;
    await _releasePlayer();
    try {
      await job();
    } finally {
      if (mounted) {
        setState(() => _working = false);
        final take = _take;
        if (hadPlayer && take != null && take.isVideo) {
          await _initVideo(take, reloadFrames: false);
        }
      }
    }
  }

  Future<void> _releasePlayer() async {
    final player = _player;
    if (player == null) return;
    player.removeListener(_onTick);
    setState(() => _player = null);
    await player.dispose();
  }

  void _onProgress(double v, String m) {
    if (!mounted) return;
    setState(() {
      _progress = v;
      _progressMessage = m;
    });
  }

  Future<void> _export() async {
    final id = _takeId;
    if (id == null) return;
    final take = _take;
    if (take != null && take.isExported) {
      _toast('Already saved to your gallery.');
      return;
    }
    await _runWithProgress(() async {
      try {
        await ref.read(libraryProvider.notifier).exportToGallery(id, onProgress: _onProgress);
        _toast('Saved 9:16 and 16:9 to your gallery.');
      } catch (e) {
        _toast(_friendly(e, 'Export failed.'));
      }
    });
  }

  Future<void> _share() async {
    final id = _takeId;
    if (id == null) return;
    await _runWithProgress(() async {
      try {
        final take = _take!.isVideo
            ? await ref.read(libraryProvider.notifier).ensureRendered(id, onProgress: _onProgress)
            : _take!;
        if (!mounted) return;
        setState(() => _working = false);
        await Share.shareXFiles(
          [XFile(take.portraitPath), XFile(take.landscapePath)],
          text: 'Made with FrameFuse',
        );
      } catch (e) {
        _toast(_friendly(e, 'Could not prepare files to share.'));
      }
    });
  }

  Future<void> _cancelWork() async {
    await ref.read(nativeMediaProvider).cancelExport();
  }

  Future<void> _delete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this take?', style: TextStyle(fontSize: 18)),
        content: const Text(
          'The recording and both formats will be removed from FrameFuse. '
          'Copies already saved to your gallery are kept.',
          style: TextStyle(color: AppColors.textSecondary, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: AppColors.record)),
          ),
        ],
      ),
    );
    if (confirm != true || _takeId == null) return;
    await _player?.pause();
    await ref.read(libraryProvider.notifier).deleteTake(_takeId!);
    if (mounted) Navigator.of(context).pop();
  }

  void _toast(String message) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  String _friendly(Object e, String fallback) {
    if (e is NativeMediaException) {
      final m = e.message.toLowerCase();
      if (m.contains('cancel')) return 'Cancelled.';
      return e.message;
    }
    return fallback;
  }

  // ── Build ──────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final take = _takeId == null ? null : ref.watch(takeProvider(_takeId!));
    final breadcrumb = take == null
        ? ''
        : ref.watch(libraryProvider.select((l) => l.breadcrumbFor(take)));

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          SafeArea(
            child: take == null
                ? _missing()
                : Column(
                    children: [
                      _header(take, breadcrumb),
                      Expanded(child: _previews(take)),
                      if (take.isVideo) _transport(take),
                      _actions(take),
                    ],
                  ),
          ),
          if (_working) _progressOverlay(),
        ],
      ),
    );
  }

  Widget _missing() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('This take is no longer available.',
              style: TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _header(Take take, String breadcrumb) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 14, 12, 8),
      child: Row(
        children: [
          Material(
            color: AppColors.control,
            shape: const StadiumBorder(),
            child: InkWell(
              customBorder: const StadiumBorder(),
              onTap: () => Navigator.of(context).pop(),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                child: Text(
                  'Close',
                  style: TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w500),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              breadcrumb,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.3,
              ),
            ),
          ),
          Material(
            color: AppColors.control,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => ref.read(libraryProvider.notifier).toggleFavorite(take.id),
              child: SizedBox.square(
                dimension: 34,
                child: Icon(
                  take.favorite ? Icons.star_rounded : Icons.star_rounded,
                  color: take.favorite ? AppColors.accent : const Color(0xFF808082),
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _previews(Take take) {
    return LayoutBuilder(builder: (context, c) {
      const side = 9.5, gap = 13.0;
      final landW = c.maxWidth - side * 2;
      final landH = landW * 9 / 16;
      var portH = c.maxHeight - landH - gap - 8;
      var portW = portH * 9 / 16;
      if (portW > c.maxWidth * 0.56) {
        portW = c.maxWidth * 0.56;
        portH = portW * 16 / 9;
      }
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _frame(
            width: portW,
            height: portH,
            child: take.isVideo ? _videoCrop() : _photo(take.portraitPath),
          ),
          const SizedBox(height: gap),
          _frame(
            width: landW,
            height: landH,
            child: take.isVideo ? _videoCrop() : _photo(take.landscapePath),
          ),
        ],
      );
    });
  }

  Widget _frame({required double width, required double height, required Widget child}) {
    return GestureDetector(
      onTap: _togglePlay,
      child: Container(
        width: width,
        height: height,
        foregroundDecoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.accent.withValues(alpha: 0.75), width: 1),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: ColoredBox(color: const Color(0xFF0A0A0A), child: child),
        ),
      ),
    );
  }

  Widget _videoCrop() {
    final player = _player;
    final size = _displaySize;
    if (_loadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text(_loadError!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        ),
      );
    }
    if (player == null || size == null || !player.value.isInitialized) {
      final take = _take;
      final poster = take == null ? null : File(take.thumbnailPath);
      return Stack(
        fit: StackFit.expand,
        children: [
          if (poster != null && poster.existsSync())
            Image.file(poster, fit: BoxFit.cover, gaplessPlayback: true),
          const Center(
            child: SizedBox.square(dimension: 22, child: CircularProgressIndicator(strokeWidth: 2)),
          ),
        ],
      );
    }
    return FittedBox(
      fit: BoxFit.cover,
      clipBehavior: Clip.hardEdge,
      child: SizedBox(
        width: size.width,
        height: size.height,
        child: VideoPlayer(player),
      ),
    );
  }

  Widget _photo(String path) {
    return Image.file(
      File(path),
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => const Center(
        child: Icon(Icons.broken_image_outlined, color: AppColors.textTertiary),
      ),
    );
  }

  Widget _transport(Take take) {
    final player = _player;
    final start = _dragStart ?? take.effectiveStart;
    final end = _dragEnd ?? take.effectiveEnd;
    final position = player?.value.position ?? start;
    final playing = player?.value.isPlaying ?? false;
    const grey = TextStyle(color: AppColors.textSecondary, fontSize: 11, letterSpacing: 0.5);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: player == null ? null : _togglePlay,
                icon: Icon(playing ? Icons.pause : Icons.play_arrow, color: Colors.white, size: 26),
              ),
              Text(formatClock(start), style: grey),
              Expanded(
                child: Text(
                  formatClock(end - start),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.accent,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(formatClock(end), style: grey),
              const SizedBox(width: 6),
            ],
          ),
          const SizedBox(height: 6),
          LayoutBuilder(builder: (context, c) {
            const hw = TrimBar.handleWidth;
            final track = c.maxWidth - hw * 2;
            final total = take.duration.inMilliseconds;
            final f = total == 0 ? 0.0 : (position.inMilliseconds / total).clamp(0.0, 1.0);
            final x = (hw + track * f - 28).clamp(0.0, c.maxWidth - 56);
            return Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: EdgeInsets.only(left: x),
                child: Container(
                  width: 56,
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFF48484A),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Text(
                    formatClock(position),
                    style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w500),
                  ),
                ),
              ),
            );
          }),
          const SizedBox(height: 8),
          TrimBar(
            duration: take.duration,
            start: start,
            end: end,
            position: position,
            frames: _frames,
            onTrimChanged: (s, e) => setState(() {
              _dragStart = s;
              _dragEnd = e;
            }),
            onTrimEnd: (s, e) async {
              await ref.read(libraryProvider.notifier).setTrim(take.id, s, e);
              if (mounted) {
                setState(() {
                  _dragStart = null;
                  _dragEnd = null;
                });
              }
            },
            onSeek: (t) => player?.seekTo(t),
          ),
        ],
      ),
    );
  }

  Widget _actions(Take take) {
    final exported = take.isExported;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 18, 12, 14),
      child: Row(
        children: [
          _SquareAction(
            icon: Icons.delete,
            color: AppColors.record,
            tooltip: 'Delete take',
            onTap: _delete,
          ),
          const SizedBox(width: 10),
          _SquareAction(
            icon: Icons.share,
            color: Colors.white,
            tooltip: 'Share both formats',
            onTap: _share,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SizedBox(
              height: 44,
              child: FilledButton(
                onPressed: _export,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(44),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  textStyle: const TextStyle(fontFamily: 'WorkSans', fontSize: 14, fontWeight: FontWeight.w500, letterSpacing: 0.6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (exported) ...[
                      const Icon(Icons.check, size: 18),
                      const SizedBox(width: 6),
                    ],
                    Text(exported ? 'Saved to Gallery' : 'Save & Export'),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _progressOverlay() {
    return Positioned.fill(
      child: ColoredBox(
        color: AppColors.scrim,
        child: Center(
          child: Container(
            width: 260,
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 10),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _progressMessage,
                  style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: _progress <= 0 ? null : _progress,
                    minHeight: 6,
                    backgroundColor: AppColors.control,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${(_progress * 100).round()}%',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
                TextButton(
                  onPressed: _cancelWork,
                  child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SquareAction extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  const _SquareAction({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: AppColors.control,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: SizedBox.square(
            dimension: 44,
            child: Icon(icon, color: color, size: 20),
          ),
        ),
      ),
    );
  }
}
