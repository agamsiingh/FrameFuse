import 'dart:io';
import 'package:path/path.dart' as p;
import '../../../core/platform/native_media_service.dart';

/// Result of dual output processing.
class DualOutputResult {
  final String portraitPath;
  final String landscapePath;
  final Duration duration;

  const DualOutputResult({
    required this.portraitPath,
    required this.landscapePath,
    required this.duration,
  });
}

/// Renders the two deliverables (9:16 + 16:9) from one master capture.
///
/// Video: two sequential hardware exports through Media3 Transformer
/// (center crop + optional trim). Sequential, because many devices only
/// expose one or two hardware encoder instances.
/// Photo: one native, EXIF-aware decode producing both JPEG crops.
class DualOutputProcessor {
  static const double portraitAspect = 9 / 16;
  static const double landscapeAspect = 16 / 9;

  final NativeMediaService _native;

  DualOutputProcessor({NativeMediaService? native})
      : _native = native ?? NativeMediaService();

  /// Renders `portrait.mp4` and `landscape.mp4` into [outDir].
  ///
  /// [onProgress] reports 0..1 over both exports.
  Future<DualOutputResult> renderVideo({
    required String masterPath,
    required String outDir,
    Duration? trimStart,
    Duration? trimEnd,
    required Duration duration,
    void Function(double progress, String message)? onProgress,
  }) async {
    if (!await File(masterPath).exists()) {
      throw const NativeMediaException('The original recording is missing.');
    }
    await Directory(outDir).create(recursive: true);

    final portraitPath = p.join(outDir, 'portrait.mp4');
    final landscapePath = p.join(outDir, 'landscape.mp4');

    onProgress?.call(0.0, 'Rendering 9:16...');
    await _native.exportVideo(
      id: 'portrait',
      input: masterPath,
      output: portraitPath,
      aspect: portraitAspect,
      start: trimStart,
      end: trimEnd,
      onProgress: (v) => onProgress?.call(v * 0.5, 'Rendering 9:16...'),
    );

    onProgress?.call(0.5, 'Rendering 16:9...');
    await _native.exportVideo(
      id: 'landscape',
      input: masterPath,
      output: landscapePath,
      aspect: landscapeAspect,
      start: trimStart,
      end: trimEnd,
      onProgress: (v) => onProgress?.call(0.5 + v * 0.5, 'Rendering 16:9...'),
    );

    onProgress?.call(1.0, 'Done');
    final start = trimStart ?? Duration.zero;
    final end = trimEnd ?? duration;
    return DualOutputResult(
      portraitPath: portraitPath,
      landscapePath: landscapePath,
      duration: end - start,
    );
  }

  /// Writes `portrait.jpg` and `landscape.jpg` into [outDir].
  Future<DualOutputResult> renderPhoto({
    required String sourcePath,
    required String outDir,
  }) async {
    await Directory(outDir).create(recursive: true);
    final portraitPath = p.join(outDir, 'portrait.jpg');
    final landscapePath = p.join(outDir, 'landscape.jpg');
    await _native.cropPhoto(
      source: sourcePath,
      portraitOut: portraitPath,
      landscapeOut: landscapePath,
    );
    return DualOutputResult(
      portraitPath: portraitPath,
      landscapePath: landscapePath,
      duration: Duration.zero,
    );
  }
}
