import 'dart:async';
import 'dart:ui' show Tristate;

import 'package:edmm/domain/audio/audio_controller.dart';
import 'package:edmm/domain/models/track.dart';
import 'package:edmm/domain/playback/playback_snapshot.dart';
import 'package:edmm/ui/core/themes/theme.dart';
import 'package:edmm/ui/player/view_model/player_view_model.dart';
import 'package:edmm/ui/player/widgets/player_mini_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../design_system/edmm_test_host.dart';

class _MiniAudio implements AudioController {
  final _snapshots = StreamController<PlaybackSnapshot>.broadcast();
  final _positions = StreamController<Duration>.broadcast();

  double _volume = 1;
  int playCalls = 0;
  int pauseCalls = 0;
  int muteCalls = 0;

  @override
  Stream<Duration> get position => _positions.stream;

  @override
  Stream<PlaybackSnapshot> get snapshot => _snapshots.stream;

  @override
  bool get isShuffleEnabled => false;

  @override
  double get volume => _volume;

  @override
  Future<bool> loadQueue(List<Track> tracks, {int initialIndex = 0}) async =>
      true;

  @override
  Future<void> next() async {}

  @override
  Future<void> pause() async => pauseCalls++;

  @override
  Future<void> play() async => playCalls++;

  @override
  Future<void> previous() async {}

  @override
  Future<void> seek(Duration position) async {}

  @override
  Future<void> setMute(bool muted) async {
    muteCalls++;
    _volume = muted ? 0 : 1;
  }

  @override
  Future<void> setShuffleEnabled(bool enabled) async {}

  @override
  Future<void> setVolume(double volume) async => _volume = volume;

  void emitSnapshot(PlaybackSnapshot snapshot) => _snapshots.add(snapshot);

  void emitPosition(Duration position) => _positions.add(position);

  @override
  Future<void> dispose() async {
    await _snapshots.close();
    await _positions.close();
  }
}

const _longTrack = Track(
  id: 'mini-track',
  source: 'cloudinary',
  title: 'A deliberately long electronic track title for a compact mini bar',
  artistId: 'artist',
  artistName: 'An equally long artist and collaborator description',
  durationMs: 60000,
  streamUrl: 'https://example.com/mini.mp3',
  metadata: <String, Object?>{},
);

PlayerViewModel _viewModelFor(_MiniAudio audio) {
  final viewModel = PlayerViewModel(audio);
  addTearDown(() async {
    viewModel.dispose();
    await audio.dispose();
  });
  return viewModel;
}

Future<void> _showTrack(
  WidgetTester tester, {
  required _MiniAudio audio,
  required PlayerViewModel viewModel,
  required Size viewport,
  double textScale = 1,
  EdgeInsets safeArea = EdgeInsets.zero,
  VoidCallback? onOpenPlayer,
  PlaybackStatus status = PlaybackStatus.paused,
}) async {
  await pumpEdmmTestHost(
    tester,
    viewport: viewport,
    textScale: textScale,
    safeArea: safeArea,
    child: Scaffold(
      bottomNavigationBar: PlayerMiniBar(
        viewModel: viewModel,
        onOpenPlayer: onOpenPlayer,
      ),
    ),
  );
  audio.emitSnapshot(
    PlaybackSnapshot(
      currentTrack: _longTrack,
      status: status,
      duration: const Duration(minutes: 1),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('300dp keeps content, semantics, and independent actions', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final audio = _MiniAudio();
    final viewModel = _viewModelFor(audio);
    var openCalls = 0;
    await _showTrack(
      tester,
      audio: audio,
      viewModel: viewModel,
      viewport: const Size(300, 600),
      textScale: 2,
      onOpenPlayer: () => openCalls++,
    );

    expect(find.text(_longTrack.title), findsOneWidget);
    expect(find.text(_longTrack.artistName), findsOneWidget);
    expect(find.byKey(const Key('player-mini-open')), findsOneWidget);
    expect(find.byKey(const Key('player-mini-volume-mute')), findsOneWidget);
    expect(find.byKey(const Key('player-mini-play-pause')), findsOneWidget);
    expect(find.byKey(const Key('edmm-artwork-fallback')), findsOneWidget);
    expect(find.text('100%'), findsNothing);
    expect(find.byType(BackdropFilter), findsNothing);
    expect(tester.takeException(), isNull);
    expect(find.byTooltip('Open full player'), findsOneWidget);
    expect(find.bySemanticsLabel('Mute'), findsOneWidget);
    expect(find.bySemanticsLabel('Play'), findsOneWidget);

    final openNode = tester.getSemantics(
      find.byKey(const Key('player-mini-open-semantics')),
    );
    expect(openNode.label, 'Open full player');
    expect(openNode.value, '${_longTrack.title}, ${_longTrack.artistName}');
    expect(openNode.flagsCollection.isButton, isTrue);
    expect(openNode.flagsCollection.isEnabled, Tristate.isTrue);
    final openSize = tester.getSize(find.byKey(const Key('player-mini-open')));
    expect(openSize.width, greaterThanOrEqualTo(EdmmSizes.minTouchTarget));
    expect(openSize.height, greaterThanOrEqualTo(EdmmSizes.minTouchTarget));

    for (final key in const <Key>[
      Key('player-mini-volume-mute'),
      Key('player-mini-play-pause'),
    ]) {
      expect(
        tester.getSize(find.byKey(key)),
        const Size.square(EdmmSizes.minTouchTarget),
      );
    }

    await tester.tap(find.byKey(const Key('player-mini-open')));
    await tester.tap(find.byKey(const Key('player-mini-volume-mute')));
    await tester.tap(find.byKey(const Key('player-mini-play-pause')));
    await tester.pump();
    expect(openCalls, 1);
    expect(audio.muteCalls, 1);
    expect(audio.playCalls, 1);
    semantics.dispose();
  });

  testWidgets('rose floating surface and progress use design tokens', (
    tester,
  ) async {
    final audio = _MiniAudio();
    final viewModel = _viewModelFor(audio);
    await _showTrack(
      tester,
      audio: audio,
      viewModel: viewModel,
      viewport: const Size(360, 640),
    );
    audio.emitPosition(const Duration(seconds: 30));
    await tester.pump();
    await tester.pump();

    final barFinder = find.byKey(const Key('player-mini-bar'));
    final barRect = tester.getRect(barFinder);
    expect(barRect.left, EdmmSpacing.sm);
    expect(barRect.right, 360 - EdmmSpacing.sm);
    final material = tester.widget<Material>(barFinder);
    expect(material.color, EdmmColors.surfaceRose);
    expect(material.elevation, 0);
    final shape = material.shape! as RoundedRectangleBorder;
    expect(shape.borderRadius, BorderRadius.circular(EdmmRadii.medium));

    final progressFinder = find.byKey(const Key('player-mini-progress'));
    expect(tester.getSize(progressFinder).height, 2);
    final progress = tester.widget<LinearProgressIndicator>(progressFinder);
    expect(progress.color, EdmmColors.playbackActive);
    expect(progress.value, closeTo(0.5, 0.001));
    expect(find.text('100%'), findsNothing);
  });

  for (final testCase in const <({String label, Size size, double scale})>[
    (label: 'compact 300', size: Size(300, 600), scale: 1),
    (label: 'compact 360 large text', size: Size(360, 640), scale: 2),
    (label: 'wide 800 large text', size: Size(800, 600), scale: 2),
  ]) {
    testWidgets('${testCase.label} has no overflow', (tester) async {
      final audio = _MiniAudio();
      final viewModel = _viewModelFor(audio);
      await _showTrack(
        tester,
        audio: audio,
        viewModel: viewModel,
        viewport: testCase.size,
        textScale: testCase.scale,
        safeArea: const EdgeInsets.only(top: 24, bottom: 34),
        onOpenPlayer: () {},
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(FittedBox), findsNothing);
      expect(find.byKey(const Key('player-mini-bar')), findsOneWidget);
      final barRect = tester.getRect(find.byKey(const Key('player-mini-bar')));
      expect(barRect.bottom, lessThanOrEqualTo(testCase.size.height - 34));
      if (testCase.size.width >= 800) {
        expect(find.text('100%'), findsOneWidget);
      }
    });
  }

  testWidgets('action tooltips and play state remain caller-compatible', (
    tester,
  ) async {
    final audio = _MiniAudio();
    final viewModel = _viewModelFor(audio);
    await _showTrack(
      tester,
      audio: audio,
      viewModel: viewModel,
      viewport: const Size(800, 600),
      status: PlaybackStatus.playing,
      onOpenPlayer: () {},
    );

    expect(
      tester
          .widget<IconButton>(find.byKey(const Key('player-mini-volume-mute')))
          .tooltip,
      'Mute',
    );
    expect(
      tester
          .widget<IconButton>(find.byKey(const Key('player-mini-play-pause')))
          .tooltip,
      'Pause',
    );
    expect(find.byIcon(Icons.pause), findsOneWidget);

    await tester.tap(find.byKey(const Key('player-mini-play-pause')));
    await tester.pump();
    expect(audio.pauseCalls, 1);
  });
}
