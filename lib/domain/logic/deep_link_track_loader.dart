import '../audio/audio_controller.dart';
import '../models/cloudinary_category.dart';
import '../models/track.dart';
import '../repositories/local_library_repository.dart';
import '../repositories/track_repository.dart';
import '../result.dart';

Future<bool> loadDeepLinkedTrack({
  required String trackId,
  required TrackRepository trackRepository,
  required LocalLibraryRepository localLibrary,
  required AudioController audio,
}) async {
  final cached = await localLibrary.getCachedTrack(trackId);
  if (cached != null && cached.isPlayable) {
    await audio.loadQueue([cached]);
    return true;
  }

  for (final category in CloudinaryCategory.values) {
    final result = await trackRepository.getCatalog(
      category: category,
      query: trackId,
    );
    switch (result) {
      case Ok(:final value):
        final match = _findPlayableTrack(value, trackId);
        if (match == null) continue;
        await _cacheTrack(localLibrary, match);
        await audio.loadQueue([match]);
        return true;
      case Err():
        continue;
    }
  }

  return false;
}

Track? _findPlayableTrack(List<Track> tracks, String trackId) {
  for (final track in tracks) {
    if (track.id == trackId && track.isPlayable) return track;
  }
  return null;
}

Future<void> _cacheTrack(
  LocalLibraryRepository localLibrary,
  Track track,
) async {
  try {
    await localLibrary.cacheTrack(track);
  } catch (_) {}
}
