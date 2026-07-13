import 'package:flutter/material.dart';

import '../../../domain/models/track.dart';
import '../../../l10n/app_localizations.dart';
import '../view_model/track_detail_view_model.dart';

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
      TrackDetailStatus.loading => const Center(
        child: CircularProgressIndicator(),
      ),
      TrackDetailStatus.notFound => Center(child: Text(l10n.trackNotFound)),
      TrackDetailStatus.error => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.trackDetailLoadError),
            TextButton(onPressed: vm.retry, child: Text(l10n.retry)),
          ],
        ),
      ),
      TrackDetailStatus.data => _buildDetail(context, vm.track!),
    };
  }

  Widget _buildDetail(BuildContext context, Track track) {
    final l10n = AppLocalizations.of(context);
    final metadata = track.metadata.entries.toList(growable: false)
      ..sort((a, b) => a.key.compareTo(b.key));

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Center(
          child: SizedBox.square(
            dimension: 260,
            child: track.artworkUrl.isEmpty
                ? const Icon(Icons.album, size: 160)
                : Image.network(
                    track.artworkUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) =>
                        const Icon(Icons.album, size: 160),
                  ),
          ),
        ),
        const SizedBox(height: 24),
        Text(track.title, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 4),
        Text(
          track.artistName.isEmpty ? l10n.unknownArtist : track.artistName,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              key: const Key('track-detail-play'),
              onPressed: track.isPlayable ? () => widget.onPlay(track) : null,
              icon: const Icon(Icons.play_arrow),
              label: Text(l10n.trackPlay),
            ),
          ],
        ),
        if (widget.viewModel.storageError != null) ...[
          const SizedBox(height: 12),
          Text(
            l10n.localStorageError,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
        const SizedBox(height: 24),
        _DetailRow(
          label: l10n.albumLabel,
          value: track.albumName?.trim().isNotEmpty == true
              ? track.albumName!
              : l10n.unknownAlbum,
        ),
        _DetailRow(label: l10n.sourceLabel, value: track.source),
        _DetailRow(
          label: l10n.durationLabel,
          value: _formatDuration(track.duration),
        ),
        if (metadata.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text(
            l10n.metadataTitle,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          for (final entry in metadata)
            _DetailRow(label: entry.key, value: _formatMetadata(entry.value)),
        ],
      ],
    );
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${duration.inMinutes}:${seconds.toString().padLeft(2, '0')}';
  }

  String _formatMetadata(Object? value) {
    if (value is Iterable) return value.join(', ');
    return value?.toString() ?? '—';
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 112,
          child: Text(label, style: Theme.of(context).textTheme.labelLarge),
        ),
        Expanded(child: SelectableText(value)),
      ],
    ),
  );
}
