import 'package:flutter/material.dart';

import '../../core/themes/edmm_theme_tokens.dart';
import '../../core/widgets/edmm_artwork.dart';

class PlayerArtworkStage extends StatelessWidget {
  const PlayerArtworkStage({
    super.key,
    required this.imageUrl,
    required this.size,
    required this.radius,
  });

  final String imageUrl;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox.square(
        key: const Key('player-artwork'),
        dimension: size,
        child: RepaintBoundary(
          child: EdmmArtwork(
            imageUrl: imageUrl,
            radius: radius >= EdmmRadii.large
                ? EdmmArtworkRadius.large
                : EdmmArtworkRadius.medium,
            semantics: EdmmArtworkSemantics.decorative,
          ),
        ),
      ),
    );
  }
}
