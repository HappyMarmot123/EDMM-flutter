import '../../domain/models/local_library_entities.dart';
import '../../domain/models/track.dart';
import '../../domain/repositories/local_library_repository.dart';

class NoopLocalLibraryRepository implements LocalLibraryRepository {
  const NoopLocalLibraryRepository();

  @override
  Future<bool> isFavorite(String trackId) async => false;

  @override
  Future<void> setFavorite(String trackId, bool favorite) async {}

  @override
  Future<void> toggleFavorite(String trackId) async {}

  @override
  Future<List<FavoriteRow>> getFavorites() async => const [];

  @override
  Future<int> createPlaylist(String name) async => -1;

  @override
  Future<List<PlaylistRow>> getPlaylists() async => const [];

  @override
  Future<bool> addTrackToPlaylist(int playlistId, String trackId) async =>
      false;

  @override
  Future<void> removeTrackFromPlaylist(int playlistId, String trackId) async {}

  @override
  Future<List<String>> getPlaylistTrackIds(int playlistId) async => const [];

  @override
  Future<void> deletePlaylist(int playlistId) async {}

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
