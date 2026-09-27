import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../core/permissions/permission_handler.dart';
import '../../../core/platform/native_media_service.dart';
import '../../recording/data/dual_output_processor.dart';
import '../../recording/data/recording_service.dart';
import '../data/library_store.dart';
import '../domain/project.dart';

final nativeMediaProvider = Provider<NativeMediaService>((ref) {
  return NativeMediaService();
});

final libraryStoreProvider = Provider<LibraryStore>((ref) => LibraryStore());

final dualOutputProcessorProvider = Provider<DualOutputProcessor>((ref) {
  return DualOutputProcessor(native: ref.watch(nativeMediaProvider));
});

final libraryProvider =
    StateNotifierProvider<LibraryNotifier, LibraryState>((ref) {
  final notifier = LibraryNotifier(
    store: ref.watch(libraryStoreProvider),
    native: ref.watch(nativeMediaProvider),
    processor: ref.watch(dualOutputProcessorProvider),
  );
  notifier.load();
  return notifier;
});

/// Convenience: a single take by id (null once deleted).
final takeProvider = Provider.family<Take?, String>((ref, id) {
  return ref.watch(libraryProvider).data.takeById(id);
});

class LibraryState {
  final LibraryData data;
  final bool isLoaded;

  const LibraryState({this.data = const LibraryData(), this.isLoaded = false});

  Project? get currentProject => data.currentProject;
  String get currentScene => data.currentScene;

  /// "My Project / Untitled"
  String get currentLabel =>
      '${currentProject?.name ?? LibraryData.defaultProjectName} / $currentScene';

  String breadcrumbFor(Take take) {
    final project = data.projects.where((p) => p.id == take.projectId);
    final name = project.isEmpty ? '' : project.first.name;
    return '$name / ${take.scene} / ${take.label}';
  }

  LibraryState copyWith({LibraryData? data, bool? isLoaded}) => LibraryState(
        data: data ?? this.data,
        isLoaded: isLoaded ?? this.isLoaded,
      );
}

/// Owns projects and takes: creation from captures, trim/favorite edits,
/// rendering the deliverables and exporting them to the shared gallery.
class LibraryNotifier extends StateNotifier<LibraryState> {
  final LibraryStore _store;
  final NativeMediaService _native;
  final DualOutputProcessor _processor;
  static const _uuid = Uuid();
  Completer<void>? _loading;

  LibraryNotifier({
    required LibraryStore store,
    required NativeMediaService native,
    required DualOutputProcessor processor,
  })  : _store = store,
        _native = native,
        _processor = processor,
        super(const LibraryState());

  Future<void> load() {
    final existing = _loading;
    if (existing != null) return existing.future;
    final completer = _loading = Completer<void>();
    () async {
      try {
        var data = await _store.load();
        if (data.projects.isEmpty) {
          final project = _newProject(LibraryData.defaultProjectName);
          data = data.copyWith(projects: [project], currentProjectId: project.id);
          await _store.save(data);
        } else if (data.currentProject?.id != data.currentProjectId) {
          data = data.copyWith(currentProjectId: data.currentProject!.id);
        }
        if (mounted) state = LibraryState(data: data, isLoaded: true);
      } catch (e) {
        debugPrint('LibraryNotifier: load failed: $e');
        final project = _newProject(LibraryData.defaultProjectName);
        if (mounted) {
          state = LibraryState(
            data: LibraryData(projects: [project], currentProjectId: project.id),
            isLoaded: true,
          );
        }
      } finally {
        completer.complete();
      }
    }();
    return completer.future;
  }

  Project _newProject(String name) =>
      Project(id: _uuid.v4(), name: name, createdAt: DateTime.now());

  Future<void> _commit(LibraryData data) async {
    state = state.copyWith(data: data);
    await _store.save(data);
  }

  // ── Projects ────────────────────────────────────────────────────

  Future<Project> createProject(String name) async {
    await load();
    final project = _newProject(name.trim().isEmpty ? 'Untitled Project' : name.trim());
    await _commit(state.data.copyWith(
      projects: [...state.data.projects, project],
      currentProjectId: project.id,
      currentScene: LibraryData.defaultScene,
    ));
    return project;
  }

  Future<void> renameProject(String projectId, String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    await _commit(state.data.copyWith(
      projects: [
        for (final p in state.data.projects)
          p.id == projectId ? p.copyWith(name: trimmed) : p,
      ],
    ));
  }

  Future<void> selectProject(String projectId) =>
      _commit(state.data.copyWith(currentProjectId: projectId));

  Future<void> setScene(String scene) {
    final trimmed = scene.trim();
    return _commit(state.data.copyWith(
      currentScene: trimmed.isEmpty ? LibraryData.defaultScene : trimmed,
    ));
  }

  Future<void> deleteProject(String projectId) async {
    final doomed = state.data.takes.where((t) => t.projectId == projectId);
    for (final take in doomed) {
      await _store.deleteTakeFiles(take);
    }
    var projects = state.data.projects.where((p) => p.id != projectId).toList();
    if (projects.isEmpty) projects = [_newProject(LibraryData.defaultProjectName)];
    await _commit(LibraryData(
      projects: projects,
      takes: state.data.takes.where((t) => t.projectId != projectId).toList(),
      currentProjectId: state.data.currentProjectId == projectId
          ? projects.first.id
          : state.data.currentProjectId,
      currentScene: state.data.currentScene,
    ));
  }

  // ── Takes ───────────────────────────────────────────────────────

  Future<Take> _createTakeShell(TakeType type) async {
    await load();
    final project = state.currentProject!;
    final id = _uuid.v4();
    final dir = await _store.takeDirFor(id);
    await Directory(dir).create(recursive: true);
    return Take(
      id: id,
      projectId: project.id,
      scene: state.currentScene,
      number: state.data.nextTakeNumber(project.id, state.currentScene),
      type: type,
      createdAt: DateTime.now(),
      dir: dir,
    );
  }

  /// Store a finished master recording as a new take.
  Future<Take> addVideoTake(RecordedClip clip) async {
    var take = await _createTakeShell(TakeType.video);
    await LibraryStore.moveFile(clip.path, take.masterPath);

    // Prefer the container's duration over the UI stopwatch.
    final info = await _native.probeVideo(take.masterPath);
    take = take.copyWith(duration: info?.duration ?? clip.duration);

    await _commit(state.data.copyWith(takes: [...state.data.takes, take]));
    unawaited(_makeThumbnail(take));
    return take;
  }

  /// Crop a captured photo into both formats and store it as a new take.
  Future<Take> addPhotoTake(String sourcePath) async {
    final take = await _createTakeShell(TakeType.photo);
    try {
      await _processor.renderPhoto(sourcePath: sourcePath, outDir: take.dir);
    } catch (e) {
      await _store.deleteTakeFiles(take);
      rethrow;
    } finally {
      try {
        await File(sourcePath).delete();
      } catch (_) {}
    }
    await _commit(state.data.copyWith(takes: [...state.data.takes, take]));
    return take;
  }

  Future<void> _makeThumbnail(Take take) async {
    if (!take.isVideo) return;
    final frames = await _native.extractThumbnails(
      path: take.masterPath,
      outDir: take.dir,
      count: 1,
      maxWidth: 360,
    );
    if (frames.isNotEmpty) {
      try {
        await File(frames.first).rename(take.thumbnailPath);
      } catch (_) {}
      _touch(take.id);
    }
  }

  /// Filmstrip frames for the trim bar (cached per take).
  Future<List<String>> filmstrip(Take take, {int count = 8}) async {
    if (!take.isVideo) return const [];
    final dir = Directory(take.filmstripPath);
    if (await dir.exists()) {
      final files = (await dir.list().toList())
          .whereType<File>()
          .map((f) => f.path)
          .where((f) => f.endsWith('.jpg'))
          .toList()
        ..sort();
      if (files.length >= count) return files;
    }
    return _native.extractThumbnails(
      path: take.masterPath,
      outDir: take.filmstripPath,
      count: count,
      maxWidth: 160,
    );
  }

  /// Forces listeners (e.g. thumbnails) to rebuild after file changes.
  void _touch(String takeId) {
    if (!mounted) return;
    state = state.copyWith(data: state.data.copyWith(takes: [...state.data.takes]));
  }

  Future<void> _updateTake(String id, Take Function(Take) update) async {
    await _commit(state.data.copyWith(takes: [
      for (final t in state.data.takes) t.id == id ? update(t) : t,
    ]));
  }

  Future<void> toggleFavorite(String takeId) =>
      _updateTake(takeId, (t) => t.copyWith(favorite: !t.favorite));

  Future<void> setTrim(String takeId, Duration start, Duration end) {
    return _updateTake(takeId, (t) {
      final s = start <= Duration.zero ? null : start;
      final e = end >= t.duration ? null : end;
      return t.copyWith(trimStart: s, trimEnd: e);
    });
  }

  Future<void> deleteTake(String takeId) async {
    final take = state.data.takeById(takeId);
    if (take == null) return;
    await _store.deleteTakeFiles(take);
    await _commit(state.data.copyWith(
      takes: state.data.takes.where((t) => t.id != takeId).toList(),
    ));
  }

  /// Make sure the 9:16 and 16:9 files exist for the current trim.
  Future<Take> ensureRendered(
    String takeId, {
    void Function(double progress, String message)? onProgress,
  }) async {
    var take = state.data.takeById(takeId);
    if (take == null) throw const NativeMediaException('This take was deleted.');
    if (take.rendersUpToDate &&
        await File(take.portraitPath).exists() &&
        await File(take.landscapePath).exists()) {
      return take;
    }

    await _processor.renderVideo(
      masterPath: take.masterPath,
      outDir: take.dir,
      trimStart: take.trimStart,
      trimEnd: take.trimEnd,
      duration: take.duration,
      onProgress: onProgress,
    );
    await _updateTake(
      takeId,
      (t) => t.copyWith(
        hasRenders: true,
        renderedStart: take!.effectiveStart,
        renderedEnd: take.effectiveEnd,
        exportedAt: null,
      ),
    );
    take = state.data.takeById(takeId)!;
    return take;
  }

  /// Render (if needed) and copy both deliverables to the shared gallery.
  Future<void> exportToGallery(
    String takeId, {
    void Function(double progress, String message)? onProgress,
  }) async {
    final take = await ensureRendered(
      takeId,
      onProgress: (v, m) => onProgress?.call(v * 0.9, m),
    );

    final sdk = await _native.sdkInt();
    if (sdk != null && sdk < 29) {
      final ok = await AppPermissionHandler.requestLegacyStorage();
      if (!ok) {
        throw const NativeMediaException(
          'Storage permission is needed to save to your gallery.',
        );
      }
    }

    onProgress?.call(0.92, 'Saving to gallery...');
    final project = state.data.projects.where((p) => p.id == take.projectId);
    final base = _fileBaseName(
      project.isEmpty ? 'FrameFuse' : project.first.name,
      take,
    );
    final ext = take.isVideo ? 'mp4' : 'jpg';
    await _native.saveToGallery(
      path: take.portraitPath,
      isVideo: take.isVideo,
      displayName: '${base}_9x16.$ext',
    );
    await _native.saveToGallery(
      path: take.landscapePath,
      isVideo: take.isVideo,
      displayName: '${base}_16x9.$ext',
    );
    await _updateTake(takeId, (t) => t.copyWith(exportedAt: DateTime.now()));
    onProgress?.call(1.0, 'Saved');
  }

  static String _fileBaseName(String projectName, Take take) {
    String clean(String s) =>
        s.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_').replaceAll(RegExp(r'^_+|_+$'), '');
    final stamp = DateFormat('yyyyMMdd_HHmmss').format(take.createdAt);
    final parts = [clean(projectName), clean(take.scene), 'Take${take.number.toString().padLeft(3, '0')}', stamp]
        .where((s) => s.isNotEmpty);
    return parts.join('_');
  }

  @visibleForTesting
  static String fileBaseNameForTest(String projectName, Take take) =>
      _fileBaseName(projectName, take);
}
