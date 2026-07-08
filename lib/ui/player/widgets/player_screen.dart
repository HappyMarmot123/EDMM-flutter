import 'package:flutter/material.dart';

import '../../../domain/playback/playback_snapshot.dart';
import '../../../domain/result.dart';
import '../../../l10n/app_localizations.dart';
import '../view_model/player_view_model.dart';

class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key, required this.viewModel});
  final PlayerViewModel viewModel;

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  bool _expanded = true;
  bool _eqEnabled = false;
  bool _visualizerEnabled = false;

  @override
  void dispose() {
    widget.viewModel.dispose();
    super.dispose();
  }

  String _fmt(Duration d) =>
      '${d.inMinutes.toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  IconData _volumeIcon(PlayerViewModel vm) {
    if (vm.isMuted || vm.volume <= 0) return Icons.volume_off;
    if (vm.volume < 0.5) return Icons.volume_down;
    return Icons.volume_up;
  }

  String _statusText(PlaybackStatus status) => switch (status) {
    PlaybackStatus.idle => 'idle',
    PlaybackStatus.loading => 'loading',
    PlaybackStatus.ready => 'ready',
    PlaybackStatus.playing => 'playing',
    PlaybackStatus.paused => 'paused',
    PlaybackStatus.completed => 'completed',
    PlaybackStatus.error => 'error',
  };

  String _errorText(Failure failure) => switch (failure) {
    NetworkFailure() => 'Network issue while loading audio',
    ServerFailure(:final statusCode) => 'Server error ($statusCode)',
    ParseFailure() => 'Playback data is invalid',
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.nowPlaying),
        actions: [
          IconButton(
            icon: Icon(_expanded ? Icons.expand_more : Icons.expand_less),
            key: const Key('player-expand-toggle'),
            onPressed: () {
              setState(() => _expanded = !_expanded);
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListenableBuilder(
          listenable: widget.viewModel,
          builder: (context, _) {
            final vm = widget.viewModel;
            final track = vm.snapshot.currentTrack;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (vm.hasError)
                MaterialBanner(
                    backgroundColor: Theme.of(context).colorScheme.errorContainer,
                    content: Text(_errorText(vm.snapshot.error!)),
                    actions: [
                      TextButton(
                        onPressed: () {},
                        child: const Text('Dismiss'),
                      ),
                    ],
                  ),
                if (track == null)
                  const Expanded(
                    child: Center(child: Text('No track loaded')),
                  )
                else if (!_expanded)
                  Expanded(child: _buildMiniBody(vm, l10n))
                else
                  Expanded(child: _buildExpandedBody(vm, l10n)),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildExpandedBody(PlayerViewModel vm, AppLocalizations l10n) {
    final track = vm.snapshot.currentTrack!;

    return Column(
      children: [
        Text(_statusText(vm.snapshot.status), style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 12),
        Expanded(
          child: Center(
            child: track.artworkUrl.isNotEmpty
                ? Image.network(
                    track.artworkUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => const Icon(Icons.album, size: 160),
                  )
                : const Icon(Icons.album, size: 160),
          ),
        ),
        Text(track.title, style: Theme.of(context).textTheme.titleLarge),
        Text(track.artistName.isEmpty ? l10n.unknownArtist : track.artistName),
        const SizedBox(height: 16),
        StreamBuilder<Duration>(
          stream: vm.position,
          builder: (context, snap) {
            final pos = snap.data ?? Duration.zero;
            final total = vm.snapshot.duration.inMilliseconds == 0
                ? 1
                : vm.snapshot.duration.inMilliseconds;
            return Column(
              children: [
                Slider(
                  key: const Key('player-progress-slider'),
                  value: pos.inMilliseconds.clamp(0, total).toDouble(),
                  max: total.toDouble(),
                  onChanged: (value) => vm.seek(Duration(milliseconds: value.round())),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_fmt(pos)),
                    Text(_fmt(vm.snapshot.duration)),
                  ],
                ),
              ],
            );
          },
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              key: const Key('player-shuffle-button'),
              iconSize: 38,
              icon: Icon(
                vm.isShuffleEnabled ? Icons.shuffle_on : Icons.shuffle,
                color: vm.isShuffleEnabled ? Theme.of(context).colorScheme.primary : null,
              ),
              onPressed: vm.toggleShuffle,
            ),
            const SizedBox(width: 8),
            IconButton(
              iconSize: 36,
              icon: const Icon(Icons.skip_previous),
              onPressed: vm.previous,
            ),
            IconButton(
              iconSize: 56,
              icon: Icon(vm.snapshot.isPlaying ? Icons.pause : Icons.play_arrow),
              onPressed: vm.playPause,
            ),
            IconButton(
              iconSize: 36,
              icon: const Icon(Icons.skip_next),
              onPressed: vm.next,
            ),
            const SizedBox(width: 8),
            IconButton(
              key: const Key('player-eq-toggle'),
              iconSize: 28,
              icon: Icon(_eqEnabled ? Icons.tune : Icons.tune_outlined),
              onPressed: () => setState(() => _eqEnabled = !_eqEnabled),
            ),
            IconButton(
              key: const Key('player-visualizer-toggle'),
              iconSize: 28,
              icon: Icon(
                _visualizerEnabled ? Icons.graphic_eq : Icons.bar_chart_outlined,
              ),
              onPressed: () => setState(() => _visualizerEnabled = !_visualizerEnabled),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            IconButton(
              key: const Key('player-volume-mute-button'),
              icon: Icon(_volumeIcon(vm)),
              onPressed: vm.toggleMute,
            ),
            Expanded(
              child: Slider(
                key: const Key('player-volume-slider'),
                value: vm.volume,
                min: 0,
                max: 1,
                onChanged: vm.setVolume,
              ),
            ),
            Text('${(vm.volume * 100).round()}%'),
          ],
        ),
        if (_eqEnabled || _visualizerEnabled)
          Text(
            'EQ / visualizer scope toggled',
            style: Theme.of(context).textTheme.bodySmall,
          ),
      ],
    );
  }

  Widget _buildMiniBody(PlayerViewModel vm, AppLocalizations l10n) {
    final track = vm.snapshot.currentTrack!;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            if (track.artworkUrl.isNotEmpty)
              Image.network(
                track.artworkUrl,
                width: 72,
                height: 72,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => const Icon(Icons.music_note),
              )
            else
              const Icon(Icons.music_note, size: 72),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(track.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(
                    track.artistName.isEmpty ? l10n.unknownArtist : track.artistName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            IconButton(
              key: const Key('player-mini-volume-mute'),
              icon: Icon(vm.isMuted ? Icons.volume_off : Icons.volume_up),
              onPressed: vm.toggleMute,
            ),
            IconButton(
              icon: Icon(vm.snapshot.isPlaying ? Icons.pause : Icons.play_arrow),
              onPressed: vm.playPause,
              iconSize: 36,
            ),
          ],
        ),
      ),
    );
  }
}
