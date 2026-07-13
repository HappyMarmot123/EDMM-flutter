import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/models/local_library_entities.dart';
import '../../domain/models/track.dart';
import '../../domain/repositories/local_library_repository.dart';

typedef _RepositoryState = ({
  Map<String, int> favorites,
  List<PlaylistRow> playlists,
  Map<int, List<String>> playlistTrackIds,
  List<String> recentTrackIds,
  Map<String, Track> trackCache,
  int nextPlaylistId,
});

class FileLocalLibraryRepository implements LocalLibraryRepository {
  FileLocalLibraryRepository._({
    required this._file,
    required this._prefs,
    int Function()? nowMs,
  }) : _nowMs = nowMs ?? (() => DateTime.now().millisecondsSinceEpoch);

  static const String _fileName = 'edmm_local_library.json';
  static const String _audioSettingsPrefix = 'audio_setting:';
  static const int _maxRecentPlays = 10;

  static Future<FileLocalLibraryRepository> open({
    String? filePath,
    int Function()? nowMs,
    SharedPreferences? prefs,
  }) async {
    final resolvedPrefs = prefs ?? await SharedPreferences.getInstance();
    final file = filePath != null ? File(filePath) : await _defaultFile();
    final repo = FileLocalLibraryRepository._(
      file: file,
      prefs: resolvedPrefs,
      nowMs: nowMs,
    );
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
  final int Function() _nowMs;

  final Map<String, int> _favorites = <String, int>{};
  final List<PlaylistRow> _playlists = <PlaylistRow>[];
  final Map<int, List<String>> _playlistTrackIds = <int, List<String>>{};
  final List<String> _recentTrackIds = <String>[];
  final Map<String, Track> _trackCache = <String, Track>{};
  int _nextPlaylistId = 1;
  Future<void> _writeTail = Future<void>.value();

  @override
  Future<bool> isFavorite(String trackId) async =>
      _read(() => _favorites.containsKey(trackId));

  @override
  Future<void> setFavorite(String trackId, bool favorite) async =>
      _write(() async {
        if (favorite) {
          _favorites[trackId] = _nowMs();
        } else {
          _favorites.remove(trackId);
        }
        await _persist();
      });

  @override
  Future<void> toggleFavorite(String trackId) async => _write(() async {
    if (_favorites.containsKey(trackId)) {
      _favorites.remove(trackId);
    } else {
      _favorites[trackId] = _nowMs();
    }
    await _persist();
  });

  @override
  Future<List<FavoriteRow>> getFavorites() async => _read(() {
    final rows = _favorites.entries
        .map(
          (entry) =>
              FavoriteRow(id: null, trackId: entry.key, addedAt: entry.value),
        )
        .toList(growable: false);
    rows.sort((a, b) => b.addedAt.compareTo(a.addedAt));
    return rows;
  });

  @override
  Future<int> createPlaylist(String name) async => _write(() async {
    final id = _nextPlaylistId++;
    _playlists.add(PlaylistRow(id: id, name: name, createdAt: _nowMs()));
    _playlistTrackIds[id] = <String>[];
    await _persist();
    return id;
  });

  @override
  Future<List<PlaylistRow>> getPlaylists() async => _read(() {
    final rows = _playlists.toList(growable: false);
    rows.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return rows;
  });

  @override
  Future<bool> addTrackToPlaylist(int playlistId, String trackId) async =>
      _write(() async {
        final tracks = _playlistTrackIds[playlistId];
        if (tracks == null) return false;
        if (tracks.contains(trackId)) return true;
        tracks.add(trackId);
        await _persist();
        return true;
      });

  @override
  Future<void> removeTrackFromPlaylist(int playlistId, String trackId) async =>
      _write(() async {
        final tracks = _playlistTrackIds[playlistId];
        if (tracks == null) return;
        tracks.remove(trackId);
        await _persist();
      });

  @override
  Future<List<String>> getPlaylistTrackIds(int playlistId) async => _read(() {
    final tracks = _playlistTrackIds[playlistId];
    return tracks == null ? <String>[] : List<String>.from(tracks);
  });

  @override
  Future<void> deletePlaylist(int playlistId) async => _write(() async {
    _playlists.removeWhere((playlist) => playlist.id == playlistId);
    _playlistTrackIds.remove(playlistId);
    await _persist();
  });

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

      _favorites
        ..clear()
        ..addAll(_decodeFavorites(decoded['favorites']));

      final parsedPlaylists = _decodePlaylists(decoded['playlists']);
      _playlists
        ..clear()
        ..addAll(parsedPlaylists.playlists);
      _playlistTrackIds
        ..clear()
        ..addAll(parsedPlaylists.playlistTrackIds);
      _nextPlaylistId = parsedPlaylists.nextPlaylistId;

      _recentTrackIds
        ..clear()
        ..addAll(_decodeStringList(decoded['recentTrackIds']));

      _trackCache
        ..clear()
        ..addAll(await _decodeTrackCache(decoded['trackCache']));
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
    'favorites': _favorites,
    'playlists': _playlists
        .map(
          (playlist) => <String, dynamic>{
            'id': playlist.id,
            'name': playlist.name,
            'createdAt': playlist.createdAt,
            'trackIds': _playlistTrackIds[playlist.id] ?? <String>[],
          },
        )
        .toList(growable: false),
    'nextPlaylistId': _nextPlaylistId,
    'recentTrackIds': _recentTrackIds,
    'trackCache': _trackCache.map(
      (trackId, track) => MapEntry(trackId, track.toJson()),
    ),
  };

  Map<String, int> _decodeFavorites(dynamic raw) {
    if (raw is! Map) return <String, int>{};
    final decoded = <String, int>{};
    for (final entry in raw.entries) {
      final value = entry.value;
      final timestamp = switch (value) {
        int value => value,
        num value => value.toInt(),
        _ => null,
      };
      if (timestamp != null) {
        decoded[entry.key.toString()] = timestamp;
      }
    }
    return decoded;
  }

  ({
    List<PlaylistRow> playlists,
    Map<int, List<String>> playlistTrackIds,
    int nextPlaylistId,
  })
  _decodePlaylists(dynamic raw) {
    if (raw is! List) {
      return (
        playlists: <PlaylistRow>[],
        playlistTrackIds: <int, List<String>>{},
        nextPlaylistId: 1,
      );
    }

    final playlistTrackIds = <int, List<String>>{};
    final playlists = <PlaylistRow>[];
    var maxPlaylistId = 0;

    for (final entry in raw) {
      if (entry is! Map) continue;
      final id = entry['id'];
      final parsedId = switch (id) {
        int value => value,
        num value => value.toInt(),
        _ => null,
      };
      final name = entry['name'];
      final createdAtRaw = entry['createdAt'];
      if (parsedId == null || name is! String || createdAtRaw is! num) continue;
      playlistTrackIds[parsedId] = _decodeStringList(entry['trackIds']);
      playlists.add(
        PlaylistRow(id: parsedId, name: name, createdAt: createdAtRaw.toInt()),
      );
      if (parsedId > maxPlaylistId) maxPlaylistId = parsedId;
    }
    return (
      playlists: playlists,
      playlistTrackIds: playlistTrackIds,
      nextPlaylistId: maxPlaylistId + 1,
    );
  }

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
    favorites: Map<String, int>.from(_favorites),
    playlists: List<PlaylistRow>.from(_playlists),
    playlistTrackIds: _playlistTrackIds.map(
      (playlistId, trackIds) =>
          MapEntry(playlistId, List<String>.from(trackIds)),
    ),
    recentTrackIds: List<String>.from(_recentTrackIds),
    trackCache: Map<String, Track>.from(_trackCache),
    nextPlaylistId: _nextPlaylistId,
  );

  void _restoreState(_RepositoryState snapshot) {
    _favorites
      ..clear()
      ..addAll(snapshot.favorites);
    _playlists
      ..clear()
      ..addAll(snapshot.playlists);
    _playlistTrackIds
      ..clear()
      ..addAll(snapshot.playlistTrackIds);
    _recentTrackIds
      ..clear()
      ..addAll(snapshot.recentTrackIds);
    _trackCache
      ..clear()
      ..addAll(snapshot.trackCache);
    _nextPlaylistId = snapshot.nextPlaylistId;
  }
}
