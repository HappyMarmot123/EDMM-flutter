// lib/data/audio/playback_mapping.dart
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart' show ProcessingState;
import '../../domain/models/track.dart';
import '../../domain/playback/playback_snapshot.dart';

PlaybackStatus mapProcessingState(ProcessingState state, bool playing) {
  switch (state) {
    case ProcessingState.idle:
      return PlaybackStatus.idle;
    case ProcessingState.loading:
    case ProcessingState.buffering:
      return PlaybackStatus.loading;
    case ProcessingState.ready:
      return playing ? PlaybackStatus.playing : PlaybackStatus.paused;
    case ProcessingState.completed:
      return PlaybackStatus.completed;
  }
}

MediaItem toMediaItem(Track track) => MediaItem(
      id: track.streamUrl ?? track.id,
      title: track.title,
      artist: track.artistName,
      album: track.albumName,
      duration: track.duration,
      artUri: track.artworkUrl.isNotEmpty ? Uri.parse(track.artworkUrl) : null,
    );
