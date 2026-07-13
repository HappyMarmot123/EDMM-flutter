import 'package:flutter/material.dart';

import '../../../domain/models/track.dart';
import '../../../l10n/app_localizations.dart';
import '../view_model/playlist_detail_view_model.dart';
import 'local_library_track_tile.dart';

class PlaylistDetailScreen extends StatefulWidget {
  const PlaylistDetailScreen({
    super.key,
    required this.viewModel,
    required this.onPlay,
    required this.onOpenTrack,
  });

  final PlaylistDetailViewModel viewModel;
  final void Function(List<Track> queue, int index) onPlay;
  final ValueChanged<String> onOpenTrack;

  @override
  State<PlaylistDetailScreen> createState() => _PlaylistDetailScreenState();
}

class _PlaylistDetailScreenState extends State<PlaylistDetailScreen> {
  @override
  void initState() {
    super.initState();
    widget.viewModel.init();
  }

  @override
  void didUpdateWidget(covariant PlaylistDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.viewModel, widget.viewModel)) {
      oldWidget.viewModel.dispose();
      widget.viewModel.init();
    }
  }

  @override
  void dispose() {
    widget.viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListenableBuilder(
      listenable: widget.viewModel,
      builder: (context, _) => Scaffold(
        appBar: AppBar(
          title: Text(widget.viewModel.playlist?.name ?? l10n.playlistsTitle),
        ),
        body: _buildBody(context),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final vm = widget.viewModel;
    return switch (vm.status) {
      PlaylistDetailStatus.loading => const Center(
        child: CircularProgressIndicator(),
      ),
      PlaylistDetailStatus.storageError => _MessageWithRetry(
        message: l10n.libraryStorageError,
        retryLabel: l10n.retry,
        onRetry: vm.refresh,
      ),
      PlaylistDetailStatus.notFound => Center(
        child: Text(l10n.playlistNotFound),
      ),
      PlaylistDetailStatus.empty => Center(
        child: Text(l10n.playlistTracksEmpty),
      ),
      PlaylistDetailStatus.data => ListView.builder(
        key: const Key('playlist-detail-list'),
        itemCount: vm.items.length,
        itemBuilder: (context, index) {
          final item = vm.items[index];
          return LocalLibraryTrackTile(
            item: item,
            onOpenTrack: () => widget.onOpenTrack(item.trackId),
            onPlay: item.isPlayable
                ? () {
                    final selection = vm.playbackSelectionFor(item.trackId);
                    if (selection != null) {
                      widget.onPlay(selection.queue, selection.index);
                    }
                  }
                : null,
            onRemove: () => vm.removeTrack(item.trackId),
            playButtonKey: Key('playlist-track-play-${item.trackId}'),
          );
        },
      ),
    };
  }
}

class _MessageWithRetry extends StatelessWidget {
  const _MessageWithRetry({
    required this.message,
    required this.retryLabel,
    required this.onRetry,
  });

  final String message;
  final String retryLabel;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(message),
        TextButton(onPressed: onRetry, child: Text(retryLabel)),
      ],
    ),
  );
}
