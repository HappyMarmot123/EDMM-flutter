import 'package:edmm/domain/audio/audio_effects_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('noop effects controller reports equalizer as unavailable', () {
    expect(
      const NoopAudioEffectsController().equalizerSupport,
      AudioEqualizerSupport.unavailable,
    );
  });
}
