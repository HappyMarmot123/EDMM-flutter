import '../models/track.dart';
import '../repositories/local_library_repository.dart';

Future<void> persistPlaybackSelection(
  LocalLibraryRepository localLibrary,
  List<Track> queue,
  int index,
) async {
  final selectedTrack = index >= 0 && index < queue.length
      ? queue[index]
      : null;

  if (selectedTrack != null) {
    await persistPlaybackTrack(localLibrary, selectedTrack);
  }

  for (final track in queue) {
    if (track.id == selectedTrack?.id) continue;
    await _cacheTrack(localLibrary, track);
  }
}

Future<void> persistPlaybackTrack(
  LocalLibraryRepository localLibrary,
  Track track,
) async {
  await _cacheTrack(localLibrary, track);
  try {
    await localLibrary.recordRecentPlay(track.id);
  } catch (_) {}
}

Future<void> _cacheTrack(
  LocalLibraryRepository localLibrary,
  Track track,
) async {
  try {
    await localLibrary.cacheTrack(track);
  } catch (_) {}
}
