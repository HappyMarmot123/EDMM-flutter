import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:edmm/l10n/app_localizations.dart';
import 'package:edmm/domain/audio/audio_controller.dart';
import 'package:edmm/domain/models/track.dart';
import 'package:edmm/domain/playback/playback_snapshot.dart';
import 'package:edmm/ui/player/view_model/player_view_model.dart';
import 'package:edmm/ui/player/widgets/player_screen.dart';

class _FakeAudio implements AudioController {
  final snap = StreamController<PlaybackSnapshot>.broadcast();
  final pos = StreamController<Duration>.broadcast();
  int plays = 0, nexts = 0, previouses = 0, seeks = 0;
  Duration? lastSeek;
  @override Stream<PlaybackSnapshot> get snapshot => snap.stream;
  @override Stream<Duration> get position => pos.stream;
  @override Future<void> play() async => plays++;
  @override Future<void> pause() async {}
  @override Future<void> seek(Duration position) async { seeks++; lastSeek = position; }
  @override Future<void> next() async => nexts++;
  @override Future<void> previous() async => previouses++;
  @override Future<void> loadQueue(List<Track> tracks, {int initialIndex = 0}) async {}
  @override Future<void> dispose() async {}
}

Widget _host(Widget child) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    );

void main() {
  testWidgets('shows current track title and play triggers controller', (tester) async {
    final audio = _FakeAudio();
    final vm = PlayerViewModel(audio);
    await tester.pumpWidget(_host(PlayerScreen(viewModel: vm)));
    final track = Track(id: 'x', source: 'cloudinary', title: 'Bloom', artistId: 'a',
        artistName: 'Feint', durationMs: 1000, streamUrl: 'u', metadata: const {});
    audio.snap.add(PlaybackSnapshot(currentTrack: track, status: PlaybackStatus.paused,
        duration: const Duration(seconds: 1)));
    await tester.pump();
    expect(find.text('Bloom'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.play_arrow));
    expect(audio.plays, 1);
  });

  testWidgets('transport and seek controls delegate to controller', (tester) async {
    final audio = _FakeAudio();
    final vm = PlayerViewModel(audio);
    await tester.pumpWidget(_host(PlayerScreen(viewModel: vm)));
    final track = Track(id: 'x', source: 'cloudinary', title: 'Bloom', artistId: 'a',
        artistName: 'Feint', durationMs: 60000, streamUrl: 'u', metadata: const {});
    audio.snap.add(PlaybackSnapshot(currentTrack: track, status: PlaybackStatus.paused,
        duration: const Duration(minutes: 1)));
    audio.pos.add(Duration.zero);
    await tester.pump();

    await tester.tap(find.byIcon(Icons.skip_next));
    await tester.tap(find.byIcon(Icons.skip_previous));
    await tester.drag(find.byType(Slider), const Offset(120, 0));
    await tester.pump();

    expect(audio.nexts, 1);
    expect(audio.previouses, 1);
    expect(audio.seeks, greaterThan(0));
    expect(audio.lastSeek, isNotNull);
  });
}
