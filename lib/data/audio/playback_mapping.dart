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

Uri? _absoluteHttpUri(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;
  final uri = Uri.tryParse(trimmed);
  if (uri == null || !uri.isAbsolute) return null;
  if (uri.toString() != trimmed) return null;
  final scheme = uri.scheme.toLowerCase();
  return (scheme == 'http' || scheme == 'https') ? uri : null;
}

Uri? streamUriForTrack(Track track) =>
    track.isPlayable ? _absoluteHttpUri(track.streamUrl) : null;

MediaItem toMediaItem(Track track) => MediaItem(
      id: streamUriForTrack(track)?.toString() ?? track.id,
      title: track.title,
      artist: track.artistName,
      album: track.albumName,
      duration: track.duration,
      artUri: _absoluteHttpUri(track.artworkUrl),
    );
