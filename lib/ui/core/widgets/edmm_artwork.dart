import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../motion/edmm_motion.dart';
import '../themes/edmm_theme_extensions.dart';
import '../themes/edmm_theme_tokens.dart';

enum EdmmArtworkRadius { small, medium, large }

enum EdmmArtworkSemantics { decorative, informative }

class EdmmArtwork extends StatelessWidget {
  const EdmmArtwork({
    super.key,
    this.imageUrl,
    this.imageProvider,
    this.radius = EdmmArtworkRadius.medium,
    this.semantics = EdmmArtworkSemantics.decorative,
    this.semanticLabel,
    this.fadeIn = true,
  }) : assert(
         imageUrl == null || imageProvider == null,
         'Provide either imageUrl or imageProvider, not both.',
       );

  final String? imageUrl;
  final ImageProvider<Object>? imageProvider;
  final EdmmArtworkRadius radius;
  final EdmmArtworkSemantics semantics;
  final String? semanticLabel;
  final bool fadeIn;

  @override
  Widget build(BuildContext context) {
    assert(
      semantics != EdmmArtworkSemantics.informative ||
          (semanticLabel?.trim().isNotEmpty ?? false),
      'Informative artwork requires a semanticLabel.',
    );

    final visual = AspectRatio(
      aspectRatio: 1,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_radiusValue),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final provider = _provider;
            if (provider == null) {
              return _ArtworkFallback(radius: radius);
            }

            final resizedProvider = _resizeFor(
              context: context,
              constraints: constraints,
              provider: provider,
            );
            final reduceMotion = EdmmMotion.reducedMotionOf(context);
            return Image(
              image: resizedProvider,
              fit: BoxFit.cover,
              filterQuality: FilterQuality.medium,
              excludeFromSemantics: true,
              errorBuilder: (context, error, stackTrace) {
                return _ArtworkFallback(radius: radius);
              },
              frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                final isVisible = wasSynchronouslyLoaded || frame != null;
                if (!fadeIn || wasSynchronouslyLoaded) {
                  return isVisible ? child : _ArtworkFallback(radius: radius);
                }
                return Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    _ArtworkFallback(radius: radius),
                    AnimatedOpacity(
                      key: const Key('edmm-artwork-image'),
                      opacity: isVisible ? 1 : 0,
                      duration: EdmmMotion.resolve(
                        EdmmMotion.standard,
                        reduceMotion: reduceMotion,
                      ),
                      curve: EdmmMotion.enterCurve,
                      child: child,
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );

    if (semantics == EdmmArtworkSemantics.decorative) {
      return ExcludeSemantics(child: visual);
    }
    return Semantics(
      container: true,
      image: true,
      label: semanticLabel,
      child: ExcludeSemantics(child: visual),
    );
  }

  ImageProvider<Object>? get _provider {
    if (imageProvider != null) {
      return imageProvider;
    }
    final normalizedUrl = imageUrl?.trim();
    if (normalizedUrl == null || normalizedUrl.isEmpty) {
      return null;
    }
    return NetworkImage(normalizedUrl);
  }

  double get _radiusValue => switch (radius) {
    EdmmArtworkRadius.small => EdmmRadii.small,
    EdmmArtworkRadius.medium => EdmmRadii.medium,
    EdmmArtworkRadius.large => EdmmRadii.large,
  };

  ImageProvider<Object> _resizeFor({
    required BuildContext context,
    required BoxConstraints constraints,
    required ImageProvider<Object> provider,
  }) {
    if (provider is ResizeImage) {
      return provider;
    }
    final constrainedSide =
        constraints.hasBoundedWidth && constraints.hasBoundedHeight
        ? math.min(constraints.maxWidth, constraints.maxHeight)
        : EdmmEffects.artworkDecodeLongestSide.toDouble();
    final safeSide = constrainedSide.isFinite && constrainedSide > 0
        ? constrainedSide
        : EdmmEffects.artworkDecodeLongestSide.toDouble();
    final physicalSide = (safeSide * MediaQuery.devicePixelRatioOf(context))
        .ceil()
        .clamp(1, EdmmEffects.artworkDecodeLongestSide);

    return ResizeImage(
      provider,
      width: physicalSide,
      height: physicalSide,
      policy: ResizeImagePolicy.fit,
    );
  }
}

class _ArtworkFallback extends StatelessWidget {
  const _ArtworkFallback({required this.radius});

  final EdmmArtworkRadius radius;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).edmm;
    return ColoredBox(
      key: const Key('edmm-artwork-fallback'),
      color: colors.surfaceRaised,
      child: Center(
        child: Icon(
          Icons.album_outlined,
          color: colors.brandSoft,
          size: radius == EdmmArtworkRadius.small ? 20 : 24,
        ),
      ),
    );
  }
}
