import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:edmm/domain/audio/audio_controller.dart';
import 'package:edmm/domain/models/track.dart';
import 'package:edmm/domain/playback/playback_snapshot.dart';
import 'package:edmm/ui/player/view_model/player_view_model.dart';

class _FakeAudio implements AudioController {
  final _snap = StreamController<PlaybackSnapshot>.broadcast();
  final _pos = StreamController<Duration>.broadcast();
  int plays = 0, pauses = 0, nexts = 0, previouses = 0, seeks = 0;
  Duration? lastSeek;
  @override Stream<PlaybackSnapshot> get snapshot => _snap.stream;
  @override Stream<Duration> get position => _pos.stream;
  @override Future<void> play() async => plays++;
  @override Future<void> pause() async => pauses++;
  @override Future<void> seek(Duration position) async { seeks++; lastSeek = position; }
  @override Future<void> next() async => nexts++;
  @override Future<void> previous() async => previouses++;
  @override Future<void> loadQueue(List<Track> tracks, {int initialIndex = 0}) async {}
  @override Future<void> dispose() async {}
}

void main() {
  test('mirrors snapshot stream and notifies', () async {
    final audio = _FakeAudio();
    final vm = PlayerViewModel(audio);
    var notified = 0;
    vm.addListener(() => notified++);
    audio._snap.add(const PlaybackSnapshot(status: PlaybackStatus.playing));
    await Future<void>.delayed(Duration.zero);
    expect(vm.snapshot.status, PlaybackStatus.playing);
    expect(notified, greaterThan(0));
  });

  test('playPause delegates based on current status', () async {
    final audio = _FakeAudio();
    final vm = PlayerViewModel(audio);
    audio._snap.add(const PlaybackSnapshot(status: PlaybackStatus.paused));
    await Future<void>.delayed(Duration.zero);
    await vm.playPause();
    expect(audio.plays, 1);
    audio._snap.add(const PlaybackSnapshot(status: PlaybackStatus.playing));
    await Future<void>.delayed(Duration.zero);
    await vm.playPause();
    expect(audio.pauses, 1);
  });

  test('transport controls delegate to audio controller', () async {
    final audio = _FakeAudio();
    final vm = PlayerViewModel(audio);

    await vm.seek(const Duration(seconds: 7));
    await vm.next();
    await vm.previous();

    expect(audio.seeks, 1);
    expect(audio.lastSeek, const Duration(seconds: 7));
    expect(audio.nexts, 1);
    expect(audio.previouses, 1);
  });
}
