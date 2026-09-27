import 'package:path/path.dart' as p;

/// A named collection of takes (e.g. "My Project").
class Project {
  final String id;
  final String name;
  final DateTime createdAt;

  const Project({
    required this.id,
    required this.name,
    required this.createdAt,
  });

  Project copyWith({String? name}) =>
      Project(id: id, name: name ?? this.name, createdAt: createdAt);

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Project.fromJson(Map<String, dynamic> json) => Project(
        id: json['id'] as String,
        name: json['name'] as String? ?? 'Untitled Project',
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
            DateTime.now(),
      );
}

enum TakeType { video, photo }

const Object _unset = Object();

/// One press of the shutter: a master video (or a dual-cropped photo) plus
/// its rendered 9:16 / 16:9 deliverables once exported.
///
/// All files live in [dir]; only file *names* are persisted so the library
/// survives app-data path changes.
class Take {
  static const masterFile = 'master.mp4';
  static const portraitVideoFile = 'portrait.mp4';
  static const landscapeVideoFile = 'landscape.mp4';
  static const portraitPhotoFile = 'portrait.jpg';
  static const landscapePhotoFile = 'landscape.jpg';
  static const thumbnailFile = 'thumb.jpg';
  static const filmstripDir = 'filmstrip';

  final String id;
  final String projectId;
  final String scene;
  final int number;
  final TakeType type;
  final DateTime createdAt;
  final Duration duration;

  /// Trim selection; null means "from start" / "to end".
  final Duration? trimStart;
  final Duration? trimEnd;

  final bool favorite;

  /// Trim range the files in [dir] were last rendered with (videos only).
  final Duration? renderedStart;
  final Duration? renderedEnd;
  final bool hasRenders;

  /// When the deliverables were last copied to the shared gallery.
  final DateTime? exportedAt;

  /// Absolute folder containing this take's files (not persisted).
  final String dir;

  const Take({
    required this.id,
    required this.projectId,
    required this.scene,
    required this.number,
    required this.type,
    required this.createdAt,
    required this.dir,
    this.duration = Duration.zero,
    this.trimStart,
    this.trimEnd,
    this.favorite = false,
    this.renderedStart,
    this.renderedEnd,
    this.hasRenders = false,
    this.exportedAt,
  });

  bool get isVideo => type == TakeType.video;
  bool get isPhoto => type == TakeType.photo;

  String get label => 'Take ${number.toString().padLeft(3, '0')}';

  String get masterPath => p.join(dir, masterFile);
  String get thumbnailPath => p.join(dir, thumbnailFile);
  String get filmstripPath => p.join(dir, filmstripDir);

  String get portraitPath =>
      p.join(dir, isVideo ? portraitVideoFile : portraitPhotoFile);
  String get landscapePath =>
      p.join(dir, isVideo ? landscapeVideoFile : landscapePhotoFile);

  Duration get effectiveStart => trimStart ?? Duration.zero;
  Duration get effectiveEnd => trimEnd ?? duration;
  Duration get trimmedDuration => effectiveEnd - effectiveStart;
  bool get isTrimmed =>
      effectiveStart > Duration.zero || effectiveEnd < duration;

  /// Whether rendered files exist and match the current trim.
  bool get rendersUpToDate {
    if (isPhoto) return true;
    return hasRenders &&
        renderedStart == effectiveStart &&
        renderedEnd == effectiveEnd;
  }

  bool get isExported => exportedAt != null && rendersUpToDate;

  Take copyWith({
    String? projectId,
    String? scene,
    Duration? duration,
    Object? trimStart = _unset,
    Object? trimEnd = _unset,
    bool? favorite,
    Object? renderedStart = _unset,
    Object? renderedEnd = _unset,
    bool? hasRenders,
    Object? exportedAt = _unset,
  }) {
    return Take(
      id: id,
      projectId: projectId ?? this.projectId,
      scene: scene ?? this.scene,
      number: number,
      type: type,
      createdAt: createdAt,
      dir: dir,
      duration: duration ?? this.duration,
      trimStart:
          identical(trimStart, _unset) ? this.trimStart : trimStart as Duration?,
      trimEnd: identical(trimEnd, _unset) ? this.trimEnd : trimEnd as Duration?,
      favorite: favorite ?? this.favorite,
      renderedStart: identical(renderedStart, _unset)
          ? this.renderedStart
          : renderedStart as Duration?,
      renderedEnd: identical(renderedEnd, _unset)
          ? this.renderedEnd
          : renderedEnd as Duration?,
      hasRenders: hasRenders ?? this.hasRenders,
      exportedAt: identical(exportedAt, _unset)
          ? this.exportedAt
          : exportedAt as DateTime?,
    );
  }

  static int? _ms(Duration? d) => d?.inMilliseconds;
  static Duration? _dur(Object? v) =>
      v == null ? null : Duration(milliseconds: (v as num).toInt());

  Map<String, dynamic> toJson() => {
        'id': id,
        'projectId': projectId,
        'scene': scene,
        'number': number,
        'type': type.name,
        'createdAt': createdAt.toIso8601String(),
        'durationMs': duration.inMilliseconds,
        'trimStartMs': _ms(trimStart),
        'trimEndMs': _ms(trimEnd),
        'favorite': favorite,
        'renderedStartMs': _ms(renderedStart),
        'renderedEndMs': _ms(renderedEnd),
        'hasRenders': hasRenders,
        'exportedAt': exportedAt?.toIso8601String(),
      };

  factory Take.fromJson(Map<String, dynamic> json, {required String dir}) {
    return Take(
      id: json['id'] as String,
      projectId: json['projectId'] as String,
      scene: json['scene'] as String? ?? 'Untitled',
      number: (json['number'] as num?)?.toInt() ?? 1,
      type: json['type'] == 'photo' ? TakeType.photo : TakeType.video,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      dir: dir,
      duration: _dur(json['durationMs']) ?? Duration.zero,
      trimStart: _dur(json['trimStartMs']),
      trimEnd: _dur(json['trimEndMs']),
      favorite: json['favorite'] as bool? ?? false,
      renderedStart: _dur(json['renderedStartMs']),
      renderedEnd: _dur(json['renderedEndMs']),
      hasRenders: json['hasRenders'] as bool? ?? false,
      exportedAt: DateTime.tryParse(json['exportedAt'] as String? ?? ''),
    );
  }
}

/// Everything the library persists.
class LibraryData {
  final List<Project> projects;
  final List<Take> takes;
  final String? currentProjectId;
  final String currentScene;

  const LibraryData({
    this.projects = const [],
    this.takes = const [],
    this.currentProjectId,
    this.currentScene = defaultScene,
  });

  static const defaultScene = 'Untitled';
  static const defaultProjectName = 'My Project';

  Project? get currentProject {
    for (final project in projects) {
      if (project.id == currentProjectId) return project;
    }
    return projects.isEmpty ? null : projects.first;
  }

  List<Take> takesFor(String projectId) {
    final list = takes.where((t) => t.projectId == projectId).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  Take? takeById(String id) {
    for (final take in takes) {
      if (take.id == id) return take;
    }
    return null;
  }

  /// Next take number within a project + scene (1-based, never reused
  /// while a higher-numbered take exists).
  int nextTakeNumber(String projectId, String scene) {
    var maxNumber = 0;
    for (final t in takes) {
      if (t.projectId == projectId && t.scene == scene && t.number > maxNumber) {
        maxNumber = t.number;
      }
    }
    return maxNumber + 1;
  }

  LibraryData copyWith({
    List<Project>? projects,
    List<Take>? takes,
    String? currentProjectId,
    String? currentScene,
  }) {
    return LibraryData(
      projects: projects ?? this.projects,
      takes: takes ?? this.takes,
      currentProjectId: currentProjectId ?? this.currentProjectId,
      currentScene: currentScene ?? this.currentScene,
    );
  }

  Map<String, dynamic> toJson() => {
        'version': 1,
        'currentProjectId': currentProjectId,
        'currentScene': currentScene,
        'projects': projects.map((p) => p.toJson()).toList(),
        'takes': takes.map((t) => t.toJson()).toList(),
      };
}
