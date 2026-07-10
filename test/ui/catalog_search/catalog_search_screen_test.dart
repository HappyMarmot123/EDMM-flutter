import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:edmm/data/repositories/in_memory_local_library_repository.dart';
import 'package:edmm/l10n/app_localizations.dart';
import 'package:edmm/domain/audio/audio_controller.dart';
import 'package:edmm/domain/models/cloudinary_category.dart';
import 'package:edmm/domain/models/track.dart';
import 'package:edmm/domain/playback/playback_snapshot.dart';
import 'package:edmm/domain/repositories/track_repository.dart';
import 'package:edmm/domain/result.dart';
import 'package:edmm/ui/catalog_search/view_model/catalog_search_view_model.dart';
import 'package:edmm/ui/catalog_search/widgets/catalog_search_screen.dart';
import 'package:edmm/ui/player/view_model/player_view_model.dart';

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

class _Repo implements TrackRepository {
  _Repo(this.handler);
  Result<List<Track>> Function(CloudinaryCategory category, String query)
  handler;
  @override
  Future<Result<List<Track>>> getCatalog({
    required CloudinaryCategory category,
    String query = '',
    bool forceRefresh = false,
  }) async => handler(category, query);
}

class _Audio implements AudioController {
  final _snap = StreamController<PlaybackSnapshot>.broadcast();
  final _pos = StreamController<Duration>.broadcast();
  int pauses = 0;

  @override
  Stream<PlaybackSnapshot> get snapshot => _snap.stream;
  @override
  Stream<Duration> get position => _pos.stream;
  @override
  bool get isShuffleEnabled => false;
  @override
  double get volume => 1.0;
  @override
  Future<void> loadQueue(List<Track> tracks, {int initialIndex = 0}) async {}
  @override
  Future<void> setShuffleEnabled(bool enabled) async {}
  @override
  Future<void> setVolume(double volume) async {}
  @override
  Future<void> setMute(bool muted) async {}
  @override
  Future<void> play() async {}
  @override
  Future<void> pause() async => pauses++;
  @override
  Future<void> seek(Duration position) async {}
  @override
  Future<void> next() async {}
  @override
  Future<void> previous() async {}
  @override
  Future<void> dispose() async {
    await _snap.close();
    await _pos.close();
  }

  void emit(PlaybackSnapshot snapshot) => _snap.add(snapshot);
}

CatalogSearchViewModel _vm(
  Result<List<Track>> Function(CloudinaryCategory, String) handler, {
  InMemoryLocalLibraryRepository? localLibrary,
  CatalogView? initialView,
  _Audio? audio,
}) => CatalogSearchViewModel(
  _Repo(handler),
  audio ?? _Audio(),
  localLibrary ?? InMemoryLocalLibraryRepository(),
  initialView: initialView,
  searchDebounce: Duration.zero,
);

Widget _host(Widget child) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: child,
);

void main() {
  testWidgets('renders rows and delegates onPlay on tap', (tester) async {
    final vm = _vm((c, q) => Ok([_t('1'), _t('2')]));
    List<Track>? queue;
    int? index;
    await tester.pumpWidget(
      _host(
        CatalogSearchScreen(
          viewModel: vm,
          onPlay: (q, i) {
            queue = q;
            index = i;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Song 1'), findsOneWidget);
    await tester.tap(find.text('Song 2'));
    expect(index, 1);
    expect(queue!.length, 2);
  });

  testWidgets('shows the mini player below search results during playback', (
    tester,
  ) async {
    final audio = _Audio();
    final catalogVm = _vm((c, q) => Ok([_t('1'), _t('2')]), audio: audio);
    final playerVm = PlayerViewModel(audio);
    var openPlayerCount = 0;

    await tester.pumpWidget(
      _host(
        CatalogSearchScreen(
          viewModel: catalogVm,
          playerViewModel: playerVm,
          onOpenPlayer: () => openPlayerCount++,
          onPlay: (_, _) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    audio.emit(
      PlaybackSnapshot(
        currentTrack: _t('2'),
        status: PlaybackStatus.playing,
        duration: const Duration(minutes: 1),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Song 1'), findsOneWidget);
    expect(find.byKey(const Key('player-mini-bar')), findsOneWidget);
    expect(find.text('Song 2'), findsNWidgets(2));

    await tester.tap(find.byKey(const Key('player-mini-play-pause')));
    await tester.pump();
    expect(audio.pauses, 1);

    await tester.tap(find.byKey(const Key('player-mini-open')));
    await tester.pump();
    expect(openPlayerCount, 1);
  });

  testWidgets('search with no results shows the clear-search action', (
    tester,
  ) async {
    final vm = _vm((c, q) => Ok(q == 'zzz' ? <Track>[] : [_t('1')]));
    await tester.pumpWidget(
      _host(CatalogSearchScreen(viewModel: vm, onPlay: (_, _) {})),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pumpAndSettle();

    expect(find.text('No matching tracks'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Clear search'), findsOneWidget);
  });

  testWidgets('recent tab hydrates cached recent tracks', (tester) async {
    final localLibrary = InMemoryLocalLibraryRepository();
    await localLibrary.cacheTrack(_t('1'));
    await localLibrary.recordRecentPlay('1');
    final vm = _vm(
      (c, q) => const Ok<List<Track>>([]),
      localLibrary: localLibrary,
    );
    await tester.pumpWidget(
      _host(CatalogSearchScreen(viewModel: vm, onPlay: (_, _) {})),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ElevatedButton, 'Recent (1)'));
    await tester.pumpAndSettle();

    expect(find.text('Song 1'), findsOneWidget);
  });

  testWidgets('error after a success shows the stale list with a banner', (
    tester,
  ) async {
    var fail = false;
    final vm = _vm(
      (c, q) =>
          fail ? const Err<List<Track>>(NetworkFailure('x')) : Ok([_t('1')]),
    );
    await tester.pumpWidget(
      _host(CatalogSearchScreen(viewModel: vm, onPlay: (_, _) {})),
    );
    await tester.pumpAndSettle();

    fail = true;
    await vm.retry();
    await tester.pumpAndSettle();

    expect(find.text('Song 1'), findsOneWidget); // stale 유지
    expect(find.byType(MaterialBanner), findsOneWidget);
  });

  testWidgets('re-initializes when handed a fresh view model on rebuild', (
    tester,
  ) async {
    final vm1 = _vm((c, q) => Ok([_t('1')]));
    await tester.pumpWidget(
      _host(CatalogSearchScreen(viewModel: vm1, onPlay: (_, _) {})),
    );
    await tester.pumpAndSettle();
    expect(find.text('Song 1'), findsOneWidget);

    // go_router can rebuild the '/' route with a brand-new, uninitialized view
    // model while reusing this screen's State. It must be initialized here —
    // not left stuck on its initial `loading` status.
    final vm2 = _vm((c, q) => Ok([_t('2')]));
    await tester.pumpWidget(
      _host(CatalogSearchScreen(viewModel: vm2, onPlay: (_, _) {})),
    );
    await tester.pumpAndSettle();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Song 2'), findsOneWidget);
  });
}
