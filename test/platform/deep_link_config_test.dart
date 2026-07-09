import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android manifest registers external track deep links', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();

    expect(manifest, contains('android:name="flutter_deeplinking_enabled"'));
    expect(manifest, contains('android:name="android.intent.action.VIEW"'));
    expect(
      manifest,
      contains('android:name="android.intent.category.DEFAULT"'),
    );
    expect(
      manifest,
      contains('android:name="android.intent.category.BROWSABLE"'),
    );
    expect(manifest, contains('android:scheme="edmm"'));
  });

  test('Android manifest registers verified HTTPS app links', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();

    expect(manifest, contains('android:autoVerify="true"'));
    expect(manifest, contains('android:scheme="https"'));
    expect(manifest, contains('android:host="edmm.vercel.app"'));
    expect(manifest, contains('android:pathPrefix="/track"'));
  });

  test('iOS plist registers external track deep links', () {
    final plist = File('ios/Runner/Info.plist').readAsStringSync();

    expect(plist, contains('<key>FlutterDeepLinkingEnabled</key>'));
    expect(plist, contains('<key>CFBundleURLTypes</key>'));
    expect(plist, contains('<key>CFBundleURLSchemes</key>'));
    expect(plist, contains('<string>edmm</string>'));
  });

  test('iOS project enables associated domains for universal links', () {
    final entitlements = File(
      'ios/Runner/Runner.entitlements',
    ).readAsStringSync();
    final project = File(
      'ios/Runner.xcodeproj/project.pbxproj',
    ).readAsStringSync();

    expect(entitlements, contains('com.apple.developer.associated-domains'));
    expect(entitlements, contains('<string>applinks:edmm.vercel.app</string>'));
    expect(
      project,
      contains('CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;'),
    );
  });

  test('device regression smoke script covers platform link entry points', () {
    final script = File('tool/device_regression.ps1').readAsStringSync();

    expect(script, contains('edmm:///track/'));
    expect(script, contains('https://edmm.vercel.app/track/'));
    expect(script, contains('adb shell am start'));
    expect(script, contains('media_session'));
    expect(script, contains('xcrun simctl openurl'));
    expect(script, contains('notification'));
    expect(script, contains('artwork'));
    expect(script, contains('interruption'));
  });

  test('iOS EQ PoC script captures macOS-only verification gates', () {
    final script = File('tool/ios_eq_poc.sh').readAsStringSync();

    expect(script, contains('flutter build ios --no-codesign'));
    expect(script, contains('xcrun simctl'));
    expect(script, contains('edmm:///track/'));
    expect(script, contains('background playback'));
    expect(script, contains('interruption'));
    expect(script, contains('AVAudioUnitEQ'));
  });
}
