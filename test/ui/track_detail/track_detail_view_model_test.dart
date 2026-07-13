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

class _DelayedFavoriteLibrary extends InMemoryLocalLibraryRepository {
  final favoriteRead = Completer<bool>();
  var reads = 0;

  @override
  Future<bool> isFavorite(String trackId) {
    if (reads++ == 0) return favoriteRead.future;
    return super.isFavorite(trackId);
  }
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

class _DelayedPlaylistAddLibrary extends InMemoryLocalLibraryRepository {
  final addGate = Completer<void>();

  @override
  Future<bool> addTrackToPlaylist(int playlistId, String trackId) async {
    await addGate.future;
    return super.addTrackToPlaylist(playlistId, trackId);
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
    expect(vm.isFavorite, isFalse);
  });

  test('an initial route seed is available before asynchronous init', () async {
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
  });

  test('seed library load cannot overwrite a newer favorite toggle', () async {
    final local = _DelayedFavoriteLibrary();
    final vm = TrackDetailViewModel(
      trackId: 'track-1',
      initialTrack: _track(),
      resolver: TrackResolver(_EmptyTracks(), local),
      localLibrary: local,
    );

    final initialLoad = vm.init();
    await Future<void>.delayed(Duration.zero);
    expect(await vm.toggleFavorite(), isTrue);
    local.favoriteRead.complete(false);
    await initialLoad;

    expect(vm.isFavorite, isTrue);
    expect(await local.isFavorite('track-1'), isTrue);
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

  test('toggles favorite and caches before adding to a playlist', () async {
    final local = InMemoryLocalLibraryRepository();
    await local.cacheTrack(_track());
    final playlistId = await local.createPlaylist('Mix');
    final vm = TrackDetailViewModel(
      trackId: 'track-1',
      resolver: TrackResolver(_EmptyTracks(), local),
      localLibrary: local,
    );
    await vm.init();

    expect(await vm.toggleFavorite(), isTrue);
    expect(await local.isFavorite('track-1'), isTrue);
    expect(await vm.addToPlaylist(playlistId), isTrue);
    expect(await local.getPlaylistTrackIds(playlistId), ['track-1']);
    expect((await local.getCachedTrack('track-1'))?.title, 'Bloom');
  });

  test('adding to a deleted playlist reports failure', () async {
    final local = InMemoryLocalLibraryRepository();
    await local.cacheTrack(_track());
    final playlistId = await local.createPlaylist('Deleted');
    await local.deletePlaylist(playlistId);
    final vm = TrackDetailViewModel(
      trackId: 'track-1',
      resolver: TrackResolver(_EmptyTracks(), local),
      localLibrary: local,
    );
    await vm.init();

    expect(await vm.addToPlaylist(playlistId), isFalse);
    expect(await local.getPlaylistTrackIds(playlistId), isEmpty);
  });

  test('favorite and playlist mutations report independent success', () async {
    final local = _DelayedPlaylistAddLibrary();
    await local.cacheTrack(_track());
    final playlistId = await local.createPlaylist('Mix');
    final vm = TrackDetailViewModel(
      trackId: 'track-1',
      resolver: TrackResolver(_EmptyTracks(), local),
      localLibrary: local,
    );
    await vm.init();

    final playlistAdd = vm.addToPlaylist(playlistId);
    await Future<void>.delayed(Duration.zero);
    final favoriteToggle = await vm.toggleFavorite();
    local.addGate.complete();

    expect(favoriteToggle, isTrue);
    expect(await playlistAdd, isTrue);
    expect(await local.isFavorite('track-1'), isTrue);
    expect(await local.getPlaylistTrackIds(playlistId), ['track-1']);
  });
}
