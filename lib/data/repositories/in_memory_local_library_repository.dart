import 'dart:async';

import '../../domain/models/local_library_entities.dart';
import '../../domain/models/track.dart';
import '../../domain/repositories/local_library_repository.dart';

class InMemoryLocalLibraryRepository implements LocalLibraryRepository {
  InMemoryLocalLibraryRepository({int Function()? nowMs})
    : _nowMs = nowMs ?? (() => DateTime.now().millisecondsSinceEpoch);

  final int Function() _nowMs;
  final Map<String, int> _favorites = <String, int>{};
  final List<PlaylistRow> _playlists = <PlaylistRow>[];
  final Map<int, List<String>> _playlistTrackIds = <int, List<String>>{};
  final List<String> _recent = <String>[];
  final Map<String, Track> _trackCache = <String, Track>{};
  final Map<String, String> _audioSettings = <String, String>{};
  int _nextPlaylistId = 1;

  @override
  Future<bool> isFavorite(String trackId) async =>
      _safeRead(() => _favorites.containsKey(trackId), false);

  @override
  Future<void> setFavorite(String trackId, bool favorite) async =>
      _safeWrite(() {
        if (favorite) {
          _favorites[trackId] = _nowMs();
        } else {
          _favorites.remove(trackId);
        }
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
  Future<int> createPlaylist(String name) async => _safeRead(() {
    final id = _nextPlaylistId++;
    _playlists.add(PlaylistRow(id: id, name: name, createdAt: _nowMs()));
    _playlistTrackIds[id] = <String>[];
    return id;
  }, -1);

  @override
  Future<List<PlaylistRow>> getPlaylists() async => _safeRead(() {
    return _playlists.toList(growable: false)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }, <PlaylistRow>[]);

  @override
  Future<bool> addTrackToPlaylist(int playlistId, String trackId) async =>
      _safeRead(() {
        final tracks = _playlistTrackIds[playlistId];
        if (tracks == null) return false;
        if (!tracks.contains(trackId)) tracks.add(trackId);
        return true;
      }, false);

  @override
  Future<void> removeTrackFromPlaylist(int playlistId, String trackId) async =>
      _safeWrite(() {
        _playlistTrackIds[playlistId]?.remove(trackId);
      });

  @override
  Future<List<String>> getPlaylistTrackIds(int playlistId) async =>
      _safeRead(() {
        final tracks = _playlistTrackIds[playlistId];
        return tracks == null ? <String>[] : List<String>.from(tracks);
      }, <String>[]);

  @override
  Future<void> deletePlaylist(int playlistId) async => _safeWrite(() {
    _playlists.removeWhere((row) => row.id == playlistId);
    _playlistTrackIds.remove(playlistId);
  });

  @override
  Future<void> recordRecentPlay(String trackId) async => _safeWrite(() {
    _recent.remove(trackId);
    _recent.insert(0, trackId);
    if (_recent.length > 10) {
      _recent.removeRange(10, _recent.length);
    }
  });

  @override
  Future<List<String>> getRecentTrackIds({int limit = 10}) async =>
      _safeRead(() {
        return _recent.take(limit).toList(growable: false);
      }, <String>[]);

  @override
  Future<void> cacheTrack(Track track) async => _safeWrite(() {
    _trackCache[track.id] = track;
  });

  @override
  Future<Track?> getCachedTrack(String trackId) async =>
      _safeRead(() => _trackCache[trackId], null);

  @override
  Future<List<Track>> getCachedTracks(List<String> trackIds) async =>
      _safeRead(() {
        return trackIds
            .where((trackId) => _trackCache.containsKey(trackId))
            .map((trackId) => _trackCache[trackId]!)
            .toList(growable: false);
      }, <Track>[]);

  @override
  Future<String?> getAudioSetting(String key) async =>
      _safeRead(() => _audioSettings[key], null);

  @override
  Future<void> setAudioSetting(String key, String value) async =>
      _safeWrite(() {
        _audioSettings[key] = value;
      });

  Future<T> _safeRead<T>(T Function() action, T fallback) async {
    try {
      return action();
    } catch (_) {
      return fallback;
    }
  }

  Future<void> _safeWrite(FutureOr<void> Function() action) async {
    try {
      await action();
    } catch (_) {}
  }
}
