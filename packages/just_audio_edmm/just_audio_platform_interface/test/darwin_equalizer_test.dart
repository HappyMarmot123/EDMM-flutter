import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio_platform_interface/just_audio_platform_interface.dart';
import 'package:just_audio_platform_interface/method_channel_just_audio.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Darwin equalizer messages serialize to maps', () {
    final band = DarwinEqualizerBandMessage(
      index: 2,
      lowerFrequency: 1000.0,
      upperFrequency: 2000.0,
      centerFrequency: 1500.0,
      gain: 1.5,
    );
    expect(band.toMap(), {
      'index': 2,
      'lowerFrequency': 1000.0,
      'upperFrequency': 2000.0,
      'centerFrequency': 1500.0,
      'gain': 1.5,
    });
    expect(DarwinEqualizerBandMessage.fromMap(band.toMap()).gain, 1.5);

    final parameters = DarwinEqualizerParametersMessage(
      minDecibels: -12.0,
      maxDecibels: 12.0,
      bands: [band],
    );
    expect(parameters.toMap(), {
      'minDecibels': -12.0,
      'maxDecibels': 12.0,
      'bands': [band.toMap()],
    });
    expect(
      DarwinEqualizerParametersMessage.fromMap(parameters.toMap())
          .bands
          .single
          .centerFrequency,
      1500.0,
    );

    expect(
      DarwinEqualizerMessage(enabled: true, parameters: parameters).toMap(),
      {
        'type': 'DarwinEqualizer',
        'enabled': true,
        'parameters': parameters.toMap(),
      },
    );
    expect(
      InitRequest(
        id: 'player-1',
        darwinAudioEffects: [
          DarwinEqualizerMessage(enabled: false, parameters: null),
        ],
      ).toMap()['darwinAudioEffects'],
      [
        {
          'type': 'DarwinEqualizer',
          'enabled': false,
          'parameters': null,
        },
      ],
    );
  });

  test('MethodChannelAudioPlayer sends Darwin equalizer method calls',
      () async {
    const channel = MethodChannel('com.ryanheise.just_audio.methods.player-1');
    final calls = <MethodCall>[];
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      switch (call.method) {
        case 'darwinEqualizerGetParameters':
          return {
            'parameters': {
              'minDecibels': -12.0,
              'maxDecibels': 12.0,
              'bands': [
                {
                  'index': 0,
                  'lowerFrequency': 20.0,
                  'upperFrequency': 80.0,
                  'centerFrequency': 50.0,
                  'gain': 0.0,
                },
              ],
            },
          };
        case 'darwinEqualizerBandSetGain':
          return <String, Object?>{};
      }
      fail('Unexpected method call: ${call.method}');
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

    final player = MethodChannelAudioPlayer('player-1');
    final parametersResponse = await player.darwinEqualizerGetParameters(
      DarwinEqualizerGetParametersRequest(),
    );
    expect(parametersResponse.parameters.minDecibels, -12.0);
    expect(parametersResponse.parameters.bands.single.centerFrequency, 50.0);

    await player.darwinEqualizerBandSetGain(
      DarwinEqualizerBandSetGainRequest(bandIndex: 0, gain: 2.5),
    );

    expect(calls.map((call) => call.method), [
      'darwinEqualizerGetParameters',
      'darwinEqualizerBandSetGain',
    ]);
    expect(calls.last.arguments, {
      'bandIndex': 0,
      'gain': 2.5,
    });
  });
}
