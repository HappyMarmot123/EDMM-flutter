// test/data/audio/playback_mapping_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart' show ProcessingState;
import 'package:edmm/domain/models/track.dart';
import 'package:edmm/domain/playback/playback_snapshot.dart';
import 'package:edmm/data/audio/playback_mapping.dart';

void main() {
  test('mapProcessingState maps just_audio states', () {
    expect(mapProcessingState(ProcessingState.idle, false), PlaybackStatus.idle);
    expect(mapProcessingState(ProcessingState.loading, false), PlaybackStatus.loading);
    expect(mapProcessingState(ProcessingState.buffering, true), PlaybackStatus.loading);
    expect(mapProcessingState(ProcessingState.ready, true), PlaybackStatus.playing);
    expect(mapProcessingState(ProcessingState.ready, false), PlaybackStatus.paused);
    expect(mapProcessingState(ProcessingState.completed, false), PlaybackStatus.completed);
  });

  test('toMediaItem carries artwork uri when present', () {
    final t = Track(id: 'x', source: 'cloudinary', title: 'T', artistId: 'a',
        artistName: 'A', albumName: 'Al', durationMs: 1000, streamUrl: 'u',
        artworkUrl: 'https://art/x.jpg', metadata: const {});
    final m = toMediaItem(t);
    expect(m.title, 'T');
    expect(m.artist, 'A');
    expect(m.artUri.toString(), 'https://art/x.jpg');
    expect(m.duration, const Duration(milliseconds: 1000));
  });

  test('toMediaItem has null artUri when artwork empty', () {
    final t = Track(id: 'x', source: 'cloudinary', title: 'T', artistId: 'a',
        artistName: 'A', durationMs: 1000, streamUrl: 'u', metadata: const {});
    expect(toMediaItem(t).artUri, isNull);
  });
}
