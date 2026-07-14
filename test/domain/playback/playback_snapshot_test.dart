import 'package:flutter_test/flutter_test.dart';
import 'package:edmm/domain/models/track.dart';
import 'package:edmm/domain/playback/playback_snapshot.dart';
import 'package:edmm/domain/result.dart';

void main() {
  test('defaults and isPlaying', () {
    const s = PlaybackSnapshot();
    expect(s.status, PlaybackStatus.idle);
    expect(s.isPlaying, isFalse);
    expect(s.copyWith(status: PlaybackStatus.playing).isPlaying, isTrue);
  });

  test('supports equality for stable replay comparisons', () {
    const a = PlaybackSnapshot(
      status: PlaybackStatus.paused,
      duration: Duration(seconds: 3),
      queueIndex: 1,
      hasNext: true,
    );
    const b = PlaybackSnapshot(
      status: PlaybackStatus.paused,
      duration: Duration(seconds: 3),
      queueIndex: 1,
      hasNext: true,
    );

    expect(a, b);
    expect(a.hashCode, b.hashCode);
  });

  test('copyWith can explicitly clear nullable fields', () {
    final track = Track(
      id: 'x',
      source: 'cloudinary',
      title: 'T',
      artistId: 'a',
      artistName: 'A',
      durationMs: 1000,
      streamUrl: 'https://audio/x.m4a',
      metadata: const {},
    );
    final s = PlaybackSnapshot(
      currentTrack: track,
      queueIndex: 2,
      error: const NetworkFailure('offline'),
    );

    final cleared = s.copyWith(
      clearCurrentTrack: true,
      clearQueueIndex: true,
      clearError: true,
    );

    expect(cleared.currentTrack, isNull);
    expect(cleared.queueIndex, isNull);
    expect(cleared.error, isNull);
  });
}
