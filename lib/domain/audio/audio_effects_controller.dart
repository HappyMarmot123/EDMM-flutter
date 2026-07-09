class AudioEqualizerBand {
  const AudioEqualizerBand({
    required this.index,
    required this.label,
    required this.minGain,
    required this.maxGain,
    required this.gain,
  });

  final int index;
  final String label;
  final double minGain;
  final double maxGain;
  final double gain;

  AudioEqualizerBand copyWith({double? gain}) => AudioEqualizerBand(
    index: index,
    label: label,
    minGain: minGain,
    maxGain: maxGain,
    gain: gain ?? this.gain,
  );
}

enum AudioEqualizerSupport { supported, unsupportedOnPlatform, unavailable }

abstract class AudioEffectsController {
  bool get isEqualizerEnabled;
  AudioEqualizerSupport get equalizerSupport;
  Future<List<AudioEqualizerBand>> getEqualizerBands();
  Future<void> setEqualizerEnabled(bool enabled);
  Future<void> setEqualizerBandGain(int index, double gain);
}

class NoopAudioEffectsController implements AudioEffectsController {
  const NoopAudioEffectsController();

  @override
  bool get isEqualizerEnabled => false;

  @override
  AudioEqualizerSupport get equalizerSupport =>
      AudioEqualizerSupport.unavailable;

  @override
  Future<List<AudioEqualizerBand>> getEqualizerBands() async => const [];

  @override
  Future<void> setEqualizerEnabled(bool enabled) async {}

  @override
  Future<void> setEqualizerBandGain(int index, double gain) async {}
}
