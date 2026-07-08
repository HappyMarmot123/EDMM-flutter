import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/models/local_library_entities.dart';
import '../../domain/models/track.dart';
import '../../domain/repositories/local_library_repository.dart';

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

  @override
  Future<bool> isFavorite(String trackId) async =>
      _safeRead(() => _favorites.containsKey(trackId), false);

  @override
  Future<void> setFavorite(String trackId, bool favorite) async =>
      _safeWrite(() async {
        if (favorite) {
          _favorites[trackId] = _nowMs();
        } else {
          _favorites.remove(trackId);
        }
        await _persist();
      });

  @override
  Future<void> toggleFavorite(String trackId) async {
    final liked = await isFavorite(trackId);
    await setFavorite(trackId, !liked);
  }

  @override
  Future<List<FavoriteRow>> getFavorites() async => _safeRead(() {
    final rows = _favorites.entries
        .map(
          (entry) =>
              FavoriteRow(id: null, trackId: entry.key, addedAt: entry.value),
        )
        .toList(growable: false);
    rows.sort((a, b) => b.addedAt.compareTo(a.addedAt));
    return rows;
  }, <FavoriteRow>[]);

  @override
  Future<int> createPlaylist(String name) async => _safeRead(() async {
    final id = _nextPlaylistId++;
    _playlists.add(PlaylistRow(id: id, name: name, createdAt: _nowMs()));
    _playlistTrackIds[id] = <String>[];
    await _persist();
    return id;
  }, -1);

  @override
  Future<List<PlaylistRow>> getPlaylists() async => _safeRead(() {
    final rows = _playlists.toList(growable: false);
    rows.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return rows;
  }, <PlaylistRow>[]);

  @override
  Future<void> addTrackToPlaylist(int playlistId, String trackId) async =>
      _safeWrite(() async {
        final tracks = _playlistTrackIds[playlistId];
        if (tracks == null || tracks.contains(trackId)) return;
        tracks.add(trackId);
        await _persist();
      });

  @override
  Future<void> removeTrackFromPlaylist(int playlistId, String trackId) async =>
      _safeWrite(() async {
        final tracks = _playlistTrackIds[playlistId];
        if (tracks == null) return;
        tracks.remove(trackId);
        await _persist();
      });

  @override
  Future<List<String>> getPlaylistTrackIds(int playlistId) async =>
      _safeRead(() {
        final tracks = _playlistTrackIds[playlistId];
        return tracks == null ? <String>[] : List<String>.from(tracks);
      }, <String>[]);

  @override
  Future<void> deletePlaylist(int playlistId) async => _safeWrite(() async {
    _playlists.removeWhere((playlist) => playlist.id == playlistId);
    _playlistTrackIds.remove(playlistId);
    await _persist();
  });

  @override
  Future<void> recordRecentPlay(String trackId) async => _safeWrite(() async {
    _recentTrackIds.remove(trackId);
    _recentTrackIds.insert(0, trackId);
    if (_recentTrackIds.length > _maxRecentPlays) {
      _recentTrackIds.removeRange(_maxRecentPlays, _recentTrackIds.length);
    }
    await _persist();
  });

  @override
  Future<List<String>> getRecentTrackIds({int limit = _maxRecentPlays}) async =>
      _safeRead(() {
        final normalizedLimit = limit < 0 ? 0 : limit;
        return _recentTrackIds.take(normalizedLimit).toList(growable: false);
      }, <String>[]);

  @override
  Future<void> cacheTrack(Track track) async => _safeWrite(() async {
    _trackCache[track.id] = track;
    await _persist();
  });

  @override
  Future<Track?> getCachedTrack(String trackId) async =>
      _safeRead(() => _trackCache[trackId], null);

  @override
  Future<List<Track>> getCachedTracks(List<String> trackIds) async => _safeRead(
    () => trackIds
        .where((trackId) => _trackCache.containsKey(trackId))
        .map((trackId) => _trackCache[trackId]!)
        .toList(growable: false),
    <Track>[],
  );

  @override
  Future<String?> getAudioSetting(String key) async =>
      _safeRead(() => _prefs.getString(_audioSettingsPrefKey(key)), null);

  @override
  Future<void> setAudioSetting(String key, String value) async =>
      _safeWrite(() async {
        await _prefs.setString(_audioSettingsPrefKey(key), value);
      });

  Future<void> _load() async {
    try {
      if (!await _file.exists()) {
        return;
      }

      final raw = await _file.readAsString();
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
    } catch (_) {}
  }

  Future<void> _persist() async {
    final dir = _file.parent;
    await dir.create(recursive: true);

    final payload = _serializeState();
    final tmp = File('${_file.path}.tmp');
    final serialized = jsonEncode(payload);
    await tmp.writeAsString(serialized, flush: true);

    if (await _file.exists()) {
      await _file.delete();
    }
    await tmp.rename(_file.path);
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
        cache[entry.key.toString()] = Track.fromJson(
          trackMap.cast<String, dynamic>(),
        );
      } catch (_) {}
    }
    return cache;
  }

  String _audioSettingsPrefKey(String key) => '$_audioSettingsPrefix$key';

  Future<T> _safeRead<T>(FutureOr<T> Function() action, T fallback) async {
    try {
      return await action();
    } catch (_) {
      return fallback;
    }
  }

  Future<void> _safeWrite(Future<void> Function() action) async {
    try {
      await action();
    } catch (_) {}
  }
}
