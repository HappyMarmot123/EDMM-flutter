import 'package:flutter/material.dart';

import '../../../domain/models/track.dart';
import '../../../l10n/app_localizations.dart';
import '../view_model/catalog_search_view_model.dart';
import '../../player/view_model/player_view_model.dart';
import '../../player/widgets/player_mini_bar.dart';

class CatalogSearchScreen extends StatefulWidget {
  const CatalogSearchScreen({
    super.key,
    required this.viewModel,
    required this.onPlay,
    this.playerViewModel,
    this.onOpenPlayer,
  });

  final CatalogSearchViewModel viewModel;
  final void Function(List<Track> queue, int index) onPlay;
  final PlayerViewModel? playerViewModel;
  final VoidCallback? onOpenPlayer;

  @override
  State<CatalogSearchScreen> createState() => _CatalogSearchScreenState();
}

class _CatalogSearchScreenState extends State<CatalogSearchScreen> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    widget.viewModel.init();
  }

  @override
  void didUpdateWidget(covariant CatalogSearchScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // initState does NOT run again, so the new view model must be initialized here — or the
    // list stays stuck on its initial `loading` status when we return to it.
    if (!identical(oldWidget.viewModel, widget.viewModel)) {
      oldWidget.viewModel.dispose();
      widget.viewModel.init();
    }
    if (!identical(oldWidget.playerViewModel, widget.playerViewModel)) {
      oldWidget.playerViewModel?.dispose();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    widget.viewModel.dispose();
    widget.playerViewModel?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.trackListTitle)),
      bottomNavigationBar: widget.playerViewModel == null
          ? null
          : PlayerMiniBar(
              viewModel: widget.playerViewModel!,
              onOpenPlayer: widget.onOpenPlayer,
            ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(hintText: l10n.searchHint),
                  onChanged: widget.viewModel.setQuery,
                ),
                const SizedBox(height: 12),
                ListenableBuilder(
                  listenable: widget.viewModel,
                  builder: (context, _) {
                    final counts = widget.viewModel.counts;
                    return Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () =>
                                widget.viewModel.setView(CatalogView.pop),
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  widget.viewModel.view == CatalogView.pop
                                  ? Theme.of(
                                      context,
                                    ).colorScheme.primaryContainer
                                  : null,
                            ),
                            child: FittedBox(
                              child: Text(
                                '${l10n.tabPop} (${counts[CatalogView.pop] ?? 0})',
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () =>
                                widget.viewModel.setView(CatalogView.edm),
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  widget.viewModel.view == CatalogView.edm
                                  ? Theme.of(
                                      context,
                                    ).colorScheme.primaryContainer
                                  : null,
                            ),
                            child: FittedBox(
                              child: Text(
                                '${l10n.tabEdm} (${counts[CatalogView.edm] ?? 0})',
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () =>
                                widget.viewModel.setView(CatalogView.recent),
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  widget.viewModel.view == CatalogView.recent
                                  ? Theme.of(
                                      context,
                                    ).colorScheme.primaryContainer
                                  : null,
                            ),
                            child: FittedBox(
                              child: Text(
                                '${l10n.tabRecent} (${counts[CatalogView.recent] ?? 0})',
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: ListenableBuilder(
              listenable: widget.viewModel,
              builder: (context, _) {
                return _buildBody(context, widget.viewModel);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context, CatalogSearchViewModel vm) {
    final l10n = AppLocalizations.of(context);

    if (vm.status == CatalogStatus.loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (vm.status == CatalogStatus.error && vm.tracks.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.tracksLoadError),
            TextButton(onPressed: vm.retry, child: Text(l10n.retry)),
          ],
        ),
      );
    }

    if (vm.status == CatalogStatus.empty) {
      return Center(child: Text(l10n.tracksEmpty));
    }

    if (vm.status == CatalogStatus.searchEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.searchNoResults),
            TextButton(
              onPressed: vm.clearSearch,
              child: Text(l10n.clearSearch),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (vm.status == CatalogStatus.error)
          MaterialBanner(
            content: Text(l10n.catalogStaleWarning),
            actions: [TextButton(onPressed: vm.retry, child: Text(l10n.retry))],
          ),
        Expanded(child: _buildList(vm)),
      ],
    );
  }

  Widget _buildList(CatalogSearchViewModel vm) {
    return ListView.builder(
      itemCount: vm.tracks.length,
      itemBuilder: (context, index) {
        final l10n = AppLocalizations.of(context);
        final track = vm.tracks[index];
        final isCurrent = track.id == vm.currentTrackId;
        final isSeedSelected = track.id == vm.selectedTrackId && !isCurrent;
        final tileColor = isCurrent
            ? Theme.of(context).colorScheme.primaryContainer
            : isSeedSelected
            ? Theme.of(context).colorScheme.secondaryContainer
            : null;

        return ListTile(
          tileColor: tileColor,
          leading: track.artworkUrl.isEmpty
              ? const Icon(Icons.music_note)
              : Image.network(
                  track.artworkUrl,
                  width: 48,
                  height: 48,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const Icon(Icons.music_note),
                ),
          title: Text(track.title),
          subtitle: Text(
            track.artistName.isEmpty ? l10n.unknownArtist : track.artistName,
          ),
          trailing: isCurrent && vm.isCurrentPlaying
              ? const Icon(Icons.volume_up)
              : null,
          onTap: () => widget.onPlay(vm.tracks, index),
        );
      },
    );
  }
}
