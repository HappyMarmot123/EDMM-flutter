import 'dart:async';

import 'package:edmm/domain/audio/audio_controller.dart';
import 'package:edmm/domain/audio/audio_effects_controller.dart';
import 'package:edmm/domain/audio/audio_visualizer_controller.dart';
import 'package:edmm/domain/models/track.dart';
import 'package:edmm/domain/playback/playback_snapshot.dart';
import 'package:edmm/ui/player/view_model/player_view_model.dart';
import 'package:edmm/ui/player/widgets/player_screen.dart';
import 'package:edmm/ui/player/widgets/player_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../design_system/edmm_test_host.dart';

class _SheetAudio
    implements
        AudioController,
        AudioEffectsController,
        AudioVisualizerController {
  _SheetAudio({
    AudioVisualizerSupport visualizerSupport = AudioVisualizerSupport.supported,
  }) : _visualizerSupportValue = visualizerSupport;

  final _snapshots = StreamController<PlaybackSnapshot>.broadcast();
  final _positions = StreamController<Duration>.broadcast();
  final _spectrum = StreamController<AudioSpectrumFrame>.broadcast();
  final _visualizerSupport =
      StreamController<AudioVisualizerSupport>.broadcast();

  double _volume = 1;
  bool _shuffleEnabled = false;
  AudioEqualizerPreset _preset = AudioEqualizerPreset.flat;
  AudioVisualizerSupport _visualizerSupportValue;

  @override
  Stream<PlaybackSnapshot> get snapshot => _snapshots.stream;

  @override
  Stream<Duration> get position => _positions.stream;

  @override
  Stream<AudioSpectrumFrame> get spectrum => _spectrum.stream;

  @override
  AudioVisualizerSupport get visualizerSupport => _visualizerSupportValue;

  @override
  Stream<AudioVisualizerSupport> get visualizerSupportStream =>
      _visualizerSupport.stream;

  void emitVisualizerSupport(AudioVisualizerSupport support) {
    if (!_spectrum.hasListener) return;
    _visualizerSupportValue = support;
    _visualizerSupport.add(support);
  }

  @override
  AudioEqualizerSupport get equalizerSupport => AudioEqualizerSupport.supported;

  @override
  AudioEqualizerPreset get equalizerPreset => _preset;

  @override
  bool get isShuffleEnabled => _shuffleEnabled;

  @override
  double get volume => _volume;

  @override
  Future<bool> loadQueue(List<Track> tracks, {int initialIndex = 0}) async =>
      true;

  @override
  Future<void> next() async {}

  @override
  Future<void> pause() async {}

  @override
  Future<void> play() async {}

  @override
  Future<void> previous() async {}

  @override
  Future<void> seek(Duration position) async {}

  @override
  Future<void> setEqualizerPreset(AudioEqualizerPreset preset) async {
    _preset = preset;
  }

  @override
  Future<void> setMute(bool muted) async {
    _volume = muted ? 0 : 1;
  }

  @override
  Future<void> setShuffleEnabled(bool enabled) async {
    _shuffleEnabled = enabled;
  }

  @override
  Future<void> setVolume(double volume) async {
    _volume = volume;
  }

  void emit(PlaybackSnapshot snapshot) => _snapshots.add(snapshot);

  @override
  Future<void> dispose() async {
    await _snapshots.close();
    await _positions.close();
    await _spectrum.close();
    await _visualizerSupport.close();
  }
}

const _track = Track(
  id: 'sheet-track',
  source: 'cloudinary',
  title: 'A deliberately long sheet player title for compact layout testing',
  artistId: 'artist',
  artistName: 'An artist name that also needs responsive truncation',
  durationMs: 60000,
  streamUrl: 'https://example.com/sheet.mp3',
  metadata: <String, Object?>{},
);

Finder _playerScrollable() => find.descendant(
  of: find.byKey(const Key('player-scroll-view')),
  matching: find.byType(Scrollable),
);

void main() {
  for (final testCase in const [
    (
      label: '360x640 without system insets',
      size: Size(360, 640),
      padding: FakeViewPadding.zero,
    ),
    (
      label: '320x568 with compact system insets',
      size: Size(320, 568),
      padding: FakeViewPadding(top: 24, bottom: 24),
    ),
    (
      label: '320x560 at the tight layout boundary',
      size: Size(320, 560),
      padding: FakeViewPadding.zero,
    ),
    (
      label: '360x640 with Android system insets',
      size: Size(360, 640),
      padding: FakeViewPadding(top: 24, bottom: 34),
    ),
    (
      label: '390x844 with notch and home indicator',
      size: Size(390, 844),
      padding: FakeViewPadding(top: 47, bottom: 34),
    ),
    (
      label: '840x900 expanded player',
      size: Size(840, 900),
      padding: FakeViewPadding.zero,
    ),
  ]) {
    testWidgets(
      'showPlayerSheet ${testCase.label} uses the full height and needs no initial scroll',
      (tester) async {
        final size = testCase.size;
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        tester.view.padding = testCase.padding;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPadding);
        final audio = _SheetAudio();
        addTearDown(audio.dispose);
        final viewModel = PlayerViewModel(audio);

        await tester.pumpWidget(
          EdmmTestHost(
            child: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: FilledButton(
                    key: const Key('open-player-sheet'),
                    onPressed: () => unawaited(
                      showPlayerSheet(context, viewModel: viewModel),
                    ),
                    child: const Text('Open'),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.byKey(const Key('open-player-sheet')));
        await tester.pumpAndSettle();
        audio.emit(
          const PlaybackSnapshot(
            currentTrack: _track,
            status: PlaybackStatus.paused,
            duration: Duration(minutes: 1),
          ),
        );
        await tester.pumpAndSettle();

        final playerRect = tester.getRect(find.byType(PlayerScreen));
        expect(
          playerRect.top,
          closeTo(testCase.padding.top, 0.5),
          reason: 'safe full-height sheet started at ${playerRect.top}',
        );
        expect(
          playerRect.height,
          closeTo(size.height - testCase.padding.top, 0.5),
          reason: 'sheet player rect was $playerRect for viewport $size',
        );

        final scrollable = _playerScrollable();
        expect(scrollable, findsOneWidget);
        final position = tester.state<ScrollableState>(scrollable).position;
        expect(
          position.pixels,
          closeTo(0, 0.01),
          reason: 'initial sheet offset was ${position.pixels}',
        );
        expect(
          position.maxScrollExtent,
          closeTo(0, 0.01),
          reason: 'sheet maxScrollExtent was ${position.maxScrollExtent}',
        );
        expect(find.byKey(const Key('player-visualizer')), findsOneWidget);
        expect(audio._spectrum.hasListener, isFalse);
        expect(audio._visualizerSupport.hasListener, isTrue);

        final expectsTwoPane = size.width >= 840;
        expect(
          find.byKey(
            Key(expectsTwoPane ? 'player-two-pane' : 'player-one-pane'),
          ),
          findsOneWidget,
        );

        final viewportRect = tester.getRect(
          find.byKey(const Key('player-scroll-view')),
        );
        final contentRect = tester.getRect(
          find.byKey(const Key('player-content-column')),
        );
        expect(
          contentRect.top,
          greaterThanOrEqualTo(viewportRect.top - 0.5),
          reason: 'sheet content $contentRect starts outside $viewportRect',
        );
        expect(
          contentRect.bottom,
          lessThanOrEqualTo(viewportRect.bottom + 0.5),
          reason: 'sheet content $contentRect ends outside $viewportRect',
        );
        expect(tester.takeException(), isNull);

        await tester.tap(find.byKey(const Key('player-close-button')));
        await tester.pumpAndSettle();
        expect(find.byType(PlayerScreen), findsNothing);
        expect(audio._spectrum.hasListener, isFalse);
        expect(audio._visualizerSupport.hasListener, isFalse);
      },
    );
  }

  testWidgets(
    'shared sheet stops spectrum frames while retaining support recovery',
    (tester) async {
      final audio = _SheetAudio(
        visualizerSupport: AudioVisualizerSupport.unavailable,
      );
      addTearDown(audio.dispose);
      final viewModel = PlayerViewModel(audio);
      addTearDown(viewModel.dispose);

      await tester.pumpWidget(
        EdmmTestHost(
          child: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: FilledButton(
                  key: const Key('open-shared-player-sheet'),
                  onPressed: () => unawaited(
                    showPlayerSheet(
                      context,
                      viewModel: viewModel,
                      disposeViewModel: false,
                    ),
                  ),
                  child: const Text('Open shared'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('open-shared-player-sheet')));
      await tester.pumpAndSettle();
      audio.emit(
        const PlaybackSnapshot(
          currentTrack: _track,
          status: PlaybackStatus.playing,
          duration: Duration(minutes: 1),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byKey(const Key('player-visualizer')), findsNothing);
      expect(
        find.byKey(const Key('player-visualizer-recovery-probe')),
        findsOneWidget,
      );
      expect(audio._spectrum.hasListener, isTrue);
      expect(audio._visualizerSupport.hasListener, isTrue);

      audio.emitVisualizerSupport(AudioVisualizerSupport.supported);
      await tester.pump();
      expect(find.byKey(const Key('player-visualizer')), findsOneWidget);
      expect(
        find.byKey(const Key('player-visualizer-recovery-probe')),
        findsNothing,
      );
      expect(audio._spectrum.hasListener, isTrue);

      await tester.tap(find.byKey(const Key('player-close-button')));
      await tester.pumpAndSettle();

      expect(find.byType(PlayerScreen), findsNothing);
      expect(audio._spectrum.hasListener, isFalse);
      expect(audio._visualizerSupport.hasListener, isTrue);
    },
  );
}
