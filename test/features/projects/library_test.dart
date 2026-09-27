import 'dart:io';
import 'package:frame_fuse/features/projects/data/library_store.dart';
import 'package:frame_fuse/features/projects/domain/project.dart';
import 'package:frame_fuse/features/projects/presentation/library_controller.dart';
import 'package:flutter_test/flutter_test.dart';

Take _take({
  String id = 't1',
  String projectId = 'p1',
  String scene = 'Untitled',
  int number = 1,
  Duration duration = const Duration(seconds: 10),
  Duration? trimStart,
  Duration? trimEnd,
  bool hasRenders = false,
  Duration? renderedStart,
  Duration? renderedEnd,
  DateTime? exportedAt,
  String dir = '/tmp/t1',
}) {
  return Take(
    id: id,
    projectId: projectId,
    scene: scene,
    number: number,
    type: TakeType.video,
    createdAt: DateTime(2026, 9, 23, 10, 30, 5),
    dir: dir,
    duration: duration,
    trimStart: trimStart,
    trimEnd: trimEnd,
    hasRenders: hasRenders,
    renderedStart: renderedStart,
    renderedEnd: renderedEnd,
    exportedAt: exportedAt,
  );
}

void main() {
  group('Take', () {
    test('label is zero-padded like the reference ("Take 002")', () {
      expect(_take(number: 2).label, 'Take 002');
      expect(_take(number: 123).label, 'Take 123');
    });

    test('trim defaults to the full clip', () {
      final t = _take();
      expect(t.effectiveStart, Duration.zero);
      expect(t.effectiveEnd, const Duration(seconds: 10));
      expect(t.isTrimmed, isFalse);
      expect(t.trimmedDuration, const Duration(seconds: 10));
    });

    test('renders go stale when the trim changes', () {
      final rendered = _take(
        hasRenders: true,
        renderedStart: Duration.zero,
        renderedEnd: const Duration(seconds: 10),
        exportedAt: DateTime(2026),
      );
      expect(rendered.rendersUpToDate, isTrue);
      expect(rendered.isExported, isTrue);

      final trimmed = rendered.copyWith(trimStart: const Duration(seconds: 2));
      expect(trimmed.rendersUpToDate, isFalse);
      expect(trimmed.isExported, isFalse);
    });

    test('copyWith can clear nullable fields', () {
      final t = _take(trimStart: const Duration(seconds: 1));
      expect(t.copyWith(trimStart: null).trimStart, isNull);
      expect(t.copyWith(favorite: true).trimStart, const Duration(seconds: 1));
    });

    test('JSON round trip keeps everything but the (runtime) dir', () {
      final t = _take(
        trimStart: const Duration(milliseconds: 1500),
        trimEnd: const Duration(seconds: 8),
        exportedAt: DateTime(2026, 1, 2),
      ).copyWith(favorite: true);
      final back = Take.fromJson(t.toJson(), dir: '/elsewhere');
      expect(back.id, t.id);
      expect(back.number, t.number);
      expect(back.trimStart, t.trimStart);
      expect(back.trimEnd, t.trimEnd);
      expect(back.favorite, isTrue);
      expect(back.exportedAt, t.exportedAt);
      expect(back.dir, '/elsewhere');
      expect(back.masterPath.endsWith('master.mp4'), isTrue);
    });
  });

  group('LibraryData', () {
    test('take numbers are per project + scene and never reuse lower numbers', () {
      final data = LibraryData(takes: [
        _take(id: 'a', number: 1),
        _take(id: 'b', number: 3),
        _take(id: 'c', number: 7, scene: 'Intro'),
        _take(id: 'd', number: 9, projectId: 'p2'),
      ]);
      expect(data.nextTakeNumber('p1', 'Untitled'), 4);
      expect(data.nextTakeNumber('p1', 'Intro'), 8);
      expect(data.nextTakeNumber('p1', 'New scene'), 1);
      expect(data.nextTakeNumber('p2', 'Untitled'), 10);
    });

    test('currentProject falls back to the first project', () {
      final a = Project(id: 'a', name: 'A', createdAt: DateTime(2026));
      final b = Project(id: 'b', name: 'B', createdAt: DateTime(2026));
      expect(LibraryData(projects: [a, b], currentProjectId: 'b').currentProject?.id, 'b');
      expect(LibraryData(projects: [a, b], currentProjectId: 'zzz').currentProject?.id, 'a');
      expect(const LibraryData().currentProject, isNull);
    });
  });

  group('LibraryStore', () {
    late Directory root;
    late LibraryStore store;

    setUp(() async {
      root = await Directory.systemTemp.createTemp('framefuse_test');
      store = LibraryStore(rootProvider: () async => root);
    });

    tearDown(() async {
      if (await root.exists()) await root.delete(recursive: true);
    });

    test('empty store loads as empty data', () async {
      final data = await store.load();
      expect(data.projects, isEmpty);
      expect(data.takes, isEmpty);
    });

    test('save + load round trip, dropping takes whose folder vanished', () async {
      final project = Project(id: 'p1', name: 'My Project', createdAt: DateTime(2026));
      final keepDir = await store.takeDirFor('keep');
      await Directory(keepDir).create(recursive: true);

      await store.save(LibraryData(
        projects: [project],
        takes: [
          _take(id: 'keep', dir: keepDir),
          _take(id: 'gone', number: 2, dir: await store.takeDirFor('gone')),
        ],
        currentProjectId: 'p1',
        currentScene: 'Intro',
      ));

      final loaded = await store.load();
      expect(loaded.projects.single.name, 'My Project');
      expect(loaded.takes.map((t) => t.id), ['keep']);
      expect(loaded.takes.single.dir, keepDir);
      expect(loaded.currentScene, 'Intro');
    });

    test('a corrupt library file is set aside instead of crashing', () async {
      await File('${root.path}/library.json').writeAsString('{not json');
      final data = await store.load();
      expect(data.takes, isEmpty);
      expect(await File('${root.path}/library.json.corrupt').exists(), isTrue);
    });

    test('deleteTakeFiles removes the take folder', () async {
      final dir = await store.takeDirFor('x');
      await Directory(dir).create(recursive: true);
      await File('$dir/master.mp4').writeAsString('data');
      await store.deleteTakeFiles(_take(id: 'x', dir: dir));
      expect(await Directory(dir).exists(), isFalse);
    });
  });

  test('export file names are filesystem-safe and descriptive', () {
    final name = LibraryNotifier.fileBaseNameForTest(
      'My Project!',
      _take(number: 2, scene: 'Intro / take'),
    );
    expect(name, 'My_Project_Intro_take_Take002_20260923_103005');
  });
}
