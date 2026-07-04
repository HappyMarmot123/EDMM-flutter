import '../models/track.dart';
import '../playback/playback_snapshot.dart';

abstract class AudioController {
  Stream<PlaybackSnapshot> get snapshot;
  Stream<Duration> get position;
  Future<void> loadQueue(List<Track> tracks, {int initialIndex = 0});
  Future<void> play();
  Future<void> pause();
  Future<void> seek(Duration position);
  Future<void> next();
  Future<void> previous();
  Future<void> dispose();
}
