import '../models/track.dart';
import '../result.dart';

enum PlaybackStatus { idle, loading, ready, playing, paused, completed, error }

class PlaybackSnapshot {
  const PlaybackSnapshot({
    this.currentTrack,
    this.status = PlaybackStatus.idle,
    this.duration = Duration.zero,
    this.queueIndex,
    this.hasNext = false,
    this.hasPrevious = false,
    this.error,
  });

  final Track? currentTrack;
  final PlaybackStatus status;
  final Duration duration;
  final int? queueIndex;
  final bool hasNext;
  final bool hasPrevious;
  final Failure? error;

  bool get isPlaying => status == PlaybackStatus.playing;

  PlaybackSnapshot copyWith({
    Track? currentTrack,
    PlaybackStatus? status,
    Duration? duration,
    int? queueIndex,
    bool? hasNext,
    bool? hasPrevious,
    Failure? error,
  }) => PlaybackSnapshot(
        currentTrack: currentTrack ?? this.currentTrack,
        status: status ?? this.status,
        duration: duration ?? this.duration,
        queueIndex: queueIndex ?? this.queueIndex,
        hasNext: hasNext ?? this.hasNext,
        hasPrevious: hasPrevious ?? this.hasPrevious,
        error: error ?? this.error,
      );
}
