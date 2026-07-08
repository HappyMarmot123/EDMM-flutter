import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../domain/audio/audio_controller.dart';
import '../../../domain/playback/playback_snapshot.dart';

class PlayerViewModel extends ChangeNotifier {
  PlayerViewModel(this._audio) {
    _sub = _audio.snapshot.listen((s) {
      snapshot = s;
      notifyListeners();
    });
    _volume = _audio.volume;
    _mute = _volume <= 0;
    _prevVolume = _volume > 0 ? _volume : 1.0;
    _shuffleEnabled = _audio.isShuffleEnabled;
  }

  final AudioController _audio;
  late final StreamSubscription<PlaybackSnapshot> _sub;
  bool _mute = false;
  double _volume = 1.0;
  double _prevVolume = 1.0;
  bool _shuffleEnabled = false;

  PlaybackSnapshot snapshot = const PlaybackSnapshot();
  Stream<Duration> get position => _audio.position;

  bool get isMuted => _mute;
  double get volume => _volume;
  bool get isShuffleEnabled => _shuffleEnabled;

  Future<void> playPause() => snapshot.isPlaying ? _audio.pause() : _audio.play();
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

  bool get hasError => snapshot.error != null;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}
