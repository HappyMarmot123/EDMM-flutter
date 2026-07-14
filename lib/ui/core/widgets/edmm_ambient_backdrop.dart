import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../motion/edmm_motion.dart';
import '../themes/edmm_theme_extensions.dart';
import '../themes/edmm_theme_tokens.dart';

enum EdmmAmbientBackdropVariant { catalogEdge, playerArtwork }

class EdmmAmbientBackdrop extends StatelessWidget {
  const EdmmAmbientBackdrop({
    super.key,
    required this.variant,
    required this.child,
    this.artwork,
  }) : assert(
         variant == EdmmAmbientBackdropVariant.playerArtwork || artwork == null,
         'Artwork is only supported by the player backdrop.',
       );

  final EdmmAmbientBackdropVariant variant;
  final Widget child;
  final ImageProvider<Object>? artwork;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).edmm;
    final reducedMotion = EdmmMotion.reducedMotionOf(context);
    final fallback = variant == EdmmAmbientBackdropVariant.catalogEdge
        ? RadialGradient(
            center: Alignment.topRight,
            radius: 1.2,
            colors: <Color>[colors.surfaceRose, colors.canvas],
          )
        : LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[colors.surfaceRose, colors.canvasDeep],
          );

    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        DecoratedBox(
          key: const Key('edmm-ambient-fallback'),
          decoration: BoxDecoration(gradient: fallback),
        ),
        if (variant == EdmmAmbientBackdropVariant.playerArtwork &&
            artwork != null) ...<Widget>[
          RepaintBoundary(
            child: ClipRect(
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(
                  sigmaX: EdmmEffects.artworkBackdropBlurSigma,
                  sigmaY: EdmmEffects.artworkBackdropBlurSigma,
                ),
                child: ExcludeSemantics(
                  child: Image(
                    image: ResizeImage(
                      artwork!,
                      width: EdmmEffects.artworkDecodeLongestSide,
                      height: EdmmEffects.artworkDecodeLongestSide,
                      policy: ResizeImagePolicy.fit,
                    ),
                    fit: BoxFit.cover,
                    filterQuality: FilterQuality.low,
                    frameBuilder: (context, child, frame, synchronous) {
                      return AnimatedOpacity(
                        key: const Key('edmm-ambient-artwork'),
                        opacity: reducedMotion || synchronous || frame != null
                            ? 1
                            : 0,
                        duration: EdmmMotion.resolve(
                          EdmmMotion.ambient,
                          reduceMotion: reducedMotion,
                        ),
                        curve: EdmmMotion.enterCurve,
                        child: child,
                      );
                    },
                    errorBuilder: (_, _, _) => const SizedBox.expand(),
                  ),
                ),
              ),
            ),
          ),
          ColoredBox(
            key: const Key('edmm-ambient-scrim'),
            color: Colors.black.withValues(
              alpha: EdmmEffects.backdropScrimOpacity,
            ),
          ),
        ],
        child,
      ],
    );
  }
}
