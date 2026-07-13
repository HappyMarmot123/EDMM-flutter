import 'package:flutter/material.dart';

import '../../../domain/models/local_library_entities.dart';
import '../../../domain/models/track.dart';
import '../../../l10n/app_localizations.dart';
import '../view_model/library_view_model.dart';
import 'create_playlist_dialog.dart';
import 'local_library_track_tile.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({
    super.key,
    required this.viewModel,
    required this.onPlay,
    required this.onOpenTrack,
    required this.onOpenPlaylist,
  });

  final LibraryViewModel viewModel;
  final void Function(List<Track> queue, int index) onPlay;
  final ValueChanged<String> onOpenTrack;
  final ValueChanged<PlaylistRow> onOpenPlaylist;

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  @override
  void initState() {
    super.initState();
    widget.viewModel.init();
  }

  @override
  void didUpdateWidget(covariant LibraryScreen oldWidget) {
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

  Future<void> _showCreatePlaylistDialog() async {
    final name = await showCreatePlaylistDialog(
      context,
      fieldKey: const Key('playlist-name-field'),
      confirmKey: const Key('playlist-create-confirm'),
    );
    if (name == null || !mounted) return;
    await widget.viewModel.createPlaylist(name);
  }

  Future<void> _confirmDeletePlaylist(PlaylistRow playlist) async {
    final id = playlist.id;
    if (id == null) return;
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.playlistDelete),
        content: Text(playlist.name),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.playlistDelete),
          ),
        ],
      ),
    );
    if (confirmed == true) await widget.viewModel.deletePlaylist(id);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.libraryTitle),
        actions: [
          IconButton(
            key: const Key('playlist-create-button'),
            tooltip: l10n.playlistCreate,
            onPressed: _showCreatePlaylistDialog,
            icon: const Icon(Icons.playlist_add),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: widget.viewModel,
        builder: (context, _) => _buildBody(context),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final vm = widget.viewModel;
    if (vm.status == LibraryStatus.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (vm.status == LibraryStatus.storageError) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.libraryStorageError),
            TextButton(onPressed: vm.refresh, child: Text(l10n.retry)),
          ],
        ),
      );
    }

    return CustomScrollView(
      key: const Key('library-scroll'),
      slivers: [
        SliverToBoxAdapter(child: _SectionHeader(title: l10n.favoritesTitle)),
        if (vm.favorites.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
              child: Text(l10n.favoritesEmpty),
            ),
          )
        else
          SliverList(
            key: const Key('library-favorites-list'),
            delegate: SliverChildBuilderDelegate(
              (context, index) => _buildFavorite(vm, index),
              childCount: vm.favorites.length,
            ),
          ),
        SliverToBoxAdapter(child: _SectionHeader(title: l10n.playlistsTitle)),
        if (vm.playlists.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
              child: Text(l10n.playlistsEmpty),
            ),
          )
        else
          SliverList(
            key: const Key('library-playlists-list'),
            delegate: SliverChildBuilderDelegate(
              (context, index) =>
                  _buildPlaylistTile(context, vm.playlists[index]),
              childCount: vm.playlists.length,
            ),
          ),
      ],
    );
  }

  Widget _buildFavorite(LibraryViewModel vm, int index) {
    final item = vm.favorites[index];
    return LocalLibraryTrackTile(
      item: item,
      onOpenTrack: () => widget.onOpenTrack(item.trackId),
      onPlay: item.isPlayable
          ? () {
              final selection = vm.playbackSelectionForFavorite(item.trackId);
              if (selection != null) {
                widget.onPlay(selection.queue, selection.index);
              }
            }
          : null,
      playButtonKey: Key('library-favorite-play-${item.trackId}'),
    );
  }

  Widget _buildPlaylistTile(BuildContext context, PlaylistRow playlist) {
    final l10n = AppLocalizations.of(context);
    return ListTile(
      title: Text(playlist.name),
      leading: const Icon(Icons.queue_music),
      onTap: playlist.id == null ? null : () => widget.onOpenPlaylist(playlist),
      trailing: IconButton(
        key: Key('playlist-delete-${playlist.id}'),
        tooltip: l10n.playlistDelete,
        onPressed: playlist.id == null
            ? null
            : () => _confirmDeletePlaylist(playlist),
        icon: const Icon(Icons.delete_outline),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
    child: Text(title, style: Theme.of(context).textTheme.titleLarge),
  );
}
