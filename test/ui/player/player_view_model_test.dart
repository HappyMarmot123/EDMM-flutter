import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:edmm/data/repositories/in_memory_local_library_repository.dart';
import 'package:edmm/domain/audio/audio_controller.dart';
import 'package:edmm/domain/audio/audio_effects_controller.dart';
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

class _FakeEffects implements AudioEffectsController {
  _FakeEffects([this._preset = AudioEqualizerPreset.flat]);

  final setPresetCalls = <AudioEqualizerPreset>[];
  AudioEqualizerPreset _preset;

  @override
  AudioEqualizerSupport get equalizerSupport => AudioEqualizerSupport.supported;

  @override
  AudioEqualizerPreset get equalizerPreset => _preset;

  @override
  Future<void> setEqualizerPreset(AudioEqualizerPreset preset) async {
    _preset = preset;
    setPresetCalls.add(preset);
  }
}

class _DelayedSettingsRepository extends InMemoryLocalLibraryRepository {
  _DelayedSettingsRepository(this.values);

  final Map<String, String> values;
  final readGate = Completer<void>();

  @override
  Future<String?> getAudioSetting(String key) async {
    await readGate.future;
    return values[key];
  }
}

class _ThrowingSettingsRepository extends InMemoryLocalLibraryRepository {
  @override
  Future<void> setAudioSetting(String key, String value) async {
    throw StateError('settings write failed');
  }
}

class _DelayedVolumeAudio extends _FakeAudio {
  final volumeGate = Completer<void>();

  @override
  Future<void> setVolume(double volume) async {
    await volumeGate.future;
    await super.setVolume(volume);
  }
}

class _SequencedVolumeAudio extends _FakeAudio {
  final requestedVolumes = <double>[];
  final gates = <Completer<void>>[];

  @override
  Future<void> setVolume(double volume) async {
    requestedVolumes.add(volume);
    final gate = Completer<void>();
    gates.add(gate);
    await gate.future;
    await super.setVolume(volume);
  }
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
      expect(audio.volume, closeTo(0.75, 0.0001));
    },
  );

  test('defaults equalizer preset to flat', () async {
    final effects = _FakeEffects();
    final vm = PlayerViewModel(_FakeAudio(), effectsController: effects);
    await Future<void>.delayed(Duration.zero);

    expect(vm.equalizerPreset, AudioEqualizerPreset.flat);
    expect(effects.setPresetCalls, isEmpty);
  });

  test('restores stored bass boost preset', () async {
    final effects = _FakeEffects();
    final localLibrary = InMemoryLocalLibraryRepository();
    await localLibrary.setAudioSetting('equalizer.preset', 'bass');

    final vm = PlayerViewModel(
      _FakeAudio(),
      localLibrary: localLibrary,
      effectsController: effects,
    );
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(vm.equalizerPreset, AudioEqualizerPreset.bassBoost);
    expect(effects.setPresetCalls, [AudioEqualizerPreset.bassBoost]);
  });

  test('falls back to flat for invalid stored equalizer preset', () async {
    final effects = _FakeEffects(AudioEqualizerPreset.bassBoost);
    final localLibrary = InMemoryLocalLibraryRepository();
    await localLibrary.setAudioSetting('equalizer.preset', 'edm');

    final vm = PlayerViewModel(
      _FakeAudio(),
      localLibrary: localLibrary,
      effectsController: effects,
    );
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(vm.equalizerPreset, AudioEqualizerPreset.flat);
    expect(effects.setPresetCalls, [AudioEqualizerPreset.flat]);
  });

  test('stores selected equalizer preset', () async {
    final effects = _FakeEffects();
    final localLibrary = InMemoryLocalLibraryRepository();
    final vm = PlayerViewModel(
      _FakeAudio(),
      localLibrary: localLibrary,
      effectsController: effects,
    );

    await vm.setEqualizerPreset(AudioEqualizerPreset.bassBoost);

    expect(vm.equalizerPreset, AudioEqualizerPreset.bassBoost);
    expect(effects.setPresetCalls, [AudioEqualizerPreset.bassBoost]);
    expect(await localLibrary.getAudioSetting('equalizer.preset'), 'bass');
  });

  test('restores volume, mute, shuffle, and equalizer settings', () async {
    final audio = _FakeAudio();
    final effects = _FakeEffects();
    final localLibrary = InMemoryLocalLibraryRepository();
    await localLibrary.setAudioSetting('volume', '0.35');
    await localLibrary.setAudioSetting('muted', 'true');
    await localLibrary.setAudioSetting('shuffle', 'true');
    await localLibrary.setAudioSetting('equalizer.preset', 'bass');

    final vm = PlayerViewModel(
      audio,
      localLibrary: localLibrary,
      effectsController: effects,
    );
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(vm.volume, 0.0);
    expect(vm.isMuted, isTrue);
    expect(vm.isShuffleEnabled, isTrue);
    expect(vm.equalizerPreset, AudioEqualizerPreset.bassBoost);
    expect(audio.setVolumeCalls, contains(0.35));
    expect(audio.setMuteCalls, [true]);
    expect(audio.setShuffleCalls, [true]);
  });

  test('persists volume, mute, shuffle, and equalizer user changes', () async {
    final audio = _FakeAudio();
    final effects = _FakeEffects();
    final localLibrary = InMemoryLocalLibraryRepository();
    final vm = PlayerViewModel(
      audio,
      localLibrary: localLibrary,
      effectsController: effects,
    );
    await Future<void>.delayed(Duration.zero);

    await vm.setVolume(0.4);
    await vm.toggleMute();
    await vm.toggleShuffle();
    await vm.setEqualizerPreset(AudioEqualizerPreset.bassBoost);

    expect(await localLibrary.getAudioSetting('volume'), '0.4');
    expect(await localLibrary.getAudioSetting('muted'), 'true');
    expect(await localLibrary.getAudioSetting('shuffle'), 'true');
    expect(await localLibrary.getAudioSetting('equalizer.preset'), 'bass');
  });

  test(
    'user changes win when stored settings finish restoring later',
    () async {
      final audio = _FakeAudio();
      final effects = _FakeEffects();
      final localLibrary = _DelayedSettingsRepository({
        'volume': '0.2',
        'muted': 'true',
        'shuffle': 'false',
        'equalizer.preset': 'flat',
      });
      final vm = PlayerViewModel(
        audio,
        localLibrary: localLibrary,
        effectsController: effects,
      );

      await vm.setVolume(0.8);
      await vm.toggleShuffle();
      await vm.setEqualizerPreset(AudioEqualizerPreset.bassBoost);
      localLibrary.readGate.complete();
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(vm.volume, 0.8);
      expect(vm.isMuted, isFalse);
      expect(vm.isShuffleEnabled, isTrue);
      expect(vm.equalizerPreset, AudioEqualizerPreset.bassBoost);
      expect(audio.volume, 0.8);
      expect(audio.shuffleEnabled, isTrue);
      expect(effects.equalizerPreset, AudioEqualizerPreset.bassBoost);
    },
  );

  test(
    'settings write failures do not roll back applied player state',
    () async {
      final audio = _FakeAudio();
      final effects = _FakeEffects();
      final vm = PlayerViewModel(
        audio,
        localLibrary: _ThrowingSettingsRepository(),
        effectsController: effects,
      );
      await Future<void>.delayed(Duration.zero);

      await expectLater(vm.setVolume(0.6), completes);
      await expectLater(vm.toggleShuffle(), completes);
      await expectLater(
        vm.setEqualizerPreset(AudioEqualizerPreset.bassBoost),
        completes,
      );

      expect(vm.volume, 0.6);
      expect(vm.isShuffleEnabled, isTrue);
      expect(vm.equalizerPreset, AudioEqualizerPreset.bassBoost);
    },
  );

  test('in-flight volume command persists after view model disposal', () async {
    final audio = _DelayedVolumeAudio();
    final localLibrary = InMemoryLocalLibraryRepository();
    final vm = PlayerViewModel(audio, localLibrary: localLibrary);
    await Future<void>.delayed(Duration.zero);

    final command = vm.setVolume(0.4);
    vm.dispose();
    audio.volumeGate.complete();
    await command;

    expect(audio.volume, 0.4);
    expect(await localLibrary.getAudioSetting('volume'), '0.4');
    expect(await localLibrary.getAudioSetting('muted'), 'false');
  });

  test('volume commands are serialized so the latest request wins', () async {
    final audio = _SequencedVolumeAudio();
    final localLibrary = InMemoryLocalLibraryRepository();
    final vm = PlayerViewModel(audio, localLibrary: localLibrary);
    await Future<void>.delayed(Duration.zero);

    final first = vm.setVolume(0.2);
    await Future<void>.delayed(Duration.zero);
    final second = vm.setVolume(0.8);
    await Future<void>.delayed(Duration.zero);

    expect(audio.requestedVolumes, [0.2]);
    audio.gates.first.complete();
    await Future<void>.delayed(Duration.zero);
    expect(audio.requestedVolumes, [0.2, 0.8]);
    audio.gates.last.complete();
    await Future.wait([first, second]);

    expect(audio.volume, 0.8);
    expect(vm.volume, 0.8);
    expect(await localLibrary.getAudioSetting('volume'), '0.8');
  });

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

  test('records playing current track in the local library', () async {
    final audio = _FakeAudio();
    final localLibrary = InMemoryLocalLibraryRepository();
    PlayerViewModel(audio, localLibrary: localLibrary);

    audio._snap.add(
      PlaybackSnapshot(currentTrack: _track(), status: PlaybackStatus.playing),
    );
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(await localLibrary.getRecentTrackIds(), ['x']);
    expect((await localLibrary.getCachedTrack('x'))?.id, 'x');
  });

  test('dismisses error banner without dropping snapshot error', () async {
    final audio = _FakeAudio();
    final vm = PlayerViewModel(audio);
    audio._snap.add(
      PlaybackSnapshot(
        currentTrack: _track(),
        status: PlaybackStatus.error,
        error: ServerFailure(503),
      ),
    );
    await Future<void>.delayed(Duration.zero);

    expect(vm.hasError, isTrue);
    expect(vm.shouldShowErrorBanner, isTrue);

    vm.dismissError();
    expect(vm.hasError, isTrue);
    expect(vm.shouldShowErrorBanner, isFalse);
  });

  test(
    'retryPlayback replays the current track and coexists with dismiss',
    () async {
      final audio = _FakeAudio();
      final vm = PlayerViewModel(audio);
      audio._snap.add(
        PlaybackSnapshot(
          currentTrack: _track(),
          status: PlaybackStatus.error,
          error: const NetworkFailure('offline'),
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(vm.canRetryPlayback, isTrue);
      vm.dismissError();
      expect(vm.shouldShowErrorBanner, isFalse);

      await vm.retryPlayback();

      expect(audio.plays, 1);
      expect(vm.shouldShowErrorBanner, isFalse);
    },
  );

  test('retryPlayback is unavailable without a current track', () async {
    final audio = _FakeAudio();
    final vm = PlayerViewModel(audio);
    audio._snap.add(
      const PlaybackSnapshot(
        status: PlaybackStatus.error,
        error: ParseFailure('No playable tracks'),
      ),
    );
    await Future<void>.delayed(Duration.zero);

    expect(vm.canRetryPlayback, isFalse);
    await vm.retryPlayback();
    expect(audio.plays, 0);
  });

  test('clears dismissed error state on non-error snapshots', () async {
    final audio = _FakeAudio();
    final vm = PlayerViewModel(audio);
    audio._snap.add(
      PlaybackSnapshot(
        currentTrack: _track(),
        status: PlaybackStatus.error,
        error: ParseFailure('bad'),
      ),
    );
    await Future<void>.delayed(Duration.zero);
    vm.dismissError();
    expect(vm.shouldShowErrorBanner, isFalse);

    audio._snap.add(
      PlaybackSnapshot(
        currentTrack: _track(),
        status: PlaybackStatus.paused,
        duration: Duration(seconds: 1),
      ),
    );
    await Future<void>.delayed(Duration.zero);
    expect(vm.shouldShowErrorBanner, isFalse);
    expect(vm.hasError, isFalse);
  });

  test('tracks error token changes across different failures', () async {
    final audio = _FakeAudio();
    final vm = PlayerViewModel(audio);
    final firstError = PlaybackSnapshot(
      currentTrack: _track(),
      status: PlaybackStatus.error,
      error: NetworkFailure('offline'),
    );
    final secondError = PlaybackSnapshot(
      currentTrack: _track(),
      status: PlaybackStatus.error,
      error: ServerFailure(503),
    );
    audio._snap.add(firstError);
    await Future<void>.delayed(Duration.zero);
    final firstToken = vm.latestErrorToken;

    vm.dismissError();
    audio._snap.add(secondError);
    await Future<void>.delayed(Duration.zero);
    expect(vm.latestErrorToken, isNot(equals(firstToken)));
    expect(vm.shouldShowErrorBanner, isTrue);
  });
}
