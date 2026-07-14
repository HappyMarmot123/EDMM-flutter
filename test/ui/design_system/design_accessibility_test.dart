import 'dart:async';
import 'dart:ui' show SemanticsAction, Tristate;

import 'package:edmm/data/repositories/in_memory_local_library_repository.dart';
import 'package:edmm/domain/audio/audio_controller.dart';
import 'package:edmm/domain/audio/audio_effects_controller.dart';
import 'package:edmm/domain/audio/audio_visualizer_controller.dart';
import 'package:edmm/domain/models/cloudinary_category.dart';
import 'package:edmm/domain/models/track.dart';
import 'package:edmm/domain/playback/playback_snapshot.dart';
import 'package:edmm/domain/repositories/track_repository.dart';
import 'package:edmm/domain/result.dart';
import 'package:edmm/ui/catalog_search/view_model/catalog_search_view_model.dart';
import 'package:edmm/ui/catalog_search/widgets/catalog_search_screen.dart';
import 'package:edmm/ui/core/themes/edmm_theme_extensions.dart';
import 'package:edmm/ui/core/themes/edmm_theme_tokens.dart';
import 'package:edmm/ui/core/widgets/edmm_state_view.dart';
import 'package:edmm/ui/player/view_model/player_view_model.dart';
import 'package:edmm/ui/player/widgets/player_mini_bar.dart';
import 'package:edmm/ui/player/widgets/player_screen.dart';
import 'package:edmm/ui/track_detail/widgets/track_detail_content.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'edmm_test_host.dart';

const _playingTrack = Track(
  id: 'playing',
  source: 'fixture',
  title: 'Midnight Signal',
  artistId: 'artist-1',
  artistName: 'Rose Circuit',
  albumName: 'After Dark',
  durationMs: 210000,
  streamUrl: 'https://example.test/audio/playing.mp3',
  metadata: <String, dynamic>{'year': 2026, 'genre': 'Electronic'},
);

const _secondTrack = Track(
  id: 'second',
  source: 'fixture',
  title: 'Neon Archive',
  artistId: 'artist-2',
  artistName: 'Pulse Memory',
  albumName: 'Night Index',
  durationMs: 185000,
  streamUrl: 'https://example.test/audio/second.mp3',
);

const _unavailableTrack = Track(
  id: 'unavailable',
  source: 'fixture',
  title: 'Silent Artwork',
  artistId: 'artist-3',
  artistName: 'Static Frame',
  durationMs: 90000,
  metadata: <String, dynamic>{'resourceType': 'image'},
);

const _longKoreanTrack = Track(
  id: 'long-ko',
  source: 'fixture',
  title: '한밤의 전자음악 기록 보관소에서 발견한 아주 긴 트랙 제목',
  artistId: 'artist-ko',
  artistName: '장문의 아티스트 이름과 여러 협업자가 함께한 프로젝트',
  albumName: '도시의 밤과 새벽 사이',
  durationMs: 3723000,
  streamUrl: 'https://example.test/audio/long-ko.mp3',
  metadata: <String, dynamic>{
    '설명': '작은 화면과 큰 글자에서도 마지막 메타데이터까지 도달할 수 있어야 합니다',
    '장르': <String>['일렉트로닉', '앰비언트', '드럼 앤 베이스'],
    '발매 연도': 2026,
  },
);

void main() {
  testWidgets(
    'compact catalog keeps 48dp actions, localized state semantics, and focus order',
    (tester) async {
      final semantics = tester.ensureSemantics();
      final audio = _TestAudioController();
      addTearDown(audio.dispose);
      final repository = _DeferredTrackRepository();
      final viewModel = CatalogSearchViewModel(
        repository,
        audio,
        InMemoryLocalLibraryRepository(),
        initialTrackId: _playingTrack.id,
        searchDebounce: Duration.zero,
      );

      await pumpEdmmTestHost(
        tester,
        viewport: EdmmTestViewports.compactPhone,
        locale: const Locale('ko'),
        textScale: 2,
        disableAnimations: true,
        child: CatalogSearchScreen(
          viewModel: viewModel,
          onPlay: (_, _) {},
          onOpenTrack: (_) {},
        ),
      );
      await tester.pump();

      final loadingNode = tester.getSemantics(
        find.bySemanticsLabel('트랙을 불러오는 중'),
      );
      expect(loadingNode.flagsCollection.isLiveRegion, isTrue);

      repository.complete(
        const Ok<List<Track>>(<Track>[
          _playingTrack,
          _secondTrack,
          _unavailableTrack,
        ]),
      );
      await _pumpFixedFrames(tester);
      audio.emitSnapshot(
        const PlaybackSnapshot(
          currentTrack: _playingTrack,
          status: PlaybackStatus.playing,
          duration: Duration(milliseconds: 210000),
        ),
      );
      await _pumpFixedFrames(tester);

      expect(tester.takeException(), isNull);
      _expectMinimumTarget(tester, const Key('catalog-search-field'));
      for (final key in const <Key>[
        Key('catalog-tab-pop'),
        Key('catalog-tab-edm'),
        Key('catalog-tab-recent'),
      ]) {
        _expectMinimumTarget(tester, key);
      }

      final playingNode = tester.getSemantics(
        find.byKey(const Key('catalog-track-primary-playing')),
      );
      expect(playingNode.label, contains('현재 재생 중'));
      expect(RegExp('현재 재생 중').allMatches(playingNode.label), hasLength(1));
      expect(playingNode.flagsCollection.isSelected, Tristate.isTrue);

      final catalogScrollable = find.descendant(
        of: find.byKey(const Key('catalog-track-list')),
        matching: find.byType(Scrollable),
      );
      await tester.scrollUntilVisible(
        find.byKey(const Key('catalog-track-primary-unavailable')),
        160,
        scrollable: catalogScrollable,
      );
      await tester.pump();
      final unavailableNode = tester.getSemantics(
        find.byKey(const Key('catalog-track-primary-unavailable')),
      );
      expect(unavailableNode.label, contains('재생할 수 없음'));
      expect(unavailableNode.flagsCollection.isEnabled, Tristate.isFalse);
      _expectMinimumTarget(
        tester,
        const Key('catalog-track-primary-unavailable'),
      );

      audio.emitSnapshot(
        const PlaybackSnapshot(
          currentTrack: _playingTrack,
          status: PlaybackStatus.paused,
          duration: Duration(milliseconds: 210000),
        ),
      );
      await _pumpFixedFrames(tester);
      await tester.scrollUntilVisible(
        find.byKey(const Key('catalog-track-primary-playing')),
        -160,
        scrollable: catalogScrollable,
      );
      await tester.pump();
      final pausedNode = tester.getSemantics(
        find.byKey(const Key('catalog-track-primary-playing')),
      );
      expect(pausedNode.label, contains('현재 트랙, 일시정지됨'));
      expect(RegExp('현재 트랙, 일시정지됨').allMatches(pausedNode.label), hasLength(1));
      expect(pausedNode.label, isNot(contains('현재 재생 중')));
      expect(pausedNode.flagsCollection.isSelected, Tristate.isTrue);

      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(
        _primaryFocusIsWithin(find.byKey(const Key('catalog-header-github'))),
        isTrue,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(
        _primaryFocusIsWithin(find.byKey(const Key('catalog-search-field'))),
        isTrue,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(
        _primaryFocusIsWithin(find.byKey(const Key('catalog-tab-pop'))),
        isTrue,
      );

      final searchTop = tester.getTopLeft(
        find.byKey(const Key('catalog-search-field')),
      );
      final filtersTop = tester.getTopLeft(
        find.byKey(const Key('catalog-filter-wrap')),
      );
      expect(searchTop.dy, lessThan(filtersTop.dy));
      expect(tester.takeException(), isNull);
      semantics.dispose();
    },
  );

  testWidgets(
    'detail keeps compact reading order, wide composition, and long Korean reachability',
    (tester) async {
      Track? playedTrack;
      for (final fixture in const <({Size viewport, bool twoPane})>[
        (viewport: Size(320, 568), twoPane: false),
        (viewport: Size(1024, 768), twoPane: true),
      ]) {
        await pumpEdmmTestHost(
          tester,
          viewport: fixture.viewport,
          locale: const Locale('ko'),
          textScale: 2,
          disableAnimations: true,
          child: TrackDetailContent(
            track: _longKoreanTrack,
            onPlay: (track) => playedTrack = track,
          ),
        );
        await tester.pump();

        expect(
          find.byKey(
            Key(
              fixture.twoPane
                  ? 'track-detail-two-pane'
                  : 'track-detail-one-pane',
            ),
          ),
          findsOneWidget,
        );
        _expectMinimumTarget(tester, const Key('track-detail-play'));
        expect(find.byKey(const Key('track-detail-favorite')), findsNothing);
        expect(
          find.byKey(const Key('track-detail-add-playlist')),
          findsNothing,
        );
        expect(find.byIcon(Icons.favorite), findsNothing);
        expect(find.byIcon(Icons.favorite_border), findsNothing);
        expect(find.byIcon(Icons.playlist_add), findsNothing);
        expect(find.textContaining('즐겨찾기'), findsNothing);
        expect(find.textContaining('플레이리스트'), findsNothing);
        expect(find.textContaining('Favorite'), findsNothing);
        expect(find.textContaining('Playlist'), findsNothing);

        if (fixture.twoPane) {
          expect(
            tester.getRect(find.byKey(const Key('track-detail-artwork'))).right,
            lessThanOrEqualTo(
              tester
                  .getRect(find.byKey(const Key('track-detail-heading')))
                  .left,
            ),
          );
        } else {
          final artworkTop = tester.getTopLeft(
            find.byKey(const Key('track-detail-artwork')),
          );
          final headingTop = tester.getTopLeft(
            find.byKey(const Key('track-detail-heading')),
          );
          final playTop = tester.getTopLeft(
            find.byKey(const Key('track-detail-play')),
          );
          final metadataTop = tester.getTopLeft(
            find.byKey(const Key('track-detail-core-metadata')),
          );
          expect(artworkTop.dy, lessThan(headingTop.dy));
          expect(headingTop.dy, lessThan(playTop.dy));
          expect(playTop.dy, lessThan(metadataTop.dy));

          FocusManager.instance.primaryFocus?.unfocus();
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.pump();
          expect(
            _primaryFocusIsWithin(find.byKey(const Key('track-detail-play'))),
            isTrue,
          );

          final detailScrollable = find
              .descendant(
                of: find.byKey(const Key('track-detail-scroll')),
                matching: find.byType(Scrollable),
              )
              .first;
          await tester.scrollUntilVisible(
            find.byKey(const Key('track-detail-additional-metadata')),
            180,
            scrollable: detailScrollable,
          );
          await tester.ensureVisible(
            find.byKey(const Key('track-detail-play')),
          );
          await tester.tap(find.byKey(const Key('track-detail-play')));
          await tester.pump();
          expect(playedTrack, _longKoreanTrack);
        }
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets(
    'compact mini player keeps safe long-content actions and focus order',
    (tester) async {
      final semantics = tester.ensureSemantics();
      final fixture = _createPlayerFixture();
      addTearDown(fixture.dispose);
      var openCount = 0;

      await pumpEdmmTestHost(
        tester,
        viewport: EdmmTestViewports.compactPhone,
        locale: const Locale('ko'),
        textScale: 2,
        safeArea: const EdgeInsets.only(bottom: 24),
        disableAnimations: true,
        child: Scaffold(
          bottomNavigationBar: PlayerMiniBar(
            viewModel: fixture.viewModel,
            onOpenPlayer: () => openCount++,
          ),
        ),
      );
      fixture.audio.emitSnapshot(
        const PlaybackSnapshot(
          currentTrack: _longKoreanTrack,
          status: PlaybackStatus.playing,
          duration: Duration(milliseconds: 3723000),
        ),
      );
      await _pumpFixedFrames(tester);

      expect(tester.takeException(), isNull);
      for (final key in const <Key>[
        Key('player-mini-open'),
        Key('player-mini-volume-mute'),
        Key('player-mini-play-pause'),
      ]) {
        _expectMinimumTarget(tester, key);
      }

      final barRect = tester.getRect(find.byKey(const Key('player-mini-bar')));
      expect(barRect.left, greaterThanOrEqualTo(EdmmSpacing.sm));
      expect(
        barRect.right,
        lessThanOrEqualTo(
          EdmmTestViewports.compactPhone.width - EdmmSpacing.sm,
        ),
      );
      expect(
        barRect.bottom,
        lessThanOrEqualTo(EdmmTestViewports.compactPhone.height - 24),
      );

      final openNode = tester.getSemantics(
        find.byKey(const Key('player-mini-open-semantics')),
      );
      expect(openNode.label, '전체 플레이어 열기');
      expect(openNode.value, contains(_longKoreanTrack.title));
      expect(find.bySemanticsLabel('전체 플레이어 열기'), findsOneWidget);
      expect(find.bySemanticsLabel('음소거'), findsOneWidget);
      expect(find.bySemanticsLabel('일시정지'), findsOneWidget);

      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(
        _primaryFocusIsWithin(find.byKey(const Key('player-mini-open'))),
        isTrue,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(
        _primaryFocusIsWithin(find.byKey(const Key('player-mini-volume-mute'))),
        isTrue,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(
        _primaryFocusIsWithin(find.byKey(const Key('player-mini-play-pause'))),
        isTrue,
      );

      await tester.tap(find.byKey(const Key('player-mini-open')));
      await tester.tap(find.byKey(const Key('player-mini-volume-mute')));
      await tester.tap(find.byKey(const Key('player-mini-play-pause')));
      await tester.pumpAndSettle();
      expect(openCount, 1);
      expect(fixture.audio.volume, 0);
      expect(fixture.audio.pauseCalls, 1);
      expect(tester.takeException(), isNull);
      semantics.dispose();
    },
  );

  testWidgets(
    'wide full player exposes labeled values, toggles, targets, focus, and contrast',
    (tester) async {
      final semantics = tester.ensureSemantics();
      final fixture = _createPlayerFixture();
      addTearDown(fixture.dispose);

      await pumpEdmmTestHost(
        tester,
        viewport: const Size(840, 900),
        disableAnimations: true,
        child: PlayerScreen(
          viewModel: fixture.viewModel,
          disposeViewModel: false,
          onClose: () {},
        ),
      );
      fixture.audio.emitSnapshot(
        const PlaybackSnapshot(
          currentTrack: _playingTrack,
          status: PlaybackStatus.playing,
          duration: Duration(milliseconds: 210000),
          hasNext: true,
        ),
      );
      await tester.pump();
      fixture.audio.emitPosition(const Duration(seconds: 42));
      fixture.audio.emitSpectrum(_spectrum(Duration.zero, 0.42));
      await _pumpFixedFrames(tester, count: 3);

      expect(find.byKey(const Key('player-two-pane')), findsOneWidget);
      expect(find.byKey(const Key('player-one-pane')), findsNothing);
      expect(find.byType(Image), findsNothing);
      expect(
        tester.getRect(find.byKey(const Key('player-presentation-pane'))).right,
        lessThanOrEqualTo(
          tester.getRect(find.byKey(const Key('player-controls-pane'))).left,
        ),
      );

      final progressNode = tester.getSemantics(
        find.bySemanticsLabel('Playback progress'),
      );
      expect(progressNode.label, 'Playback progress');
      expect(progressNode.value, '00:42 of 03:30');
      expect(progressNode.getSemanticsData().increasedValue, '00:52 of 03:30');
      expect(progressNode.getSemanticsData().decreasedValue, '00:31 of 03:30');
      expect(
        progressNode.getSemanticsData().hasAction(SemanticsAction.increase),
        isTrue,
      );
      expect(
        progressNode.getSemanticsData().hasAction(SemanticsAction.decrease),
        isTrue,
      );
      final volumeNode = tester.getSemantics(find.bySemanticsLabel('Volume'));
      expect(volumeNode.label, 'Volume');
      expect(volumeNode.value, '65%');
      expect(volumeNode.getSemanticsData().increasedValue, '70%');
      expect(volumeNode.getSemanticsData().decreasedValue, '60%');
      expect(
        volumeNode.getSemanticsData().hasAction(SemanticsAction.increase),
        isTrue,
      );
      expect(
        volumeNode.getSemanticsData().hasAction(SemanticsAction.decrease),
        isTrue,
      );
      final visualizerNode = tester.getSemantics(
        find.byKey(const Key('player-visualizer-semantics')),
      );
      expect(visualizerNode.label, 'Audio spectrum');
      expect(visualizerNode.flagsCollection.isToggled, Tristate.isTrue);
      expect(visualizerNode.flagsCollection.isEnabled, Tristate.isTrue);
      final shuffleNode = tester.getSemantics(
        find.byKey(const Key('player-shuffle-semantics')),
      );
      expect(shuffleNode.label, 'Shuffle');
      expect(shuffleNode.flagsCollection.isToggled, Tristate.isFalse);
      expect(find.bySemanticsLabel('Playback progress'), findsOneWidget);
      expect(find.bySemanticsLabel('Volume'), findsOneWidget);
      expect(find.bySemanticsLabel('Audio spectrum'), findsOneWidget);
      expect(find.bySemanticsLabel('00:42'), findsNothing);
      expect(find.bySemanticsLabel('65%'), findsNothing);

      tester.semantics.performAction(
        find.semantics.byLabel('Playback progress'),
        SemanticsAction.increase,
      );
      tester.semantics.performAction(
        find.semantics.byLabel('Volume'),
        SemanticsAction.decrease,
      );
      await tester.pumpAndSettle();
      expect(fixture.audio.lastSeek, const Duration(milliseconds: 52500));
      expect(fixture.audio.setVolumeCalls.last, closeTo(0.60, 0.000001));

      await tester.tap(find.byKey(const Key('player-shuffle-button')));
      await tester.tap(find.byKey(const Key('player-visualizer-toggle')));
      await tester.pumpAndSettle();
      expect(
        tester
            .getSemantics(find.byKey(const Key('player-shuffle-semantics')))
            .flagsCollection
            .isToggled,
        Tristate.isTrue,
      );
      expect(
        tester
            .getSemantics(find.byKey(const Key('player-visualizer-semantics')))
            .flagsCollection
            .isToggled,
        Tristate.isFalse,
      );

      for (final key in const <Key>[
        Key('player-close-button'),
        Key('player-progress-slider'),
        Key('player-shuffle-button'),
        Key('player-previous-button'),
        Key('player-play-pause-button'),
        Key('player-next-button'),
        Key('player-visualizer-toggle'),
        Key('player-volume-mute-button'),
        Key('player-volume-slider'),
        Key('player-eq-preset-flat'),
        Key('player-eq-preset-bass'),
      ]) {
        _expectMinimumTarget(tester, key);
      }

      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(
        _primaryFocusIsWithin(find.byKey(const Key('player-close-button'))),
        isTrue,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(
        _primaryFocusIsWithin(find.byKey(const Key('player-progress-slider'))),
        isTrue,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(
        _primaryFocusIsWithin(find.byKey(const Key('player-shuffle-button'))),
        isTrue,
      );

      final colors = Theme.of(
        tester.element(find.byKey(const Key('player-two-pane'))),
      ).edmm;
      expect(
        _contrastRatio(colors.textPrimary, colors.canvas),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrastRatio(colors.focusRing, colors.surfaceRose),
        greaterThanOrEqualTo(3),
      );
      expect(
        _contrastRatio(colors.playbackActive, colors.canvasDeep),
        greaterThanOrEqualTo(3),
      );
      expect(tester.takeException(), isNull);
      semantics.dispose();
    },
  );

  testWidgets(
    'compact large-text player remains reachable and honors reduced motion',
    (tester) async {
      final fixture = _createPlayerFixture();
      addTearDown(fixture.dispose);
      var closeCount = 0;

      await pumpEdmmTestHost(
        tester,
        viewport: EdmmTestViewports.compactPhone,
        textScale: 2,
        disableAnimations: true,
        child: PlayerScreen(
          viewModel: fixture.viewModel,
          disposeViewModel: false,
          onClose: () => closeCount++,
        ),
      );
      fixture.audio.emitSnapshot(
        const PlaybackSnapshot(
          currentTrack: _playingTrack,
          status: PlaybackStatus.playing,
          duration: Duration(milliseconds: 210000),
        ),
      );
      await tester.pump();
      fixture.audio.emitSpectrum(_spectrum(Duration.zero, 0.2));
      fixture.audio.emitSpectrum(
        _spectrum(const Duration(milliseconds: 40), 0.9),
      );
      await tester.pump();

      expect(find.byKey(const Key('player-one-pane')), findsOneWidget);
      expect(find.byKey(const Key('player-two-pane')), findsNothing);
      var visualizer = tester.widget<AudioSpectrumVisualizer>(
        find.byKey(const Key('player-visualizer-bars')),
      );
      expect(visualizer.magnitudes, everyElement(0.2));
      expect(fixture.viewModel.isVisualizerEnabled, isTrue);

      fixture.audio.emitSpectrum(
        _spectrum(const Duration(milliseconds: 400), 0.7),
      );
      await tester.pump();
      await tester.pump();
      visualizer = tester.widget<AudioSpectrumVisualizer>(
        find.byKey(const Key('player-visualizer-bars')),
      );
      expect(visualizer.magnitudes, everyElement(0.7));

      final playerScrollable = find.descendant(
        of: find.byKey(const Key('player-scroll-view')),
        matching: find.byType(Scrollable),
      );
      await tester.scrollUntilVisible(
        find.byKey(const Key('player-eq-preset-bass')),
        160,
        scrollable: playerScrollable,
      );
      _expectMinimumTarget(tester, const Key('player-eq-preset-bass'));

      final dragTarget = find.byKey(const Key('player-close-drag-area'));
      final gesture = await tester.startGesture(tester.getCenter(dragTarget));
      await gesture.moveBy(const Offset(0, 40));
      await tester.pump(const Duration(milliseconds: 200));
      await gesture.up();
      await tester.pump();
      final translatedPlayer = tester.widget<Transform>(
        find
            .descendant(
              of: find.byType(PlayerScreen),
              matching: find.byType(Transform),
            )
            .first,
      );
      expect(translatedPlayer.transform.getTranslation().y, closeTo(0, 0.01));
      expect(closeCount, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('wide route-hidden player stops spectrum work until visible', (
    tester,
  ) async {
    final fixture = _createPlayerFixture();
    addTearDown(fixture.dispose);
    final routeVisible = ValueNotifier<bool>(false);
    addTearDown(routeVisible.dispose);

    await pumpEdmmTestHost(
      tester,
      viewport: const Size(1024, 768),
      child: ValueListenableBuilder<bool>(
        valueListenable: routeVisible,
        builder: (context, visible, child) => TickerMode(
          enabled: visible,
          child: PlayerScreen(
            viewModel: fixture.viewModel,
            disposeViewModel: false,
            onClose: () {},
          ),
        ),
      ),
    );
    fixture.audio.emitSnapshot(
      const PlaybackSnapshot(
        currentTrack: _playingTrack,
        status: PlaybackStatus.playing,
        duration: Duration(milliseconds: 210000),
      ),
    );
    await _pumpFixedFrames(tester);

    expect(find.byKey(const Key('player-two-pane')), findsOneWidget);
    expect(find.byKey(const Key('player-visualizer')), findsNothing);
    expect(
      find.byKey(const Key('player-visualizer-recovery-probe')),
      findsNothing,
    );
    expect(fixture.audio.hasSpectrumListener, isFalse);
    expect(fixture.audio.hasSupportListener, isTrue);

    routeVisible.value = true;
    await _pumpFixedFrames(tester);
    expect(find.byKey(const Key('player-visualizer')), findsOneWidget);
    expect(fixture.audio.hasSpectrumListener, isTrue);

    routeVisible.value = false;
    await _pumpFixedFrames(tester);
    expect(find.byKey(const Key('player-visualizer')), findsNothing);
    expect(fixture.audio.hasSpectrumListener, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('loading skeleton stays stable when motion is reduced', (
    tester,
  ) async {
    await pumpEdmmTestHost(
      tester,
      viewport: EdmmTestViewports.compactPhone,
      disableAnimations: true,
      child: const Scaffold(
        body: EdmmStateView(
          kind: EdmmStateKind.loading,
          title: 'Loading tracks',
        ),
      ),
    );

    final before = tester
        .widget<FadeTransition>(
          find.byKey(const Key('edmm-state-skeleton-pulse')),
        )
        .opacity
        .value;
    await tester.pump(const Duration(seconds: 1));
    final after = tester
        .widget<FadeTransition>(
          find.byKey(const Key('edmm-state-skeleton-pulse')),
        )
        .opacity
        .value;
    expect(before, after);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpFixedFrames(WidgetTester tester, {int count = 8}) async {
  for (var index = 0; index < count; index++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

void _expectMinimumTarget(WidgetTester tester, Key key) {
  final size = tester.getSize(find.byKey(key));
  expect(size.width, greaterThanOrEqualTo(EdmmSizes.minTouchTarget));
  expect(size.height, greaterThanOrEqualTo(EdmmSizes.minTouchTarget));
}

bool _primaryFocusIsWithin(Finder finder) {
  final context = FocusManager.instance.primaryFocus?.context;
  if (context is! Element) return false;
  final targets = finder.evaluate().toSet();
  if (targets.contains(context)) return true;
  var found = false;
  context.visitAncestorElements((ancestor) {
    if (targets.contains(ancestor)) {
      found = true;
      return false;
    }
    return true;
  });
  return found;
}

double _contrastRatio(Color first, Color second) {
  final lighter = first.computeLuminance() >= second.computeLuminance()
      ? first
      : second;
  final darker = identical(lighter, first) ? second : first;
  return (lighter.computeLuminance() + 0.05) /
      (darker.computeLuminance() + 0.05);
}

AudioSpectrumFrame _spectrum(Duration timestamp, double magnitude) {
  return AudioSpectrumFrame(
    sampleRate: 48000,
    timestamp: timestamp,
    magnitudes: List<double>.filled(18, magnitude),
  );
}

_PlayerFixture _createPlayerFixture() {
  final audio = _TestAudioController();
  final viewModel = PlayerViewModel(
    audio,
    localLibrary: InMemoryLocalLibraryRepository(),
    effectsController: audio,
    visualizerController: audio,
  );
  return _PlayerFixture(audio: audio, viewModel: viewModel);
}

class _PlayerFixture {
  const _PlayerFixture({required this.audio, required this.viewModel});

  final _TestAudioController audio;
  final PlayerViewModel viewModel;

  Future<void> dispose() async {
    viewModel.dispose();
    await audio.dispose();
  }
}

class _DeferredTrackRepository implements TrackRepository {
  final Completer<Result<List<Track>>> _result =
      Completer<Result<List<Track>>>();

  void complete(Result<List<Track>> result) => _result.complete(result);

  @override
  Future<Result<List<Track>>> getCatalog({
    required CloudinaryCategory category,
    String query = '',
    bool forceRefresh = false,
  }) => _result.future;
}

class _TestAudioController
    implements
        AudioController,
        AudioEffectsController,
        AudioVisualizerController {
  final StreamController<PlaybackSnapshot> _snapshots =
      StreamController<PlaybackSnapshot>.broadcast(sync: true);
  final StreamController<Duration> _positions =
      StreamController<Duration>.broadcast(sync: true);
  final StreamController<AudioSpectrumFrame> _spectra =
      StreamController<AudioSpectrumFrame>.broadcast(sync: true);
  final StreamController<AudioVisualizerSupport> _supports =
      StreamController<AudioVisualizerSupport>.broadcast(sync: true);

  bool _shuffle = false;
  double _volume = 0.65;
  double _lastAudibleVolume = 0.65;
  AudioEqualizerPreset _preset = AudioEqualizerPreset.flat;
  int pauseCalls = 0;
  Duration? lastSeek;
  final List<double> setVolumeCalls = <double>[];

  bool get hasSpectrumListener => _spectra.hasListener;
  bool get hasSupportListener => _supports.hasListener;

  void emitSnapshot(PlaybackSnapshot snapshot) => _snapshots.add(snapshot);
  void emitPosition(Duration position) => _positions.add(position);
  void emitSpectrum(AudioSpectrumFrame frame) => _spectra.add(frame);

  @override
  Stream<PlaybackSnapshot> get snapshot => _snapshots.stream;

  @override
  Stream<Duration> get position => _positions.stream;

  @override
  Stream<AudioSpectrumFrame> get spectrum => _spectra.stream;

  @override
  Stream<AudioVisualizerSupport> get visualizerSupportStream =>
      _supports.stream;

  @override
  AudioVisualizerSupport get visualizerSupport =>
      AudioVisualizerSupport.supported;

  @override
  AudioEqualizerSupport get equalizerSupport => AudioEqualizerSupport.supported;

  @override
  AudioEqualizerPreset get equalizerPreset => _preset;

  @override
  bool get isShuffleEnabled => _shuffle;

  @override
  double get volume => _volume;

  @override
  Future<bool> loadQueue(List<Track> tracks, {int initialIndex = 0}) async =>
      tracks.isNotEmpty;

  @override
  Future<void> setShuffleEnabled(bool enabled) async => _shuffle = enabled;

  @override
  Future<void> setVolume(double volume) async {
    _volume = volume.clamp(0.0, 1.0).toDouble();
    setVolumeCalls.add(_volume);
    if (_volume > 0) _lastAudibleVolume = _volume;
  }

  @override
  Future<void> setMute(bool muted) async {
    if (muted) {
      if (_volume > 0) _lastAudibleVolume = _volume;
      _volume = 0;
      return;
    }
    _volume = _lastAudibleVolume;
  }

  @override
  Future<void> setEqualizerPreset(AudioEqualizerPreset preset) async {
    _preset = preset;
  }

  @override
  Future<void> play() async {}

  @override
  Future<void> pause() async => pauseCalls++;

  @override
  Future<void> seek(Duration position) async => lastSeek = position;

  @override
  Future<void> next() async {}

  @override
  Future<void> previous() async {}

  @override
  Future<void> dispose() async {
    await _snapshots.close();
    await _positions.close();
    await _spectra.close();
    await _supports.close();
  }
}
