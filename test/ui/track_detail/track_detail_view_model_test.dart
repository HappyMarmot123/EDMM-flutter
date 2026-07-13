import 'dart:async';

import 'package:edmm/data/repositories/in_memory_local_library_repository.dart';
import 'package:edmm/domain/logic/track_resolver.dart';
import 'package:edmm/domain/models/cloudinary_category.dart';
import 'package:edmm/domain/models/track.dart';
import 'package:edmm/domain/repositories/track_repository.dart';
import 'package:edmm/domain/result.dart';
import 'package:edmm/ui/track_detail/view_model/track_detail_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

Track _track({String title = 'Bloom'}) => Track(
  id: 'track-1',
  source: 'cloudinary',
  title: title,
  artistId: 'artist',
  artistName: 'Feint',
  albumName: 'Monstercat',
  durationMs: 90_000,
  streamUrl: 'https://example.com/track-1.mp3',
  metadata: const {'resourceType': 'video', 'genre': 'Drum & Bass'},
);

class _EmptyTracks implements TrackRepository {
  @override
  Future<Result<List<Track>>> getCatalog({
    required CloudinaryCategory category,
    String query = '',
    bool forceRefresh = false,
  }) async => const Ok([]);
}

class _SequencedTracks implements TrackRepository {
  final responses = <Completer<Result<List<Track>>>>[];
  var calls = 0;

  @override
  Future<Result<List<Track>>> getCatalog({
    required CloudinaryCategory category,
    String query = '',
    bool forceRefresh = false,
  }) => responses[calls++].future;
}

class _FailingCacheLibrary extends InMemoryLocalLibraryRepository {
  @override
  Future<void> cacheTrack(Track track) async {
    throw StateError('storage');
  }
}

void main() {
  test('loads detail without any playback dependency or side effect', () async {
    final local = InMemoryLocalLibraryRepository();
    await local.cacheTrack(_track());
    final vm = TrackDetailViewModel(
      trackId: 'track-1',
      resolver: TrackResolver(_EmptyTracks(), local),
      localLibrary: local,
    );

    await vm.init();

    expect(vm.status, TrackDetailStatus.data);
    expect(vm.track?.title, 'Bloom');
  });

  test('an initial route seed is available and cached during init', () async {
    final local = InMemoryLocalLibraryRepository();
    final vm = TrackDetailViewModel(
      trackId: 'track-1',
      initialTrack: _track(),
      resolver: TrackResolver(_EmptyTracks(), local),
      localLibrary: local,
    );

    expect(vm.status, TrackDetailStatus.data);
    expect(vm.track?.title, 'Bloom');
    await vm.init();
    expect(vm.status, TrackDetailStatus.data);
    expect((await local.getCachedTrack('track-1'))?.title, 'Bloom');
  });

  test('seed cache failures are exposed without hiding detail', () async {
    final local = _FailingCacheLibrary();
    final vm = TrackDetailViewModel(
      trackId: 'track-1',
      initialTrack: _track(),
      resolver: TrackResolver(_EmptyTracks(), local),
      localLibrary: local,
    );

    await vm.init();

    expect(vm.status, TrackDetailStatus.data);
    expect(vm.track?.title, 'Bloom');
    expect(vm.storageError, isA<StateError>());
  });

  test('detail ignores an older resolution that completes last', () async {
    final local = InMemoryLocalLibraryRepository();
    final tracks = _SequencedTracks();
    final older = Completer<Result<List<Track>>>();
    final newer = Completer<Result<List<Track>>>();
    tracks.responses.addAll([older, newer]);
    final vm = TrackDetailViewModel(
      trackId: 'track-1',
      resolver: TrackResolver(tracks, local),
      localLibrary: local,
    );

    final olderLoad = vm.init();
    await Future<void>.delayed(Duration.zero);
    final newerLoad = vm.retry();
    newer.complete(Ok([_track(title: 'New')]));
    await newerLoad;
    older.complete(Ok([_track(title: 'Old')]));
    await olderLoad;

    expect(vm.track?.title, 'New');
    expect((await local.getCachedTrack('track-1'))?.title, 'New');
  });
}
