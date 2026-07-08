import 'dart:async';

import 'package:edmm/data/repositories/in_memory_local_library_repository.dart';
import 'package:edmm/domain/audio/audio_controller.dart';
import 'package:edmm/domain/logic/deep_link_track_loader.dart';
import 'package:edmm/domain/models/cloudinary_category.dart';
import 'package:edmm/domain/models/track.dart';
import 'package:edmm/domain/playback/playback_snapshot.dart';
import 'package:edmm/domain/repositories/track_repository.dart';
import 'package:edmm/domain/result.dart';
import 'package:flutter_test/flutter_test.dart';

Track _t(String id, {bool playable = true}) => Track(
  id: id,
  source: 'cloudinary',
  title: 'Song $id',
  artistId: 'a',
  artistName: 'Artist',
  durationMs: 1,
  streamUrl: playable ? 'https://example.com/$id.mp3' : '',
  metadata: const {'resourceType': 'video'},
);

class _Repo implements TrackRepository {
  _Repo(this.handler);

  final Result<List<Track>> Function(CloudinaryCategory category, String query)
  handler;
  final calls = <String>[];

  @override
  Future<Result<List<Track>>> getCatalog({
    required CloudinaryCategory category,
    String query = '',
    bool forceRefresh = false,
  }) async {
    calls.add('${category.wire}|$query');
    return handler(category, query);
  }
}

class _Audio implements AudioController {
  final loadedQueues = <List<Track>>[];
  int plays = 0;

  @override
  Stream<Duration> get position => Stream<Duration>.empty();

  @override
  Stream<PlaybackSnapshot> get snapshot => Stream<PlaybackSnapshot>.empty();

  @override
  bool get isShuffleEnabled => false;

  @override
  double get volume => 1.0;

  @override
  Future<void> loadQueue(List<Track> tracks, {int initialIndex = 0}) async {
    loadedQueues.add(tracks);
  }

  @override
  Future<void> play() async => plays++;

  @override
  Future<void> pause() async {}

  @override
  Future<void> seek(Duration position) async {}

  @override
  Future<void> next() async {}

  @override
  Future<void> previous() async {}

  @override
  Future<void> setShuffleEnabled(bool enabled) async {}

  @override
  Future<void> setVolume(double volume) async {}

  @override
  Future<void> setMute(bool muted) async {}

  @override
  Future<void> dispose() async {}
}

void main() {
  test('loads a cached playable track without autoplaying', () async {
    final localLibrary = InMemoryLocalLibraryRepository();
    await localLibrary.cacheTrack(_t('track-1'));
    final audio = _Audio();
    final repo = _Repo((category, query) => const Ok<List<Track>>([]));

    final loaded = await loadDeepLinkedTrack(
      trackId: 'track-1',
      trackRepository: repo,
      localLibrary: localLibrary,
      audio: audio,
    );

    expect(loaded, isTrue);
    expect(audio.loadedQueues.single.single.id, 'track-1');
    expect(audio.plays, 0);
    expect(repo.calls, isEmpty);
    expect(await localLibrary.getRecentTrackIds(), isEmpty);
  });

  test('falls back to remote catalogs and caches the matched track', () async {
    final localLibrary = InMemoryLocalLibraryRepository();
    final audio = _Audio();
    final repo = _Repo(
      (category, query) => Ok(
        category == CloudinaryCategory.edm ? [_t('track-2')] : [_t('other')],
      ),
    );

    final loaded = await loadDeepLinkedTrack(
      trackId: 'track-2',
      trackRepository: repo,
      localLibrary: localLibrary,
      audio: audio,
    );

    expect(loaded, isTrue);
    expect(repo.calls, ['pop|track-2', 'edm|track-2']);
    expect(audio.loadedQueues.single.single.id, 'track-2');
    expect((await localLibrary.getCachedTrack('track-2'))?.id, 'track-2');
    expect(await localLibrary.getRecentTrackIds(), isEmpty);
  });

  test(
    'returns false without loading audio when no playable match exists',
    () async {
      final audio = _Audio();
      final repo = _Repo(
        (category, query) => Ok([_t('track-3', playable: false)]),
      );

      final loaded = await loadDeepLinkedTrack(
        trackId: 'track-3',
        trackRepository: repo,
        localLibrary: InMemoryLocalLibraryRepository(),
        audio: audio,
      );

      expect(loaded, isFalse);
      expect(audio.loadedQueues, isEmpty);
      expect(audio.plays, 0);
    },
  );
}
