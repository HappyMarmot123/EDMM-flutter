import 'dart:async';

import 'package:edmm/data/repositories/in_memory_local_library_repository.dart';
import 'package:edmm/domain/audio/audio_controller.dart';
import 'package:edmm/domain/models/track.dart';
import 'package:edmm/domain/playback/playback_snapshot.dart';
import 'package:edmm/domain/telemetry/playback_telemetry.dart';
import 'package:edmm/ui/core/widgets/playback_shell.dart';
import 'package:edmm/ui/player/widgets/player_mini_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../design_system/edmm_test_host.dart';

class _Audio implements AudioController {
  final _snapshots = StreamController<PlaybackSnapshot>.broadcast();
  final _positions = StreamController<Duration>.broadcast();
  double _volume = 1;

  @override
  Stream<Duration> get position => _positions.stream;

  @override
  Stream<PlaybackSnapshot> get snapshot => _snapshots.stream;

  @override
  bool get isShuffleEnabled => false;

  @override
  double get volume => _volume;

  @override
  Future<void> dispose() async {
    await _snapshots.close();
    await _positions.close();
  }

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
  Future<void> setMute(bool muted) async => _volume = muted ? 0 : 1;

  @override
  Future<void> setShuffleEnabled(bool enabled) async {}

  @override
  Future<void> setVolume(double volume) async => _volume = volume;

  void emit(PlaybackSnapshot snapshot) => _snapshots.add(snapshot);
}

Track _track() => Track(
  id: 'shared',
  source: 'cloudinary',
  title: 'Shared player',
  artistId: 'artist',
  artistName: 'Artist',
  durationMs: 60000,
  streamUrl: 'https://example.com/shared.mp3',
  metadata: const {},
);

class _PlaybackHarness extends StatefulWidget {
  const _PlaybackHarness({super.key, required this.initialAudio});

  final _Audio initialAudio;

  @override
  State<_PlaybackHarness> createState() => _PlaybackHarnessState();
}

class _PlaybackHarnessState extends State<_PlaybackHarness> {
  late _Audio audio = widget.initialAudio;
  final localLibrary = InMemoryLocalLibraryRepository();

  void replaceAudio(_Audio replacement) {
    setState(() => audio = replacement);
  }

  @override
  Widget build(BuildContext context) => PlaybackShell(
    audio: audio,
    localLibrary: localLibrary,
    telemetry: const NoopPlaybackTelemetrySink(),
    child: const SizedBox.expand(),
  );
}

void main() {
  testWidgets('generic body ends above the safe raised mini player', (
    tester,
  ) async {
    final audio = _Audio();
    addTearDown(audio.dispose);
    await pumpEdmmTestHost(
      tester,
      viewport: const Size(360, 640),
      textScale: 2,
      safeArea: const EdgeInsets.only(top: 24, bottom: 34),
      child: PlaybackShell(
        audio: audio,
        localLibrary: InMemoryLocalLibraryRepository(),
        telemetry: const NoopPlaybackTelemetrySink(),
        child: const Align(
          alignment: Alignment.bottomCenter,
          child: SizedBox(
            key: Key('generic-body-last-marker'),
            width: 40,
            height: 24,
          ),
        ),
      ),
    );
    audio.emit(
      PlaybackSnapshot(
        currentTrack: _track(),
        status: PlaybackStatus.paused,
        duration: const Duration(minutes: 1),
      ),
    );
    await tester.pump();

    final scaffold = tester.widget<Scaffold>(
      find.byKey(const Key('playback-shell-scaffold')),
    );
    expect(scaffold.extendBody, isFalse);
    expect(scaffold.bottomNavigationBar, isA<PlayerMiniBar>());
    final markerRect = tester.getRect(
      find.byKey(const Key('generic-body-last-marker')),
    );
    final miniRect = tester.getRect(find.byKey(const Key('player-mini-bar')));
    expect(markerRect.bottom, lessThanOrEqualTo(miniRect.top));
    expect(miniRect.bottom, lessThanOrEqualTo(640 - 34));
    expect(tester.takeException(), isNull);
  });

  testWidgets('mini and full player share one settings view model', (
    tester,
  ) async {
    final audio = _Audio();
    addTearDown(audio.dispose);
    await tester.pumpWidget(
      EdmmTestHost(
        child: PlaybackShell(
          audio: audio,
          localLibrary: InMemoryLocalLibraryRepository(),
          telemetry: const NoopPlaybackTelemetrySink(),
          child: const SizedBox.expand(),
        ),
      ),
    );
    audio.emit(
      PlaybackSnapshot(
        currentTrack: _track(),
        status: PlaybackStatus.paused,
        duration: const Duration(minutes: 1),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('100%'), findsOneWidget);
    await tester.tap(find.byKey(const Key('player-mini-open')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('player-volume-mute-button')));
    await tester.pump();
    expect(find.text('0%'), findsNWidgets(2));

    await tester.tap(find.byKey(const Key('player-close-button')));
    await tester.pumpAndSettle();
    expect(find.text('0%'), findsOneWidget);

    audio.emit(
      PlaybackSnapshot(
        currentTrack: _track(),
        status: PlaybackStatus.playing,
        duration: const Duration(minutes: 1),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.pause), findsOneWidget);
  });

  testWidgets('open sheet keeps its view model alive across dependency swap', (
    tester,
  ) async {
    final firstAudio = _Audio();
    final secondAudio = _Audio();
    addTearDown(firstAudio.dispose);
    addTearDown(secondAudio.dispose);
    final harnessKey = GlobalKey<_PlaybackHarnessState>();
    await tester.pumpWidget(
      EdmmTestHost(
        child: _PlaybackHarness(key: harnessKey, initialAudio: firstAudio),
      ),
    );
    firstAudio.emit(
      PlaybackSnapshot(
        currentTrack: _track(),
        status: PlaybackStatus.paused,
        duration: const Duration(minutes: 1),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('player-mini-open')));
    await tester.pumpAndSettle();

    harnessKey.currentState!.replaceAudio(secondAudio);
    await tester.pump();
    await tester.tap(find.byKey(const Key('player-volume-mute-button')));
    await tester.pump();

    expect(firstAudio.volume, 0);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const Key('player-close-button')));
    await tester.pumpAndSettle();
  });
}
