import 'package:edmm/ui/core/themes/theme.dart';
import 'package:edmm/ui/core/widgets/edmm_section_label.dart';
import 'package:edmm/ui/core/widgets/edmm_timecode.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../design_system/edmm_component_gallery.dart';
import '../../design_system/edmm_test_host.dart';

void main() {
  test('timecode formatting is stable and presentation-only', () {
    expect(formatEdmmTimecode(Duration.zero), '00:00');
    expect(formatEdmmTimecode(const Duration(minutes: 9, seconds: 8)), '09:08');
    expect(
      formatEdmmTimecode(const Duration(hours: 1, minutes: 2, seconds: 3)),
      '1:02:03',
    );
    expect(formatEdmmTimecode(const Duration(seconds: -2)), '00:00');
  });

  testWidgets('section label preserves localized copy and time uses tabulars', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await pumpEdmmTestHost(
      tester,
      viewport: EdmmTestViewports.compactPhone,
      textScale: 2,
      locale: const Locale('ko'),
      child: const Scaffold(
        body: SizedBox(
          width: 240,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              EdmmSectionLabel(
                key: Key('section-label'),
                label: '최근 재생한 음악',
                isHeader: true,
              ),
              EdmmTimecode(
                key: Key('timecode'),
                value: Duration(minutes: 9, seconds: 8),
                semanticLabel: '9분 8초',
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('최근 재생한 음악'), findsOneWidget);
    expect(find.text('09:08'), findsOneWidget);
    expect(
      tester
          .getSemantics(find.byKey(const Key('section-label')))
          .flagsCollection
          .isHeader,
      isTrue,
    );
    expect(
      tester.getSemantics(find.byKey(const Key('timecode'))).label,
      '9분 8초',
    );
    final timeText = tester.widget<Text>(find.text('09:08'));
    expect(timeText.style!.fontFeatures, EdmmTypography.timeData.fontFeatures);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('component gallery supports text scale two without overflow', (
    tester,
  ) async {
    await pumpEdmmTestHost(
      tester,
      viewport: EdmmTestViewports.compactPhone,
      textScale: 2,
      child: const Scaffold(body: EdmmComponentGallery()),
    );
    await tester.pump();

    expect(find.byType(FittedBox), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
