/// Storage-related constants for FrameFuse.
class StorageConstants {
  StorageConstants._();

  /// Root directory name inside the device's media/pictures folder.
  static const String appDirectoryName = 'FrameFuse';

  /// Sub-directories
  static const String photosDirectory = 'Photos';
  static const String videosDirectory = 'Videos';

  /// File extensions
  static const String photoExtension = '.jpg';
  static const String videoExtension = '.mp4';

  /// File name patterns
  static const String portraitSuffix = '_portrait';
  static const String landscapeSuffix = '_landscape';
  static const String masterSuffix = '_master';
  static const String dateFormat = 'yyyy-MM-dd_HH-mm-ss';

  /// JPEG quality (0-100)
  static const int photoQuality = 95;

  /// Minimum free storage required to start recording (in bytes) — 100 MB
  static const int minFreeStorageBytes = 100 * 1024 * 1024;

  /// Low storage warning threshold (in bytes) — 500 MB
  static const int lowStorageWarningBytes = 500 * 1024 * 1024;

  /// MIME types
  static const String jpegMimeType = 'image/jpeg';
  static const String mp4MimeType = 'video/mp4';
}
