import 'package:edmm/ui/core/themes/theme.dart';
import 'package:edmm/ui/core/widgets/edmm_surface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../design_system/edmm_test_host.dart';

Material _surfaceMaterial(WidgetTester tester, Key key) {
  return tester.widget<Material>(
    find.descendant(of: find.byKey(key), matching: find.byType(Material)).first,
  );
}

void main() {
  testWidgets('surface variants resolve semantic color, radius, and outline', (
    tester,
  ) async {
    await pumpEdmmTestHost(
      tester,
      child: Scaffold(
        body: Column(
          children: <Widget>[
            for (final variant in EdmmSurfaceVariant.values)
              SizedBox(
                width: 120,
                height: 52,
                child: EdmmSurface(
                  key: Key('surface-${variant.name}'),
                  variant: variant,
                  child: const SizedBox.expand(),
                ),
              ),
          ],
        ),
      ),
    );

    final plain = _surfaceMaterial(tester, const Key('surface-plain'));
    final outlined = _surfaceMaterial(tester, const Key('surface-outlined'));
    final raised = _surfaceMaterial(tester, const Key('surface-raised'));
    final modal = _surfaceMaterial(tester, const Key('surface-modal'));

    expect(plain.color, EdmmColors.surface);
    expect(raised.color, EdmmColors.surfaceRaised);
    expect(modal.color, EdmmColors.canvasDeep);
    expect(
      (outlined.shape! as RoundedRectangleBorder).side,
      const BorderSide(color: EdmmColors.outline),
    );
    expect(
      (modal.shape! as RoundedRectangleBorder).borderRadius,
      BorderRadius.circular(EdmmRadii.large),
    );
    expect(modal.clipBehavior, Clip.antiAlias);
    expect(find.byType(BackdropFilter), findsNothing);
  });

  testWidgets('rose tone stays orthogonal to structural variant', (
    tester,
  ) async {
    await pumpEdmmTestHost(
      tester,
      child: const EdmmSurface(
        key: Key('rose-surface'),
        tone: EdmmSurfaceTone.rose,
        variant: EdmmSurfaceVariant.raised,
        child: SizedBox(width: 100, height: 48),
      ),
    );

    final material = _surfaceMaterial(tester, const Key('rose-surface'));
    expect(material.color, EdmmColors.surfaceRose);
    expect(material.elevation, 0);
  });
}
