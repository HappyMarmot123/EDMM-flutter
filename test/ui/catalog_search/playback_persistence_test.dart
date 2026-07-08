import 'package:edmm/data/repositories/in_memory_local_library_repository.dart';
import 'package:edmm/domain/logic/playback_persistence.dart';
import 'package:edmm/domain/models/track.dart';
import 'package:flutter_test/flutter_test.dart';

Track _t(String id) => Track(
  id: id,
  source: 'cloudinary',
  title: 'Song $id',
  artistId: 'a',
  artistName: 'Artist',
  durationMs: 1,
  streamUrl: 'u',
  metadata: const {'resourceType': 'video'},
);

void main() {
  test('caches the queue and records the selected track as recent', () async {
    final localLibrary = InMemoryLocalLibraryRepository();
    final queue = [_t('1'), _t('2')];

    await persistPlaybackSelection(localLibrary, queue, 1);

    expect(await localLibrary.getRecentTrackIds(), ['2']);
    expect(
      (await localLibrary.getCachedTracks(['1', '2'])).map((track) => track.id),
      ['1', '2'],
    );
  });

  test(
    'caches the queue without recording recent when index is invalid',
    () async {
      final localLibrary = InMemoryLocalLibraryRepository();
      final queue = [_t('1')];

      await persistPlaybackSelection(localLibrary, queue, 3);

      expect(await localLibrary.getRecentTrackIds(), isEmpty);
      expect((await localLibrary.getCachedTrack('1'))?.id, '1');
    },
  );
}
