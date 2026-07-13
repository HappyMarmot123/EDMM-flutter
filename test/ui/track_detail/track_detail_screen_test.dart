import 'package:edmm/data/repositories/in_memory_local_library_repository.dart';
import 'package:edmm/domain/logic/track_resolver.dart';
import 'package:edmm/domain/models/cloudinary_category.dart';
import 'package:edmm/domain/models/track.dart';
import 'package:edmm/domain/repositories/track_repository.dart';
import 'package:edmm/domain/result.dart';
import 'package:edmm/l10n/app_localizations.dart';
import 'package:edmm/ui/track_detail/view_model/track_detail_view_model.dart';
import 'package:edmm/ui/track_detail/widgets/track_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _EmptyTracks implements TrackRepository {
  @override
  Future<Result<List<Track>>> getCatalog({
    required CloudinaryCategory category,
    String query = '',
    bool forceRefresh = false,
  }) async => const Ok([]);
}

const _track = Track(
  id: 'track-1',
  source: 'cloudinary',
  title: 'Bloom',
  artistId: 'artist',
  artistName: 'Feint',
  albumName: 'Monstercat',
  durationMs: 90_000,
  streamUrl: 'https://example.com/track-1.mp3',
  metadata: {'genre': 'Drum & Bass'},
);

void main() {
  testWidgets('playlist picker scrolls a long collection on a small surface', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var now = 0;
    final local = InMemoryLocalLibraryRepository(nowMs: () => now++);
    await local.cacheTrack(_track);
    for (var index = 0; index < 30; index++) {
      await local.createPlaylist('Playlist $index');
    }
    final vm = TrackDetailViewModel(
      trackId: _track.id,
      initialTrack: _track,
      resolver: TrackResolver(_EmptyTracks(), local),
      localLibrary: local,
    );

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: TrackDetailScreen(viewModel: vm, onPlay: (_) {}),
      ),
    );
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('track-detail-add-playlist')));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    final picker = tester.widget<ListView>(
      find.byKey(const Key('track-detail-playlist-list')),
    );
    expect(picker.childrenDelegate, isA<SliverChildBuilderDelegate>());
    expect(find.text('Playlist 0'), findsNothing);
    await tester.scrollUntilVisible(
      find.text('Playlist 0'),
      400,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Playlist 0'), findsOneWidget);
    expect(
      find.byKey(const Key('track-detail-create-playlist')),
      findsOneWidget,
    );
  });

  testWidgets('renders metadata and only plays after explicit Play tap', (
    tester,
  ) async {
    final local = InMemoryLocalLibraryRepository();
    await local.cacheTrack(_track);
    final vm = TrackDetailViewModel(
      trackId: _track.id,
      resolver: TrackResolver(_EmptyTracks(), local),
      localLibrary: local,
    );
    var playCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: TrackDetailScreen(viewModel: vm, onPlay: (_) => playCount++),
      ),
    );
    await tester.pumpAndSettle();

    expect(playCount, 0);
    expect(find.text('Bloom'), findsOneWidget);
    expect(find.text('Feint'), findsOneWidget);
    expect(find.text('Monstercat'), findsOneWidget);

    await tester.tap(find.byKey(const Key('track-detail-play')));
    await tester.pump();
    expect(playCount, 1);

    await tester.scrollUntilVisible(
      find.text('Drum & Bass'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Drum & Bass'), findsOneWidget);
  });

  testWidgets('creates a named playlist and adds the current track', (
    tester,
  ) async {
    final local = InMemoryLocalLibraryRepository();
    await local.cacheTrack(_track);
    final vm = TrackDetailViewModel(
      trackId: _track.id,
      initialTrack: _track,
      resolver: TrackResolver(_EmptyTracks(), local),
      localLibrary: local,
    );

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: TrackDetailScreen(viewModel: vm, onPlay: (_) {}),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('track-detail-add-playlist')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('track-detail-create-playlist')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('track-detail-create-playlist-confirm')),
    );
    await tester.pump();
    expect(find.byKey(const Key('track-detail-playlist-name')), findsOneWidget);
    final blankField = tester.widget<TextField>(
      find.byKey(const Key('track-detail-playlist-name')),
    );
    expect(blankField.decoration?.errorText, isNotNull);
    expect(await local.getPlaylists(), isEmpty);

    await tester.enterText(
      find.byKey(const Key('track-detail-playlist-name')),
      'Night Drive',
    );
    await tester.tap(
      find.byKey(const Key('track-detail-create-playlist-confirm')),
    );
    await tester.pumpAndSettle();

    final playlist = (await local.getPlaylists()).single;
    expect(playlist.name, 'Night Drive');
    expect(await local.getPlaylistTrackIds(playlist.id!), ['track-1']);
  });
}
