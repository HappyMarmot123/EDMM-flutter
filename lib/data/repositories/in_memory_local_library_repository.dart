import 'dart:async';

import '../../domain/models/track.dart';
import '../../domain/repositories/local_library_repository.dart';

class InMemoryLocalLibraryRepository implements LocalLibraryRepository {
  final List<String> _recent = <String>[];
  final Map<String, Track> _trackCache = <String, Track>{};
  final Map<String, String> _audioSettings = <String, String>{};

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
