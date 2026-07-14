import 'dart:convert';
import 'dart:io';

import 'package:edmm/data/repositories/file_local_library_repository.dart';
import 'package:edmm/domain/models/track.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Track _track(String id) => Track(
  id: id,
  source: 'cloudinary',
  title: id,
  artistId: 'artist-$id',
  artistName: 'Artist $id',
  durationMs: 1234,
  streamUrl: 'https://example.com/$id',
  metadata: const {},
);

class _ReadFailingFile implements File {
  @override
  Future<bool> exists() async => true;

  @override
  Future<String> readAsString({Encoding encoding = utf8}) async {
    throw FileSystemException('read failed', 'unreadable-library.json');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _RenameFailingFile implements File {
  _RenameFailingFile(this._delegate, {required this.failRename});

  final File _delegate;
  final bool failRename;

  @override
  String get path => _delegate.path;

  @override
  Directory get parent => _delegate.parent;

  @override
  Future<bool> exists() => _delegate.exists();

  @override
  Future<String> readAsString({Encoding encoding = utf8}) =>
      _delegate.readAsString(encoding: encoding);

  @override
  Future<File> writeAsString(
    String contents, {
    FileMode mode = FileMode.write,
    Encoding encoding = utf8,
    bool flush = false,
  }) async {
    await _delegate.writeAsString(
      contents,
      mode: mode,
      encoding: encoding,
      flush: flush,
    );
    return this;
  }

  @override
  Future<FileSystemEntity> delete({bool recursive = false}) =>
      _delegate.delete(recursive: recursive);

  @override
  Future<File> rename(String newPath) async {
    if (failRename) {
      throw FileSystemException('rename failed', path);
    }
    await _delegate.rename(newPath);
    return this;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('FileLocalLibraryRepository', () {
    test('persists and restores recents, cache, and settings', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final dir = await Directory.systemTemp.createTemp(
        'edmm-file-local-library-repo-',
      );
      final file = File('${dir.path}/edmm_local_library.json');
      addTearDown(() => dir.delete(recursive: true));

      final repo = await FileLocalLibraryRepository.open(
        filePath: file.path,
        prefs: prefs,
      );

      await repo.recordRecentPlay('track-1');
      await repo.recordRecentPlay('track-2');

      await repo.cacheTrack(_track('track-1'));
      await repo.cacheTrack(_track('track-2'));

      await repo.setAudioSetting('shuffle', 'true');

      final reopen = await FileLocalLibraryRepository.open(
        filePath: file.path,
        prefs: prefs,
      );

      expect(await reopen.getRecentTrackIds(), ['track-2', 'track-1']);
      expect((await reopen.getCachedTrack('track-2'))?.id, 'track-2');
      expect(await reopen.getAudioSetting('shuffle'), 'true');
    });

    test(
      'purges legacy favorites and playlists on open while preserving data',
      () async {
        SharedPreferences.setMockInitialValues({
          'audio_setting:shuffle': 'true',
        });
        final prefs = await SharedPreferences.getInstance();
        final dir = await Directory.systemTemp.createTemp(
          'edmm-file-local-library-legacy-purge-',
        );
        final file = File('${dir.path}/edmm_local_library.json');
        addTearDown(() => dir.delete(recursive: true));
        await file.writeAsString(
          jsonEncode({
            'favorites': {'legacy-favorite': 100},
            'playlists': [
              {
                'id': 7,
                'name': 'Legacy mix',
                'createdAt': 200,
                'trackIds': ['track-1'],
              },
            ],
            'nextPlaylistId': 8,
            'recentTrackIds': ['track-2', 'track-1'],
            'trackCache': {
              'track-1': _track('track-1').toJson(),
              'track-2': _track('track-2').toJson(),
            },
          }),
          flush: true,
        );

        final repo = await FileLocalLibraryRepository.open(
          filePath: file.path,
          prefs: prefs,
        );

        expect(await repo.getRecentTrackIds(), ['track-2', 'track-1']);
        expect(
          (await repo.getCachedTracks([
            'track-1',
            'track-2',
          ])).map((track) => track.id),
          ['track-1', 'track-2'],
        );
        expect(await repo.getAudioSetting('shuffle'), 'true');

        final migrated =
            jsonDecode(await file.readAsString()) as Map<String, dynamic>;
        expect(migrated['schemaVersion'], 2);
        expect(migrated, isNot(contains('favorites')));
        expect(migrated, isNot(contains('playlists')));
        expect(migrated, isNot(contains('nextPlaylistId')));
        expect(migrated['recentTrackIds'], ['track-2', 'track-1']);
        expect(
          (migrated['trackCache'] as Map<String, dynamic>).keys,
          containsAll(['track-1', 'track-2']),
        );
      },
    );

    test('handles corrupted JSON file safely without throwing', () async {
      SharedPreferences.setMockInitialValues({
        'audio_setting:shuffle': 'false',
      });
      final prefs = await SharedPreferences.getInstance();

      final dir = await Directory.systemTemp.createTemp(
        'edmm-file-local-library-corrupt-',
      );
      final file = File('${dir.path}/edmm_local_library.json');
      await file.writeAsString('{not-json}', flush: true);
      addTearDown(() => dir.delete(recursive: true));

      final repo = await FileLocalLibraryRepository.open(
        filePath: file.path,
        prefs: prefs,
      );

      expect(await repo.getRecentTrackIds(), isEmpty);
      expect(await repo.getCachedTrack('any'), isNull);
      expect(await repo.getAudioSetting('shuffle'), 'false');

      await repo.recordRecentPlay('track-safe');
      expect(await repo.getRecentTrackIds(), ['track-safe']);
    });

    test('surfaces file read failures while opening', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      await expectLater(
        IOOverrides.runZoned(
          () => FileLocalLibraryRepository.open(
            filePath: 'unreadable-library.json',
            prefs: prefs,
          ),
          createFile: (_) => _ReadFailingFile(),
        ),
        throwsA(isA<FileSystemException>()),
      );
    });

    test('surfaces persistence failures from runtime writes', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final dir = await Directory.systemTemp.createTemp(
        'edmm-file-local-library-write-failure-',
      );
      addTearDown(() => dir.delete(recursive: true));
      final blockingFile = File('${dir.path}/not-a-directory');
      await blockingFile.writeAsString('blocking parent');
      final repo = await FileLocalLibraryRepository.open(
        filePath: '${blockingFile.path}/library.json',
        prefs: prefs,
      );

      await expectLater(
        repo.recordRecentPlay('track-1'),
        throwsA(isA<FileSystemException>()),
      );
    });

    test('serializes concurrent writes and persists every update', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final dir = await Directory.systemTemp.createTemp(
        'edmm-file-local-library-concurrent-writes-',
      );
      final file = File('${dir.path}/edmm_local_library.json');
      addTearDown(() => dir.delete(recursive: true));
      final repo = await FileLocalLibraryRepository.open(
        filePath: file.path,
        prefs: prefs,
      );

      await Future.wait([
        for (var index = 0; index < 32; index++)
          repo.cacheTrack(_track('track-$index')),
      ]);

      final reopen = await FileLocalLibraryRepository.open(
        filePath: file.path,
        prefs: prefs,
      );
      expect(
        await reopen.getCachedTracks([
          for (var index = 0; index < 32; index++) 'track-$index',
        ]),
        hasLength(32),
      );
    });

    test(
      'rolls back failed writes and hides uncommitted state from reads',
      () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final dir = await Directory.systemTemp.createTemp(
          'edmm-file-local-library-write-rollback-',
        );
        addTearDown(() => dir.delete(recursive: true));
        final blockingFile = File('${dir.path}/not-a-directory');
        await blockingFile.writeAsString('blocking parent');
        final repo = await FileLocalLibraryRepository.open(
          filePath: '${blockingFile.path}/library.json',
          prefs: prefs,
        );

        final failedWrite = repo.recordRecentPlay('track-1');
        final readDuringWrite = repo.getRecentTrackIds();

        await expectLater(failedWrite, throwsA(isA<FileSystemException>()));
        expect(await readDuringWrite, isEmpty);
        expect(await repo.getRecentTrackIds(), isEmpty);
      },
    );

    test(
      'rolls back every in-memory collection after persistence fails',
      () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final root = await Directory.systemTemp.createTemp(
          'edmm-file-local-library-state-rollback-',
        );
        addTearDown(() => root.delete(recursive: true));
        final storageDir = Directory('${root.path}/storage');
        final file = File('${storageDir.path}/library.json');
        final repo = await FileLocalLibraryRepository.open(
          filePath: file.path,
          prefs: prefs,
        );
        await repo.recordRecentPlay('track-1');
        await repo.cacheTrack(_track('track-1'));

        await storageDir.delete(recursive: true);
        final blockingFile = File(storageDir.path);
        await blockingFile.writeAsString('blocking parent');

        await expectLater(
          repo.recordRecentPlay('track-2'),
          throwsA(isA<FileSystemException>()),
        );
        await expectLater(
          repo.cacheTrack(_track('track-2')),
          throwsA(isA<FileSystemException>()),
        );

        expect(await repo.getRecentTrackIds(), ['track-1']);
        expect((await repo.getCachedTrack('track-1'))?.id, 'track-1');
        expect(await repo.getCachedTrack('track-2'), isNull);

        await blockingFile.delete();
        await repo.recordRecentPlay('recovered');
        expect(await repo.getRecentTrackIds(), ['recovered', 'track-1']);
      },
    );

    test('preserves the durable state when replacing the file fails', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final dir = await Directory.systemTemp.createTemp(
        'edmm-file-local-library-durable-rollback-',
      );
      final file = File('${dir.path}/edmm_local_library.json');
      final tmp = File('${file.path}.tmp');
      final backup = File('${file.path}.bak');
      addTearDown(() => dir.delete(recursive: true));

      final seed = await FileLocalLibraryRepository.open(
        filePath: file.path,
        prefs: prefs,
      );
      await seed.recordRecentPlay('original');
      await seed.cacheTrack(_track('original'));

      await IOOverrides.runZoned(
        () async {
          final repo = await FileLocalLibraryRepository.open(
            filePath: file.path,
            prefs: prefs,
          );

          await expectLater(
            repo.recordRecentPlay('uncommitted'),
            throwsA(isA<FileSystemException>()),
          );
        },
        createFile: (path) => _RenameFailingFile(switch (path) {
          final value when value == file.path => file,
          final value when value == tmp.path => tmp,
          final value when value == backup.path => backup,
          _ => throw StateError('Unexpected file path: $path'),
        }, failRename: path == tmp.path),
      );

      final reopen = await FileLocalLibraryRepository.open(
        filePath: file.path,
        prefs: prefs,
      );
      expect(await reopen.getRecentTrackIds(), ['original']);
      expect((await reopen.getCachedTrack('original'))?.id, 'original');
    });

    test(
      'ignores cached tracks whose map key does not match Track.id',
      () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final dir = await Directory.systemTemp.createTemp(
          'edmm-file-local-library-cache-key-',
        );
        final file = File('${dir.path}/edmm_local_library.json');
        addTearDown(() => dir.delete(recursive: true));
        await file.writeAsString(
          jsonEncode({
            'trackCache': {'requested-id': _track('different-id').toJson()},
          }),
          flush: true,
        );

        final repo = await FileLocalLibraryRepository.open(
          filePath: file.path,
          prefs: prefs,
        );

        expect(await repo.getCachedTrack('requested-id'), isNull);
        expect(await repo.getCachedTrack('different-id'), isNull);
      },
    );
  });
}
