import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:edmm/l10n/app_localizations.dart';
import 'package:edmm/domain/audio/audio_effects_controller.dart';
import 'package:edmm/domain/audio/audio_controller.dart';
import 'package:edmm/domain/models/track.dart';
import 'package:edmm/domain/playback/playback_snapshot.dart';
import 'package:edmm/domain/result.dart';
import 'package:edmm/ui/player/view_model/player_view_model.dart';
import 'package:edmm/ui/player/widgets/player_screen.dart';

class _FakeAudio implements AudioController, AudioEffectsController {
  final _snap = StreamController<PlaybackSnapshot>.broadcast();
  final _pos = StreamController<Duration>.broadcast();

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
  bool equalizerEnabled = false;
  AudioEqualizerSupport support = AudioEqualizerSupport.supported;
  final setEqualizerCalls = <bool>[];
  final setEqualizerBandGainCalls = <({int index, double gain})>[];
  List<AudioEqualizerBand> bands = const [
    AudioEqualizerBand(
      index: 0,
      label: '80 Hz',
      minGain: -6,
      maxGain: 6,
      gain: 0,
    ),
    AudioEqualizerBand(
      index: 1,
      label: '1 kHz',
      minGain: -6,
      maxGain: 6,
      gain: 0,
    ),
  ];

  @override
  Stream<PlaybackSnapshot> get snapshot => _snap.stream;

  @override
  Stream<Duration> get position => _pos.stream;

  @override
  bool get isShuffleEnabled => shuffleEnabled;

  @override
  double get volume => _volume;

  @override
  Future<void> loadQueue(List<Track> tracks, {int initialIndex = 0}) async {}

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
  bool get isEqualizerEnabled => equalizerEnabled;

  @override
  AudioEqualizerSupport get equalizerSupport => support;

  @override
  Future<List<AudioEqualizerBand>> getEqualizerBands() async => bands;

  @override
  Future<void> setEqualizerEnabled(bool enabled) async {
    equalizerEnabled = enabled;
    setEqualizerCalls.add(enabled);
  }

  @override
  Future<void> setEqualizerBandGain(int index, double gain) async {
    setEqualizerBandGainCalls.add((index: index, gain: gain));
    bands = [
      for (final band in bands)
        band.index == index ? band.copyWith(gain: gain) : band,
    ];
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
  }
}

Widget _host(Widget child) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: child,
);

Track _track() => Track(
  id: 'x',
  source: 'cloudinary',
  title: 'Bloom',
  artistId: 'a',
  artistName: 'Feint',
  durationMs: 60000,
  streamUrl: 'u',
  metadata: const {},
);

void main() {
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

    await tester.tap(find.byKey(const Key('player-shuffle-button')));
    await tester.tap(find.byKey(const Key('player-volume-mute-button')));
    await tester.drag(
      find.byKey(const Key('player-volume-slider')),
      const Offset(100, 0),
    );
    await tester.tap(find.byIcon(Icons.skip_next));
    await tester.tap(find.byIcon(Icons.skip_previous));
    await tester.tap(find.byKey(const Key('player-eq-toggle')));
    await tester.tap(find.byKey(const Key('player-visualizer-toggle')));
    await tester.pumpAndSettle();

    expect(audio.setShuffleCalls, [true]);
    expect(audio.setMuteCalls, [true]);
    expect(audio.setVolumeCalls, isNotEmpty);
    expect(audio.nexts, 1);
    expect(audio.previouses, 1);
    expect(audio.setShuffleCalls, [true]);
    expect(audio.setEqualizerCalls, [true]);
    expect(find.byKey(const Key('player-eq-panel')), findsOneWidget);
    expect(find.byKey(const Key('player-visualizer')), findsOneWidget);
    await tester.tap(find.byIcon(Icons.play_arrow));
    expect(audio.plays, 1);
  });

  testWidgets('equalizer panel delegates band gain changes', (tester) async {
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

    await tester.tap(find.byKey(const Key('player-eq-toggle')));
    await tester.pumpAndSettle();
    await tester.drag(
      find.byKey(const Key('player-eq-band-0')),
      const Offset(0, -80),
    );
    await tester.pump();

    expect(audio.setEqualizerBandGainCalls, isNotEmpty);
  });

  testWidgets(
    'shows platform-neutral equalizer copy on unsupported platforms',
    (tester) async {
      final audio = _FakeAudio()
        ..support = AudioEqualizerSupport.unsupportedOnPlatform
        ..bands = const [];
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

      await tester.tap(find.byKey(const Key('player-eq-toggle')));
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
    expect(find.widgetWithText(TextButton, 'Dismiss'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Dismiss'));
    await tester.pump();
    expect(find.byType(MaterialBanner), findsNothing);
  });

  testWidgets(
    'toggle expand mode shows mini player and hides expanded controls',
    (tester) async {
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

      expect(find.byKey(const Key('player-progress-slider')), findsOneWidget);
      expect(find.byIcon(Icons.skip_next), findsOneWidget);
      expect(find.byKey(const Key('player-mini-volume-mute')), findsNothing);

      await tester.tap(find.byKey(const Key('player-expand-toggle')));
      await tester.pump();

      expect(find.byKey(const Key('player-progress-slider')), findsNothing);
      expect(find.byIcon(Icons.skip_next), findsNothing);
      expect(find.byKey(const Key('player-mini-volume-mute')), findsOneWidget);

      await tester.tap(find.byKey(const Key('player-mini-volume-mute')));
      await tester.pump();
      expect(audio.setMuteCalls, [true]);
      await tester.tap(find.byIcon(Icons.play_arrow));
      expect(audio.plays, 1);
    },
  );

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
}
