import 'package:flutter/material.dart';

import '../../../domain/models/track.dart';
import '../../../l10n/app_localizations.dart';
import '../../core/widgets/edmm_ambient_backdrop.dart';
import '../../core/widgets/edmm_content_layout.dart';
import '../../core/widgets/edmm_state_view.dart';
import '../view_model/catalog_search_view_model.dart';
import 'catalog_header.dart';
import 'catalog_track_list.dart';

class CatalogSearchScreen extends StatefulWidget {
  const CatalogSearchScreen({
    super.key,
    required this.viewModel,
    required this.onPlay,
    this.onOpenTrack,
  });

  final CatalogSearchViewModel viewModel;
  final void Function(List<Track> queue, int index) onPlay;
  final ValueChanged<Track>? onOpenTrack;

  @override
  State<CatalogSearchScreen> createState() => _CatalogSearchScreenState();
}

class _CatalogSearchScreenState extends State<CatalogSearchScreen> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.viewModel.query);
    widget.viewModel.init();
  }

  @override
  void didUpdateWidget(covariant CatalogSearchScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.viewModel, widget.viewModel)) {
      oldWidget.viewModel.dispose();
      _syncSearchController(widget.viewModel.query);
      widget.viewModel.init();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    widget.viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      body: EdmmAmbientBackdrop(
        variant: EdmmAmbientBackdropVariant.catalogEdge,
        child: SafeArea(
          bottom: false,
          child: EdmmContentLayout(
            width: EdmmContentWidth.standard,
            child: ListenableBuilder(
              listenable: widget.viewModel,
              builder: (context, _) {
                final vm = widget.viewModel;
                return Column(
                  children: <Widget>[
                    CatalogHeader(
                      appTitle: l10n.appTitle,
                      screenTitle: l10n.trackListTitle,
                      searchLabel: l10n.searchHint,
                      searchController: _searchController,
                      onQueryChanged: vm.setQuery,
                      popLabel: l10n.tabPop,
                      popCount: vm.counts[CatalogView.pop] ?? 0,
                      popSelected: vm.view == CatalogView.pop,
                      onPopSelected: () => vm.setView(CatalogView.pop),
                      edmLabel: l10n.tabEdm,
                      edmCount: vm.counts[CatalogView.edm] ?? 0,
                      edmSelected: vm.view == CatalogView.edm,
                      onEdmSelected: () => vm.setView(CatalogView.edm),
                      recentLabel: l10n.tabRecent,
                      recentCount: vm.counts[CatalogView.recent] ?? 0,
                      recentSelected: vm.view == CatalogView.recent,
                      onRecentSelected: () => vm.setView(CatalogView.recent),
                    ),
                    Expanded(child: _buildBody(context, vm)),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, CatalogSearchViewModel vm) {
    final l10n = AppLocalizations.of(context);

    if (vm.status == CatalogStatus.loading) {
      return EdmmStateView(
        kind: EdmmStateKind.loading,
        title: l10n.catalogLoading,
      );
    }
    if (vm.status == CatalogStatus.error && vm.tracks.isEmpty) {
      return EdmmStateView(
        kind: EdmmStateKind.error,
        title: l10n.tracksLoadError,
        actionLabel: l10n.retry,
        onAction: vm.retry,
      );
    }
    if (vm.status == CatalogStatus.empty) {
      return EdmmStateView(kind: EdmmStateKind.empty, title: l10n.tracksEmpty);
    }
    if (vm.status == CatalogStatus.searchEmpty) {
      return EdmmStateView(
        kind: EdmmStateKind.searchEmpty,
        title: l10n.searchNoResults,
        actionLabel: l10n.clearSearch,
        onAction: _clearSearch,
      );
    }

    return CatalogTrackList(
      tracks: vm.tracks,
      currentTrackId: vm.currentTrackId,
      selectedTrackId: vm.selectedTrackId,
      isCurrentPlaying: vm.isCurrentPlaying,
      unknownArtistLabel: l10n.unknownArtist,
      currentPlayingSemanticLabel: l10n.trackStatePlaying,
      currentPausedSemanticLabel: l10n.trackStatePaused,
      unplayableSemanticLabel: l10n.trackStateUnavailable,
      detailsLabel: l10n.openTrackDetails,
      onPlay: widget.onPlay,
      onOpenTrack: widget.onOpenTrack,
      header: vm.status == CatalogStatus.error
          ? MaterialBanner(
              forceActionsBelow: true,
              content: Text(l10n.catalogStaleWarning),
              actions: <Widget>[
                TextButton(onPressed: vm.retry, child: Text(l10n.retry)),
              ],
            )
          : null,
    );
  }

  void _clearSearch() {
    _syncSearchController('');
    widget.viewModel.clearSearch();
  }

  void _syncSearchController(String value) {
    _searchController.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
  }
}
