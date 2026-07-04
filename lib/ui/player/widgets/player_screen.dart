import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';
import '../view_model/player_view_model.dart';

class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key, required this.viewModel});
  final PlayerViewModel viewModel;

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  @override
  void dispose() {
    widget.viewModel.dispose();
    super.dispose();
  }

  String _fmt(Duration d) =>
      '${d.inMinutes.toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.nowPlaying)),
      body: ListenableBuilder(
        listenable: widget.viewModel,
        builder: (context, _) {
          final s = widget.viewModel.snapshot;
          final track = s.currentTrack;
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  child: Center(
                    child: (track != null && track.artworkUrl.isNotEmpty)
                        ? Image.network(track.artworkUrl,
                            errorBuilder: (_, _, _) => const Icon(Icons.album, size: 160))
                        : const Icon(Icons.album, size: 160),
                  ),
                ),
                Text(track?.title ?? '', style: Theme.of(context).textTheme.titleLarge),
                Text(track?.artistName ?? l10n.unknownArtist),
                const SizedBox(height: 16),
                StreamBuilder<Duration>(
                  stream: widget.viewModel.position,
                  builder: (context, snap) {
                    final pos = snap.data ?? Duration.zero;
                    final total = s.duration.inMilliseconds == 0 ? 1 : s.duration.inMilliseconds;
                    return Column(children: [
                      Slider(
                        value: pos.inMilliseconds.clamp(0, total).toDouble(),
                        max: total.toDouble(),
                        onChanged: (v) =>
                            widget.viewModel.seek(Duration(milliseconds: v.round())),
                      ),
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Text(_fmt(pos)),
                        Text(_fmt(s.duration)),
                      ]),
                    ]);
                  },
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(iconSize: 40, icon: const Icon(Icons.skip_previous),
                        onPressed: widget.viewModel.previous),
                    IconButton(
                      iconSize: 56,
                      icon: Icon(s.isPlaying ? Icons.pause : Icons.play_arrow),
                      onPressed: widget.viewModel.playPause,
                    ),
                    IconButton(iconSize: 40, icon: const Icon(Icons.skip_next),
                        onPressed: widget.viewModel.next),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
