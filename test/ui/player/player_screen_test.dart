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
  int plays = 0;
  @override Stream<PlaybackSnapshot> get snapshot => snap.stream;
  @override Stream<Duration> get position => pos.stream;
  @override Future<void> play() async => plays++;
  @override Future<void> pause() async {}
  @override Future<void> seek(Duration position) async {}
  @override Future<void> next() async {}
  @override Future<void> previous() async {}
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
}
