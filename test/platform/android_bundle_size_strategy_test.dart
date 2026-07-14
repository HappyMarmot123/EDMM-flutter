import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android bundle size budgets are internally consistent', () {
    final decoded =
        jsonDecode(
              File('tool/android_bundle_size_budget.json').readAsStringSync(),
            )
            as Map<String, dynamic>;
    final metrics = decoded['metrics']! as Map<String, dynamic>;

    expect(decoded['baselineFlutter'], '3.44.5');
    expect(
      metrics.keys,
      containsAll(<String>[
        'bundleBytes',
        'allNativeBytes',
        'arm64NativeBytes',
        'dexBytes',
        'assetsBytes',
        'resourcesBytes',
        'estimatedArm64BaseBytes',
      ]),
    );
    for (final entry in metrics.entries) {
      final rule = entry.value! as Map<String, dynamic>;
      final baseline = rule['baselineBytes']! as int;
      final growth = rule['maxGrowthBytes']! as int;
      final limit = rule['limitBytes']! as int;
      expect(baseline, greaterThan(0), reason: entry.key);
      expect(growth, greaterThan(0), reason: entry.key);
      expect(limit, greaterThan(baseline), reason: entry.key);
    }
  });

  test('bundle gate requires production ABIs and split symbols', () {
    final script = File(
      'tool/check_android_bundle_size.ps1',
    ).readAsStringSync();

    for (final abi in <String>['armeabi-v7a', 'arm64-v8a', 'x86_64']) {
      expect(script, contains('base/lib/$abi/libapp.so'));
      expect(script, contains('base/lib/$abi/libflutter.so'));
    }
    for (final symbols in <String>[
      'app.android-arm.symbols',
      'app.android-arm64.symbols',
      'app.android-x64.symbols',
    ]) {
      expect(script, contains(symbols));
    }
  });

  test('CI builds AAB, enforces budgets, and retains failure evidence', () {
    final workflow = File('.github/workflows/ci.yml').readAsStringSync();

    expect(workflow, contains('flutter-version: 3.44.5'));
    expect(workflow, contains('flutter build appbundle --release'));
    expect(workflow, contains('--split-debug-info=build/symbols/android'));
    expect(workflow, contains('check_android_bundle_size.ps1'));
    expect(workflow, contains('if: always()'));
    expect(workflow, contains('build/android-bundle-size-report.json'));
  });
}
