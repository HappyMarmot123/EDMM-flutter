import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show SemanticsAction, Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:edmm/domain/audio/audio_effects_controller.dart';
import 'package:edmm/domain/audio/audio_controller.dart';
import 'package:edmm/domain/audio/audio_visualizer_controller.dart';
import 'package:edmm/domain/models/track.dart';
import 'package:edmm/domain/playback/playback_snapshot.dart';
import 'package:edmm/domain/result.dart';
import 'package:edmm/ui/core/themes/edmm_theme_tokens.dart';
import 'package:edmm/ui/core/widgets/edmm_ambient_backdrop.dart';
import 'package:edmm/ui/core/widgets/edmm_artwork.dart';
import 'package:edmm/ui/player/view_model/player_view_model.dart';
import 'package:edmm/ui/player/widgets/player_adaptive_layout.dart';
import 'package:edmm/ui/player/widgets/player_artwork_stage.dart';
import 'package:edmm/ui/player/widgets/player_equalizer_panel.dart';
import 'package:edmm/ui/player/widgets/player_progress_section.dart'
    as progress;
import 'package:edmm/ui/player/widgets/player_screen.dart';
import 'package:edmm/ui/player/widgets/player_transport_controls.dart';
import 'package:edmm/ui/player/widgets/player_visualizer.dart' as visualizer;
import 'package:edmm/ui/player/widgets/player_volume_controls.dart';

import '../design_system/edmm_test_host.dart';

class _FakeAudio
    implements
        AudioController,
        AudioEffectsController,
        AudioVisualizerController {
  final _snap = StreamController<PlaybackSnapshot>.broadcast();
  final _pos = StreamController<Duration>.broadcast();
  final _spectrum = StreamController<AudioSpectrumFrame>.broadcast();
  final _visualizerSupport =
      StreamController<AudioVisualizerSupport>.broadcast();

  int plays = 0;
  int pauses = 0;
  int nexts = 0;
  int previouses = 0;
  int seeks = 0;
  Duration? lastSeek;

  bool shuffleEnabled = false;
  double _volume = 1.0;
  final setShuffleCalls = <bool>[];
  final setVolumeCalls = <double>[];
  final setMuteCalls = <bool>[];
  AudioEqualizerPreset preset = AudioEqualizerPreset.flat;
  AudioEqualizerSupport support = AudioEqualizerSupport.supported;
  AudioVisualizerSupport spectrumSupport = AudioVisualizerSupport.supported;
  final setEqualizerPresetCalls = <AudioEqualizerPreset>[];

  @override
  Stream<PlaybackSnapshot> get snapshot => _snap.stream;

  @override
  Stream<Duration> get position => _pos.stream;

  @override
  Stream<AudioSpectrumFrame> get spectrum => _spectrum.stream;

  @override
  AudioVisualizerSupport get visualizerSupport => spectrumSupport;

  @override
  Stream<AudioVisualizerSupport> get visualizerSupportStream =>
      _visualizerSupport.stream;

  void emitVisualizerSupport(AudioVisualizerSupport support) {
    if (!_spectrum.hasListener) return;
    spectrumSupport = support;
    _visualizerSupport.add(support);
  }

  @override
  bool get isShuffleEnabled => shuffleEnabled;

  @override
  double get volume => _volume;

  @override
  Future<bool> loadQueue(List<Track> tracks, {int initialIndex = 0}) async =>
      true;

  @override
  Future<void> setShuffleEnabled(bool enabled) async {
    shuffleEnabled = enabled;
    setShuffleCalls.add(enabled);
  }

  @override
  Future<void> setVolume(double volume) async {
    _volume = volume;
    setVolumeCalls.add(volume);
  }

  @override
  Future<void> setMute(bool muted) async {
    setMuteCalls.add(muted);
    _volume = muted ? 0.0 : 1.0;
  }

  @override
  AudioEqualizerPreset get equalizerPreset => preset;

  @override
  AudioEqualizerSupport get equalizerSupport => support;

  @override
  Future<void> setEqualizerPreset(AudioEqualizerPreset preset) async {
    this.preset = preset;
    setEqualizerPresetCalls.add(preset);
  }

  @override
  Future<void> play() async => plays++;

  @override
  Future<void> pause() async => pauses++;

  @override
  Future<void> seek(Duration position) async {
    seeks++;
    lastSeek = position;
  }

  @override
  Future<void> next() async => nexts++;

  @override
  Future<void> previous() async => previouses++;

  @override
  Future<void> dispose() async {
    await _snap.close();
    await _pos.close();
    await _spectrum.close();
    await _visualizerSupport.close();
  }
}

Widget _host(
  Widget child, {
  double textScale = 1,
  Locale locale = const Locale('en'),
}) => EdmmTestHost(textScale: textScale, locale: locale, child: child);

Finder _playerScrollable() => find.descendant(
  of: find.byKey(const Key('player-scroll-view')),
  matching: find.byType(Scrollable),
);

void _expectFullyWithin(
  WidgetTester tester, {
  required Finder target,
  required Finder viewport,
  required String reason,
}) {
  expect(target, findsOneWidget, reason: '$reason must exist');
  final targetRect = tester.getRect(target);
  final viewportRect = tester.getRect(viewport);
  const epsilon = 0.5;

  expect(
    targetRect.left,
    greaterThanOrEqualTo(viewportRect.left - epsilon),
    reason: '$reason left edge $targetRect is outside $viewportRect',
  );
  expect(
    targetRect.top,
    greaterThanOrEqualTo(viewportRect.top - epsilon),
    reason: '$reason top edge $targetRect is outside $viewportRect',
  );
  expect(
    targetRect.right,
    lessThanOrEqualTo(viewportRect.right + epsilon),
    reason: '$reason right edge $targetRect is outside $viewportRect',
  );
  expect(
    targetRect.bottom,
    lessThanOrEqualTo(viewportRect.bottom + epsilon),
    reason: '$reason bottom edge $targetRect is outside $viewportRect',
  );
}

void _expectPlayerFitsWithoutScrolling(WidgetTester tester, Size size) {
  final viewport = find.byKey(const Key('player-scroll-view'));
  final scrollable = _playerScrollable();
  expect(scrollable, findsOneWidget);
  final position = tester.state<ScrollableState>(scrollable).position;
  final label = '${size.width.toInt()}x${size.height.toInt()}';
  final viewportRect = tester.getRect(viewport);

  expect(
    position.pixels,
    closeTo(0, 0.01),
    reason: '$label initial scroll offset was ${position.pixels}',
  );
  expect(
    position.maxScrollExtent,
    closeTo(0, 0.01),
    reason: '$label maxScrollExtent was ${position.maxScrollExtent}',
  );
  final maxWidth = find.byKey(const Key('player-two-pane')).evaluate().isEmpty
      ? 560.0
      : 1120.0;
  expect(
    viewportRect.width,
    lessThanOrEqualTo(maxWidth + 0.5),
    reason: '$label player content was too wide: $viewportRect',
  );

  for (final key in const <Key>[
    Key('player-content-column'),
    Key('player-artwork'),
    Key('player-visualizer'),
    Key('player-progress-slider'),
    Key('player-transport-controls'),
    Key('player-volume-controls'),
    Key('player-eq-panel'),
  ]) {
    _expectFullyWithin(
      tester,
      target: find.byKey(key),
      viewport: viewport,
      reason: '$label $key',
    );
  }
}

double _contrastRatio(Color foreground, Color background) {
  final foregroundLuminance = foreground.computeLuminance();
  final backgroundLuminance = background.computeLuminance();
  final lighter = math.max(foregroundLuminance, backgroundLuminance);
  final darker = math.min(foregroundLuminance, backgroundLuminance);
  return (lighter + 0.05) / (darker + 0.05);
}

Track _track({String artworkUrl = ''}) => Track(
  id: 'x',
  source: 'cloudinary',
  title: 'Bloom',
  artistId: 'a',
  artistName: 'Feint',
  artworkUrl: artworkUrl,
  durationMs: 60000,
  streamUrl: 'u',
  metadata: const {},
);

void main() {
  testWidgets('player composes extracted value-driven presentation widgets', (
    tester,
  ) async {
    final audio = _FakeAudio();
    final vm = PlayerViewModel(audio);
    await tester.pumpWidget(_host(PlayerScreen(viewModel: vm)));
    audio._snap.add(
      PlaybackSnapshot(
        currentTrack: _track(),
        status: PlaybackStatus.paused,
        duration: const Duration(minutes: 1),
      ),
    );
    await tester.pump();

    expect(find.byType(PlayerAdaptiveLayout), findsOneWidget);
    expect(find.byType(PlayerArtworkStage), findsOneWidget);
    expect(find.byType(progress.PlayerProgressSection), findsOneWidget);
    expect(find.byType(PlayerTransportControls), findsOneWidget);
    expect(find.byType(PlayerVolumeControls), findsOneWidget);
    expect(find.byType(PlayerEqualizerPanel), findsOneWidget);
    expect(find.byType(visualizer.PlayerVisualizer), findsOneWidget);
  });

  testWidgets('adaptive player owns the canonical one and two pane boundary', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final testCase in const <({Size size, bool twoPane})>[
      (size: Size(599, 400), twoPane: false),
      (size: Size(600, 500), twoPane: true),
      (size: Size(600, 501), twoPane: false),
      (size: Size(839, 600), twoPane: false),
      (size: Size(840, 900), twoPane: true),
    ]) {
      tester.view.physicalSize = testCase.size;
      await tester.pumpWidget(
        _host(
          PlayerAdaptiveLayout(
            builder: (context, density, artworkSize) =>
                const PlayerAdaptiveContent(
                  presentation: SizedBox.shrink(),
                  controls: SizedBox.shrink(),
                ),
          ),
        ),
      );

      expect(
        find.byKey(
          Key(testCase.twoPane ? 'player-two-pane' : 'player-one-pane'),
        ),
        findsOneWidget,
        reason: '${testCase.size} selected the wrong adaptive structure',
      );
      expect(
        find.byKey(
          Key(testCase.twoPane ? 'player-one-pane' : 'player-two-pane'),
        ),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('expanded controls delegate to player view model', (
    tester,
  ) async {
    final audio = _FakeAudio();
    final vm = PlayerViewModel(audio);
    await tester.pumpWidget(_host(PlayerScreen(viewModel: vm)));
    audio._snap.add(
      PlaybackSnapshot(
        currentTrack: _track(),
        status: PlaybackStatus.paused,
        duration: const Duration(minutes: 1),
      ),
    );
    audio._pos.add(Duration.zero);
    await tester.pump();

    expect(find.text('Bloom'), findsOneWidget);
    expect(find.byKey(const Key('player-shuffle-button')), findsOneWidget);
    expect(find.byKey(const Key('player-volume-slider')), findsOneWidget);
    expect(find.byKey(const Key('player-visualizer')), findsOneWidget);
    expect(audio._spectrum.hasListener, isFalse);

    await tester.tap(find.byKey(const Key('player-visualizer-toggle')));
    await tester.pump();
    expect(find.byKey(const Key('player-visualizer')), findsNothing);
    expect(audio._spectrum.hasListener, isFalse);

    await tester.tap(find.byKey(const Key('player-visualizer-toggle')));
    await tester.pump();
    expect(find.byKey(const Key('player-visualizer')), findsOneWidget);
    expect(audio._spectrum.hasListener, isFalse);

    await tester.tap(find.byKey(const Key('player-shuffle-button')));
    await tester.tap(find.byKey(const Key('player-volume-mute-button')));
    await tester.drag(
      find.byKey(const Key('player-volume-slider')),
      const Offset(100, 0),
    );
    await tester.tap(find.byIcon(Icons.skip_next));
    await tester.tap(find.byIcon(Icons.skip_previous));
    await tester.pumpAndSettle();

    expect(audio.setShuffleCalls, [true]);
    expect(audio.setMuteCalls, [true]);
    expect(audio.setVolumeCalls, isNotEmpty);
    expect(audio.nexts, 1);
    expect(audio.previouses, 1);
    expect(audio.setShuffleCalls, [true]);
    expect(find.byKey(const Key('player-eq-panel')), findsOneWidget);
    expect(find.byKey(const Key('player-eq-preset-flat')), findsOneWidget);
    expect(find.byKey(const Key('player-eq-preset-bass')), findsOneWidget);
    expect(find.byKey(const Key('player-eq-band-0')), findsNothing);
    expect(find.byKey(const Key('player-visualizer')), findsOneWidget);
    await tester.tap(find.byIcon(Icons.play_arrow));
    expect(audio.plays, 1);
  });

  test('formats hour-long position and duration as H:MM:SS', () {
    expect(
      formatPlaybackDuration(const Duration(hours: 1, minutes: 1, seconds: 2)),
      '1:01:02',
    );
    expect(
      formatPlaybackDuration(const Duration(hours: 1, minutes: 2, seconds: 3)),
      '1:02:03',
    );
    expect(
      formatPlaybackDuration(const Duration(minutes: 9, seconds: 8)),
      '09:08',
    );
  });

  testWidgets('equalizer panel delegates preset changes', (tester) async {
    final audio = _FakeAudio();
    final vm = PlayerViewModel(audio);
    await tester.pumpWidget(_host(PlayerScreen(viewModel: vm)));
    audio._snap.add(
      PlaybackSnapshot(
        currentTrack: _track(),
        status: PlaybackStatus.paused,
        duration: const Duration(minutes: 1),
      ),
    );
    await tester.pump();

    expect(find.text('Flat'), findsOneWidget);
    expect(find.text('Bass Boost'), findsOneWidget);
    expect(find.byKey(const Key('player-eq-band-0')), findsNothing);

    await tester.tap(find.byKey(const Key('player-eq-preset-bass')));
    await tester.pump();

    expect(audio.setEqualizerPresetCalls, [AudioEqualizerPreset.bassBoost]);
  });

  testWidgets(
    'shows platform-neutral equalizer copy on unsupported platforms',
    (tester) async {
      final audio = _FakeAudio()
        ..support = AudioEqualizerSupport.unsupportedOnPlatform;
      final vm = PlayerViewModel(audio);
      await tester.pumpWidget(_host(PlayerScreen(viewModel: vm)));
      audio._snap.add(
        PlaybackSnapshot(
          currentTrack: _track(),
          status: PlaybackStatus.paused,
          duration: const Duration(minutes: 1),
        ),
      );
      await tester.pump();

      await tester.pumpAndSettle();

      expect(
        find.text(
          'Equalizer is available on supported Android, iOS, and macOS devices',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('uses localized player copy for empty and error states', (
    tester,
  ) async {
    final audio = _FakeAudio();
    final vm = PlayerViewModel(audio);
    await tester.pumpWidget(_host(PlayerScreen(viewModel: vm)));
    await tester.pump();

    expect(find.text('No track loaded'), findsOneWidget);

    audio._snap.add(
      PlaybackSnapshot(
        currentTrack: _track(),
        status: PlaybackStatus.error,
        error: const NetworkFailure('offline'),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Network issue while loading audio'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Retry'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Dismiss'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Retry'));
    await tester.pump();
    expect(audio.plays, 1);
    expect(find.byType(MaterialBanner), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Dismiss'));
    await tester.pump();
    expect(find.byType(MaterialBanner), findsNothing);
  });

  testWidgets('does not offer retry for an error without a current track', (
    tester,
  ) async {
    final audio = _FakeAudio();
    final vm = PlayerViewModel(audio);
    await tester.pumpWidget(_host(PlayerScreen(viewModel: vm)));
    audio._snap.add(
      const PlaybackSnapshot(
        status: PlaybackStatus.error,
        error: ParseFailure('No playable tracks'),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byType(MaterialBanner), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Retry'), findsNothing);
    expect(find.widgetWithText(TextButton, 'Dismiss'), findsOneWidget);
  });

  testWidgets('close controls dismiss the fullscreen player', (tester) async {
    final audio = _FakeAudio();
    final vm = PlayerViewModel(audio);
    var closeCount = 0;
    await tester.pumpWidget(
      _host(
        PlayerScreen(
          viewModel: vm,
          onClose: () {
            closeCount++;
          },
        ),
      ),
    );
    audio._snap.add(
      PlaybackSnapshot(
        currentTrack: _track(),
        status: PlaybackStatus.paused,
        duration: const Duration(minutes: 1),
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('player-progress-slider')), findsOneWidget);
    expect(find.byIcon(Icons.skip_next), findsOneWidget);
    expect(find.byKey(const Key('player-mini-bar')), findsNothing);

    await tester.tap(find.byKey(const Key('player-close-button')));
    await tester.pump();
    expect(closeCount, 1);

    await tester.drag(
      find.byKey(const Key('player-close-drag-area')),
      const Offset(0, 300),
    );
    await tester.pump();
    expect(closeCount, 2);

    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(closeCount, 3);
  });

  testWidgets('shows a banner on playback error', (tester) async {
    final audio = _FakeAudio();
    final vm = PlayerViewModel(audio);
    await tester.pumpWidget(_host(PlayerScreen(viewModel: vm)));
    audio._snap.add(
      PlaybackSnapshot(currentTrack: _track(), status: PlaybackStatus.playing),
    );
    await tester.pump();
    audio._snap.add(
      PlaybackSnapshot(
        currentTrack: _track(),
        status: PlaybackStatus.error,
        duration: const Duration(minutes: 1),
        error: ParseFailure('bad'),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text('Bloom'), findsOneWidget);
    expect(find.byType(MaterialBanner), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsOneWidget);
  });

  testWidgets('visualizer paints decoded PCM spectrum frames', (tester) async {
    final audio = _FakeAudio();
    final vm = PlayerViewModel(audio);
    await tester.pumpWidget(_host(PlayerScreen(viewModel: vm)));
    audio._snap.add(
      PlaybackSnapshot(
        currentTrack: _track(),
        status: PlaybackStatus.playing,
        duration: const Duration(minutes: 1),
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('player-visualizer')), findsOneWidget);
    expect(audio._spectrum.hasListener, isTrue);

    audio._spectrum.add(
      AudioSpectrumFrame(
        sampleRate: 48000,
        timestamp: const Duration(milliseconds: 40),
        magnitudes: const [0.1, 0.45, 0.9],
      ),
    );
    await tester.pump();

    final visualizer = tester.widget<AudioSpectrumVisualizer>(
      find.byKey(const Key('player-visualizer-bars')),
    );
    expect(visualizer.magnitudes, const [0.1, 0.45, 0.9]);
  });

  testWidgets('visualizer toggle is disabled when PCM capture is unavailable', (
    tester,
  ) async {
    final audio = _FakeAudio()
      ..spectrumSupport = AudioVisualizerSupport.unavailable;
    final vm = PlayerViewModel(audio);
    await tester.pumpWidget(_host(PlayerScreen(viewModel: vm)));
    audio._snap.add(
      PlaybackSnapshot(
        currentTrack: _track(),
        status: PlaybackStatus.playing,
        duration: const Duration(minutes: 1),
      ),
    );
    await tester.pump();

    final toggle = tester.widget<IconButton>(
      find.byKey(const Key('player-visualizer-toggle')),
    );
    expect(toggle.onPressed, isNull);
    expect(find.byKey(const Key('player-visualizer')), findsNothing);
    expect(
      find.byKey(const Key('player-visualizer-unavailable')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('player-visualizer-recovery-probe')),
      findsOneWidget,
    );
    expect(audio._spectrum.hasListener, isTrue);
    expect(audio._visualizerSupport.hasListener, isTrue);
  });

  testWidgets(
    'visible recovery probe lets native support return without painting frames',
    (tester) async {
      final audio = _FakeAudio();
      final vm = PlayerViewModel(audio);
      await tester.pumpWidget(_host(PlayerScreen(viewModel: vm)));
      audio._snap.add(
        PlaybackSnapshot(
          currentTrack: _track(),
          status: PlaybackStatus.playing,
          duration: const Duration(minutes: 1),
        ),
      );
      await tester.pump();

      expect(vm.isVisualizerEnabled, isTrue);
      expect(find.byKey(const Key('player-visualizer')), findsOneWidget);
      expect(audio._spectrum.hasListener, isTrue);

      audio.emitVisualizerSupport(AudioVisualizerSupport.unavailable);
      await tester.pump();

      expect(find.byKey(const Key('player-visualizer')), findsNothing);
      expect(
        find.byKey(const Key('player-visualizer-unavailable')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('player-visualizer-recovery-probe')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('player-visualizer-bars')), findsNothing);
      expect(audio._spectrum.hasListener, isTrue);
      expect(audio._visualizerSupport.hasListener, isTrue);

      audio.emitVisualizerSupport(AudioVisualizerSupport.supported);
      await tester.pump();

      expect(
        find.byKey(const Key('player-visualizer-recovery-probe')),
        findsNothing,
      );
      expect(find.byKey(const Key('player-visualizer')), findsOneWidget);
      expect(audio._spectrum.hasListener, isTrue);
    },
  );

  for (final status in const <PlaybackStatus>[
    PlaybackStatus.loading,
    PlaybackStatus.paused,
    PlaybackStatus.completed,
    PlaybackStatus.error,
  ]) {
    testWidgets(
      'visualizer $status uses a static frame without spectrum work',
      (tester) async {
        final audio = _FakeAudio();
        addTearDown(audio.dispose);
        final vm = PlayerViewModel(audio);

        await tester.pumpWidget(_host(PlayerScreen(viewModel: vm)));
        audio._snap.add(
          PlaybackSnapshot(
            currentTrack: _track(),
            status: status,
            duration: const Duration(minutes: 1),
          ),
        );
        await tester.pump();

        expect(find.byKey(const Key('player-visualizer')), findsOneWidget);
        expect(
          find.byKey(const Key('player-visualizer-static')),
          findsOneWidget,
        );
        expect(find.byKey(const Key('player-visualizer-bars')), findsNothing);
        expect(audio._spectrum.hasListener, isFalse);
        expect(audio._visualizerSupport.hasListener, isTrue);
      },
    );
  }

  testWidgets('stored visualizer preference can stay off during playback', (
    tester,
  ) async {
    final audio = _FakeAudio();
    addTearDown(audio.dispose);
    final vm = PlayerViewModel(audio);

    await tester.pumpWidget(_host(PlayerScreen(viewModel: vm)));
    audio._snap.add(
      PlaybackSnapshot(
        currentTrack: _track(),
        status: PlaybackStatus.playing,
        duration: const Duration(minutes: 1),
      ),
    );
    await tester.pump();
    expect(audio._spectrum.hasListener, isTrue);

    await tester.tap(find.byKey(const Key('player-visualizer-toggle')));
    await tester.pump();

    expect(vm.isVisualizerEnabled, isFalse);
    expect(find.byKey(const Key('player-visualizer')), findsNothing);
    expect(audio._spectrum.hasListener, isFalse);
    expect(audio._visualizerSupport.hasListener, isTrue);
  });

  testWidgets(
    'route-hidden player stops spectrum work and resumes when visible',
    (tester) async {
      final audio = _FakeAudio()
        ..spectrumSupport = AudioVisualizerSupport.unavailable;
      addTearDown(audio.dispose);
      final vm = PlayerViewModel(audio);
      addTearDown(vm.dispose);
      final routeVisible = ValueNotifier<bool>(false);
      addTearDown(routeVisible.dispose);

      await tester.pumpWidget(
        _host(
          ValueListenableBuilder<bool>(
            valueListenable: routeVisible,
            builder: (context, visible, child) => TickerMode(
              enabled: visible,
              child: PlayerScreen(viewModel: vm, disposeViewModel: false),
            ),
          ),
        ),
      );
      audio._snap.add(
        PlaybackSnapshot(
          currentTrack: _track(),
          status: PlaybackStatus.playing,
          duration: const Duration(minutes: 1),
        ),
      );
      await tester.pump();

      expect(vm.isVisualizerEnabled, isTrue);
      expect(find.byKey(const Key('player-visualizer')), findsNothing);
      expect(
        find.byKey(const Key('player-visualizer-recovery-probe')),
        findsNothing,
      );
      expect(audio._spectrum.hasListener, isFalse);
      expect(audio._visualizerSupport.hasListener, isTrue);

      routeVisible.value = true;
      await tester.pump();
      expect(find.byKey(const Key('player-visualizer')), findsNothing);
      expect(
        find.byKey(const Key('player-visualizer-recovery-probe')),
        findsOneWidget,
      );
      expect(audio._spectrum.hasListener, isTrue);

      audio.emitVisualizerSupport(AudioVisualizerSupport.supported);
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const Key('player-visualizer')), findsOneWidget);
      expect(
        find.byKey(const Key('player-visualizer-recovery-probe')),
        findsNothing,
      );
      expect(audio._spectrum.hasListener, isTrue);

      routeVisible.value = false;
      await tester.pump();
      expect(find.byKey(const Key('player-visualizer')), findsNothing);
      expect(audio._spectrum.hasListener, isFalse);
      expect(audio._visualizerSupport.hasListener, isTrue);
    },
  );

  testWidgets('reduced motion throttles frames without changing preference', (
    tester,
  ) async {
    final audio = _FakeAudio();
    addTearDown(audio.dispose);
    final vm = PlayerViewModel(audio);

    await tester.pumpWidget(
      EdmmTestHost(disableAnimations: true, child: PlayerScreen(viewModel: vm)),
    );
    audio._snap.add(
      PlaybackSnapshot(
        currentTrack: _track(),
        status: PlaybackStatus.playing,
        duration: const Duration(minutes: 1),
      ),
    );
    await tester.pump();

    audio._spectrum.add(
      AudioSpectrumFrame(
        sampleRate: 48000,
        timestamp: Duration.zero,
        magnitudes: const <double>[0.2],
      ),
    );
    audio._spectrum.add(
      AudioSpectrumFrame(
        sampleRate: 48000,
        timestamp: const Duration(milliseconds: 40),
        magnitudes: const <double>[0.9],
      ),
    );
    await tester.pump();

    var bars = tester.widget<AudioSpectrumVisualizer>(
      find.byKey(const Key('player-visualizer-bars')),
    );
    expect(bars.magnitudes, const <double>[0.2]);
    expect(vm.isVisualizerEnabled, isTrue);

    audio._spectrum.add(
      AudioSpectrumFrame(
        sampleRate: 48000,
        timestamp: const Duration(milliseconds: 400),
        magnitudes: const <double>[0.7],
      ),
    );
    await tester.pump();
    await tester.pump();
    bars = tester.widget<AudioSpectrumVisualizer>(
      find.byKey(const Key('player-visualizer-bars')),
    );
    expect(bars.magnitudes, const <double>[0.7]);
    expect(vm.isVisualizerEnabled, isTrue);
  });

  testWidgets(
    'bright artwork keeps one capped blur behind a fixed dark scrim',
    (tester) async {
      final audio = _FakeAudio();
      addTearDown(audio.dispose);
      final vm = PlayerViewModel(audio);

      await tester.pumpWidget(_host(PlayerScreen(viewModel: vm)));
      audio._snap.add(
        PlaybackSnapshot(
          currentTrack: _track(
            artworkUrl: 'https://example.com/bright-artwork.png',
          ),
          status: PlaybackStatus.paused,
          duration: const Duration(minutes: 1),
        ),
      );
      await tester.pump();

      expect(find.byType(EdmmAmbientBackdrop), findsOneWidget);
      expect(find.byType(EdmmArtwork), findsOneWidget);
      expect(find.byType(ImageFiltered), findsOneWidget);
      final blurredImage = tester.widget<Image>(
        find.descendant(
          of: find.byType(ImageFiltered),
          matching: find.byType(Image),
        ),
      );
      expect(blurredImage.image, isA<ResizeImage>());
      final resized = blurredImage.image as ResizeImage;
      expect(resized.width, EdmmEffects.artworkDecodeLongestSide);
      expect(resized.height, EdmmEffects.artworkDecodeLongestSide);

      final scrim = tester.widget<ColoredBox>(
        find.byKey(const Key('edmm-ambient-scrim')),
      );
      expect(scrim.color.a, closeTo(EdmmEffects.backdropScrimOpacity, 0.001));
      final brightWorstCase = Color.alphaBlend(scrim.color, Colors.white);
      expect(
        _contrastRatio(EdmmColors.textPrimary, brightWorstCase),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrastRatio(EdmmColors.playbackActive, brightWorstCase),
        greaterThanOrEqualTo(3),
      );
    },
  );

  testWidgets('reduced motion removes artwork and drag snap transitions', (
    tester,
  ) async {
    final audio = _FakeAudio();
    addTearDown(audio.dispose);
    final vm = PlayerViewModel(audio);
    var closeCount = 0;

    await tester.pumpWidget(
      EdmmTestHost(
        disableAnimations: true,
        child: PlayerScreen(viewModel: vm, onClose: () => closeCount++),
      ),
    );
    audio._snap.add(
      PlaybackSnapshot(
        currentTrack: _track(
          artworkUrl: 'https://example.com/reduced-artwork.png',
        ),
        status: PlaybackStatus.paused,
        duration: const Duration(minutes: 1),
      ),
    );
    await tester.pump();

    final ambientOpacity = tester.widget<AnimatedOpacity>(
      find.byKey(const Key('edmm-ambient-artwork')),
    );
    final artworkOpacity = tester.widget<AnimatedOpacity>(
      find.byKey(const Key('edmm-artwork-image')),
    );
    expect(ambientOpacity.duration, Duration.zero);
    expect(artworkOpacity.duration, Duration.zero);

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
  });

  for (final size in const <Size>[
    Size(300, 600),
    Size(320, 568),
    Size(360, 640),
    Size(390, 844),
    Size(600, 960),
    Size(800, 1280),
    Size(840, 900),
    Size(1024, 768),
  ]) {
    testWidgets(
      'portrait ${size.width.toInt()}x${size.height.toInt()} shows all player content without scrolling',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final audio = _FakeAudio();
        addTearDown(audio.dispose);
        final vm = PlayerViewModel(audio);

        await tester.pumpWidget(_host(PlayerScreen(viewModel: vm)));
        audio._snap.add(
          PlaybackSnapshot(
            currentTrack: _track(),
            status: PlaybackStatus.paused,
            duration: const Duration(minutes: 1),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('player-visualizer')), findsOneWidget);
        _expectPlayerFitsWithoutScrolling(tester, size);
        final expectsTwoPane = size.width >= 840;
        expect(
          find.byKey(
            Key(expectsTwoPane ? 'player-two-pane' : 'player-one-pane'),
          ),
          findsOneWidget,
        );
        if (expectsTwoPane) {
          final presentation = tester.getRect(
            find.byKey(const Key('player-presentation-pane')),
          );
          final controls = tester.getRect(
            find.byKey(const Key('player-controls-pane')),
          );
          expect(presentation.right, lessThanOrEqualTo(controls.left));
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final size in const <Size>[
    Size(640, 360),
    Size(844, 390),
    Size(1024, 600),
  ]) {
    testWidgets(
      'wide ${size.width.toInt()}x${size.height.toInt()} keeps core controls visible',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final audio = _FakeAudio();
        addTearDown(audio.dispose);
        final vm = PlayerViewModel(audio);

        await tester.pumpWidget(_host(PlayerScreen(viewModel: vm)));
        audio._snap.add(
          PlaybackSnapshot(
            currentTrack: _track(),
            status: PlaybackStatus.paused,
            duration: const Duration(minutes: 1),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('player-two-pane')), findsOneWidget);
        final viewport = find.byKey(const Key('player-scroll-view'));
        for (final key in const <Key>[
          Key('player-progress-slider'),
          Key('player-transport-controls'),
          Key('player-volume-controls'),
          Key('player-eq-panel'),
        ]) {
          _expectFullyWithin(
            tester,
            target: find.byKey(key),
            viewport: viewport,
            reason: '${size.width.toInt()}x${size.height.toInt()} $key',
          );
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('small landscape player scrolls without layout overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(640, 320);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final audio = _FakeAudio();
    final vm = PlayerViewModel(audio);

    await tester.pumpWidget(_host(PlayerScreen(viewModel: vm)));
    audio._snap.add(
      PlaybackSnapshot(
        currentTrack: _track(),
        status: PlaybackStatus.paused,
        duration: const Duration(minutes: 1),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byType(SingleChildScrollView), findsOneWidget);
    final scrollable = _playerScrollable();
    final position = tester.state<ScrollableState>(scrollable).position;
    expect(position.pixels, closeTo(0, 0.01));
    expect(position.maxScrollExtent, greaterThan(0));
    await tester.scrollUntilVisible(
      find.byKey(const Key('player-eq-panel')),
      200,
      scrollable: scrollable,
    );
    await tester.pumpAndSettle();
    expect(position.pixels, greaterThan(0));
    _expectFullyWithin(
      tester,
      target: find.byKey(const Key('player-eq-panel')),
      viewport: find.byKey(const Key('player-scroll-view')),
      reason: '640x320 equalizer after scrolling',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'large text player keeps the final controls reachable by scroll',
    (tester) async {
      const size = Size(320, 568);
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final audio = _FakeAudio();
      addTearDown(audio.dispose);
      final vm = PlayerViewModel(audio);

      await tester.pumpWidget(_host(PlayerScreen(viewModel: vm), textScale: 2));
      audio._snap.add(
        PlaybackSnapshot(
          currentTrack: _track(),
          status: PlaybackStatus.paused,
          duration: const Duration(minutes: 1),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final scrollable = _playerScrollable();
      final position = tester.state<ScrollableState>(scrollable).position;
      expect(position.pixels, closeTo(0, 0.01));
      await tester.scrollUntilVisible(
        find.byKey(const Key('player-eq-panel')),
        200,
        scrollable: scrollable,
      );
      await tester.pumpAndSettle();
      _expectFullyWithin(
        tester,
        target: find.byKey(const Key('player-eq-panel')),
        viewport: find.byKey(const Key('player-scroll-view')),
        reason: '320x568 textScale 2 equalizer after scrolling',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('transport and audio buttons expose accessible tooltips', (
    tester,
  ) async {
    final audio = _FakeAudio();
    final vm = PlayerViewModel(audio);
    await tester.pumpWidget(_host(PlayerScreen(viewModel: vm)));
    audio._snap.add(
      PlaybackSnapshot(
        currentTrack: _track(),
        status: PlaybackStatus.paused,
        duration: const Duration(minutes: 1),
      ),
    );
    await tester.pump();

    for (final key in const [
      Key('player-shuffle-button'),
      Key('player-previous-button'),
      Key('player-play-pause-button'),
      Key('player-next-button'),
      Key('player-visualizer-toggle'),
      Key('player-volume-mute-button'),
    ]) {
      final button = tester.widget<IconButton>(find.byKey(key));
      expect(
        button.tooltip,
        isNotEmpty,
        reason: '$key needs an accessible name',
      );
    }
  });

  for (final testCase
      in const <
        ({
          Locale locale,
          String progressLabel,
          String progressValue,
          String progressIncreasedValue,
          String progressDecreasedValue,
          String volumeLabel,
          String visualizerLabel,
          String visualizerActionLabel,
          String shuffleLabel,
        })
      >[
        (
          locale: Locale('en'),
          progressLabel: 'Playback progress',
          progressValue: '00:30 of 01:00',
          progressIncreasedValue: '00:33 of 01:00',
          progressDecreasedValue: '00:27 of 01:00',
          volumeLabel: 'Volume',
          visualizerLabel: 'Audio spectrum',
          visualizerActionLabel: 'Hide audio spectrum',
          shuffleLabel: 'Shuffle',
        ),
        (
          locale: Locale('ko'),
          progressLabel: '재생 위치',
          progressValue: '01:00 중 00:30',
          progressIncreasedValue: '01:00 중 00:33',
          progressDecreasedValue: '01:00 중 00:27',
          volumeLabel: '음량',
          visualizerLabel: '오디오 스펙트럼',
          visualizerActionLabel: '오디오 스펙트럼 숨기기',
          shuffleLabel: '셔플',
        ),
      ]) {
    testWidgets(
      '${testCase.locale.languageCode} player controls expose one localized semantics node',
      (tester) async {
        final semantics = tester.ensureSemantics();
        final audio = _FakeAudio().._volume = 0.42;
        addTearDown(audio.dispose);
        final vm = PlayerViewModel(audio);

        await tester.pumpWidget(
          _host(PlayerScreen(viewModel: vm), locale: testCase.locale),
        );
        audio._snap.add(
          PlaybackSnapshot(
            currentTrack: _track(),
            status: PlaybackStatus.paused,
            duration: const Duration(minutes: 1),
          ),
        );
        await tester.pump();
        audio._pos.add(const Duration(seconds: 30));
        await tester.pump();

        final progress = tester.getSemantics(
          find.bySemanticsLabel(testCase.progressLabel),
        );
        expect(progress.label, testCase.progressLabel);
        expect(progress.value, testCase.progressValue);
        expect(
          progress.getSemanticsData().increasedValue,
          testCase.progressIncreasedValue,
        );
        expect(
          progress.getSemanticsData().decreasedValue,
          testCase.progressDecreasedValue,
        );
        expect(
          progress.getSemanticsData().hasAction(SemanticsAction.increase),
          isTrue,
        );
        expect(
          progress.getSemanticsData().hasAction(SemanticsAction.decrease),
          isTrue,
        );

        final volume = tester.getSemantics(
          find.bySemanticsLabel(testCase.volumeLabel),
        );
        expect(volume.label, testCase.volumeLabel);
        expect(volume.value, '42%');
        expect(volume.getSemanticsData().increasedValue, '47%');
        expect(volume.getSemanticsData().decreasedValue, '37%');
        expect(
          volume.getSemanticsData().hasAction(SemanticsAction.increase),
          isTrue,
        );
        expect(
          volume.getSemanticsData().hasAction(SemanticsAction.decrease),
          isTrue,
        );

        final shuffle = tester.getSemantics(
          find.byKey(const Key('player-shuffle-semantics')),
        );
        expect(shuffle.label, testCase.shuffleLabel);
        expect(shuffle.flagsCollection.isToggled, Tristate.isFalse);
        expect(
          shuffle.getSemanticsData().hasAction(SemanticsAction.tap),
          isTrue,
        );

        final visualizerNode = tester.getSemantics(
          find.byKey(const Key('player-visualizer-semantics')),
        );
        expect(visualizerNode.label, testCase.visualizerLabel);
        expect(visualizerNode.flagsCollection.isToggled, Tristate.isTrue);
        expect(
          visualizerNode.getSemanticsData().hasAction(SemanticsAction.tap),
          isTrue,
        );

        expect(find.bySemanticsLabel(testCase.progressLabel), findsOneWidget);
        expect(find.bySemanticsLabel(testCase.volumeLabel), findsOneWidget);
        expect(find.bySemanticsLabel(testCase.visualizerLabel), findsOneWidget);
        expect(
          find.bySemanticsLabel(testCase.visualizerActionLabel),
          findsNothing,
        );
        expect(find.bySemanticsLabel('00:30'), findsNothing);
        expect(find.bySemanticsLabel('42%'), findsNothing);

        tester.semantics.performAction(
          find.semantics.byLabel(testCase.progressLabel),
          SemanticsAction.increase,
        );
        tester.semantics.performAction(
          find.semantics.byLabel(testCase.volumeLabel),
          SemanticsAction.decrease,
        );
        await tester.pumpAndSettle();

        expect(audio.lastSeek, const Duration(seconds: 33));
        expect(audio.setVolumeCalls.last, closeTo(0.37, 0.000001));
        semantics.dispose();
      },
    );
  }

  testWidgets('very narrow player wraps controls and exposes shuffle state', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(300, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final semantics = tester.ensureSemantics();
    final audio = _FakeAudio();
    final vm = PlayerViewModel(audio);

    await tester.pumpWidget(_host(PlayerScreen(viewModel: vm)));
    audio._snap.add(
      PlaybackSnapshot(
        currentTrack: _track(),
        status: PlaybackStatus.paused,
        duration: const Duration(minutes: 1),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(
      tester
          .getSemantics(find.byKey(const Key('player-shuffle-semantics')))
          .flagsCollection
          .isToggled,
      Tristate.isFalse,
    );
    expect(
      tester
          .getSemantics(find.byKey(const Key('player-visualizer-semantics')))
          .flagsCollection
          .isToggled,
      Tristate.isTrue,
    );

    await tester.tap(find.byKey(const Key('player-shuffle-button')));
    await tester.pump();
    expect(
      tester
          .getSemantics(find.byKey(const Key('player-shuffle-semantics')))
          .flagsCollection
          .isToggled,
      Tristate.isTrue,
    );
    await tester.tap(find.byKey(const Key('player-visualizer-toggle')));
    await tester.pump();
    expect(
      tester
          .getSemantics(find.byKey(const Key('player-visualizer-semantics')))
          .flagsCollection
          .isToggled,
      Tristate.isFalse,
    );
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });
}
