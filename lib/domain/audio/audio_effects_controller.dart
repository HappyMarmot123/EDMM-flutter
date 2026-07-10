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

enum AudioEqualizerPreset { flat, bassBoost }

const defaultAudioEqualizerPreset = AudioEqualizerPreset.flat;

const equalizerPresetSettingKey = 'equalizer.preset';

const _presetFrequencies = <double>[
  32,
  64,
  125,
  250,
  500,
  1000,
  2000,
  4000,
  8000,
  16000,
];

const _flatPresetGains = <double>[0, 0, 0, 0, 0, 0, 0, 0, 0, 0];

const _bassBoostPresetGains = <double>[8, 7, 5, 2, 0, -1, -1, 0, 1, 2];

AudioEqualizerPreset audioEqualizerPresetFromStorage(String? value) {
  return switch (value?.trim()) {
    'bass' => AudioEqualizerPreset.bassBoost,
    'flat' || _ => defaultAudioEqualizerPreset,
  };
}

extension AudioEqualizerPresetX on AudioEqualizerPreset {
  String get storageValue => switch (this) {
    AudioEqualizerPreset.flat => 'flat',
    AudioEqualizerPreset.bassBoost => 'bass',
  };

  List<double> get gains => switch (this) {
    AudioEqualizerPreset.flat => _flatPresetGains,
    AudioEqualizerPreset.bassBoost => _bassBoostPresetGains,
  };

  bool get appliesProcessing => this != AudioEqualizerPreset.flat;

  double gainForFrequency(double frequency) {
    var nearestIndex = 0;
    var nearestDistance = (frequency - _presetFrequencies.first).abs();
    for (var i = 1; i < _presetFrequencies.length; i++) {
      final distance = (frequency - _presetFrequencies[i]).abs();
      if (distance < nearestDistance) {
        nearestIndex = i;
        nearestDistance = distance;
      }
    }
    return gains[nearestIndex];
  }
}

abstract class AudioEffectsController {
  AudioEqualizerSupport get equalizerSupport;
  AudioEqualizerPreset get equalizerPreset;
  Future<void> setEqualizerPreset(AudioEqualizerPreset preset);
}

class NoopAudioEffectsController implements AudioEffectsController {
  const NoopAudioEffectsController();

  @override
  AudioEqualizerSupport get equalizerSupport =>
      AudioEqualizerSupport.unavailable;

  @override
  AudioEqualizerPreset get equalizerPreset => AudioEqualizerPreset.flat;

  @override
  Future<void> setEqualizerPreset(AudioEqualizerPreset preset) async {}
}
