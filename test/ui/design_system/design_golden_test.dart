import 'dart:async';

import 'package:edmm/data/repositories/in_memory_local_library_repository.dart';
import 'package:edmm/domain/audio/audio_controller.dart';
import 'package:edmm/domain/audio/audio_effects_controller.dart';
import 'package:edmm/domain/audio/audio_visualizer_controller.dart';
import 'package:edmm/domain/logic/track_resolver.dart';
import 'package:edmm/domain/models/cloudinary_category.dart';
import 'package:edmm/domain/models/track.dart';
import 'package:edmm/domain/playback/playback_snapshot.dart';
import 'package:edmm/domain/repositories/track_repository.dart';
import 'package:edmm/domain/result.dart';
import 'package:edmm/ui/catalog_search/view_model/catalog_search_view_model.dart';
import 'package:edmm/ui/catalog_search/widgets/catalog_search_screen.dart';
import 'package:edmm/ui/player/view_model/player_view_model.dart';
import 'package:edmm/ui/player/widgets/player_mini_bar.dart';
import 'package:edmm/ui/player/widgets/player_screen.dart';
import 'package:edmm/ui/track_detail/view_model/track_detail_view_model.dart';
import 'package:edmm/ui/track_detail/widgets/track_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'edmm_test_host.dart';

const _goldenRootKey = Key('design-golden-root');

const _primaryTrack = Track(
  id: 'midnight-signal',
  source: 'fixture',
  title: 'Midnight Signal',
  artistId: 'rose-circuit',
  artistName: 'Rose Circuit',
  albumName: 'After Dark',
  durationMs: 210000,
  streamUrl: 'https://example.test/audio/midnight-signal.mp3',
  metadata: <String, dynamic>{'genre': 'Electronic', 'year': 2026},
);

const _secondaryTrack = Track(
  id: 'neon-archive',
  source: 'fixture',
  title: 'Neon Archive',
  artistId: 'pulse-memory',
  artistName: 'Pulse Memory',
  albumName: 'Night Index',
  durationMs: 185000,
  streamUrl: 'https://example.test/audio/neon-archive.mp3',
);

const _unavailableTrack = Track(
  id: 'silent-artwork',
  source: 'fixture',
  title: 'Silent Artwork',
  artistId: 'static-frame',
  artistName: 'Static Frame',
  durationMs: 90000,
  metadata: <String, dynamic>{'resourceType': 'image'},
);

void main() {
  testWidgets('catalog data golden', (tester) async {
    final audio = _GoldenAudioController();
    addTearDown(audio.dispose);
    final viewModel = CatalogSearchViewModel(
      _StaticTrackRepository(
        const Ok<List<Track>>(<Track>[
          _primaryTrack,
          _secondaryTrack,
          _unavailableTrack,
        ]),
      ),
      audio,
      InMemoryLocalLibraryRepository(),
      initialTrackId: _primaryTrack.id,
      searchDebounce: Duration.zero,
    );

    await _pumpGoldenHost(
      tester,
      viewport: EdmmTestViewports.compactPhone,
      child: CatalogSearchScreen(
        viewModel: viewModel,
        onPlay: (_, _) {},
        onOpenTrack: (_) {},
      ),
    );
    audio.emitSnapshot(
      const PlaybackSnapshot(
        currentTrack: _primaryTrack,
        status: PlaybackStatus.playing,
        duration: Duration(milliseconds: 210000),
      ),
    );
    await _pumpFixedFrames(tester);

    expect(find.byKey(const Key('catalog-track-list')), findsOneWidget);
    await _expectGolden(tester, 'catalog_data');
  });

  testWidgets('catalog empty golden', (tester) async {
    final audio = _GoldenAudioController();
    addTearDown(audio.dispose);
    final viewModel = CatalogSearchViewModel(
      const _StaticTrackRepository(Ok<List<Track>>(<Track>[])),
      audio,
      InMemoryLocalLibraryRepository(),
      searchDebounce: Duration.zero,
    );

    await _pumpGoldenHost(
      tester,
      viewport: EdmmTestViewports.compactPhone,
      child: CatalogSearchScreen(viewModel: viewModel, onPlay: (_, _) {}),
    );
    await _pumpFixedFrames(tester);

    expect(find.text('No tracks'), findsOneWidget);
    await _expectGolden(tester, 'catalog_empty');
  });

  testWidgets('catalog error golden', (tester) async {
    final audio = _GoldenAudioController();
    addTearDown(audio.dispose);
    final viewModel = CatalogSearchViewModel(
      const _StaticTrackRepository(
        Err<List<Track>>(NetworkFailure('offline fixture')),
      ),
      audio,
      InMemoryLocalLibraryRepository(),
      searchDebounce: Duration.zero,
    );

    await _pumpGoldenHost(
      tester,
      viewport: EdmmTestViewports.compactPhone,
      child: CatalogSearchScreen(viewModel: viewModel, onPlay: (_, _) {}),
    );
    await _pumpFixedFrames(tester);

    expect(find.text("Couldn't load tracks"), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    await _expectGolden(tester, 'catalog_error');
  });

  testWidgets('track detail golden', (tester) async {
    final localLibrary = InMemoryLocalLibraryRepository();
    final viewModel = TrackDetailViewModel(
      trackId: _primaryTrack.id,
      initialTrack: _primaryTrack,
      resolver: TrackResolver(
        const _StaticTrackRepository(Ok<List<Track>>(<Track>[_primaryTrack])),
        localLibrary,
      ),
      localLibrary: localLibrary,
    );

    await _pumpGoldenHost(
      tester,
      viewport: const Size(1024, 768),
      child: TrackDetailScreen(viewModel: viewModel, onPlay: (_) {}),
    );
    await _pumpFixedFrames(tester, count: 4);

    expect(find.byKey(const Key('track-detail-two-pane')), findsOneWidget);
    expect(find.text(_primaryTrack.title), findsOneWidget);
    await _expectGolden(tester, 'track_detail');
  });

  testWidgets('persistent mini player golden', (tester) async {
    final fixture = _createPlayerFixture();
    addTearDown(fixture.dispose);

    await _pumpGoldenHost(
      tester,
      viewport: const Size(390, 144),
      child: Scaffold(
        body: const SizedBox.expand(),
        bottomNavigationBar: PlayerMiniBar(
          viewModel: fixture.viewModel,
          onOpenPlayer: () {},
        ),
      ),
    );
    fixture.audio.emitSnapshot(
      const PlaybackSnapshot(
        currentTrack: _primaryTrack,
        status: PlaybackStatus.playing,
        duration: Duration(milliseconds: 210000),
      ),
    );
    await tester.pump();
    fixture.audio.emitPosition(const Duration(seconds: 42));
    await _pumpFixedFrames(tester, count: 3);

    expect(find.byKey(const Key('player-mini-bar')), findsOneWidget);
    await _expectGolden(tester, 'player_mini');
  });

  testWidgets('full player phone 320x568 golden', (tester) async {
    final fixture = _createPlayerFixture();
    addTearDown(fixture.dispose);

    await _pumpGoldenHost(
      tester,
      viewport: const Size(320, 568),
      child: PlayerScreen(
        viewModel: fixture.viewModel,
        disposeViewModel: false,
        onClose: () {},
      ),
    );
    await _seedPlayer(fixture, tester);

    expect(find.byKey(const Key('player-one-pane')), findsOneWidget);
    expect(find.byKey(const Key('player-two-pane')), findsNothing);
    await _expectGolden(tester, 'player_full_phone_320x568');
  });

  testWidgets('full player two-pane 840x900 golden', (tester) async {
    final fixture = _createPlayerFixture();
    addTearDown(fixture.dispose);

    await _pumpGoldenHost(
      tester,
      viewport: const Size(840, 900),
      child: PlayerScreen(
        viewModel: fixture.viewModel,
        disposeViewModel: false,
        onClose: () {},
      ),
    );
    await _seedPlayer(fixture, tester);

    expect(find.byKey(const Key('player-two-pane')), findsOneWidget);
    expect(find.byKey(const Key('player-one-pane')), findsNothing);
    await _expectGolden(tester, 'player_full_two_pane_840x900');
  });
}

Widget _goldenRoot(Widget child) {
  return RepaintBoundary(
    key: _goldenRootKey,
    child: SizedBox.expand(child: child),
  );
}

Future<void> _pumpGoldenHost(
  WidgetTester tester, {
  required Size viewport,
  required Widget child,
}) async {
  await pumpEdmmTestHost(
    tester,
    viewport: viewport,
    locale: const Locale('en'),
    devicePixelRatio: 1,
    textScale: 1,
    safeArea: EdgeInsets.zero,
    viewInsets: EdgeInsets.zero,
    disableAnimations: true,
    platform: TargetPlatform.android,
    child: _goldenRoot(child),
  );
}

Future<void> _pumpFixedFrames(WidgetTester tester, {int count = 8}) async {
  for (var index = 0; index < count; index++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

Future<void> _seedPlayer(_PlayerFixture fixture, WidgetTester tester) async {
  fixture.audio.emitSnapshot(
    const PlaybackSnapshot(
      currentTrack: _primaryTrack,
      status: PlaybackStatus.playing,
      duration: Duration(milliseconds: 210000),
      hasNext: true,
    ),
  );
  await tester.pump();
  fixture.audio.emitPosition(const Duration(seconds: 42));
  fixture.audio.emitSpectrum(
    AudioSpectrumFrame(
      sampleRate: 48000,
      timestamp: Duration.zero,
      magnitudes: const <double>[
        0.18,
        0.28,
        0.44,
        0.62,
        0.78,
        0.56,
        0.36,
        0.48,
        0.72,
        0.84,
        0.58,
        0.4,
        0.3,
        0.52,
        0.68,
        0.46,
        0.32,
        0.2,
      ],
    ),
  );
  await _pumpFixedFrames(tester, count: 3);
}

Future<void> _expectGolden(WidgetTester tester, String name) async {
  expect(tester.takeException(), isNull);
  expect(
    find.byType(Image),
    findsNothing,
    reason: 'Golden fixtures must use deterministic fallback artwork.',
  );
  await expectLater(
    find.byKey(_goldenRootKey),
    matchesGoldenFile('../../goldens/design_system/$name.png'),
  );
}

_PlayerFixture _createPlayerFixture() {
  final audio = _GoldenAudioController();
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

  final _GoldenAudioController audio;
  final PlayerViewModel viewModel;

  Future<void> dispose() async {
    viewModel.dispose();
    await audio.dispose();
  }
}

class _StaticTrackRepository implements TrackRepository {
  const _StaticTrackRepository(this.result);

  final Result<List<Track>> result;

  @override
  Future<Result<List<Track>>> getCatalog({
    required CloudinaryCategory category,
    String query = '',
    bool forceRefresh = false,
  }) async => result;
}

class _GoldenAudioController
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
  Future<void> pause() async {}

  @override
  Future<void> seek(Duration position) async {}

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
