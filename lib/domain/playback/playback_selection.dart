import '../models/library_track_item.dart';
import '../models/track.dart';

class PlaybackSelection {
  const PlaybackSelection({required this.queue, required this.index});

  final List<Track> queue;
  final int index;
}

PlaybackSelection? playbackSelectionForItems(
  List<LibraryTrackItem> items,
  String trackId,
) {
  final queue = List<Track>.unmodifiable(
    items
        .map((item) => item.track)
        .whereType<Track>()
        .where((track) => track.isPlayable),
  );
  final index = queue.indexWhere((track) => track.id == trackId);
  if (index < 0) return null;
  return PlaybackSelection(queue: queue, index: index);
}
