import '../models/track.dart';
import '../playback/playback_snapshot.dart';

abstract class AudioController {
  Stream<PlaybackSnapshot> get snapshot;
  Stream<Duration> get position;
  bool get isShuffleEnabled;
  double get volume;

  /// Returns true only when the new queue is ready for playback.
  Future<bool> loadQueue(List<Track> tracks, {int initialIndex = 0});
  Future<void> setShuffleEnabled(bool enabled);
  Future<void> setVolume(double volume);
  Future<void> setMute(bool muted);
  Future<void> play();
  Future<void> pause();
  Future<void> seek(Duration position);
  Future<void> next();
  Future<void> previous();
  Future<void> dispose();
}
