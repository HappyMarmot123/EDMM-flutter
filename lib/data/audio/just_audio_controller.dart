// lib/data/audio/just_audio_controller.dart
import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import '../../domain/audio/audio_controller.dart';
import '../../domain/models/track.dart' as domain;
import '../../domain/playback/playback_snapshot.dart';
import '../../domain/result.dart';
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
  PlaybackSnapshot _latestSnapshot = const PlaybackSnapshot();
  bool _shuffleEnabled = false;
  double _volume = 1.0;

  @override
  Stream<PlaybackSnapshot> get snapshot async* {
    yield _latestSnapshot;
    yield* _snapshotController.stream;
  }

  @override
  Stream<Duration> get position => _positionController.stream;

  @override
  bool get isShuffleEnabled => _shuffleEnabled;

  @override
  double get volume => _volume;

  @override
  Future<void> loadQueue(List<domain.Track> tracks,
      {int initialIndex = 0}) async {
    final playable = <({domain.Track track, Uri uri, int originalIndex})>[];
    for (var i = 0; i < tracks.length; i++) {
      final uri = streamUriForTrack(tracks[i]);
      if (uri != null) {
        playable.add((track: tracks[i], uri: uri, originalIndex: i));
      }
    }

    if (playable.isEmpty) {
      _tracks = const [];
      queue.add(const []);
      mediaItem.add(null);
      _emitError(const ParseFailure('No playable tracks'));
      return;
    }

    var mappedInitialIndex =
        playable.indexWhere((entry) => entry.originalIndex == initialIndex);
    if (mappedInitialIndex < 0) {
      mappedInitialIndex =
          playable.indexWhere((entry) => entry.originalIndex > initialIndex);
    }
    if (mappedInitialIndex < 0) mappedInitialIndex = 0;

    _tracks = [for (final entry in playable) entry.track];
    queue.add(_tracks.map(toMediaItem).toList());
    try {
      await _player.setAudioSources(
        [for (final entry in playable) AudioSource.uri(entry.uri)],
        initialIndex: mappedInitialIndex,
      );
      _updateMediaItem(mappedInitialIndex);
      _emitSnapshot();
    } catch (e) {
      _emitError(ParseFailure(e));
    }
  }

  @override
  Future<void> setShuffleEnabled(bool enabled) =>
      _guard(() async {
        await _player.setShuffleModeEnabled(enabled);
        _shuffleEnabled = enabled;
        if (enabled) {
          await _player.shuffle();
        }
      });

  @override
  Future<void> setVolume(double volume) => _guard(() async {
        final clamped = volume.clamp(0.0, 1.0).toDouble();
        _volume = clamped;
        await _player.setVolume(clamped);
      });

  @override
  Future<void> setMute(bool muted) => setVolume(muted ? 0.0 : 1.0);

  @override
  Future<void> play() => _guard(_player.play);
  @override
  Future<void> pause() => _guard(_player.pause);
  @override
  Future<void> seek(Duration position) => _guard(() => _player.seek(position));
  @override
  Future<void> next() => _guard(_player.seekToNext);
  @override
  Future<void> previous() => _guard(_player.seekToPrevious);

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
    _setSnapshot(PlaybackSnapshot(
      currentTrack: current,
      status: mapProcessingState(_player.processingState, _player.playing),
      duration: _player.duration ?? Duration.zero,
      queueIndex: index,
      hasNext: _player.hasNext,
      hasPrevious: _player.hasPrevious,
    ));
  }

  void _emitError(Failure error) {
    _setSnapshot(PlaybackSnapshot(status: PlaybackStatus.error, error: error));
  }

  void _setSnapshot(PlaybackSnapshot snapshot) {
    _latestSnapshot = snapshot;
    if (!_snapshotController.isClosed) {
      _snapshotController.add(snapshot);
    }
  }

  Future<void> _guard(Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      _emitError(ParseFailure(e));
    }
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
