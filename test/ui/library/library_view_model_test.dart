import 'dart:async';

import 'package:edmm/data/repositories/in_memory_local_library_repository.dart';
import 'package:edmm/domain/models/local_library_entities.dart';
import 'package:edmm/domain/models/track.dart';
import 'package:edmm/ui/library/view_model/library_view_model.dart';
import 'package:edmm/ui/library/view_model/playlist_detail_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

Track _track(String id) => Track(
  id: id,
  source: 'cloudinary',
  title: 'Song $id',
  artistId: 'artist',
  artistName: 'Artist',
  durationMs: 1_000,
  streamUrl: 'https://example.com/$id.mp3',
);

class _FailingLibrary extends InMemoryLocalLibraryRepository {
  @override
  Future<List<FavoriteRow>> getFavorites() => throw StateError('storage');
}

class _SequencedFavoritesLibrary extends InMemoryLocalLibraryRepository {
  final responses = <Completer<List<FavoriteRow>>>[];
  var calls = 0;

  @override
  Future<List<FavoriteRow>> getFavorites() => responses[calls++].future;
}

class _SequencedPlaylistsLibrary extends InMemoryLocalLibraryRepository {
  final responses = <Completer<List<PlaylistRow>>>[];
  var calls = 0;

  @override
  Future<List<PlaylistRow>> getPlaylists() => responses[calls++].future;
}

void main() {
  test('hydrates favorites from cache in favorite order', () async {
    var now = 0;
    final local = InMemoryLocalLibraryRepository(nowMs: () => ++now);
    await local.cacheTrack(_track('first'));
    await local.cacheTrack(_track('second'));
    await local.setFavorite('first', true);
    await local.setFavorite('second', true);

    final vm = LibraryViewModel(local);
    await vm.init();

    expect(vm.status, LibraryStatus.data);
    expect(vm.favorites.map((item) => item.trackId), ['second', 'first']);
    expect(vm.favorites.map((item) => item.track?.id), ['second', 'first']);
  });

  test('creates trimmed playlists and deletes them', () async {
    final local = InMemoryLocalLibraryRepository();
    final vm = LibraryViewModel(local);
    await vm.init();

    expect(await vm.createPlaylist('  Road trip  '), isTrue);
    expect(vm.playlists.single.name, 'Road trip');
    await vm.deletePlaylist(vm.playlists.single.id!);
    expect(vm.playlists, isEmpty);
  });

  test('exposes storage failures instead of an empty library', () async {
    final vm = LibraryViewModel(_FailingLibrary());

    await vm.init();

    expect(vm.status, LibraryStatus.storageError);
    expect(vm.error, isA<StateError>());
  });

  test('library ignores an older refresh that completes last', () async {
    final local = _SequencedFavoritesLibrary();
    await local.cacheTrack(_track('older'));
    await local.cacheTrack(_track('newer'));
    final older = Completer<List<FavoriteRow>>();
    final newer = Completer<List<FavoriteRow>>();
    local.responses.addAll([older, newer]);
    final vm = LibraryViewModel(local);

    final olderLoad = vm.refresh();
    final newerLoad = vm.refresh();
    newer.complete(const [FavoriteRow(id: 2, trackId: 'newer', addedAt: 2)]);
    await newerLoad;
    older.complete(const [FavoriteRow(id: 1, trackId: 'older', addedAt: 1)]);
    await olderLoad;

    expect(vm.favorites.map((item) => item.trackId), ['newer']);
  });

  test(
    'playlist detail keeps insertion order and maps playback index',
    () async {
      final local = InMemoryLocalLibraryRepository();
      final playlistId = await local.createPlaylist('Mix');
      await local.cacheTrack(_track('one'));
      await local.cacheTrack(_track('two'));
      await local.addTrackToPlaylist(playlistId, 'two');
      await local.addTrackToPlaylist(playlistId, 'one');

      final vm = PlaylistDetailViewModel(local, playlistId: playlistId);
      await vm.init();

      expect(vm.items.map((item) => item.trackId), ['two', 'one']);
      final selection = vm.playbackSelectionFor('one');
      expect(selection?.queue.map((track) => track.id), ['two', 'one']);
      expect(selection?.index, 1);
    },
  );

  test(
    'playlist detail ignores an older refresh that completes last',
    () async {
      final local = _SequencedPlaylistsLibrary();
      final older = Completer<List<PlaylistRow>>();
      final newer = Completer<List<PlaylistRow>>();
      local.responses.addAll([older, newer]);
      final vm = PlaylistDetailViewModel(local, playlistId: 1);

      final olderLoad = vm.refresh();
      final newerLoad = vm.refresh();
      newer.complete(const [PlaylistRow(id: 1, name: 'New', createdAt: 2)]);
      await newerLoad;
      older.complete(const [PlaylistRow(id: 1, name: 'Old', createdAt: 1)]);
      await olderLoad;

      expect(vm.playlist?.name, 'New');
    },
  );
}
