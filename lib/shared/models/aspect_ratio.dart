/// Aspect ratio model for dual-output framing.
enum OutputAspectRatio {
  portrait(
    label: 'Portrait 9:16',
    widthRatio: 9,
    heightRatio: 16,
    platforms: ['YouTube Shorts', 'Instagram Reels', 'TikTok', 'WhatsApp Status'],
  ),
  landscape(
    label: 'Landscape 16:9',
    widthRatio: 16,
    heightRatio: 9,
    platforms: ['YouTube', 'Desktop Video', 'Presentations'],
  );

  final String label;
  final int widthRatio;
  final int heightRatio;
  final List<String> platforms;

  const OutputAspectRatio({
    required this.label,
    required this.widthRatio,
    required this.heightRatio,
    required this.platforms,
  });

  double get value => widthRatio / heightRatio;
  bool get isPortrait => widthRatio < heightRatio;
  bool get isLandscape => widthRatio > heightRatio;
}

/// Preview mode during camera operation.
enum PreviewMode {
  dual('Dual Preview'),
  portrait('Portrait Only'),
  landscape('Landscape Only');

  final String label;
  const PreviewMode(this.label);
}
