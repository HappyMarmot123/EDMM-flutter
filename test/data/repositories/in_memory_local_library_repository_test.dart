import 'package:edmm/data/repositories/in_memory_local_library_repository.dart';
import 'package:edmm/data/repositories/noop_local_library_repository.dart';
import 'package:edmm/domain/models/track.dart';
import 'package:flutter_test/flutter_test.dart';

Track _track(String id) => Track(
  id: id,
  source: 'cloudinary',
  title: id,
  artistId: 'a',
  artistName: 'A',
  durationMs: 1_000,
  streamUrl: 'https://example.com/$id',
  metadata: const {},
);

void main() {
  test('recent plays keep latest 10 and deduplicate on repeat', () async {
    final repo = InMemoryLocalLibraryRepository();
    for (var i = 0; i < 12; i++) {
      await repo.recordRecentPlay('track-$i');
    }
    expect(await repo.getRecentTrackIds(), hasLength(10));
    expect(await repo.getRecentTrackIds(), [
      'track-11',
      'track-10',
      'track-9',
      'track-8',
      'track-7',
      'track-6',
      'track-5',
      'track-4',
      'track-3',
      'track-2',
    ]);

    await repo.recordRecentPlay('track-5');
    expect(await repo.getRecentTrackIds(), [
      'track-5',
      'track-11',
      'track-10',
      'track-9',
      'track-8',
      'track-7',
      'track-6',
      'track-4',
      'track-3',
      'track-2',
    ]);
  });

  test('tracks cache roundtrips and preserves requested order', () async {
    final repo = InMemoryLocalLibraryRepository();

    await repo.cacheTrack(_track('t1'));
    await repo.cacheTrack(_track('t2'));
    await repo.cacheTrack(_track('t3'));
    final cached = await repo.getCachedTrack('t2');
    expect(cached?.id, 't2');

    final inOrder = await repo.getCachedTracks(['t3', 't1', 't2']);
    expect(inOrder.map((track) => track.id), ['t3', 't1', 't2']);
  });

  test('audio settings persist as simple key/value', () async {
    final repo = InMemoryLocalLibraryRepository();
    await repo.setAudioSetting('volume', '0.8');
    expect(await repo.getAudioSetting('volume'), '0.8');
    expect(await repo.getAudioSetting('missing'), isNull);
  });

  test('noop local repository keeps app-safe defaults', () async {
    const repo = NoopLocalLibraryRepository();
    expect(await repo.getRecentTrackIds(), isEmpty);
    expect(await repo.getCachedTrack('any'), isNull);
    expect(await repo.getCachedTracks(['any']), isEmpty);
    expect(await repo.getAudioSetting('any'), isNull);
  });
}
