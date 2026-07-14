import 'package:edmm/data/repositories/in_memory_local_library_repository.dart';
import 'package:edmm/domain/logic/track_resolver.dart';
import 'package:edmm/domain/models/cloudinary_category.dart';
import 'package:edmm/domain/models/track.dart';
import 'package:edmm/domain/repositories/track_repository.dart';
import 'package:edmm/domain/result.dart';
import 'package:flutter_test/flutter_test.dart';

Track _track(String id, {bool playable = true}) => Track(
  id: id,
  source: 'cloudinary',
  title: 'Song $id',
  artistId: 'artist',
  artistName: 'Artist',
  durationMs: 60_000,
  streamUrl: playable ? 'https://example.com/$id.mp3' : null,
  metadata: const {'resourceType': 'video'},
);

class _TrackRepository implements TrackRepository {
  _TrackRepository(this.onGet);

  final Result<List<Track>> Function(CloudinaryCategory, String) onGet;
  final calls = <String>[];

  @override
  Future<Result<List<Track>>> getCatalog({
    required CloudinaryCategory category,
    String query = '',
    bool forceRefresh = false,
  }) async {
    calls.add('${category.wire}|$query|$forceRefresh');
    return onGet(category, query);
  }
}

void main() {
  test('returns the cached track without touching remote catalogs', () async {
    final local = InMemoryLocalLibraryRepository();
    await local.cacheTrack(_track('cached', playable: false));
    final remote = _TrackRepository((_, _) => const Ok([]));

    final result = await TrackResolver(remote, local).resolve('cached');

    expect(result, isA<Ok<Track?>>());
    expect((result as Ok<Track?>).value?.id, 'cached');
    expect(remote.calls, isEmpty);
  });

  test(
    'finds an exact remote match, preserves category order, and caches it',
    () async {
      final local = InMemoryLocalLibraryRepository();
      final remote = _TrackRepository(
        (category, _) => Ok(
          category == CloudinaryCategory.edm
              ? [_track('target')]
              : [_track('not-target')],
        ),
      );

      final result = await TrackResolver(remote, local).resolve('target');

      expect((result as Ok<Track?>).value?.id, 'target');
      expect(remote.calls, ['pop|target|false', 'edm|target|false']);
      expect((await local.getCachedTrack('target'))?.id, 'target');
    },
  );

  test('a later exact match wins over an earlier catalog failure', () async {
    final remote = _TrackRepository(
      (category, _) => category == CloudinaryCategory.pop
          ? const Err(NetworkFailure('offline'))
          : Ok([_track('target')]),
    );

    final result = await TrackResolver(
      remote,
      InMemoryLocalLibraryRepository(),
    ).resolve('target');

    expect((result as Ok<Track?>).value?.id, 'target');
  });
}
