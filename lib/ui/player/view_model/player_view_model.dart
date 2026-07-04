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
  }

  final AudioController _audio;
  late final StreamSubscription<PlaybackSnapshot> _sub;

  PlaybackSnapshot snapshot = const PlaybackSnapshot();
  Stream<Duration> get position => _audio.position;

  Future<void> playPause() => snapshot.isPlaying ? _audio.pause() : _audio.play();
  Future<void> seek(Duration to) => _audio.seek(to);
  Future<void> next() => _audio.next();
  Future<void> previous() => _audio.previous();

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}
