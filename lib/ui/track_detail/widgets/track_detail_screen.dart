import 'package:flutter/material.dart';

import '../../../domain/models/track.dart';
import '../../../l10n/app_localizations.dart';
import '../../core/themes/edmm_theme_tokens.dart';
import '../../core/widgets/edmm_content_layout.dart';
import '../../core/widgets/edmm_state_view.dart';
import '../view_model/track_detail_view_model.dart';
import 'track_detail_content.dart';

class TrackDetailScreen extends StatefulWidget {
  const TrackDetailScreen({
    super.key,
    required this.viewModel,
    required this.onPlay,
  });

  final TrackDetailViewModel viewModel;
  final ValueChanged<Track> onPlay;

  @override
  State<TrackDetailScreen> createState() => _TrackDetailScreenState();
}

class _TrackDetailScreenState extends State<TrackDetailScreen> {
  @override
  void initState() {
    super.initState();
    widget.viewModel.init();
  }

  @override
  void didUpdateWidget(covariant TrackDetailScreen oldWidget) {
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
    return Scaffold(
      appBar: AppBar(title: Text(l10n.trackDetailsTitle)),
      body: ListenableBuilder(
        listenable: widget.viewModel,
        builder: (context, _) => _buildBody(context),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final vm = widget.viewModel;
    return switch (vm.status) {
      TrackDetailStatus.loading => _DetailState(
        kind: EdmmStateKind.loading,
        title: l10n.trackDetailsTitle,
      ),
      TrackDetailStatus.notFound => _DetailState(
        kind: EdmmStateKind.empty,
        title: l10n.trackNotFound,
      ),
      TrackDetailStatus.error => _DetailState(
        kind: EdmmStateKind.error,
        title: l10n.trackDetailLoadError,
        actionLabel: l10n.retry,
        onAction: vm.retry,
      ),
      TrackDetailStatus.data => TrackDetailContent(
        track: vm.track!,
        storageError: vm.storageError,
        onPlay: widget.onPlay,
      ),
    };
  }
}

class _DetailState extends StatelessWidget {
  const _DetailState({
    required this.kind,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  final EdmmStateKind kind;
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return EdmmContentLayout(
      width: EdmmContentWidth.standard,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: EdmmSpacing.xl),
        child: EdmmStateView(
          kind: kind,
          title: title,
          actionLabel: actionLabel,
          onAction: onAction,
        ),
      ),
    );
  }
}
