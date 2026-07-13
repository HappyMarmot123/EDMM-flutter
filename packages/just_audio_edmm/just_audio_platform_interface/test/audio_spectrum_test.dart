import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio_platform_interface/just_audio_platform_interface.dart';

void main() {
  test('supported spectrum events deserialize normalized frames', () {
    final event = AudioSpectrumEventMessage.fromMap(<dynamic, dynamic>{
      'available': true,
      'sampleRate': 48000,
      'timestamp': 123456,
      'magnitudes': <double>[0, 0.25, 0.5, 0.75, 1],
    });

    expect(event.available, isTrue);
    expect(event.unavailableReason, isNull);
    expect(event.frame, isNotNull);
    expect(event.frame!.sampleRate, 48000);
    expect(event.frame!.timestamp, const Duration(microseconds: 123456));
    expect(event.frame!.magnitudes, <double>[0, 0.25, 0.5, 0.75, 1]);
  });

  test('unavailable spectrum events deserialize without a frame', () {
    final event = AudioSpectrumEventMessage.fromMap(<dynamic, dynamic>{
      'available': false,
      'reason': 'pcmUnavailable',
    });

    expect(event.available, isFalse);
    expect(event.unavailableReason, 'pcmUnavailable');
    expect(event.frame, isNull);
  });

  test('spectrum frame parsing clamps malformed native magnitudes', () {
    final event = AudioSpectrumEventMessage.fromMap(<dynamic, dynamic>{
      'available': true,
      'sampleRate': 44100,
      'timestamp': 1,
      'magnitudes': <double>[-1, 0.5, 2],
    });

    expect(event.frame!.magnitudes, <double>[0, 0.5, 1]);
  });
}
