import '../audio/audio_controller.dart';
import '../repositories/local_library_repository.dart';
import '../repositories/track_repository.dart';
import '../result.dart';
import 'track_resolver.dart';

Future<bool> loadDeepLinkedTrack({
  required String trackId,
  required TrackRepository trackRepository,
  required LocalLibraryRepository localLibrary,
  required AudioController audio,
}) async {
  final result = await TrackResolver(
    trackRepository,
    localLibrary,
  ).resolve(trackId, requirePlayable: true);
  switch (result) {
    case Ok(value: final track?) when track.isPlayable:
      return audio.loadQueue([track]);
    case Ok():
    case Err():
      return false;
  }
}
