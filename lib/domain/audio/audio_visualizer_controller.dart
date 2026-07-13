enum AudioVisualizerSupport { supported, unavailable }

const defaultAudioVisualizerEnabled = true;
const visualizerEnabledSettingKey = 'visualizer.enabled';

class AudioSpectrumFrame {
  AudioSpectrumFrame({
    required this.sampleRate,
    required this.timestamp,
    required List<double> magnitudes,
  }) : magnitudes = List<double>.unmodifiable(
         magnitudes.map((value) => value.clamp(0.0, 1.0).toDouble()),
       );

  final int sampleRate;
  final Duration timestamp;
  final List<double> magnitudes;
}

abstract interface class AudioVisualizerController {
  AudioVisualizerSupport get visualizerSupport;
  Stream<AudioVisualizerSupport> get visualizerSupportStream;
  Stream<AudioSpectrumFrame> get spectrum;
}

class NoopAudioVisualizerController implements AudioVisualizerController {
  const NoopAudioVisualizerController();

  @override
  AudioVisualizerSupport get visualizerSupport =>
      AudioVisualizerSupport.unavailable;

  @override
  Stream<AudioVisualizerSupport> get visualizerSupportStream =>
      Stream<AudioVisualizerSupport>.value(AudioVisualizerSupport.unavailable);

  @override
  Stream<AudioSpectrumFrame> get spectrum =>
      const Stream<AudioSpectrumFrame>.empty();
}
