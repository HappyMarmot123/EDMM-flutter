import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const forkRoot = 'packages/just_audio_edmm/just_audio';

  test('platform interface exposes a dedicated spectrum event stream', () {
    final interfaceSource = File(
      '$forkRoot/../just_audio_platform_interface/lib/'
      'just_audio_platform_interface.dart',
    ).readAsStringSync();
    final methodChannelSource = File(
      '$forkRoot/../just_audio_platform_interface/lib/'
      'method_channel_just_audio.dart',
    ).readAsStringSync();

    expect(interfaceSource, contains('AudioSpectrumEventMessage'));
    expect(interfaceSource, contains('audioSpectrumEventMessageStream'));
    expect(methodChannelSource, contains('com.ryanheise.just_audio.spectrum.'));
  });

  test('Android observes decoded PCM without RECORD_AUDIO Visualizer', () {
    final playerSource = File(
      '$forkRoot/android/src/main/java/com/ryanheise/just_audio/'
      'AudioPlayer.java',
    ).readAsStringSync();
    final sinkSource = File(
      '$forkRoot/android/src/main/java/com/ryanheise/just_audio/'
      'SpectrumAudioBufferSink.java',
    ).readAsStringSync();
    final androidSource = '$playerSource\n$sinkSource';

    expect(androidSource, contains('TeeAudioProcessor'));
    expect(androidSource, contains('setAudioProcessors'));
    expect(androidSource, contains('SpectrumAudioBufferSink'));
    expect(androidSource, contains('pcmUnavailable'));
    expect(androidSource, contains('static final int BIN_COUNT = 24'));
    expect(androidSource, contains('FRAME_PERIOD_MILLIS = 40'));
    expect(playerSource, contains('if (spectrumUnavailableForOffload)'));
    expect(playerSource, contains('new DefaultRenderersFactory(context)'));
    expect(
      sinkSource,
      contains('captureGeneration.get() != generation'),
      reason: 'queued events from a cancelled capture must not leak',
    );
    expect(androidSource, isNot(contains('android.media.audiofx.Visualizer')));
    expect(androidSource, isNot(contains('RECORD_AUDIO')));
  });

  test('Darwin tap publishes PCM only through an RT-safe mailbox', () {
    final equalizerSource = File(
      '$forkRoot/darwin/just_audio/Sources/just_audio/DarwinEqualizer.m',
    ).readAsStringSync();
    final playerSource = File(
      '$forkRoot/darwin/just_audio/Sources/just_audio/AudioPlayer.m',
    ).readAsStringSync();
    final uriSource = File(
      '$forkRoot/darwin/just_audio/Sources/just_audio/UriAudioSource.m',
    ).readAsStringSync();
    final process = _between(
      equalizerSource,
      'static void DarwinEqualizerTapProcess',
      '@implementation DarwinEqualizer',
    );
    final spectrumListen = _between(playerSource, 'onListen:^{', 'onCancel:^{');

    expect(equalizerSource, contains('spectrumCaptureEnabled'));
    expect(equalizerSource, contains('DarwinSpectrumMailboxSlot'));
    expect(equalizerSource, contains('DarwinEqualizerCaptureSpectrum'));
    expect(equalizerSource, contains('dispatch_source_set_timer'));
    expect(equalizerSource, contains('#define DARWIN_SPECTRUM_BIN_COUNT 24'));
    expect(
      equalizerSource,
      contains('#define DARWIN_SPECTRUM_FRAME_INTERVAL_SECONDS 0.04'),
    );
    expect(process, contains('DarwinEqualizerCaptureSpectrum'));
    expect(process, isNot(contains('malloc(')));
    expect(process, isNot(contains('calloc(')));
    expect(process, isNot(contains('free(')));
    expect(process, isNot(contains('dispatch_')));
    expect(process, isNot(contains('sendEvent')));
    expect(process, isNot(contains('NSLock')));
    expect(process, isNot(contains('pthread_mutex')));
    expect(spectrumListen, isNot(contains('@"available": @YES')));
    expect(equalizerSource, contains('spectrumSupportStatus'));
    expect(equalizerSource, contains('DarwinSpectrumUnsupportedPCM'));
    expect(uriSource, contains('markSpectrumTapPending'));
    expect(uriSource, contains('markSpectrumTapUnavailable'));
    expect(equalizerSource, contains('dispatch_get_specific'));
    expect(equalizerSource, contains('performOnSpectrumQueueSynchronously'));
  });

  test(
    'app exposes visualizer as a capability separate from AudioController',
    () {
      final domainSource = File(
        'lib/domain/audio/audio_visualizer_controller.dart',
      ).readAsStringSync();
      final controllerSource = File(
        'lib/data/audio/just_audio_controller.dart',
      ).readAsStringSync();

      expect(
        domainSource,
        contains('abstract interface class AudioVisualizerController'),
      );
      expect(domainSource, contains('Stream<AudioSpectrumFrame> get spectrum'));
      expect(
        domainSource,
        contains('Stream<AudioVisualizerSupport> get visualizerSupportStream'),
      );
      expect(
        controllerSource,
        contains('visualizer.AudioVisualizerController'),
      );
      expect(controllerSource, contains('_spectrumFrames'));
      expect(controllerSource, contains('.audioSpectrumStream'));
    },
  );
}

String _between(String source, String start, String end) {
  final startIndex = source.indexOf(start);
  expect(startIndex, isNonNegative, reason: 'Missing block start: $start');
  final endIndex = source.indexOf(end, startIndex + start.length);
  expect(endIndex, isNonNegative, reason: 'Missing block end: $end');
  return source.substring(startIndex, endIndex);
}
