import 'package:flutter/foundation.dart';

import '../../../domain/logic/library_track_hydrator.dart';
import '../../../domain/models/library_track_item.dart';
import '../../../domain/models/local_library_entities.dart';
import '../../../domain/playback/playback_selection.dart';
import '../../../domain/repositories/local_library_repository.dart';

enum LibraryStatus { loading, data, empty, storageError }

class LibraryViewModel extends ChangeNotifier {
  LibraryViewModel(this._localLibrary);

  final LocalLibraryRepository _localLibrary;
  bool _disposed = false;
  int _refreshGeneration = 0;

  LibraryStatus status = LibraryStatus.loading;
  List<LibraryTrackItem> favorites = const [];
  List<PlaylistRow> playlists = const [];
  Object? error;

  Future<void> init() => refresh();

  Future<void> refresh() async {
    final generation = ++_refreshGeneration;
    status = LibraryStatus.loading;
    error = null;
    notifyListeners();
    try {
      final favoriteRows = await _localLibrary.getFavorites();
      final loadedFavorites = await hydrateCachedTrackIds(
        _localLibrary,
        favoriteRows.map((row) => row.trackId).toList(growable: false),
      );
      final loadedPlaylists = await _localLibrary.getPlaylists();
      if (!_isActiveRefresh(generation)) return;
      favorites = loadedFavorites;
      playlists = List<PlaylistRow>.unmodifiable(loadedPlaylists);
      status = favorites.isEmpty && playlists.isEmpty
          ? LibraryStatus.empty
          : LibraryStatus.data;
    } catch (caught) {
      if (!_isActiveRefresh(generation)) return;
      error = caught;
      favorites = const [];
      playlists = const [];
      status = LibraryStatus.storageError;
    }
    notifyListeners();
  }

  bool _isActiveRefresh(int generation) =>
      !_disposed && generation == _refreshGeneration;

  Future<bool> createPlaylist(String name) async {
    final normalizedName = name.trim();
    if (normalizedName.isEmpty) return false;
    try {
      final id = await _localLibrary.createPlaylist(normalizedName);
      if (id < 0) throw StateError('Playlist could not be created');
      await refresh();
      return true;
    } catch (caught) {
      _setStorageError(caught);
      return false;
    }
  }

  Future<void> deletePlaylist(int playlistId) async {
    try {
      await _localLibrary.deletePlaylist(playlistId);
      await refresh();
    } catch (caught) {
      _setStorageError(caught);
    }
  }

  PlaybackSelection? playbackSelectionForFavorite(String trackId) =>
      playbackSelectionForItems(favorites, trackId);

  void _setStorageError(Object caught) {
    error = caught;
    status = LibraryStatus.storageError;
    notifyListeners();
  }

  @override
  void notifyListeners() {
    if (_disposed) return;
    super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _refreshGeneration += 1;
    super.dispose();
  }
}
