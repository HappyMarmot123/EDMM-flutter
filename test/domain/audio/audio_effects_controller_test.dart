import 'package:edmm/domain/audio/audio_effects_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('equalizer presets match original EDMM storage values', () {
    expect(AudioEqualizerPreset.flat.storageValue, 'flat');
    expect(AudioEqualizerPreset.bassBoost.storageValue, 'bass');
    expect(defaultAudioEqualizerPreset, AudioEqualizerPreset.flat);
    expect(
      audioEqualizerPresetFromStorage('bass'),
      AudioEqualizerPreset.bassBoost,
    );
    expect(audioEqualizerPresetFromStorage('edm'), AudioEqualizerPreset.flat);
  });

  test('bass boost preset uses original EDMM gain curve', () {
    expect(AudioEqualizerPreset.flat.gains, List<double>.filled(10, 0));
    expect(AudioEqualizerPreset.bassBoost.gains, <double>[
      8,
      7,
      5,
      2,
      0,
      -1,
      -1,
      0,
      1,
      2,
    ]);
    expect(AudioEqualizerPreset.bassBoost.gainForFrequency(64), 7);
    expect(AudioEqualizerPreset.bassBoost.gainForFrequency(16000), 2);
  });

  test('noop effects controller reports equalizer as unavailable', () {
    const controller = NoopAudioEffectsController();

    expect(controller.equalizerSupport, AudioEqualizerSupport.unavailable);
    expect(controller.equalizerPreset, AudioEqualizerPreset.flat);
  });
}
