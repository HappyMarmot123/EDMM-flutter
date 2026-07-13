import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/models/track.dart';
import '../../domain/repositories/local_library_repository.dart';

typedef _RepositoryState = ({
  List<String> recentTrackIds,
  Map<String, Track> trackCache,
});

class FileLocalLibraryRepository implements LocalLibraryRepository {
  FileLocalLibraryRepository._({required this._file, required this._prefs});

  static const String _fileName = 'edmm_local_library.json';
  static const String _audioSettingsPrefix = 'audio_setting:';
  static const int _maxRecentPlays = 10;
  static const int _schemaVersion = 2;
  static const Set<String> _removedCollectionKeys = {
    'favorites',
    'playlists',
    'nextPlaylistId',
  };

  static Future<FileLocalLibraryRepository> open({
    String? filePath,
    SharedPreferences? prefs,
  }) async {
    final resolvedPrefs = prefs ?? await SharedPreferences.getInstance();
    final file = filePath != null ? File(filePath) : await _defaultFile();
    final repo = FileLocalLibraryRepository._(file: file, prefs: resolvedPrefs);
    await repo._load();
    return repo;
  }

  static Future<File> _defaultFile() async {
    final dir = await getApplicationSupportDirectory();
    final file = File('${dir.path}/$_fileName');
    return file;
  }

  final File _file;
  final SharedPreferences _prefs;

  final List<String> _recentTrackIds = <String>[];
  final Map<String, Track> _trackCache = <String, Track>{};
  Future<void> _writeTail = Future<void>.value();

  @override
  Future<void> recordRecentPlay(String trackId) async => _write(() async {
    _recentTrackIds.remove(trackId);
    _recentTrackIds.insert(0, trackId);
    if (_recentTrackIds.length > _maxRecentPlays) {
      _recentTrackIds.removeRange(_maxRecentPlays, _recentTrackIds.length);
    }
    await _persist();
  });

  @override
  Future<List<String>> getRecentTrackIds({int limit = _maxRecentPlays}) async =>
      _read(() {
        final normalizedLimit = limit < 0 ? 0 : limit;
        return _recentTrackIds.take(normalizedLimit).toList(growable: false);
      });

  @override
  Future<void> cacheTrack(Track track) async => _write(() async {
    _trackCache[track.id] = track;
    await _persist();
  });

  @override
  Future<Track?> getCachedTrack(String trackId) async =>
      _read(() => _trackCache[trackId]);

  @override
  Future<List<Track>> getCachedTracks(List<String> trackIds) async => _read(
    () => trackIds
        .where((trackId) => _trackCache.containsKey(trackId))
        .map((trackId) => _trackCache[trackId]!)
        .toList(growable: false),
  );

  @override
  Future<String?> getAudioSetting(String key) async =>
      _read(() => _prefs.getString(_audioSettingsPrefKey(key)));

  @override
  Future<void> setAudioSetting(String key, String value) async => _write(
    () async {
      final stored = await _prefs.setString(_audioSettingsPrefKey(key), value);
      if (!stored) {
        throw StateError('Failed to persist audio setting: $key');
      }
    },
  );

  Future<void> _load() async {
    try {
      var source = _file;
      if (!await source.exists()) {
        final backup = File('${_file.path}.bak');
        if (!await backup.exists()) return;
        source = backup;
        try {
          await backup.rename(_file.path);
          source = _file;
        } on FileSystemException {
          // The backup remains a valid recovery source even when restoring it
          // to the primary path is not currently possible.
        }
      }

      final raw = await source.readAsString();
      if (raw.trim().isEmpty) return;

      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return;

      _recentTrackIds
        ..clear()
        ..addAll(_decodeStringList(decoded['recentTrackIds']));

      _trackCache
        ..clear()
        ..addAll(await _decodeTrackCache(decoded['trackCache']));

      final storedSchemaVersion = decoded['schemaVersion'];
      final canRewriteSchema =
          storedSchemaVersion is! num || storedSchemaVersion <= _schemaVersion;
      final needsMigration =
          canRewriteSchema &&
          (storedSchemaVersion != _schemaVersion ||
              _removedCollectionKeys.any(decoded.containsKey));
      if (needsMigration) await _persist();
    } on FormatException {
      // A corrupted cache is recoverable: keep the in-memory library empty.
    }
  }

  Future<void> _persist() async {
    final dir = _file.parent;
    await dir.create(recursive: true);

    final payload = _serializeState();
    final tmp = File('${_file.path}.tmp');
    final backup = File('${_file.path}.bak');
    final serialized = jsonEncode(payload);
    await tmp.writeAsString(serialized, flush: true);

    if (!await _file.exists()) {
      await tmp.rename(_file.path);
      await _deleteCommittedBackup(backup);
      return;
    }

    if (await backup.exists()) {
      await backup.delete();
    }
    await _file.rename(backup.path);
    try {
      await tmp.rename(_file.path);
    } catch (error, stackTrace) {
      try {
        await backup.rename(_file.path);
      } on FileSystemException {
        // Keep the backup in place so a later open can recover it.
      }
      Error.throwWithStackTrace(error, stackTrace);
    }
    await _deleteCommittedBackup(backup);
  }

  Future<void> _deleteCommittedBackup(File backup) async {
    try {
      if (await backup.exists()) {
        await backup.delete();
      }
    } on FileSystemException {
      // The primary file is already committed; a stale backup is harmless and
      // will be replaced before the next transaction.
    }
  }

  Map<String, dynamic> _serializeState() => {
    'schemaVersion': _schemaVersion,
    'recentTrackIds': _recentTrackIds,
    'trackCache': _trackCache.map(
      (trackId, track) => MapEntry(trackId, track.toJson()),
    ),
  };

  List<String> _decodeStringList(dynamic raw) {
    if (raw is! List) return <String>[];
    return raw.whereType<String>().toList(growable: false);
  }

  Future<Map<String, Track>> _decodeTrackCache(dynamic raw) async {
    if (raw is! Map) return <String, Track>{};
    final cache = <String, Track>{};
    for (final entry in raw.entries) {
      final trackMap = entry.value;
      if (trackMap is! Map) continue;
      try {
        final trackId = entry.key.toString();
        final track = Track.fromJson(trackMap.cast<String, dynamic>());
        if (track.id != trackId) continue;
        cache[trackId] = track;
      } catch (_) {}
    }
    return cache;
  }

  String _audioSettingsPrefKey(String key) => '$_audioSettingsPrefix$key';

  Future<T> _read<T>(FutureOr<T> Function() action) async {
    final pendingWrites = _writeTail;
    await pendingWrites;
    return await action();
  }

  Future<T> _write<T>(Future<T> Function() action) {
    final operation = _writeTail.then((_) async {
      final snapshot = _snapshotState();
      try {
        return await action();
      } catch (_) {
        _restoreState(snapshot);
        rethrow;
      }
    });
    _writeTail = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return operation;
  }

  _RepositoryState _snapshotState() => (
    recentTrackIds: List<String>.from(_recentTrackIds),
    trackCache: Map<String, Track>.from(_trackCache),
  );

  void _restoreState(_RepositoryState snapshot) {
    _recentTrackIds
      ..clear()
      ..addAll(snapshot.recentTrackIds);
    _trackCache
      ..clear()
      ..addAll(snapshot.trackCache);
  }
}
