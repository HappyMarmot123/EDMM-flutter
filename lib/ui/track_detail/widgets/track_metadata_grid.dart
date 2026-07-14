import 'package:flutter/material.dart';

import '../../core/layout/edmm_breakpoints.dart';
import '../../core/themes/edmm_theme_extensions.dart';
import '../../core/themes/edmm_theme_tokens.dart';
import '../../core/widgets/edmm_surface.dart';

@immutable
class TrackMetadataItem {
  const TrackMetadataItem({required this.label, required this.value});

  final String label;
  final String value;
}

class TrackMetadataGrid extends StatelessWidget {
  const TrackMetadataGrid({super.key, required this.items});

  final List<TrackMetadataItem> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : EdmmBreakpoints.standardContentMaxWidth;
        final columnCount = availableWidth >= EdmmBreakpoints.mediumMinWidth
            ? 2
            : 1;
        final itemWidth = columnCount == 1
            ? availableWidth
            : (availableWidth - EdmmSpacing.md) / columnCount;

        return Wrap(
          spacing: EdmmSpacing.md,
          runSpacing: EdmmSpacing.md,
          children: <Widget>[
            for (final item in items)
              SizedBox(
                width: itemWidth,
                child: _TrackMetadataTile(item: item),
              ),
          ],
        );
      },
    );
  }
}

class _TrackMetadataTile extends StatelessWidget {
  const _TrackMetadataTile({required this.item});

  final TrackMetadataItem item;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).edmm;
    return EdmmSurface(
      variant: EdmmSurfaceVariant.outlined,
      child: Padding(
        padding: const EdgeInsets.all(EdmmSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              item.label,
              softWrap: true,
              style: EdmmTypography.utilityLabel.copyWith(
                color: colors.textMuted,
              ),
            ),
            const SizedBox(height: EdmmSpacing.xs),
            SelectableText(
              item.value,
              style: EdmmTypography.bodyStrong.copyWith(
                color: colors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
