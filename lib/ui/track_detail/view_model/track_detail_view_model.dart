import 'package:flutter/foundation.dart';

import '../../../domain/logic/track_resolver.dart';
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

  TrackDetailStatus status;
  Track? track;
  Failure? resolutionError;
  Object? storageError;

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
    storageError = null;
    notifyListeners();
    try {
      await _localLibrary.cacheTrack(seededTrack);
    } catch (caught) {
      if (!_isActiveLoad(generation)) return;
      storageError = caught;
    }
    if (!_isActiveLoad(generation)) return;
    notifyListeners();
  }

  Future<void> _load({bool forceRefresh = false}) async {
    final generation = ++_loadGeneration;
    status = TrackDetailStatus.loading;
    resolutionError = null;
    storageError = null;
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
    }
    if (!_isActiveLoad(generation)) return;
    notifyListeners();
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
    super.dispose();
  }
}
