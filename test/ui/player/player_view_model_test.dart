import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:edmm/domain/audio/audio_controller.dart';
import 'package:edmm/domain/models/track.dart';
import 'package:edmm/domain/playback/playback_snapshot.dart';
import 'package:edmm/domain/result.dart';
import 'package:edmm/domain/telemetry/playback_telemetry.dart';
import 'package:edmm/ui/player/view_model/player_view_model.dart';

class _FakeAudio implements AudioController {
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
  Future<void> dispose() async {}
}

Track _track() => Track(
  id: 'x',
  source: 'cloudinary',
  title: 'Bloom',
  artistId: 'a',
  artistName: 'Feint',
  durationMs: 60000,
  streamUrl: 'https://example.com/bloom.mp3',
  metadata: const {},
);

class _PlaybackTelemetryRecorder extends PlaybackTelemetrySink {
  final events = <PlaybackTelemetryEvent>[];

  @override
  void emit(PlaybackTelemetryEvent event) => events.add(event);
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

  test('toggleShuffle updates shuffle state and controller state', () async {
    final audio = _FakeAudio();
    final vm = PlayerViewModel(audio);
    await vm.toggleShuffle();
    expect(audio.setShuffleCalls, [true]);
    expect(vm.isShuffleEnabled, isTrue);

    await vm.toggleShuffle();
    expect(audio.setShuffleCalls, [true, false]);
    expect(vm.isShuffleEnabled, isFalse);
  });

  test('setVolume clamps and updates muted state', () async {
    final audio = _FakeAudio();
    final vm = PlayerViewModel(audio);

    await vm.setVolume(0.2);
    expect(audio.setVolumeCalls, [0.2]);
    expect(vm.volume, closeTo(0.2, 0.0001));
    expect(vm.isMuted, isFalse);

    await vm.setVolume(-0.5);
    expect(audio.setVolumeCalls.last, 0.0);
    expect(vm.volume, 0.0);
    expect(vm.isMuted, isTrue);
  });

  test(
    'toggleMute delegates to mute API and restores previous volume',
    () async {
      final audio = _FakeAudio();
      final vm = PlayerViewModel(audio);
      await vm.setVolume(0.75);

      await vm.toggleMute();
      expect(audio.setMuteCalls, [true]);
      expect(vm.isMuted, isTrue);
      expect(vm.volume, 0.0);

      await vm.toggleMute();
      expect(audio.setMuteCalls, [true, false]);
      expect(vm.isMuted, isFalse);
      expect(vm.volume, closeTo(0.75, 0.0001));
    },
  );

  test('emits playback error telemetry from snapshot errors', () async {
    final audio = _FakeAudio();
    final telemetry = _PlaybackTelemetryRecorder();
    PlayerViewModel(audio, telemetry: telemetry);

    audio._snap.add(
      PlaybackSnapshot(
        currentTrack: _track(),
        status: PlaybackStatus.error,
        queueIndex: 2,
        error: const ServerFailure(503),
      ),
    );
    await Future<void>.delayed(Duration.zero);

    expect(telemetry.events, hasLength(1));
    expect(
      telemetry.events.single.name,
      PlaybackTelemetryEventNames.errorReported,
    );
    expect(
      telemetry.events.single.payload[PlaybackTelemetryPayload.failureCategory],
      'server',
    );
    expect(
      telemetry.events.single.payload[PlaybackTelemetryPayload
          .failureRetryable],
      isTrue,
    );
    expect(
      telemetry.events.single.payload[PlaybackTelemetryPayload.status],
      'error',
    );
    expect(
      telemetry.events.single.payload[PlaybackTelemetryPayload.hasCurrentTrack],
      isTrue,
    );
    expect(
      telemetry.events.single.payload[PlaybackTelemetryPayload.queueIndex],
      2,
    );
  });
}
