import 'dart:async';

import 'package:edmm/data/repositories/in_memory_local_library_repository.dart';
import 'package:edmm/domain/audio/audio_controller.dart';
import 'package:edmm/domain/models/cloudinary_category.dart';
import 'package:edmm/domain/models/track.dart';
import 'package:edmm/domain/playback/playback_snapshot.dart';
import 'package:edmm/domain/repositories/local_library_repository.dart';
import 'package:edmm/domain/repositories/track_repository.dart';
import 'package:edmm/domain/result.dart';
import 'package:edmm/domain/telemetry/catalog_search_telemetry.dart';
import 'package:edmm/domain/telemetry/playback_telemetry.dart';
import 'package:edmm/l10n/app_localizations.dart';
import 'package:edmm/routing/router.dart';
import 'package:edmm/routing/routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

Track _track(String id) => Track(
  id: id,
  source: 'cloudinary',
  title: 'Song $id',
  artistId: 'artist',
  artistName: 'Artist',
  durationMs: 60_000,
  streamUrl: 'https://audio.example/$id.m4a',
  metadata: const {'resourceType': 'video'},
);

class _Repo implements TrackRepository {
  @override
  Future<Result<List<Track>>> getCatalog({
    required CloudinaryCategory category,
    String query = '',
    bool forceRefresh = false,
  }) async => Ok([_track('1'), _track('2')]);
}

class _Audio implements AudioController {
  _Audio({this.loadSucceeds = true, this.loadHandler});

  final bool loadSucceeds;
  final Future<bool> Function(List<Track> tracks, int initialIndex)?
  loadHandler;
  final snapshots = StreamController<PlaybackSnapshot>.broadcast();
  final positions = StreamController<Duration>.broadcast();
  final loaded = <List<Track>>[];
  int plays = 0;

  @override
  Stream<PlaybackSnapshot> get snapshot => snapshots.stream;
  @override
  Stream<Duration> get position => positions.stream;
  @override
  bool get isShuffleEnabled => false;
  @override
  double get volume => 1;
  @override
  Future<bool> loadQueue(List<Track> tracks, {int initialIndex = 0}) async {
    loaded.add(tracks);
    final handler = loadHandler;
    if (handler != null) return handler(tracks, initialIndex);
    return loadSucceeds;
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
  Future<void> dispose() async {
    await snapshots.close();
    await positions.close();
  }
}

Widget _host(_Audio audio, LocalLibraryRepository localLibrary) =>
    MultiProvider(
      providers: [
        Provider<TrackRepository>.value(value: _Repo()),
        Provider<AudioController>.value(value: audio),
        Provider<LocalLibraryRepository>.value(value: localLibrary),
        Provider<CatalogSearchTelemetrySink>.value(
          value: const NoopCatalogSearchTelemetrySink(),
        ),
        Provider<PlaybackTelemetrySink>.value(
          value: const NoopPlaybackTelemetrySink(),
        ),
      ],
      child: MaterialApp.router(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: appRouter,
      ),
    );

void main() {
  testWidgets('one mini player survives catalog and track detail navigation', (
    tester,
  ) async {
    final audio = _Audio();
    final local = InMemoryLocalLibraryRepository();
    addTearDown(audio.dispose);
    addTearDown(() => appRouter.go(Routes.trackList));

    appRouter.go(Routes.trackList);
    await tester.pumpWidget(_host(audio, local));
    await tester.pumpAndSettle();
    audio.snapshots.add(
      PlaybackSnapshot(
        currentTrack: _track('1'),
        status: PlaybackStatus.playing,
        duration: const Duration(minutes: 1),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('player-mini-bar')), findsOneWidget);

    await tester.tap(find.byKey(const Key('catalog-track-detail-1')));
    await tester.pumpAndSettle();
    expect(find.text('Track details'), findsOneWidget);
    expect(find.byKey(const Key('player-mini-bar')), findsOneWidget);
    expect(audio.loaded, isEmpty);
    expect(audio.plays, 0);

    await tester.tap(find.byKey(const Key('track-detail-play')));
    await tester.pump();
    expect(audio.loaded.single.single.id, '1');
    expect(audio.plays, 1);
  });

  testWidgets('legacy collection URLs redirect to the catalog', (tester) async {
    final audio = _Audio();
    final local = InMemoryLocalLibraryRepository();
    addTearDown(audio.dispose);
    addTearDown(() => appRouter.go(Routes.trackList));

    appRouter.go('/library');
    await tester.pumpWidget(_host(audio, local));
    await tester.pumpAndSettle();

    expect(appRouter.routeInformationProvider.value.uri.path, Routes.trackList);
    expect(find.text('Song 1'), findsOneWidget);
    expect(find.byKey(const Key('catalog-open-library')), findsNothing);
    expect(find.byKey(const Key('library-scroll')), findsNothing);

    appRouter.go('/library/playlist/42');
    await tester.pumpAndSettle();

    expect(appRouter.routeInformationProvider.value.uri.path, Routes.trackList);
    expect(find.text('Song 1'), findsOneWidget);
    expect(find.byKey(const Key('playlist-detail-list')), findsNothing);
  });

  testWidgets('a direct track deep link resolves without starting playback', (
    tester,
  ) async {
    final audio = _Audio();
    final local = InMemoryLocalLibraryRepository();
    addTearDown(audio.dispose);
    addTearDown(() => appRouter.go(Routes.trackList));

    appRouter.go(trackDetailLocation('2'));
    await tester.pumpWidget(_host(audio, local));
    await tester.pumpAndSettle();

    expect(find.text('Song 2'), findsOneWidget);
    expect(audio.loaded, isEmpty);
    expect(audio.plays, 0);
    expect((await local.getCachedTrack('2'))?.id, '2');
  });

  testWidgets('a rejected queue load never starts the previous source', (
    tester,
  ) async {
    final audio = _Audio(loadSucceeds: false);
    final local = InMemoryLocalLibraryRepository();
    addTearDown(audio.dispose);
    addTearDown(() => appRouter.go(Routes.trackList));

    appRouter.go(trackDetailLocation('1'), extra: _track('1'));
    await tester.pumpWidget(_host(audio, local));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('track-detail-play')));
    await tester.pumpAndSettle();

    expect(audio.loaded, hasLength(1));
    expect(audio.plays, 0);
    expect(await local.getRecentTrackIds(), isEmpty);
  });

  testWidgets(
    'only the latest overlapping playback request plays and persists',
    (tester) async {
      final older = Completer<bool>();
      final newer = Completer<bool>();
      final audio = _Audio(
        loadHandler: (_, initialIndex) =>
            initialIndex == 0 ? older.future : newer.future,
      );
      final local = InMemoryLocalLibraryRepository();
      addTearDown(audio.dispose);
      addTearDown(() => appRouter.go(Routes.trackList));

      appRouter.go(Routes.trackList);
      await tester.pumpWidget(_host(audio, local));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Song 1'));
      await tester.pump();
      await tester.tap(find.text('Song 2'));
      await tester.pump();

      newer.complete(true);
      await tester.pump();
      await tester.pump();
      older.complete(true);
      await tester.pumpAndSettle();

      expect(audio.plays, 1);
      expect(await local.getRecentTrackIds(), ['2']);
    },
  );
}
