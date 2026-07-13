import 'track.dart';

/// Keeps a local-library identifier visible even when its cached payload is
/// missing or could not be decoded.
class LibraryTrackItem {
  const LibraryTrackItem({required this.trackId, this.track});

  final String trackId;
  final Track? track;

  bool get isAvailable => track != null;
  bool get isPlayable => track?.isPlayable ?? false;
}
