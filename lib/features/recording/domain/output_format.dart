/// Output format specification for dual-output generation.
class OutputFormat {
  final int width;
  final int height;
  final int fps;
  final int videoBitrate;
  final int audioBitrate;
  final String codec;

  const OutputFormat({
    required this.width,
    required this.height,
    this.fps = 30,
    this.videoBitrate = 10000000, // 10 Mbps
    this.audioBitrate = 128000,   // 128 kbps
    this.codec = 'h264',
  });

  double get aspectRatio => width / height;
  bool get isPortrait => width < height;
  bool get isLandscape => width > height;

  /// Standard portrait format (1080×1920).
  static const OutputFormat portrait1080 = OutputFormat(
    width: 1080,
    height: 1920,
    videoBitrate: 8000000,
  );

  /// Standard landscape format (1920×1080).
  static const OutputFormat landscape1080 = OutputFormat(
    width: 1920,
    height: 1080,
    videoBitrate: 8000000,
  );

  /// 4K portrait format (2160×3840).
  static const OutputFormat portrait4K = OutputFormat(
    width: 2160,
    height: 3840,
    videoBitrate: 35000000,
  );

  /// 4K landscape format (3840×2160).
  static const OutputFormat landscape4K = OutputFormat(
    width: 3840,
    height: 2160,
    videoBitrate: 35000000,
  );

  @override
  String toString() => '$width×$height @${fps}fps';
}
