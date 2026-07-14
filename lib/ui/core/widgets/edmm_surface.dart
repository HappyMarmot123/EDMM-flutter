import 'package:flutter/material.dart';

import '../themes/edmm_theme_extensions.dart';
import '../themes/edmm_theme_tokens.dart';

enum EdmmSurfaceVariant { plain, outlined, raised, modal }

enum EdmmSurfaceTone { neutral, rose }

class EdmmSurface extends StatelessWidget {
  const EdmmSurface({
    super.key,
    required this.child,
    this.variant = EdmmSurfaceVariant.plain,
    this.tone = EdmmSurfaceTone.neutral,
  });

  final Widget child;
  final EdmmSurfaceVariant variant;
  final EdmmSurfaceTone tone;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).edmm;
    final background = tone == EdmmSurfaceTone.rose
        ? colors.surfaceRose
        : switch (variant) {
            EdmmSurfaceVariant.plain ||
            EdmmSurfaceVariant.outlined => colors.surface,
            EdmmSurfaceVariant.raised => colors.surfaceRaised,
            EdmmSurfaceVariant.modal => colors.canvasDeep,
          };
    final radius = switch (variant) {
      EdmmSurfaceVariant.plain => EdmmRadii.small,
      EdmmSurfaceVariant.outlined ||
      EdmmSurfaceVariant.raised => EdmmRadii.medium,
      EdmmSurfaceVariant.modal => EdmmRadii.large,
    };
    final side = variant == EdmmSurfaceVariant.outlined
        ? BorderSide(color: colors.outline)
        : BorderSide.none;

    return Material(
      color: background,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
        side: side,
      ),
      clipBehavior: variant == EdmmSurfaceVariant.modal
          ? Clip.antiAlias
          : Clip.none,
      child: child,
    );
  }
}
