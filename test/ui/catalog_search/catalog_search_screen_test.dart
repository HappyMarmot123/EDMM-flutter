import 'dart:async';
import 'dart:ui' show Tristate;

import 'package:edmm/data/repositories/in_memory_local_library_repository.dart';
import 'package:edmm/domain/audio/audio_controller.dart';
import 'package:edmm/domain/models/cloudinary_category.dart';
import 'package:edmm/domain/models/track.dart';
import 'package:edmm/domain/playback/playback_snapshot.dart';
import 'package:edmm/domain/repositories/track_repository.dart';
import 'package:edmm/domain/result.dart';
import 'package:edmm/ui/catalog_search/view_model/catalog_search_view_model.dart';
import 'package:edmm/ui/catalog_search/widgets/catalog_search_screen.dart';
import 'package:edmm/ui/core/themes/theme.dart';
import 'package:edmm/ui/core/widgets/edmm_filter_pill.dart';
import 'package:edmm/ui/core/widgets/edmm_state_view.dart';
import 'package:edmm/ui/core/widgets/edmm_track_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../design_system/edmm_test_host.dart';

Track _t(
  String id, {
  String? title,
  String artistName = 'Artist',
  String artworkUrl = '',
  int durationMs = 1,
  String? streamUrl,
}) => Track(
  id: id,
  source: 'cloudinary',
  title: title ?? 'Song $id',
  artistId: 'a',
  artistName: artistName,
  artworkUrl: artworkUrl,
  durationMs: durationMs,
  streamUrl: streamUrl ?? 'https://audio.example/$id.m4a',
  metadata: const {'resourceType': 'video'},
);

typedef _CatalogHandler =
    FutureOr<Result<List<Track>>> Function(
      CloudinaryCategory category,
      String query,
    );

class _Repo implements TrackRepository {
  _Repo(this.handler);

  _CatalogHandler handler;

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
  Future<bool> loadQueue(List<Track> tracks, {int initialIndex = 0}) async =>
      true;
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
  _CatalogHandler handler, {
  InMemoryLocalLibraryRepository? localLibrary,
  CatalogView? initialView,
  String? initialTrackId,
  _Audio? audio,
}) => CatalogSearchViewModel(
  _Repo(handler),
  audio ?? _Audio(),
  localLibrary ?? InMemoryLocalLibraryRepository(),
  initialView: initialView,
  initialTrackId: initialTrackId,
  searchDebounce: Duration.zero,
);

Future<void> _pumpCatalog(
  WidgetTester tester,
  CatalogSearchViewModel viewModel, {
  Size viewport = EdmmTestViewports.standardPhone,
  Locale locale = const Locale('en'),
  double textScale = 1,
  void Function(List<Track>, int)? onPlay,
  ValueChanged<Track>? onOpenTrack,
}) async {
  await pumpEdmmTestHost(
    tester,
    viewport: viewport,
    locale: locale,
    textScale: textScale,
    child: CatalogSearchScreen(
      viewModel: viewModel,
      onPlay: onPlay ?? (_, _) {},
      onOpenTrack: onOpenTrack,
    ),
  );
}

void main() {
  testWidgets('catalog filters preserve dynamic type and selected state', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final vm = _vm((c, q) => Ok([_t('1'), _t('2')]));

    await _pumpCatalog(
      tester,
      vm,
      viewport: EdmmTestViewports.compactPhone,
      textScale: 2,
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(FittedBox), findsNothing);
    expect(find.byType(EdmmFilterPill), findsNWidgets(3));
    expect(
      tester
          .getSemantics(find.byKey(const Key('catalog-tab-pop')))
          .flagsCollection
          .isSelected,
      Tristate.isTrue,
    );
    expect(
      tester
          .getSemantics(find.byKey(const Key('catalog-tab-edm')))
          .flagsCollection
          .isSelected,
      Tristate.isFalse,
    );

    await tester.tap(find.byKey(const Key('catalog-tab-edm')));
    await tester.pumpAndSettle();
    expect(
      tester
          .getSemantics(find.byKey(const Key('catalog-tab-edm')))
          .flagsCollection
          .isSelected,
      Tristate.isTrue,
    );
    semantics.dispose();
  });

  testWidgets('search and filter actions meet the 48dp target', (tester) async {
    final vm = _vm((c, q) => Ok([_t('1')]));
    await _pumpCatalog(
      tester,
      vm,
      viewport: EdmmTestViewports.compactPhone,
      textScale: 2,
    );
    await tester.pumpAndSettle();

    expect(
      tester.getSize(find.byKey(const Key('catalog-search-field'))).height,
      greaterThanOrEqualTo(EdmmSizes.minTouchTarget),
    );
    for (final key in const <Key>[
      Key('catalog-tab-pop'),
      Key('catalog-tab-edm'),
      Key('catalog-tab-recent'),
    ]) {
      expect(
        tester.getSize(find.byKey(key)).height,
        greaterThanOrEqualTo(EdmmSizes.minTouchTarget),
      );
    }
  });

  for (final viewport in const <Size>[
    EdmmTestViewports.compactPhone,
    EdmmTestViewports.standardPhone,
    EdmmTestViewports.tabletPortrait,
  ]) {
    for (final locale in const <Locale>[Locale('en'), Locale('ko')]) {
      for (final textScale in const <double>[1, 2]) {
        testWidgets(
          'fits ${viewport.width}dp ${locale.languageCode} at text scale $textScale',
          (tester) async {
            final vm = _vm(
              (c, q) => Ok([
                _t(
                  'long',
                  title:
                      'A very long electronic dance music title that remains readable',
                  artistName:
                      'A long artist collaboration name that must not overflow',
                ),
              ]),
            );

            await _pumpCatalog(
              tester,
              vm,
              viewport: viewport,
              locale: locale,
              textScale: textScale,
              onOpenTrack: (_) {},
            );
            await tester.pumpAndSettle();

            expect(tester.takeException(), isNull);
            expect(find.byType(FittedBox), findsNothing);
            expect(find.byType(ListView), findsOneWidget);
          },
        );
      }
    }
  }

  testWidgets('loading uses the stable shared state pattern', (tester) async {
    final pending = Completer<Result<List<Track>>>();
    final vm = _vm((c, q) => pending.future);

    await _pumpCatalog(
      tester,
      vm,
      viewport: EdmmTestViewports.compactPhone,
      textScale: 2,
    );
    await tester.pump();

    expect(find.byType(EdmmStateView), findsOneWidget);
    expect(find.byKey(const Key('edmm-state-skeleton')), findsOneWidget);
    expect(
      tester.widget<EdmmStateView>(find.byType(EdmmStateView)).title,
      'Loading tracks',
    );

    pending.complete(Ok([_t('loaded')]));
    await tester.pumpAndSettle();
    expect(find.text('Song loaded'), findsOneWidget);
  });

  testWidgets('empty catalog uses the shared empty state', (tester) async {
    final vm = _vm((c, q) => const Ok<List<Track>>([]));
    await _pumpCatalog(
      tester,
      vm,
      viewport: EdmmTestViewports.tabletPortrait,
      locale: const Locale('ko'),
      textScale: 2,
    );
    await tester.pumpAndSettle();

    expect(find.byType(EdmmStateView), findsOneWidget);
    expect(find.text('트랙이 없습니다'), findsOneWidget);
    expect(find.byIcon(Icons.inbox_outlined), findsOneWidget);
  });

  testWidgets('error without data keeps an independent retry action', (
    tester,
  ) async {
    var calls = 0;
    final vm = _vm((c, q) {
      calls++;
      return const Err<List<Track>>(NetworkFailure('offline'));
    });
    await _pumpCatalog(
      tester,
      vm,
      viewport: EdmmTestViewports.compactPhone,
      textScale: 2,
    );
    await tester.pumpAndSettle();
    final beforeRetry = calls;

    expect(find.byType(EdmmStateView), findsOneWidget);
    expect(find.text("Couldn't load tracks"), findsOneWidget);
    final retry = find.widgetWithText(TextButton, 'Retry');
    await tester.ensureVisible(retry);
    await tester.pumpAndSettle();
    await tester.tap(retry);
    await tester.pumpAndSettle();
    expect(calls, greaterThan(beforeRetry));
  });

  testWidgets('search clear resets both controller and view model', (
    tester,
  ) async {
    final vm = _vm((c, q) => Ok(q == 'zzz' ? <Track>[] : [_t('1')]));
    await _pumpCatalog(
      tester,
      vm,
      viewport: EdmmTestViewports.compactPhone,
      textScale: 2,
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('catalog-search-field')),
      'zzz',
    );
    await tester.pumpAndSettle();

    expect(find.text('No matching tracks'), findsOneWidget);
    final clearSearch = find.widgetWithText(TextButton, 'Clear search');
    await tester.ensureVisible(clearSearch);
    await tester.pumpAndSettle();
    await tester.tap(clearSearch);
    await tester.pumpAndSettle();

    expect(vm.query, isEmpty);
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('catalog-search-field')))
          .controller!
          .text,
      isEmpty,
    );
    expect(find.text('Song 1'), findsOneWidget);
  });

  testWidgets('recent filter hydrates cached recent tracks', (tester) async {
    final localLibrary = InMemoryLocalLibraryRepository();
    await localLibrary.cacheTrack(_t('1'));
    await localLibrary.recordRecentPlay('1');
    final vm = _vm(
      (c, q) => const Ok<List<Track>>([]),
      localLibrary: localLibrary,
    );
    await _pumpCatalog(
      tester,
      vm,
      viewport: EdmmTestViewports.compactPhone,
      locale: const Locale('ko'),
      textScale: 2,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('catalog-tab-recent')));
    await tester.pumpAndSettle();

    expect(find.text('Song 1'), findsOneWidget);
  });

  testWidgets('error after success keeps stale data, banner, and retry', (
    tester,
  ) async {
    var fail = false;
    final vm = _vm(
      (c, q) => fail
          ? const Err<List<Track>>(NetworkFailure('offline'))
          : Ok([_t('1')]),
    );
    await _pumpCatalog(
      tester,
      vm,
      viewport: EdmmTestViewports.compactPhone,
      locale: const Locale('ko'),
      textScale: 2,
    );
    await tester.pumpAndSettle();

    fail = true;
    await vm.retry();
    await tester.pumpAndSettle();

    expect(find.byType(MaterialBanner), findsOneWidget);
    expect(find.text('저장된 결과 표시 중 — 새로고침 실패'), findsOneWidget);
    expect(tester.takeException(), isNull);
    expect(
      find.descendant(
        of: find.byType(MaterialBanner),
        matching: find.widgetWithText(TextButton, '다시 시도'),
      ),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(
      find.text('Song 1'),
      160,
      scrollable: find.descendant(
        of: find.byKey(const Key('catalog-track-list')),
        matching: find.byType(Scrollable),
      ),
    );
    expect(find.text('Song 1'), findsOneWidget);
  });

  testWidgets(
    'data rows preserve queue, details, artwork failure, and base states',
    (tester) async {
      final semantics = tester.ensureSemantics();
      const longTitle =
          'Midnight Signal Extended Archive Transmission for Compact Screens';
      const longArtist =
          'Rose Circuit with an exceptionally descriptive collaboration';
      final current = _t(
        'current',
        title: longTitle,
        artistName: longArtist,
        artworkUrl: 'https://example.invalid/missing-cover.png',
        durationMs: 252000,
      );
      final selected = _t('selected');
      final blocked = _t('blocked', artistName: '', streamUrl: '/relative.m4a');
      final tracks = <Track>[current, selected, blocked];
      final audio = _Audio();
      final vm = _vm(
        (c, q) => Ok(tracks),
        initialTrackId: selected.id,
        audio: audio,
      );
      List<Track>? playedQueue;
      int? playedIndex;
      Track? openedTrack;

      await _pumpCatalog(
        tester,
        vm,
        onPlay: (queue, index) {
          playedQueue = queue;
          playedIndex = index;
        },
        onOpenTrack: (track) => openedTrack = track,
      );
      await tester.pumpAndSettle();
      audio.emit(
        PlaybackSnapshot(
          currentTrack: current,
          status: PlaybackStatus.playing,
          duration: current.duration,
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(EdmmTrackRow), findsNWidgets(3));
      expect(
        find.descendant(
          of: find.byKey(const Key('catalog-track-current')),
          matching: find.byKey(const Key('edmm-artwork-fallback')),
        ),
        findsOneWidget,
      );
      expect(
        tester
            .widget<EdmmTrackRow>(
              find.byKey(const Key('catalog-track-current')),
            )
            .state,
        EdmmTrackRowState.playingCurrent,
      );
      expect(
        tester
            .widget<EdmmTrackRow>(
              find.byKey(const Key('catalog-track-selected')),
            )
            .state,
        EdmmTrackRowState.selected,
      );
      expect(
        tester
            .widget<EdmmTrackRow>(
              find.byKey(const Key('catalog-track-blocked')),
            )
            .state,
        EdmmTrackRowState.unplayable,
      );
      expect(find.text('Unknown artist'), findsOneWidget);

      final currentSemantics = tester.getSemantics(
        find.byKey(const Key('catalog-track-primary-current')),
      );
      expect(currentSemantics.label, contains('Currently playing'));
      expect(
        RegExp('Currently playing').allMatches(currentSemantics.label),
        hasLength(1),
      );
      expect(currentSemantics.label, isNot(contains('Now Playing')));
      expect(currentSemantics.flagsCollection.isSelected, Tristate.isTrue);

      final selectedSemantics = tester.getSemantics(
        find.byKey(const Key('catalog-track-primary-selected')),
      );
      expect(selectedSemantics.flagsCollection.isSelected, Tristate.isTrue);
      expect(selectedSemantics.label, isNot(contains('Currently playing')));
      expect(selectedSemantics.label, isNot(contains('Unavailable')));

      final blockedSemantics = tester.getSemantics(
        find.byKey(const Key('catalog-track-primary-blocked')),
      );
      expect(blockedSemantics.label, contains('Unavailable'));
      expect(blockedSemantics.flagsCollection.isEnabled, Tristate.isFalse);

      audio.emit(
        PlaybackSnapshot(
          currentTrack: current,
          status: PlaybackStatus.paused,
          duration: current.duration,
        ),
      );
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<EdmmTrackRow>(
              find.byKey(const Key('catalog-track-current')),
            )
            .state,
        EdmmTrackRowState.current,
      );
      final pausedSemantics = tester.getSemantics(
        find.byKey(const Key('catalog-track-primary-current')),
      );
      expect(pausedSemantics.label, contains('Current track, paused'));
      expect(
        RegExp('Current track, paused').allMatches(pausedSemantics.label),
        hasLength(1),
      );
      expect(pausedSemantics.label, isNot(contains('Currently playing')));
      expect(pausedSemantics.flagsCollection.isSelected, Tristate.isTrue);

      await tester.tap(find.byKey(const Key('catalog-track-detail-current')));
      await tester.pump();
      expect(openedTrack, current);
      expect(playedQueue, isNull);

      await tester.tap(find.text('Song selected'));
      await tester.pump();
      expect(identical(playedQueue, vm.tracks), isTrue);
      expect(playedIndex, 1);

      await tester.tap(find.text('Song blocked'));
      await tester.pump();
      expect(playedIndex, 1);

      await tester.tap(find.byKey(const Key('catalog-track-detail-blocked')));
      await tester.pump();
      expect(openedTrack, blocked);
      semantics.dispose();
    },
  );

  testWidgets('long lists remain lazy ListView.builder content', (
    tester,
  ) async {
    final tracks = List<Track>.generate(100, (index) => _t('$index'));
    final vm = _vm((c, q) => Ok(tracks));
    await _pumpCatalog(tester, vm);
    await tester.pumpAndSettle();

    expect(find.byType(ListView), findsOneWidget);
    expect(
      find.byType(EdmmTrackRow).evaluate().length,
      lessThan(tracks.length),
    );
  });

  testWidgets('re-initializes when handed a fresh view model on rebuild', (
    tester,
  ) async {
    final vm1 = _vm((c, q) => Ok([_t('1')]));
    await pumpEdmmTestHost(
      tester,
      child: CatalogSearchScreen(viewModel: vm1, onPlay: (_, _) {}),
    );
    await tester.pumpAndSettle();
    expect(find.text('Song 1'), findsOneWidget);

    final vm2 = _vm((c, q) => Ok([_t('2')]));
    await tester.pumpWidget(
      EdmmTestHost(
        viewport: EdmmTestViewports.standardPhone,
        child: CatalogSearchScreen(viewModel: vm2, onPlay: (_, _) {}),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('edmm-state-skeleton')), findsNothing);
    expect(find.text('Song 2'), findsOneWidget);
  });
}
