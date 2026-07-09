import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android manifest registers external track deep links', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();

    expect(manifest, contains('android:name="flutter_deeplinking_enabled"'));
    expect(manifest, contains('android:name="android.intent.action.VIEW"'));
    expect(manifest, contains('android:name="android.intent.category.DEFAULT"'));
    expect(
      manifest,
      contains('android:name="android.intent.category.BROWSABLE"'),
    );
    expect(manifest, contains('android:scheme="edmm"'));
  });

  test('iOS plist registers external track deep links', () {
    final plist = File('ios/Runner/Info.plist').readAsStringSync();

    expect(plist, contains('<key>FlutterDeepLinkingEnabled</key>'));
    expect(plist, contains('<key>CFBundleURLTypes</key>'));
    expect(plist, contains('<key>CFBundleURLSchemes</key>'));
    expect(plist, contains('<string>edmm</string>'));
  });
}
