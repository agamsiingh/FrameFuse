import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../../../core/constants/storage_constants.dart';
import '../domain/project.dart';

/// JSON-file persistence for projects and takes.
///
/// Layout (inside the app's private documents directory):
/// ```
/// FrameFuse/
///   library.json
///   takes/<takeId>/master.mp4 | portrait.* | landscape.* | thumb.jpg
/// ```
/// Writes go to a temp file and are renamed into place, so a crash mid-write
/// can never corrupt the library.
class LibraryStore {
  final Future<Directory> Function() _rootProvider;
  Directory? _root;
  Future<void> _writeChain = Future.value();

  LibraryStore({Future<Directory> Function()? rootProvider})
      : _rootProvider = rootProvider ?? _defaultRoot;

  static Future<Directory> _defaultRoot() async {
    final docs = await getApplicationDocumentsDirectory();
    return Directory(p.join(docs.path, StorageConstants.appDirectoryName));
  }

  Future<Directory> root() async {
    final dir = _root ??= await _rootProvider();
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<File> _file() async => File(p.join((await root()).path, 'library.json'));

  Future<String> takeDirFor(String takeId) async =>
      p.join((await root()).path, 'takes', takeId);

  Future<LibraryData> load() async {
    final rootDir = await root();
    final file = await _file();
    if (!await file.exists()) return const LibraryData();

    try {
      final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      final projects = (json['projects'] as List? ?? const [])
          .map((e) => Project.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      final takes = <Take>[];
      for (final raw in (json['takes'] as List? ?? const [])) {
        final map = Map<String, dynamic>.from(raw as Map);
        final id = map['id'] as String?;
        if (id == null) continue;
        final dir = p.join(rootDir.path, 'takes', id);
        // Drop entries whose files were removed outside the app.
        if (!await Directory(dir).exists()) continue;
        takes.add(Take.fromJson(map, dir: dir));
      }
      return LibraryData(
        projects: projects,
        takes: takes,
        currentProjectId: json['currentProjectId'] as String?,
        currentScene:
            json['currentScene'] as String? ?? LibraryData.defaultScene,
      );
    } catch (e) {
      debugPrint('LibraryStore: corrupt library, starting fresh: $e');
      try {
        await file.rename('${file.path}.corrupt');
      } catch (_) {}
      return const LibraryData();
    }
  }

  /// Persist [data]. Calls are serialized in order.
  Future<void> save(LibraryData data) {
    final encoded = const JsonEncoder.withIndent(' ').convert(data.toJson());
    final next = _writeChain.then((_) async {
      final file = await _file();
      final tmp = File('${file.path}.tmp');
      await tmp.writeAsString(encoded, flush: true);
      await tmp.rename(file.path);
    });
    _writeChain = next.catchError((Object e) {
      debugPrint('LibraryStore: save failed: $e');
    });
    return next;
  }

  Future<void> deleteTakeFiles(Take take) async {
    final dir = Directory(take.dir);
    if (await dir.exists()) await dir.delete(recursive: true);
  }

  /// Move (or copy across volumes) [source] to [destination].
  static Future<void> moveFile(String source, String destination) async {
    await Directory(p.dirname(destination)).create(recursive: true);
    try {
      await File(source).rename(destination);
    } on FileSystemException {
      await File(source).copy(destination);
      try {
        await File(source).delete();
      } catch (_) {}
    }
  }
}
