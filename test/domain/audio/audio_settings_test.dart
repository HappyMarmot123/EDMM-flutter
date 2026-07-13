import 'package:edmm/domain/audio/audio_settings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('stored volume accepts only finite values from zero to one', () {
    expect(parseStoredVolume('0.35'), 0.35);
    expect(parseStoredVolume('0'), 0.0);
    expect(parseStoredVolume('1'), 1.0);
    expect(parseStoredVolume('-0.1'), isNull);
    expect(parseStoredVolume('1.1'), isNull);
    expect(parseStoredVolume('NaN'), isNull);
    expect(parseStoredVolume('not-a-number'), isNull);
  });

  test('stored booleans reject unknown values', () {
    expect(parseStoredBool('true'), isTrue);
    expect(parseStoredBool('false'), isFalse);
    expect(parseStoredBool('TRUE'), isNull);
    expect(parseStoredBool('1'), isNull);
    expect(parseStoredBool(null), isNull);
  });

  test('audio setting keys remain stable', () {
    expect(volumeSettingKey, 'volume');
    expect(mutedSettingKey, 'muted');
    expect(shuffleSettingKey, 'shuffle');
  });
}
