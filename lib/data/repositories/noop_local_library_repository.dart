import '../../domain/models/track.dart';
import '../../domain/repositories/local_library_repository.dart';

class NoopLocalLibraryRepository implements LocalLibraryRepository {
  const NoopLocalLibraryRepository();

  @override
  Future<void> recordRecentPlay(String trackId) async {}

  @override
  Future<List<String>> getRecentTrackIds({int limit = 10}) async => const [];

  @override
  Future<void> cacheTrack(Track track) async {}

  @override
  Future<Track?> getCachedTrack(String trackId) async => null;

  @override
  Future<List<Track>> getCachedTracks(List<String> trackIds) async => const [];

  @override
  Future<String?> getAudioSetting(String key) async => null;

  @override
  Future<void> setAudioSetting(String key, String value) async {}
}
