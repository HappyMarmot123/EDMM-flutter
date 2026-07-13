import 'package:flutter/foundation.dart';

import '../../../domain/logic/track_resolver.dart';
import '../../../domain/models/local_library_entities.dart';
import '../../../domain/models/track.dart';
import '../../../domain/repositories/local_library_repository.dart';
import '../../../domain/result.dart';

enum TrackDetailStatus { loading, data, notFound, error }

class TrackDetailViewModel extends ChangeNotifier {
  factory TrackDetailViewModel({
    required String trackId,
    Track? initialTrack,
    required TrackResolver resolver,
    required LocalLibraryRepository localLibrary,
  }) => TrackDetailViewModel._(
    trackId: trackId,
    initialTrack: initialTrack?.id == trackId ? initialTrack : null,
    resolver: resolver,
    localLibrary: localLibrary,
  );

  TrackDetailViewModel._({
    required this.trackId,
    required Track? initialTrack,
    required this._resolver,
    required this._localLibrary,
  }) : track = initialTrack,
       status = initialTrack == null
           ? TrackDetailStatus.loading
           : TrackDetailStatus.data;

  final String trackId;
  final TrackResolver _resolver;
  final LocalLibraryRepository _localLibrary;
  bool _disposed = false;
  int _loadGeneration = 0;
  int _favoriteRevision = 0;
  int _playlistsRevision = 0;

  TrackDetailStatus status;
  Track? track;
  bool isFavorite = false;
  List<PlaylistRow> playlists = const [];
  Failure? resolutionError;
  Object? libraryError;

  Future<void> init() {
    final seededTrack = track;
    if (seededTrack != null) return _loadSeed(seededTrack);
    return _load();
  }

  Future<void> retry() => _load(forceRefresh: true);

  Future<void> _loadSeed(Track seededTrack) async {
    final generation = ++_loadGeneration;
    status = TrackDetailStatus.data;
    resolutionError = null;
    libraryError = null;
    notifyListeners();
    try {
      await _localLibrary.cacheTrack(seededTrack);
    } catch (caught) {
      if (!_isActiveLoad(generation)) return;
      libraryError = caught;
    }
    if (!_isActiveLoad(generation)) return;
    await _loadLibraryState(seededTrack.id, generation: generation);
    if (!_isActiveLoad(generation)) return;
    notifyListeners();
  }

  Future<void> _load({bool forceRefresh = false}) async {
    final generation = ++_loadGeneration;
    status = TrackDetailStatus.loading;
    resolutionError = null;
    libraryError = null;
    notifyListeners();

    final result = await _resolver.resolve(trackId, forceRefresh: forceRefresh);
    if (!_isActiveLoad(generation)) return;
    switch (result) {
      case Err(:final error):
        resolutionError = error;
        track = null;
        status = TrackDetailStatus.error;
      case Ok(value: null):
        track = null;
        status = TrackDetailStatus.notFound;
      case Ok(value: final resolvedTrack?):
        track = resolvedTrack;
        status = TrackDetailStatus.data;
        await _loadLibraryState(resolvedTrack.id, generation: generation);
    }
    if (!_isActiveLoad(generation)) return;
    notifyListeners();
  }

  Future<void> _loadLibraryState(
    String resolvedTrackId, {
    required int generation,
  }) async {
    final favoriteRevision = _favoriteRevision;
    final playlistsRevision = _playlistsRevision;
    try {
      final loadedFavorite = await _localLibrary.isFavorite(resolvedTrackId);
      final loadedPlaylists = await _localLibrary.getPlaylists();
      if (!_isActiveLoad(generation)) return;
      if (favoriteRevision == _favoriteRevision) {
        isFavorite = loadedFavorite;
      }
      if (playlistsRevision == _playlistsRevision) {
        playlists = List<PlaylistRow>.unmodifiable(loadedPlaylists);
      }
      if (favoriteRevision == _favoriteRevision &&
          playlistsRevision == _playlistsRevision) {
        libraryError = null;
      }
    } catch (caught) {
      if (!_isActiveLoad(generation) ||
          (favoriteRevision != _favoriteRevision &&
              playlistsRevision != _playlistsRevision)) {
        return;
      }
      libraryError = caught;
      if (playlistsRevision == _playlistsRevision) playlists = const [];
    }
  }

  Future<bool> toggleFavorite() async {
    final current = track;
    if (current == null) return false;
    final next = !isFavorite;
    final revision = ++_favoriteRevision;
    try {
      if (next) await _localLibrary.cacheTrack(current);
      await _localLibrary.setFavorite(current.id, next);
      if (!_disposed && revision == _favoriteRevision) {
        _favoriteRevision += 1;
        isFavorite = next;
        libraryError = null;
        notifyListeners();
      }
      return true;
    } catch (caught) {
      if (!_disposed && revision == _favoriteRevision) {
        _favoriteRevision += 1;
        libraryError = caught;
        notifyListeners();
      }
      return false;
    }
  }

  Future<bool> addToPlaylist(int playlistId) async {
    final current = track;
    if (current == null) return false;
    final revision = ++_playlistsRevision;
    try {
      await _localLibrary.cacheTrack(current);
      final added = await _localLibrary.addTrackToPlaylist(
        playlistId,
        current.id,
      );
      if (!added) return false;
      if (!_disposed && revision == _playlistsRevision) {
        _playlistsRevision += 1;
        libraryError = null;
        notifyListeners();
      }
      return true;
    } catch (caught) {
      if (!_disposed && revision == _playlistsRevision) {
        _playlistsRevision += 1;
        libraryError = caught;
        notifyListeners();
      }
      return false;
    }
  }

  Future<bool> createPlaylistAndAdd(String name) async {
    final normalizedName = name.trim();
    if (normalizedName.isEmpty || track == null) return false;
    final revision = ++_playlistsRevision;
    try {
      final playlistId = await _localLibrary.createPlaylist(normalizedName);
      if (playlistId < 0) throw StateError('Playlist could not be created');
      final current = track!;
      await _localLibrary.cacheTrack(current);
      final added = await _localLibrary.addTrackToPlaylist(
        playlistId,
        current.id,
      );
      if (!added) throw StateError('Playlist no longer exists');
      final loadedPlaylists = await _localLibrary.getPlaylists();
      if (!_disposed && revision == _playlistsRevision) {
        _playlistsRevision += 1;
        playlists = List<PlaylistRow>.unmodifiable(loadedPlaylists);
        libraryError = null;
        notifyListeners();
      }
      return true;
    } catch (caught) {
      if (!_disposed && revision == _playlistsRevision) {
        _playlistsRevision += 1;
        libraryError = caught;
        notifyListeners();
      }
      return false;
    }
  }

  bool _isActiveLoad(int generation) =>
      !_disposed && generation == _loadGeneration;

  @override
  void notifyListeners() {
    if (_disposed) return;
    super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _loadGeneration += 1;
    _favoriteRevision += 1;
    _playlistsRevision += 1;
    super.dispose();
  }
}
