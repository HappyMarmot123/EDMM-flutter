import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../domain/audio/audio_effects_controller.dart';
import '../../../domain/audio/audio_controller.dart';
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
  }) : _audio = audio,
       _telemetry = telemetry ?? const NoopPlaybackTelemetrySink(),
       _localLibrary = localLibrary ?? const NoopLocalLibraryRepository(),
       _effectsController =
           effectsController ??
           (audio is AudioEffectsController
               ? audio as AudioEffectsController
               : const NoopAudioEffectsController()) {
    _sub = _audio.snapshot.listen((s) {
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
    _equalizerEnabled = _effectsController.isEqualizerEnabled;
    unawaited(_loadEqualizerBands());
  }

  final AudioController _audio;
  final PlaybackTelemetrySink _telemetry;
  final LocalLibraryRepository _localLibrary;
  final AudioEffectsController _effectsController;
  late final StreamSubscription<PlaybackSnapshot> _sub;
  bool _mute = false;
  double _volume = 1.0;
  double _prevVolume = 1.0;
  bool _shuffleEnabled = false;
  String? _lastPersistedTrackId;
  bool _equalizerEnabled = false;
  String? _latestErrorToken;
  String? _dismissedErrorToken;
  List<AudioEqualizerBand> _equalizerBands = const [];

  PlaybackSnapshot snapshot = const PlaybackSnapshot();
  Stream<Duration> get position => _audio.position;

  bool get isMuted => _mute;
  double get volume => _volume;
  bool get isShuffleEnabled => _shuffleEnabled;
  bool get isEqualizerEnabled => _equalizerEnabled;
  bool get shouldShowErrorBanner =>
      snapshot.error != null &&
      snapshot.status == PlaybackStatus.error &&
      _latestErrorToken != _dismissedErrorToken;
  AudioEqualizerSupport get equalizerSupport =>
      _effectsController.equalizerSupport;
  List<AudioEqualizerBand> get equalizerBands => _equalizerBands;
  String? get latestErrorToken => _latestErrorToken;

  Future<void> playPause() =>
      snapshot.isPlaying ? _audio.pause() : _audio.play();
  Future<void> seek(Duration to) => _audio.seek(to);
  Future<void> next() => _audio.next();
  Future<void> previous() => _audio.previous();

  Future<void> toggleShuffle() async {
    final nextShuffle = !_shuffleEnabled;
    await _audio.setShuffleEnabled(nextShuffle);
    _shuffleEnabled = nextShuffle;
    notifyListeners();
  }

  Future<void> setVolume(double next) async {
    final clamped = next.clamp(0.0, 1.0).toDouble();
    await _audio.setVolume(clamped);
    _volume = clamped;
    _mute = clamped <= 0;
    if (clamped > 0) {
      _prevVolume = clamped;
    }
    notifyListeners();
  }

  Future<void> toggleMute() async {
    final nextMute = !_mute;
    if (nextMute) {
      await _audio.setMute(true);
      _prevVolume = _volume > 0 ? _volume : _prevVolume;
      _volume = 0.0;
    } else {
      await _audio.setMute(false);
      _volume = _prevVolume > 0 ? _prevVolume : 1.0;
    }
    _mute = nextMute;
    notifyListeners();
  }

  Future<void> toggleEqualizer() async {
    final enabled = !_equalizerEnabled;
    await _effectsController.setEqualizerEnabled(enabled);
    _equalizerEnabled = _effectsController.isEqualizerEnabled;
    if (_equalizerBands.isEmpty) {
      await _loadEqualizerBands(notify: false);
    }
    notifyListeners();
  }

  Future<void> setEqualizerBandGain(int index, double gain) async {
    await _effectsController.setEqualizerBandGain(index, gain);
    _equalizerBands = [
      for (final band in _equalizerBands)
        band.index == index ? band.copyWith(gain: gain) : band,
    ];
    notifyListeners();
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

  Future<void> _loadEqualizerBands({bool notify = true}) async {
    _equalizerBands = await _effectsController.getEqualizerBands();
    if (notify) notifyListeners();
  }

  @override
  void dispose() {
    _sub.cancel();
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
