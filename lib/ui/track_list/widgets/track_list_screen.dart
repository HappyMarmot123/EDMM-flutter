import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';
import '../../../domain/models/track.dart';
import '../view_model/track_list_view_model.dart';

class TrackListScreen extends StatefulWidget {
  const TrackListScreen({super.key, required this.viewModel, required this.onPlay});
  final TrackListViewModel viewModel;
  final void Function(List<Track> queue, int index) onPlay;

  @override
  State<TrackListScreen> createState() => _TrackListScreenState();
}

class _TrackListScreenState extends State<TrackListScreen> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.trackListTitle)),
      body: ListenableBuilder(
        listenable: widget.viewModel,
        builder: (context, _) {
          final vm = widget.viewModel;
          switch (vm.status) {
            case TrackListStatus.loading:
              return const Center(child: CircularProgressIndicator());
            case TrackListStatus.empty:
              return Center(child: Text(l10n.tracksEmpty));
            case TrackListStatus.error:
              return Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(l10n.tracksLoadError),
                  TextButton(
                    onPressed: () => vm.load(forceRefresh: true),
                    child: Text(l10n.retry),
                  ),
                ]),
              );
            case TrackListStatus.data:
              return ListView.builder(
                itemCount: vm.tracks.length,
                itemBuilder: (context, i) {
                  final t = vm.tracks[i];
                  return ListTile(
                    leading: t.artworkUrl.isEmpty
                        ? const Icon(Icons.music_note)
                        : Image.network(t.artworkUrl, width: 48, height: 48,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => const Icon(Icons.music_note)),
                    title: Text(t.title),
                    subtitle: Text(t.artistName),
                    onTap: () => widget.onPlay(vm.tracks, i),
                  );
                },
              );
          }
        },
      ),
    );
  }
}
