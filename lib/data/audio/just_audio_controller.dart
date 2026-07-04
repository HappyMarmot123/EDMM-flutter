// lib/data/audio/just_audio_controller.dart
import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import '../../domain/audio/audio_controller.dart';
import '../../domain/models/track.dart' as domain;
import '../../domain/playback/playback_snapshot.dart';
import 'playback_mapping.dart';

class JustAudioController extends BaseAudioHandler
    with QueueHandler, SeekHandler
    implements AudioController {
  JustAudioController() {
    _subs.add(_player.playbackEventStream.listen(_broadcastState));
    _subs.add(_player.positionStream.listen(_positionController.add));
    _subs.add(_player.durationStream.listen((_) => _emitSnapshot()));
    _subs.add(_player.currentIndexStream.listen((index) {
      _updateMediaItem(index);
      _emitSnapshot();
    }));
    _subs.add(_player.playerStateStream.listen((_) => _emitSnapshot()));
  }

  final AudioPlayer _player = AudioPlayer();
  final _snapshotController = StreamController<PlaybackSnapshot>.broadcast();
  final _positionController = StreamController<Duration>.broadcast();
  final List<StreamSubscription<dynamic>> _subs = [];
  List<domain.Track> _tracks = const [];

  @override
  Stream<PlaybackSnapshot> get snapshot => _snapshotController.stream;
  @override
  Stream<Duration> get position => _positionController.stream;

  @override
  Future<void> loadQueue(List<domain.Track> tracks,
      {int initialIndex = 0}) async {
    _tracks = tracks;
    queue.add(tracks.map(toMediaItem).toList());
    await _player.setAudioSources(
      [
        for (final t in tracks)
          AudioSource.uri(Uri.parse(t.streamUrl ?? '')),
      ],
      initialIndex: initialIndex,
    );
    _updateMediaItem(initialIndex);
    _emitSnapshot();
  }

  @override
  Future<void> play() => _player.play();
  @override
  Future<void> pause() => _player.pause();
  @override
  Future<void> seek(Duration position) => _player.seek(position);
  @override
  Future<void> next() => _player.seekToNext();
  @override
  Future<void> previous() => _player.seekToPrevious();

  // OS media-control overrides (lock screen, Bluetooth, notification)
  @override
  Future<void> skipToNext() => _player.seekToNext();
  @override
  Future<void> skipToPrevious() => _player.seekToPrevious();
  @override
  Future<void> skipToQueueItem(int index) =>
      _player.seek(Duration.zero, index: index);

  @override
  Future<void> dispose() async {
    for (final s in _subs) {
      await s.cancel();
    }
    await _player.dispose();
    await _snapshotController.close();
    await _positionController.close();
  }

  void _updateMediaItem(int? index) {
    final q = queue.value;
    if (index != null && index >= 0 && index < q.length) {
      mediaItem.add(q[index]);
    }
  }

  void _emitSnapshot() {
    final index = _player.currentIndex;
    final current = (index != null && index >= 0 && index < _tracks.length)
        ? _tracks[index]
        : null;
    _snapshotController.add(PlaybackSnapshot(
      currentTrack: current,
      status: mapProcessingState(_player.processingState, _player.playing),
      duration: _player.duration ?? Duration.zero,
      queueIndex: index,
      hasNext: _player.hasNext,
      hasPrevious: _player.hasPrevious,
    ));
  }

  void _broadcastState(PlaybackEvent event) {
    playbackState.add(playbackState.value.copyWith(
      controls: [
        MediaControl.skipToPrevious,
        if (_player.playing) MediaControl.pause else MediaControl.play,
        MediaControl.skipToNext,
      ],
      systemActions: const {MediaAction.seek},
      processingState: const {
        ProcessingState.idle: AudioProcessingState.idle,
        ProcessingState.loading: AudioProcessingState.loading,
        ProcessingState.buffering: AudioProcessingState.buffering,
        ProcessingState.ready: AudioProcessingState.ready,
        ProcessingState.completed: AudioProcessingState.completed,
      }[_player.processingState]!,
      playing: _player.playing,
      updatePosition: _player.position,
      queueIndex: event.currentIndex,
    ));
  }
}
