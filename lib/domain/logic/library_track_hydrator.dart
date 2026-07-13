import '../models/library_track_item.dart';
import '../repositories/local_library_repository.dart';

Future<List<LibraryTrackItem>> hydrateCachedTrackIds(
  LocalLibraryRepository localLibrary,
  List<String> trackIds,
) async {
  final cachedTracks = await localLibrary.getCachedTracks(trackIds);
  final tracksById = {for (final track in cachedTracks) track.id: track};
  return List<LibraryTrackItem>.unmodifiable(
    trackIds.map(
      (trackId) =>
          LibraryTrackItem(trackId: trackId, track: tracksById[trackId]),
    ),
  );
}
