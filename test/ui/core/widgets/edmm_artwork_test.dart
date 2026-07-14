import 'dart:convert';
import 'dart:typed_data';

import 'package:edmm/ui/core/motion/edmm_motion.dart';
import 'package:edmm/ui/core/themes/theme.dart';
import 'package:edmm/ui/core/widgets/edmm_artwork.dart';
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
  setUp(() {
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
  });

  testWidgets('missing, successful, and failed artwork keep square geometry', (
    tester,
  ) async {
    await pumpEdmmTestHost(
      tester,
      child: Scaffold(
        body: Row(
          children: <Widget>[
            const SizedBox.square(
              dimension: 48,
              child: EdmmArtwork(key: Key('missing-artwork')),
            ),
            SizedBox.square(
              dimension: 48,
              child: EdmmArtwork(
                key: const Key('successful-artwork'),
                imageProvider: _onePixelArtwork(),
              ),
            ),
            SizedBox.square(
              dimension: 48,
              child: EdmmArtwork(
                key: const Key('failed-artwork'),
                imageProvider: MemoryImage(Uint8List.fromList(<int>[0, 1, 2])),
              ),
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    for (final key in <String>[
      'missing-artwork',
      'successful-artwork',
      'failed-artwork',
    ]) {
      expect(tester.getSize(find.byKey(Key(key))), const Size.square(48));
    }
    expect(find.byKey(const Key('edmm-artwork-fallback')), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('decode dimensions follow DPR and stay capped', (tester) async {
    await pumpEdmmTestHost(
      tester,
      devicePixelRatio: 2,
      child: Scaffold(
        body: SizedBox.square(
          dimension: 48,
          child: EdmmArtwork(imageProvider: _onePixelArtwork()),
        ),
      ),
    );

    var resized = tester.widget<Image>(find.byType(Image)).image as ResizeImage;
    expect(resized.width, 96);
    expect(resized.height, 96);
    expect(resized.policy, ResizeImagePolicy.fit);

    await pumpEdmmTestHost(
      tester,
      viewport: const Size(500, 600),
      devicePixelRatio: 4,
      child: Scaffold(
        body: SizedBox.square(
          dimension: 400,
          child: EdmmArtwork(imageProvider: _onePixelArtwork()),
        ),
      ),
    );

    resized = tester.widget<Image>(find.byType(Image)).image as ResizeImage;
    expect(resized.width, EdmmEffects.artworkDecodeLongestSide);
    expect(resized.height, EdmmEffects.artworkDecodeLongestSide);
  });

  testWidgets('semantics mode avoids duplicate decorative announcements', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await pumpEdmmTestHost(
      tester,
      child: const Scaffold(
        body: Column(
          children: <Widget>[
            EdmmArtwork(key: Key('decorative-artwork')),
            EdmmArtwork(
              key: Key('informative-artwork'),
              semantics: EdmmArtworkSemantics.informative,
              semanticLabel: 'Artwork for Midnight Signal',
            ),
          ],
        ),
      ),
    );

    expect(
      find.bySemanticsLabel('Artwork for Midnight Signal'),
      findsOneWidget,
    );
    expect(
      tester.getSemantics(find.byKey(const Key('decorative-artwork'))).label,
      isEmpty,
    );
    semantics.dispose();
  });

  testWidgets('optional fade honors reduced motion', (tester) async {
    await pumpEdmmTestHost(
      tester,
      child: Scaffold(
        body: SizedBox.square(
          dimension: 48,
          child: EdmmArtwork(imageProvider: _onePixelArtwork()),
        ),
      ),
    );

    var fade = tester.widget<AnimatedOpacity>(
      find.byKey(const Key('edmm-artwork-image')),
    );
    expect(fade.duration, EdmmMotion.standard);

    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    await pumpEdmmTestHost(
      tester,
      disableAnimations: true,
      child: Scaffold(
        body: SizedBox.square(
          dimension: 48,
          child: EdmmArtwork(imageProvider: _onePixelArtwork()),
        ),
      ),
    );

    fade = tester.widget<AnimatedOpacity>(
      find.byKey(const Key('edmm-artwork-image')),
    );
    expect(fade.duration, Duration.zero);
  });

  test('artwork sources are mutually exclusive', () {
    expect(
      () => EdmmArtwork(
        imageUrl: 'https://example.com/cover.png',
        imageProvider: _onePixelArtwork(),
      ),
      throwsAssertionError,
    );
  });
}
