import '../models/track.dart';

abstract class LocalLibraryRepository {
  // recent plays
  Future<void> recordRecentPlay(String trackId);
  Future<List<String>> getRecentTrackIds({int limit = 10});

  // track cache
  Future<void> cacheTrack(Track track);
  Future<Track?> getCachedTrack(String trackId);
  Future<List<Track>> getCachedTracks(List<String> trackIds);

  // audio settings
  Future<String?> getAudioSetting(String key);
  Future<void> setAudioSetting(String key, String value);
}
