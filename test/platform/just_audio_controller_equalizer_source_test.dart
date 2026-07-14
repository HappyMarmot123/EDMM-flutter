import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final source = File('lib/data/audio/just_audio_controller.dart');
  final playerScreen = File('lib/ui/player/widgets/player_screen.dart');
  final playerEqualizerPanel = File(
    'lib/ui/player/widgets/player_equalizer_panel.dart',
  );
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

  test(
    'equalizer presets are applied through platform band gains internally',
    () {
      final text = source.readAsStringSync();

      expect(text, contains('Future<void> setEqualizerPreset'));
      expect(text, contains('.gainForFrequency'));
      expect(text, contains('await band.setGain(gain.toDouble())'));
    },
  );

  test('Darwin preset transitions ramp out before applying all band gains', () {
    final text = source.readAsStringSync();
    final block = text.substring(
      text.indexOf('Future<void> _applyDarwinEqualizerPreset'),
      text.indexOf(
        '\n  @override',
        text.indexOf('Future<void> _applyDarwinEqualizerPreset'),
      ),
    );
    final disable = block.indexOf('await _darwinEqualizer.setEnabled(false)');
    final bandLoop = block.indexOf('for (final band in parameters.bands)');
    final restore = block.lastIndexOf(
      'await _darwinEqualizer.setEnabled(preset.appliesProcessing)',
    );

    expect(disable, isNonNegative);
    expect(bandLoop, greaterThan(disable));
    expect(restore, greaterThan(bandLoop));
    expect(block, contains('_darwinEqualizerTransitionDuration'));
  });

  test('player UI exposes presets instead of manual band sliders', () {
    final screenText = playerScreen.readAsStringSync();
    final panelText = playerEqualizerPanel.readAsStringSync();
    final equalizerUiText = '$screenText\n$panelText';
    final arbText = englishArb.readAsStringSync();

    expect(screenText, contains('PlayerEqualizerPanel('));
    expect(panelText, contains('player-eq-preset-flat'));
    expect(panelText, contains('player-eq-preset-bass'));
    expect(equalizerUiText, isNot(contains('player-eq-band-')));
    expect(equalizerUiText, isNot(contains('setEqualizerBandGain')));
    expect(screenText, contains('playerEqualizerUnsupportedPlatform'));
    expect(screenText, isNot(contains('playerEqualizerAndroidOnly')));
    expect(arbText, isNot(contains('Android devices only')));
    expect(arbText, contains('playerEqualizerPresetFlat'));
    expect(arbText, contains('playerEqualizerPresetBass'));
  });
}
