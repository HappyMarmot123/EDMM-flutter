import 'package:flutter/foundation.dart';

import '../../../domain/logic/library_track_hydrator.dart';
import '../../../domain/models/library_track_item.dart';
import '../../../domain/models/local_library_entities.dart';
import '../../../domain/playback/playback_selection.dart';
import '../../../domain/repositories/local_library_repository.dart';

enum PlaylistDetailStatus { loading, data, empty, notFound, storageError }

class PlaylistDetailViewModel extends ChangeNotifier {
  PlaylistDetailViewModel(this._localLibrary, {required this.playlistId});

  final LocalLibraryRepository _localLibrary;
  final int playlistId;
  bool _disposed = false;
  int _refreshGeneration = 0;

  PlaylistDetailStatus status = PlaylistDetailStatus.loading;
  PlaylistRow? playlist;
  List<LibraryTrackItem> items = const [];
  Object? error;

  Future<void> init() => refresh();

  Future<void> refresh() async {
    final generation = ++_refreshGeneration;
    status = PlaylistDetailStatus.loading;
    error = null;
    notifyListeners();
    try {
      final playlists = await _localLibrary.getPlaylists();
      PlaylistRow? matched;
      for (final candidate in playlists) {
        if (candidate.id == playlistId) {
          matched = candidate;
          break;
        }
      }
      if (matched == null) {
        if (!_isActiveRefresh(generation)) return;
        playlist = null;
        items = const [];
        status = PlaylistDetailStatus.notFound;
        notifyListeners();
        return;
      }
      final trackIds = await _localLibrary.getPlaylistTrackIds(playlistId);
      final loadedItems = await hydrateCachedTrackIds(_localLibrary, trackIds);
      if (!_isActiveRefresh(generation)) return;
      playlist = matched;
      items = loadedItems;
      status = items.isEmpty
          ? PlaylistDetailStatus.empty
          : PlaylistDetailStatus.data;
    } catch (caught) {
      if (!_isActiveRefresh(generation)) return;
      error = caught;
      items = const [];
      status = PlaylistDetailStatus.storageError;
    }
    notifyListeners();
  }

  bool _isActiveRefresh(int generation) =>
      !_disposed && generation == _refreshGeneration;

  Future<void> removeTrack(String trackId) async {
    try {
      await _localLibrary.removeTrackFromPlaylist(playlistId, trackId);
      await refresh();
    } catch (caught) {
      error = caught;
      status = PlaylistDetailStatus.storageError;
      notifyListeners();
    }
  }

  PlaybackSelection? playbackSelectionFor(String trackId) =>
      playbackSelectionForItems(items, trackId);

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
