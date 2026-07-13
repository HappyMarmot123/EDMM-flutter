// test/data/audio/playback_mapping_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart' show ProcessingState;
import 'package:edmm/domain/models/track.dart';
import 'package:edmm/domain/playback/playback_snapshot.dart';
import 'package:edmm/domain/result.dart';
import 'package:edmm/data/audio/playback_mapping.dart';

void main() {
  test('mapProcessingState maps just_audio states', () {
    expect(
      mapProcessingState(ProcessingState.idle, false),
      PlaybackStatus.idle,
    );
    expect(
      mapProcessingState(ProcessingState.loading, false),
      PlaybackStatus.loading,
    );
    expect(
      mapProcessingState(ProcessingState.buffering, true),
      PlaybackStatus.loading,
    );
    expect(
      mapProcessingState(ProcessingState.ready, true),
      PlaybackStatus.playing,
    );
    expect(
      mapProcessingState(ProcessingState.ready, false),
      PlaybackStatus.paused,
    );
    expect(
      mapProcessingState(ProcessingState.completed, false),
      PlaybackStatus.completed,
    );
  });

  test('toMediaItem carries artwork uri when present', () {
    final t = Track(
      id: 'x',
      source: 'cloudinary',
      title: 'T',
      artistId: 'a',
      artistName: 'A',
      albumName: 'Al',
      durationMs: 1000,
      streamUrl: 'u',
      artworkUrl: 'https://art/x.jpg',
      metadata: const {},
    );
    final m = toMediaItem(t);
    expect(m.title, 'T');
    expect(m.artist, 'A');
    expect(m.artUri.toString(), 'https://art/x.jpg');
    expect(m.duration, const Duration(milliseconds: 1000));
  });

  test('toMediaItem has null artUri when artwork empty', () {
    final t = Track(
      id: 'x',
      source: 'cloudinary',
      title: 'T',
      artistId: 'a',
      artistName: 'A',
      durationMs: 1000,
      streamUrl: 'u',
      metadata: const {},
    );
    expect(toMediaItem(t).artUri, isNull);
  });

  test('toMediaItem ignores invalid artwork uri', () {
    final t = Track(
      id: 'x',
      source: 'cloudinary',
      title: 'T',
      artistId: 'a',
      artistName: 'A',
      durationMs: 1000,
      streamUrl: 'https://audio/x.m4a',
      artworkUrl: 'https://art/%zz',
      metadata: const {},
    );
    expect(toMediaItem(t).artUri, isNull);
  });

  test('streamUriForTrack accepts only playable absolute http urls', () {
    Track track(String? streamUrl, {String resourceType = 'video'}) => Track(
      id: streamUrl ?? 'none',
      source: 'cloudinary',
      title: 'T',
      artistId: 'a',
      artistName: 'A',
      durationMs: 1000,
      streamUrl: streamUrl,
      metadata: {'resourceType': resourceType},
    );

    expect(
      streamUriForTrack(track('https://audio/x.m4a')).toString(),
      'https://audio/x.m4a',
    );
    expect(streamUriForTrack(track('')), isNull);
    expect(streamUriForTrack(track('relative/path.m4a')), isNull);
    expect(streamUriForTrack(track('ftp://audio/x.m4a')), isNull);
    expect(streamUriForTrack(track('https://audio/%zz')), isNull);
    expect(
      streamUriForTrack(track('https://image/x.jpg', resourceType: 'image')),
      isNull,
    );
  });

  test('snapshotWithPlaybackError preserves the active queue context', () {
    final track = Track(
      id: 'current',
      source: 'cloudinary',
      title: 'Current',
      artistId: 'artist',
      artistName: 'Artist',
      durationMs: 90000,
      streamUrl: 'https://audio.example/current.m4a',
    );
    final current = PlaybackSnapshot(
      currentTrack: track,
      status: PlaybackStatus.playing,
      duration: const Duration(seconds: 90),
      queueIndex: 2,
      hasNext: true,
      hasPrevious: true,
    );
    const failure = ParseFailure('decoder failed');

    final errored = snapshotWithPlaybackError(current, failure);

    expect(errored.currentTrack, track);
    expect(errored.duration, const Duration(seconds: 90));
    expect(errored.queueIndex, 2);
    expect(errored.hasNext, isTrue);
    expect(errored.hasPrevious, isTrue);
    expect(errored.status, PlaybackStatus.error);
    expect(errored.error, failure);
  });
}
