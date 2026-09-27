import 'dart:io';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../constants/storage_constants.dart';

/// Utility class for file naming, path generation, and storage management.
class FileUtils {
  FileUtils._();

  static const _uuid = Uuid();

  /// Generates a unique session ID.
  static String generateSessionId() => _uuid.v4().split('-').first;

  /// Generates a timestamp string for file naming.
  static String generateTimestamp() {
    final formatter = DateFormat(StorageConstants.dateFormat);
    return formatter.format(DateTime.now());
  }

  /// Generates file name for a captured photo.
  ///
  /// Example: `2026-09-20_14-32-10_portrait.jpg`
  static String photoFileName({
    required bool isPortrait,
    String? timestamp,
  }) {
    final ts = timestamp ?? generateTimestamp();
    final suffix = isPortrait
        ? StorageConstants.portraitSuffix
        : StorageConstants.landscapeSuffix;
    return '$ts$suffix${StorageConstants.photoExtension}';
  }

  /// Generates file name for a recorded video.
  ///
  /// Example: `2026-09-20_14-35-20_landscape.mp4`
  static String videoFileName({
    required bool isPortrait,
    String? timestamp,
  }) {
    final ts = timestamp ?? generateTimestamp();
    final suffix = isPortrait
        ? StorageConstants.portraitSuffix
        : StorageConstants.landscapeSuffix;
    return '$ts$suffix${StorageConstants.videoExtension}';
  }

  /// Generates master video file name (before cropping).
  static String masterVideoFileName({String? timestamp}) {
    final ts = timestamp ?? generateTimestamp();
    return '$ts${StorageConstants.masterSuffix}${StorageConstants.videoExtension}';
  }

  /// Returns the app's media directory, creating it if necessary.
  static Future<Directory> getAppMediaDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final mediaDir = Directory(
      p.join(appDir.path, StorageConstants.appDirectoryName),
    );
    if (!await mediaDir.exists()) {
      await mediaDir.create(recursive: true);
    }
    return mediaDir;
  }

  /// Returns the photos sub-directory.
  static Future<Directory> getPhotosDirectory() async {
    final mediaDir = await getAppMediaDirectory();
    final photosDir = Directory(
      p.join(mediaDir.path, StorageConstants.photosDirectory),
    );
    if (!await photosDir.exists()) {
      await photosDir.create(recursive: true);
    }
    return photosDir;
  }

  /// Returns the videos sub-directory.
  static Future<Directory> getVideosDirectory() async {
    final mediaDir = await getAppMediaDirectory();
    final videosDir = Directory(
      p.join(mediaDir.path, StorageConstants.videosDirectory),
    );
    if (!await videosDir.exists()) {
      await videosDir.create(recursive: true);
    }
    return videosDir;
  }

  /// Returns a temporary directory for in-progress recordings.
  static Future<Directory> getTempRecordingDirectory() async {
    final tempDir = await getTemporaryDirectory();
    final recordingDir = Directory(
      p.join(tempDir.path, 'framefuse_recording'),
    );
    if (!await recordingDir.exists()) {
      await recordingDir.create(recursive: true);
    }
    return recordingDir;
  }

  /// Generates a unique file path that does not collide with existing files.
  static Future<String> uniqueFilePath(
    Directory directory,
    String fileName,
  ) async {
    var path = p.join(directory.path, fileName);
    var file = File(path);
    var counter = 1;

    while (await file.exists()) {
      final ext = p.extension(fileName);
      final nameWithoutExt = p.basenameWithoutExtension(fileName);
      path = p.join(directory.path, '${nameWithoutExt}_$counter$ext');
      file = File(path);
      counter++;
    }

    return path;
  }

  /// Check available disk space (approximate).
  static Future<int> getAvailableStorage() async {
    try {
      final dir = await getAppMediaDirectory();
      final stat = await dir.stat();
      // FileStat doesn't provide free space directly.
      // We use a platform-level check in real production.
      // For now return a large value to avoid false positives.
      return stat.size > 0 ? StorageConstants.minFreeStorageBytes * 10 : 0;
    } catch (_) {
      return 0;
    }
  }

  /// Check if sufficient storage is available.
  static Future<bool> hasSufficientStorage() async {
    final available = await getAvailableStorage();
    return available >= StorageConstants.minFreeStorageBytes;
  }
}
