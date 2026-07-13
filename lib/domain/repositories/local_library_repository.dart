import '../models/local_library_entities.dart';
import '../models/track.dart';

abstract class LocalLibraryRepository {
  // favorites
  Future<bool> isFavorite(String trackId);
  Future<void> setFavorite(String trackId, bool favorite);
  Future<void> toggleFavorite(String trackId);
  Future<List<FavoriteRow>> getFavorites();

  // playlists
  Future<int> createPlaylist(String name);
  Future<List<PlaylistRow>> getPlaylists();

  /// Returns false when the target playlist no longer exists.
  Future<bool> addTrackToPlaylist(int playlistId, String trackId);
  Future<void> removeTrackFromPlaylist(int playlistId, String trackId);
  Future<List<String>> getPlaylistTrackIds(int playlistId);
  Future<void> deletePlaylist(int playlistId);

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
