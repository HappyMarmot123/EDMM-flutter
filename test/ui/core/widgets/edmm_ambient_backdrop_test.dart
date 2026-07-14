import 'dart:convert';
import 'dart:typed_data';

import 'package:edmm/ui/core/motion/edmm_motion.dart';
import 'package:edmm/ui/core/themes/theme.dart';
import 'package:edmm/ui/core/widgets/edmm_ambient_backdrop.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../design_system/edmm_test_host.dart';

MemoryImage _onePixelArtwork() {
  return MemoryImage(
    Uint8List.fromList(
      base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR4'
        '2mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
      ),
    ),
  );
}

void main() {
  testWidgets('catalog backdrop is static and contains no image or blur', (
    tester,
  ) async {
    await pumpEdmmTestHost(
      tester,
      child: const EdmmAmbientBackdrop(
        variant: EdmmAmbientBackdropVariant.catalogEdge,
        child: Text('Catalog'),
      ),
    );

    expect(find.text('Catalog'), findsOneWidget);
    expect(find.byType(Image), findsNothing);
    expect(find.byType(ImageFiltered), findsNothing);
    expect(find.byType(BackdropFilter), findsNothing);
    expect(find.byKey(const Key('edmm-ambient-fallback')), findsOneWidget);
  });

  testWidgets('player backdrop uses one resized image and fixed scrim', (
    tester,
  ) async {
    await pumpEdmmTestHost(
      tester,
      child: EdmmAmbientBackdrop(
        variant: EdmmAmbientBackdropVariant.playerArtwork,
        artwork: _onePixelArtwork(),
        child: const Text('Player'),
      ),
    );

    expect(find.text('Player'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
    expect(find.byType(ImageFiltered), findsOneWidget);
    expect(find.byType(BackdropFilter), findsNothing);
    expect(find.byType(RepaintBoundary), findsWidgets);
    final image = tester.widget<Image>(find.byType(Image));
    expect(image.image, isA<ResizeImage>());
    final resized = image.image as ResizeImage;
    expect(resized.width, EdmmEffects.artworkDecodeLongestSide);
    expect(resized.height, EdmmEffects.artworkDecodeLongestSide);
    expect(resized.policy, ResizeImagePolicy.fit);
    final scrim = tester.widget<ColoredBox>(
      find.byKey(const Key('edmm-ambient-scrim')),
    );
    expect(
      scrim.color,
      Colors.black.withValues(alpha: EdmmEffects.backdropScrimOpacity),
    );
    expect(EdmmEffects.backdropScrimOpacity, greaterThanOrEqualTo(0.72));
    final fade = tester.widget<AnimatedOpacity>(
      find.byKey(const Key('edmm-ambient-artwork')),
    );
    expect(fade.duration, EdmmMotion.ambient);
  });

  testWidgets('reduced motion presents artwork without a transition', (
    tester,
  ) async {
    await pumpEdmmTestHost(
      tester,
      disableAnimations: true,
      child: EdmmAmbientBackdrop(
        variant: EdmmAmbientBackdropVariant.playerArtwork,
        artwork: _onePixelArtwork(),
        child: const SizedBox.expand(),
      ),
    );

    final fade = tester.widget<AnimatedOpacity>(
      find.byKey(const Key('edmm-ambient-artwork')),
    );
    expect(fade.duration, Duration.zero);
    expect(fade.opacity, 1);
    expect(find.byType(Image), findsOneWidget);
  });
}
