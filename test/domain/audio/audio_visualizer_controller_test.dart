import 'package:edmm/domain/audio/audio_visualizer_controller.dart';
import 'package:edmm/data/audio/just_audio_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('spectrum frames own an immutable normalized magnitude snapshot', () {
    final source = <double>[0, 0.5, 1];
    final frame = AudioSpectrumFrame(
      sampleRate: 48000,
      timestamp: const Duration(microseconds: 10),
      magnitudes: source,
    );
    source[1] = 0;

    expect(frame.magnitudes, <double>[0, 0.5, 1]);
    expect(() => frame.magnitudes[0] = 1, throwsUnsupportedError);
  });

  test('noop visualizer is unavailable and emits no frames', () async {
    const controller = NoopAudioVisualizerController();

    expect(controller.visualizerSupport, AudioVisualizerSupport.unavailable);
    await expectLater(
      controller.visualizerSupportStream,
      emits(AudioVisualizerSupport.unavailable),
    );
    await expectLater(controller.spectrum, emitsDone);
  });

  test(
    'just audio visualizer streams keep stable identity across rebuilds',
    () async {
      final controller = JustAudioController();
      addTearDown(controller.dispose);

      expect(identical(controller.spectrum, controller.spectrum), isTrue);
      expect(
        identical(
          controller.visualizerSupportStream,
          controller.visualizerSupportStream,
        ),
        isTrue,
      );
    },
  );
}
