import 'package:edmm/data/repositories/in_memory_local_library_repository.dart';
import 'package:edmm/domain/models/library_track_item.dart';
import 'package:edmm/domain/models/track.dart';
import 'package:edmm/l10n/app_localizations.dart';
import 'package:edmm/ui/library/view_model/library_view_model.dart';
import 'package:edmm/ui/library/view_model/playlist_detail_view_model.dart';
import 'package:edmm/ui/library/widgets/library_screen.dart';
import 'package:edmm/ui/library/widgets/local_library_track_tile.dart';
import 'package:edmm/ui/library/widgets/playlist_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Track _track(String id) => Track(
  id: id,
  source: 'cloudinary',
  title: 'Song $id',
  artistId: 'artist',
  artistName: 'Artist',
  durationMs: 60_000,
  streamUrl: 'https://example.com/$id.mp3',
);

Widget _host(Widget child, {double textScale = 1}) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(
      context,
    ).copyWith(textScaler: TextScaler.linear(textScale)),
    child: child!,
  ),
  home: child,
);

void main() {
  testWidgets('local track actions stay compact on a narrow scaled surface', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(280, 400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var plays = 0;
    var removes = 0;

    await tester.pumpWidget(
      _host(
        Scaffold(
          body: LocalLibraryTrackTile(
            item: LibraryTrackItem(
              trackId: 'long',
              track: _track(
                'a-very-long-track-title-that-needs-readable-space',
              ),
            ),
            onOpenTrack: () {},
            onPlay: () => plays++,
            onRemove: () => removes++,
            playButtonKey: const Key('narrow-track-play'),
          ),
        ),
        textScale: 2,
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byIcon(Icons.chevron_right), findsNothing);
    expect(find.byIcon(Icons.more_vert), findsOneWidget);
    await tester.tap(find.byKey(const Key('narrow-track-play')));
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove from playlist'));
    expect(plays, 1);
    expect(removes, 1);
  });

  testWidgets('shows favorites and playlists and delegates favorite playback', (
    tester,
  ) async {
    final local = InMemoryLocalLibraryRepository();
    await local.cacheTrack(_track('one'));
    await local.setFavorite('one', true);
    await local.createPlaylist('Mix');
    var playCount = 0;

    await tester.pumpWidget(
      _host(
        LibraryScreen(
          viewModel: LibraryViewModel(local),
          onPlay: (_, _) => playCount++,
          onOpenTrack: (_) {},
          onOpenPlaylist: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Favorites'), findsOneWidget);
    expect(find.text('Song one'), findsOneWidget);
    expect(find.text('Mix'), findsOneWidget);
    await tester.tap(find.byKey(const Key('library-favorite-play-one')));
    expect(playCount, 1);
  });

  testWidgets('playlist detail preserves rows and delegates playback', (
    tester,
  ) async {
    final local = InMemoryLocalLibraryRepository();
    final playlistId = await local.createPlaylist('Mix');
    await local.cacheTrack(_track('one'));
    await local.addTrackToPlaylist(playlistId, 'one');
    var selection = (<Track>[], -1);

    await tester.pumpWidget(
      _host(
        PlaylistDetailScreen(
          viewModel: PlaylistDetailViewModel(local, playlistId: playlistId),
          onPlay: (queue, index) => selection = (queue, index),
          onOpenTrack: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Mix'), findsOneWidget);
    expect(find.text('Song one'), findsOneWidget);
    await tester.tap(find.byKey(const Key('playlist-track-play-one')));
    expect(selection.$1.single.id, 'one');
    expect(selection.$2, 0);
  });

  testWidgets('library and playlist detail build long collections lazily', (
    tester,
  ) async {
    var now = 0;
    final local = InMemoryLocalLibraryRepository(nowMs: () => now++);
    for (var index = 0; index < 60; index++) {
      await local.createPlaylist('Playlist $index');
    }

    await tester.pumpWidget(
      _host(
        LibraryScreen(
          viewModel: LibraryViewModel(local),
          onPlay: (_, _) {},
          onOpenTrack: (_) {},
          onOpenPlaylist: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    final playlistsSliver = tester.widget<SliverList>(
      find.byKey(const Key('library-playlists-list')),
    );
    expect(playlistsSliver.delegate, isA<SliverChildBuilderDelegate>());
    expect(find.text('Playlist 0'), findsNothing);
    await tester.scrollUntilVisible(
      find.text('Playlist 0'),
      600,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Playlist 0'), findsOneWidget);

    final tracks = InMemoryLocalLibraryRepository();
    final playlistId = await tracks.createPlaylist('Long mix');
    for (var index = 0; index < 60; index++) {
      final track = _track('$index');
      await tracks.cacheTrack(track);
      await tracks.addTrackToPlaylist(playlistId, track.id);
    }
    await tester.pumpWidget(
      _host(
        PlaylistDetailScreen(
          viewModel: PlaylistDetailViewModel(tracks, playlistId: playlistId),
          onPlay: (_, _) {},
          onOpenTrack: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    final trackList = tester.widget<ListView>(
      find.byKey(const Key('playlist-detail-list')),
    );
    expect(trackList.childrenDelegate, isA<SliverChildBuilderDelegate>());
    expect(find.text('Song 59'), findsNothing);
    await tester.scrollUntilVisible(
      find.text('Song 59'),
      600,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Song 59'), findsOneWidget);
  });

  testWidgets('blank playlist name keeps the dialog open with validation', (
    tester,
  ) async {
    final local = InMemoryLocalLibraryRepository();
    await tester.pumpWidget(
      _host(
        LibraryScreen(
          viewModel: LibraryViewModel(local),
          onPlay: (_, _) {},
          onOpenTrack: (_) {},
          onOpenPlaylist: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('playlist-create-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('playlist-create-confirm')));
    await tester.pump();

    expect(find.byKey(const Key('playlist-name-field')), findsOneWidget);
    final field = tester.widget<TextField>(
      find.byKey(const Key('playlist-name-field')),
    );
    expect(field.decoration?.errorText, isNotNull);
    expect(await local.getPlaylists(), isEmpty);

    await tester.enterText(
      find.byKey(const Key('playlist-name-field')),
      'Valid mix',
    );
    await tester.tap(find.byKey(const Key('playlist-create-confirm')));
    await tester.pumpAndSettle();
    expect((await local.getPlaylists()).single.name, 'Valid mix');
  });
}
