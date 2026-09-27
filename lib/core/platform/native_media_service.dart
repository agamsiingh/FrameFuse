import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Display size and duration of a video file (rotation already applied).
class VideoInfo {
  final int width;
  final int height;
  final Duration duration;

  const VideoInfo({
    required this.width,
    required this.height,
    required this.duration,
  });

  double get aspectRatio => height == 0 ? 1 : width / height;
}

/// Pixel sizes of a dual photo crop.
class PhotoCropResult {
  final int portraitWidth;
  final int portraitHeight;
  final int landscapeWidth;
  final int landscapeHeight;

  const PhotoCropResult(
    this.portraitWidth,
    this.portraitHeight,
    this.landscapeWidth,
    this.landscapeHeight,
  );
}

/// Thermal state as reported by Android's PowerManager.
enum ThermalLevel {
  unknown,
  none,
  light,
  moderate,
  severe,
  critical;

  static ThermalLevel fromStatus(int status) {
    if (status < 0) return ThermalLevel.unknown;
    switch (status) {
      case 0:
        return ThermalLevel.none;
      case 1:
        return ThermalLevel.light;
      case 2:
        return ThermalLevel.moderate;
      case 3:
        return ThermalLevel.severe;
      default:
        return ThermalLevel.critical;
    }
  }

  /// Worth telling the user about.
  bool get isHot => index >= ThermalLevel.moderate.index;
}

/// Dart façade over FrameFuse's native media layer (see `NativeBridge.kt`).
///
/// Every call degrades gracefully when the platform side is unavailable
/// (unit tests, non-Android), except operations whose whole purpose is
/// native work, which throw [NativeMediaException].
class NativeMediaService {
  static const MethodChannel _media = MethodChannel('com.framefuse/media');
  static const EventChannel _thermal = EventChannel('com.framefuse/thermal');

  final Map<String, void Function(double)> _progressListeners = {};
  bool _handlerInstalled = false;

  void _ensureHandler() {
    if (_handlerInstalled) return;
    _handlerInstalled = true;
    _media.setMethodCallHandler((call) async {
      if (call.method == 'exportProgress') {
        final args = Map<String, dynamic>.from(call.arguments as Map);
        final id = args['id'] as String? ?? '';
        final progress = (args['progress'] as num? ?? 0).toDouble() / 100.0;
        _progressListeners[id]?.call(progress.clamp(0.0, 1.0));
      }
      return null;
    });
  }

  /// Renders a center crop at [aspect] (width/height) of [input] into
  /// [output], trimmed to [start]..[end] when given. Resolves with [output].
  Future<String> exportVideo({
    required String id,
    required String input,
    required String output,
    required double aspect,
    Duration? start,
    Duration? end,
    void Function(double progress)? onProgress,
  }) async {
    _ensureHandler();
    if (onProgress != null) _progressListeners[id] = onProgress;
    try {
      final path = await _media.invokeMethod<String>('exportVideo', {
        'id': id,
        'input': input,
        'output': output,
        'aspect': aspect,
        'startMs': start?.inMilliseconds ?? 0,
        'endMs': end?.inMilliseconds ?? 0,
      });
      if (path == null) throw const NativeMediaException('Export returned no file');
      return path;
    } on PlatformException catch (e) {
      throw NativeMediaException(e.message ?? 'Export failed');
    } on MissingPluginException {
      throw const NativeMediaException('Video export is not available');
    } finally {
      _progressListeners.remove(id);
    }
  }

  Future<void> cancelExport() async {
    try {
      await _media.invokeMethod('cancelExport');
    } catch (_) {}
  }

  Future<VideoInfo?> probeVideo(String path) async {
    try {
      final map = await _media.invokeMapMethod<String, dynamic>(
        'probeVideo',
        {'path': path},
      );
      if (map == null) return null;
      return VideoInfo(
        width: (map['width'] as num).toInt(),
        height: (map['height'] as num).toInt(),
        duration: Duration(milliseconds: (map['durationMs'] as num).toInt()),
      );
    } catch (e) {
      debugPrint('NativeMediaService: probe failed: $e');
      return null;
    }
  }

  /// EXIF-aware 9:16 + 16:9 center crops of a captured photo.
  Future<PhotoCropResult> cropPhoto({
    required String source,
    required String portraitOut,
    required String landscapeOut,
    int quality = 95,
  }) async {
    try {
      final sizes = await _media.invokeListMethod<int>('cropPhoto', {
        'source': source,
        'portrait': portraitOut,
        'landscape': landscapeOut,
        'quality': quality,
      });
      if (sizes == null || sizes.length < 4) {
        throw const NativeMediaException('Photo crop returned no data');
      }
      return PhotoCropResult(sizes[0], sizes[1], sizes[2], sizes[3]);
    } on PlatformException catch (e) {
      throw NativeMediaException(e.message ?? 'Photo crop failed');
    } on MissingPluginException {
      throw const NativeMediaException('Photo crop is not available');
    }
  }

  /// Copies [path] into the shared gallery (Movies/ or Pictures/FrameFuse).
  Future<String> saveToGallery({
    required String path,
    required bool isVideo,
    required String displayName,
  }) async {
    try {
      final uri = await _media.invokeMethod<String>('saveToGallery', {
        'path': path,
        'isVideo': isVideo,
        'displayName': displayName,
      });
      if (uri == null) throw const NativeMediaException('Save returned no URI');
      return uri;
    } on PlatformException catch (e) {
      throw NativeMediaException(e.message ?? 'Could not save to gallery');
    } on MissingPluginException {
      throw const NativeMediaException('Gallery export is not available');
    }
  }

  /// Evenly spaced JPEG frames of a video, written into [outDir].
  Future<List<String>> extractThumbnails({
    required String path,
    required String outDir,
    int count = 8,
    int maxWidth = 240,
  }) async {
    try {
      final list = await _media.invokeListMethod<String>('extractThumbnails', {
        'path': path,
        'outDir': outDir,
        'count': count,
        'maxWidth': maxWidth,
      });
      return list ?? const [];
    } catch (e) {
      debugPrint('NativeMediaService: thumbnails failed: $e');
      return const [];
    }
  }

  /// Free bytes on the app's storage volume, or null if unknown.
  Future<int?> freeBytes() async {
    try {
      final v = await _media.invokeMethod<num>('getFreeBytes');
      return v?.toInt();
    } catch (_) {
      return null;
    }
  }

  /// Opens an https [url] in the user's browser. Returns false if no app
  /// can handle it.
  Future<bool> openUrl(String url) async {
    try {
      return await _media.invokeMethod<bool>('openUrl', {'url': url}) ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<int?> sdkInt() async {
    try {
      return await _media.invokeMethod<int>('getSdkInt');
    } catch (_) {
      return null;
    }
  }

  /// Thermal status stream. Emits [ThermalLevel.unknown] when unsupported.
  Stream<ThermalLevel> thermalStream() {
    return _thermal
        .receiveBroadcastStream()
        .map((e) => ThermalLevel.fromStatus((e as num).toInt()))
        .handleError((Object _) {});
  }
}

class NativeMediaException implements Exception {
  final String message;
  const NativeMediaException(this.message);

  @override
  String toString() => message;
}
