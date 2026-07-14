import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../domain/audio/audio_effects_controller.dart';
import '../../../domain/audio/audio_controller.dart';
import '../../../domain/audio/audio_settings.dart';
import '../../../domain/audio/audio_visualizer_controller.dart';
import '../../../data/repositories/noop_local_library_repository.dart';
import '../../../domain/logic/playback_persistence.dart';
import '../../../domain/playback/playback_snapshot.dart';
import '../../../domain/repositories/local_library_repository.dart';
import '../../../domain/result.dart';
import '../../../domain/telemetry/playback_telemetry.dart';

class PlayerViewModel extends ChangeNotifier {
  PlayerViewModel(
    AudioController audio, {
    PlaybackTelemetrySink? telemetry,
    LocalLibraryRepository? localLibrary,
    AudioEffectsController? effectsController,
    AudioVisualizerController? visualizerController,
  }) : _audio = audio,
       _telemetry = telemetry ?? const NoopPlaybackTelemetrySink(),
       _localLibrary = localLibrary ?? const NoopLocalLibraryRepository(),
       _effectsController =
           effectsController ??
           (audio is AudioEffectsController
               ? audio as AudioEffectsController
               : const NoopAudioEffectsController()),
       _visualizerController =
           visualizerController ??
           (audio is AudioVisualizerController
               ? audio as AudioVisualizerController
               : const NoopAudioVisualizerController()) {
    _sub = _audio.snapshot.listen((s) {
      if (_disposed) return;
      snapshot = s;
      _latestErrorToken = _errorToken(s.error);
      if (s.status != PlaybackStatus.error) {
        _dismissedErrorToken = null;
      }
      _emitPlaybackErrorTelemetry(s);
      _persistPlayingTrack(s);
      notifyListeners();
    });
    _volume = _audio.volume;
    _mute = _volume <= 0;
    _prevVolume = _volume > 0 ? _volume : 1.0;
    _shuffleEnabled = _audio.isShuffleEnabled;
    _equalizerPreset = _effectsController.equalizerPreset;
    _visualizerSupport = _visualizerController.visualizerSupport;
    _visualizerSupportSub = _visualizerController.visualizerSupportStream
        .listen((support) {
          if (_disposed || support == _visualizerSupport) return;
          _visualizerSupport = support;
          notifyListeners();
        });
    unawaited(_restoreAudioSettings());
  }

  final AudioController _audio;
  final PlaybackTelemetrySink _telemetry;
  final LocalLibraryRepository _localLibrary;
  final AudioEffectsController _effectsController;
  final AudioVisualizerController _visualizerController;
  late final StreamSubscription<PlaybackSnapshot> _sub;
  late final StreamSubscription<AudioVisualizerSupport> _visualizerSupportSub;
  bool _mute = false;
  double _volume = 1.0;
  double _prevVolume = 1.0;
  bool _shuffleEnabled = false;
  bool _visualizerEnabled = defaultAudioVisualizerEnabled;
  String? _lastPersistedTrackId;
  AudioEqualizerPreset _equalizerPreset = defaultAudioEqualizerPreset;
  late AudioVisualizerSupport _visualizerSupport;
  String? _latestErrorToken;
  String? _dismissedErrorToken;
  int _volumeSettingsRevision = 0;
  int _shuffleSettingsRevision = 0;
  int _equalizerSettingsRevision = 0;
  int _visualizerSettingsRevision = 0;
  Future<void> _volumeCommandTail = Future<void>.value();
  Future<void> _shuffleCommandTail = Future<void>.value();
  Future<void> _equalizerCommandTail = Future<void>.value();
  Future<void> _settingsWriteTail = Future<void>.value();
  bool _disposed = false;

  PlaybackSnapshot snapshot = const PlaybackSnapshot();
  Stream<Duration> get position => _audio.position;
  Stream<AudioSpectrumFrame> get spectrum => _visualizerController.spectrum;

  bool get isMuted => _mute;
  double get volume => _volume;
  bool get isShuffleEnabled => _shuffleEnabled;
  bool get isVisualizerEnabled => _visualizerEnabled;
  bool get isEqualizerEnabled => _equalizerPreset.appliesProcessing;
  AudioEqualizerPreset get equalizerPreset => _equalizerPreset;
  bool get shouldShowErrorBanner =>
      snapshot.error != null &&
      snapshot.status == PlaybackStatus.error &&
      _latestErrorToken != _dismissedErrorToken;
  bool get canRetryPlayback =>
      snapshot.error != null &&
      snapshot.status == PlaybackStatus.error &&
      snapshot.currentTrack != null;
  AudioEqualizerSupport get equalizerSupport =>
      _effectsController.equalizerSupport;
  AudioVisualizerSupport get visualizerSupport => _visualizerSupport;
  String? get latestErrorToken => _latestErrorToken;

  Future<void> playPause() =>
      snapshot.isPlaying ? _audio.pause() : _audio.play();
  Future<void> seek(Duration to) => _audio.seek(to);
  Future<void> next() => _audio.next();
  Future<void> previous() => _audio.previous();
  Future<void> retryPlayback() =>
      canRetryPlayback ? _audio.play() : Future<void>.value();

  Future<void> toggleShuffle() {
    if (_disposed) return Future<void>.value();
    _shuffleSettingsRevision += 1;
    return _enqueueShuffleCommand(() async {
      await _audio.setShuffleEnabled(!_shuffleEnabled);
      _shuffleEnabled = _audio.isShuffleEnabled;
      if (!_disposed) notifyListeners();
      await _persistSettingsSafely({
        shuffleSettingKey: _shuffleEnabled.toString(),
      });
    });
  }

  Future<void> setVolume(double next) {
    if (_disposed) return Future<void>.value();
    _volumeSettingsRevision += 1;
    final clamped = next.clamp(0.0, 1.0).toDouble();
    return _enqueueVolumeCommand(() async {
      await _audio.setVolume(clamped);
      _volume = _audio.volume;
      _mute = _volume <= 0;
      if (_volume > 0) {
        _prevVolume = _volume;
      }
      if (!_disposed) notifyListeners();
      await _persistVolumeSettings();
    });
  }

  Future<void> toggleMute() {
    if (_disposed) return Future<void>.value();
    _volumeSettingsRevision += 1;
    return _enqueueVolumeCommand(() async {
      final nextMute = !_mute;
      if (nextMute) {
        _prevVolume = _volume > 0 ? _volume : _prevVolume;
        await _audio.setMute(true);
      } else {
        final restoredVolume = _prevVolume > 0 ? _prevVolume : 1.0;
        await _audio.setMute(false);
        if ((_audio.volume - restoredVolume).abs() > 0.000001) {
          await _audio.setVolume(restoredVolume);
        }
      }
      _volume = _audio.volume;
      _mute = _volume <= 0;
      if (!_disposed) notifyListeners();
      await _persistVolumeSettings();
    });
  }

  Future<void> setEqualizerPreset(AudioEqualizerPreset preset) {
    if (_disposed) return Future<void>.value();
    _equalizerSettingsRevision += 1;
    return _enqueueEqualizerCommand(() async {
      await _effectsController.setEqualizerPreset(preset);
      _equalizerPreset = _effectsController.equalizerPreset;
      if (!_disposed) notifyListeners();
      await _persistSettingsSafely({
        equalizerPresetSettingKey: _equalizerPreset.storageValue,
      });
    });
  }

  Future<void> toggleVisualizer() {
    if (_disposed) return Future<void>.value();
    _visualizerSettingsRevision += 1;
    _visualizerEnabled = !_visualizerEnabled;
    notifyListeners();
    return _persistSettingsSafely({
      visualizerEnabledSettingKey: _visualizerEnabled.toString(),
    });
  }

  bool get hasError => snapshot.error != null;
  void dismissError() {
    _dismissedErrorToken = _latestErrorToken;
    notifyListeners();
  }

  void _emitPlaybackErrorTelemetry(PlaybackSnapshot snapshot) {
    if (snapshot.error == null) return;
    _telemetry.emit(PlaybackTelemetryEvent.errorReported(snapshot));
  }

  void _persistPlayingTrack(PlaybackSnapshot snapshot) {
    final track = snapshot.currentTrack;
    if (track == null || !snapshot.isPlaying) return;
    if (track.id == _lastPersistedTrackId) return;
    _lastPersistedTrackId = track.id;
    unawaited(persistPlaybackTrack(_localLibrary, track));
  }

  Future<void> _restoreAudioSettings() async {
    final volumeRevision = _volumeSettingsRevision;
    final shuffleRevision = _shuffleSettingsRevision;
    final equalizerRevision = _equalizerSettingsRevision;
    final visualizerRevision = _visualizerSettingsRevision;
    final stored = await Future.wait([
      _readSetting(volumeSettingKey),
      _readSetting(mutedSettingKey),
      _readSetting(shuffleSettingKey),
      _readSetting(equalizerPresetSettingKey),
      _readSetting(visualizerEnabledSettingKey),
    ]);
    if (_disposed) return;

    await _restoreVolumeSettings(
      storedVolume: stored[0],
      storedMuted: stored[1],
      revision: volumeRevision,
    );
    await _restoreShuffleSetting(stored[2], shuffleRevision);
    await _restoreEqualizerSetting(stored[3], equalizerRevision);
    _restoreVisualizerSetting(stored[4], visualizerRevision);
  }

  Future<void> _restoreVolumeSettings({
    required _SettingRead storedVolume,
    required _SettingRead storedMuted,
    required int revision,
  }) {
    if (!_canRestoreVolume(revision)) return Future<void>.value();
    final restoredVolume = storedVolume.succeeded
        ? parseStoredVolume(storedVolume.value)
        : null;
    final restoredMuted = storedMuted.succeeded
        ? parseStoredBool(storedMuted.value)
        : null;
    if (restoredVolume == null && restoredMuted == null) {
      return Future<void>.value();
    }

    return _enqueueVolumeCommand(() async {
      if (!_canRestoreVolume(revision)) return;
      if (restoredVolume != null) {
        await _audio.setVolume(restoredVolume);
        if (!_canRestoreVolume(revision)) return;
        if (restoredVolume > 0) {
          _prevVolume = restoredVolume;
        }
      }
      if (restoredMuted == true) {
        await _audio.setMute(true);
        if (!_canRestoreVolume(revision)) return;
      } else if (restoredMuted == false && _audio.volume <= 0) {
        await _audio.setMute(false);
        if (!_canRestoreVolume(revision)) return;
        if (restoredVolume != null &&
            (_audio.volume - restoredVolume).abs() > 0.000001) {
          await _audio.setVolume(restoredVolume);
          if (!_canRestoreVolume(revision)) return;
        }
      }

      _volume = _audio.volume;
      _mute = _volume <= 0;
      notifyListeners();
    });
  }

  Future<void> _restoreShuffleSetting(_SettingRead stored, int revision) {
    if (!stored.succeeded || !_canRestoreShuffle(revision)) {
      return Future<void>.value();
    }
    final restored = parseStoredBool(stored.value);
    if (restored == null || restored == _shuffleEnabled) {
      return Future<void>.value();
    }
    return _enqueueShuffleCommand(() async {
      if (!_canRestoreShuffle(revision)) return;
      await _audio.setShuffleEnabled(restored);
      if (!_canRestoreShuffle(revision)) return;
      _shuffleEnabled = _audio.isShuffleEnabled;
      notifyListeners();
    });
  }

  Future<void> _restoreEqualizerSetting(_SettingRead stored, int revision) {
    if (!stored.succeeded || !_canRestoreEqualizer(revision)) {
      return Future<void>.value();
    }
    final restored = audioEqualizerPresetFromStorage(stored.value);
    if (restored == _equalizerPreset) return Future<void>.value();
    return _enqueueEqualizerCommand(() async {
      if (!_canRestoreEqualizer(revision)) return;
      await _effectsController.setEqualizerPreset(restored);
      if (!_canRestoreEqualizer(revision)) return;
      _equalizerPreset = _effectsController.equalizerPreset;
      notifyListeners();
    });
  }

  void _restoreVisualizerSetting(_SettingRead stored, int revision) {
    if (!stored.succeeded || !_canRestoreVisualizer(revision)) return;
    final restored = parseStoredBool(stored.value);
    if (restored == null || restored == _visualizerEnabled) return;
    _visualizerEnabled = restored;
    notifyListeners();
  }

  Future<_SettingRead> _readSetting(String key) async {
    try {
      return _SettingRead.success(await _localLibrary.getAudioSetting(key));
    } catch (_) {
      return const _SettingRead.failure();
    }
  }

  Future<void> _persistVolumeSettings() => _persistSettingsSafely({
    volumeSettingKey: _prevVolume.toString(),
    mutedSettingKey: _mute.toString(),
  });

  Future<void> _persistSettingsSafely(Map<String, String> settings) {
    final operation = _settingsWriteTail.then((_) async {
      for (final entry in settings.entries) {
        try {
          await _localLibrary.setAudioSetting(entry.key, entry.value);
        } catch (_) {
          // Playback state remains authoritative when local persistence fails.
        }
      }
    });
    _settingsWriteTail = operation;
    return operation;
  }

  Future<void> _enqueueVolumeCommand(Future<void> Function() action) {
    final operation = _volumeCommandTail.then(
      (_) => action(),
      onError: (_, _) => action(),
    );
    _volumeCommandTail = operation.then<void>((_) {}, onError: (_, _) {});
    return operation;
  }

  Future<void> _enqueueShuffleCommand(Future<void> Function() action) {
    final operation = _shuffleCommandTail.then(
      (_) => action(),
      onError: (_, _) => action(),
    );
    _shuffleCommandTail = operation.then<void>((_) {}, onError: (_, _) {});
    return operation;
  }

  Future<void> _enqueueEqualizerCommand(Future<void> Function() action) {
    final operation = _equalizerCommandTail.then(
      (_) => action(),
      onError: (_, _) => action(),
    );
    _equalizerCommandTail = operation.then<void>((_) {}, onError: (_, _) {});
    return operation;
  }

  bool _canRestoreVolume(int revision) =>
      !_disposed && revision == _volumeSettingsRevision;

  bool _canRestoreShuffle(int revision) =>
      !_disposed && revision == _shuffleSettingsRevision;

  bool _canRestoreEqualizer(int revision) =>
      !_disposed && revision == _equalizerSettingsRevision;

  bool _canRestoreVisualizer(int revision) =>
      !_disposed && revision == _visualizerSettingsRevision;

  @override
  void dispose() {
    _disposed = true;
    _sub.cancel();
    _visualizerSupportSub.cancel();
    super.dispose();
  }

  String? _errorToken(Failure? failure) {
    if (failure == null) return null;
    return switch (failure) {
      NetworkFailure(:final cause) => 'network:$cause',
      ServerFailure(:final statusCode) => 'server:$statusCode',
      ParseFailure(:final cause) => 'parse:$cause',
    };
  }
}

class _SettingRead {
  const _SettingRead.success(this.value) : succeeded = true;
  const _SettingRead.failure() : succeeded = false, value = null;

  final bool succeeded;
  final String? value;
}
