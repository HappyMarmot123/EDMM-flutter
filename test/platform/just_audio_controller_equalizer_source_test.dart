import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final source = File('lib/data/audio/just_audio_controller.dart');
  final playerScreen = File('lib/ui/player/widgets/player_screen.dart');
  final englishArb = File('lib/l10n/app_en.arb');

  test('app-level just audio controller wires Darwin equalizer pipeline', () {
    final text = source.readAsStringSync();

    expect(text, contains('final DarwinEqualizer _darwinEqualizer'));
    expect(text, contains('androidAudioEffects: [_androidEqualizer]'));
    expect(text, contains('darwinAudioEffects: [_darwinEqualizer]'));
  });

  test('app-level equalizer support includes Android and Darwin platforms', () {
    final text = source.readAsStringSync();

    expect(text, contains('!kIsWeb'));
    expect(text, contains('Platform.isAndroid'));
    expect(text, contains('Platform.isIOS'));
    expect(text, contains('Platform.isMacOS'));
    expect(
      text,
      contains('_supportsAndroidEqualizer || _supportsDarwinEqualizer'),
    );
  });

  test('Darwin bands map into app equalizer band model defensively', () {
    final text = source.readAsStringSync();

    expect(
      text,
      contains('Future<List<AudioEqualizerBand>> _getDarwinEqualizerBands()'),
    );
    expect(text, contains('_darwinEqualizer.parameters.timeout'));
    expect(text, contains('label: _formatFrequency(band.centerFrequency)'));
    expect(text, contains('minGain: parameters.minDecibels'));
    expect(text, contains('maxGain: parameters.maxDecibels'));
    expect(text, contains('await band.setGain(gain)'));
    expect(text, contains('return const []'));
  });

  test('unsupported equalizer copy is not Android-only', () {
    final screenText = playerScreen.readAsStringSync();
    final arbText = englishArb.readAsStringSync();

    expect(screenText, contains('playerEqualizerUnsupportedPlatform'));
    expect(screenText, isNot(contains('playerEqualizerAndroidOnly')));
    expect(arbText, isNot(contains('Android devices only')));
  });
}
