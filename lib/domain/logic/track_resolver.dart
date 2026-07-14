import '../models/cloudinary_category.dart';
import '../models/track.dart';
import '../repositories/local_library_repository.dart';
import '../repositories/track_repository.dart';
import '../result.dart';

/// Resolves track metadata without changing playback state.
class TrackResolver {
  TrackResolver(this._trackRepository, this._localLibrary);

  final TrackRepository _trackRepository;
  final LocalLibraryRepository _localLibrary;
  final Map<String, int> _latestResolutionByTrackId = {};
  int _resolutionGeneration = 0;

  Future<Result<Track?>> resolve(
    String trackId, {
    bool forceRefresh = false,
    bool requirePlayable = false,
  }) async {
    final normalizedId = trackId.trim();
    if (normalizedId.isEmpty) return const Ok<Track?>(null);
    final generation = ++_resolutionGeneration;
    _latestResolutionByTrackId[normalizedId] = generation;

    Failure? firstFailure;
    if (!forceRefresh) {
      try {
        final cached = await _localLibrary.getCachedTrack(normalizedId);
        if (cached != null && (!requirePlayable || cached.isPlayable)) {
          return Ok(cached);
        }
      } catch (error) {
        firstFailure = ParseFailure(error);
      }
    }

    for (final category in CloudinaryCategory.values) {
      final result = await _trackRepository.getCatalog(
        category: category,
        query: normalizedId,
        forceRefresh: forceRefresh,
      );
      switch (result) {
        case Ok(:final value):
          final match = _findExactTrack(
            value,
            normalizedId,
            requirePlayable: requirePlayable,
          );
          if (match == null) continue;
          if (_latestResolutionByTrackId[normalizedId] == generation) {
            await _cacheBestEffort(match);
          }
          return Ok(match);
        case Err(:final error):
          firstFailure ??= error;
      }
    }

    return firstFailure == null ? const Ok<Track?>(null) : Err(firstFailure);
  }

  Track? _findExactTrack(
    List<Track> tracks,
    String trackId, {
    required bool requirePlayable,
  }) {
    for (final track in tracks) {
      if (track.id != trackId) continue;
      if (requirePlayable && !track.isPlayable) continue;
      return track;
    }
    return null;
  }

  Future<void> _cacheBestEffort(Track track) async {
    try {
      await _localLibrary.cacheTrack(track);
    } catch (_) {}
  }
}
