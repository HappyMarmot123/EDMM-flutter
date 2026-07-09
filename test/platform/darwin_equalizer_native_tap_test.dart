import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const darwinSourceRoot =
      'packages/just_audio_edmm/just_audio/darwin/just_audio/Sources/just_audio';

  test('Darwin equalizer native tap prototype is wired into the fork', () {
    final audioPlayer = File(
      '$darwinSourceRoot/AudioPlayer.m',
    ).readAsStringSync();
    final audioPlayerHeader = File(
      '$darwinSourceRoot/include/just_audio/AudioPlayer.h',
    ).readAsStringSync();
    final justAudioPlugin = File(
      '$darwinSourceRoot/JustAudioPlugin.m',
    ).readAsStringSync();
    final uriAudioSource = File(
      '$darwinSourceRoot/UriAudioSource.m',
    ).readAsStringSync();
    final equalizer = File(
      '$darwinSourceRoot/DarwinEqualizer.m',
    ).readAsStringSync();
    final podspec = File(
      'packages/just_audio_edmm/just_audio/darwin/just_audio.podspec',
    ).readAsStringSync();
    final initializeDarwinAudioEffects = _between(
      audioPlayer,
      '- (void)initializeDarwinAudioEffects:(NSArray *)darwinAudioEffects {',
      '- (void)handleMethodCall',
    );
    final audioEffectSetEnabled = _between(
      audioPlayer,
      '- (void)audioEffectSetEnabled',
      '- (void)darwinEqualizerGetParameters',
    );

    expect(audioPlayer, contains('audioEffectSetEnabled'));
    expect(audioPlayer, contains('darwinEqualizerGetParameters'));
    expect(audioPlayer, contains('darwinEqualizerBandSetGain'));
    expect(audioPlayer, contains('DarwinEqualizer'));
    expect(audioPlayer, contains('darwinAudioEffects'));
    expect(initializeDarwinAudioEffects, contains('id type = effect[@"type"]'));
    expect(
      initializeDarwinAudioEffects,
      contains('id enabled = effect[@"enabled"]'),
    );
    expect(
      initializeDarwinAudioEffects,
      contains('[type isKindOfClass:[NSString class]]'),
    );
    expect(
      initializeDarwinAudioEffects,
      contains('[(NSString *)type isEqualToString:@"DarwinEqualizer"]'),
    );
    expect(
      initializeDarwinAudioEffects,
      contains('[enabled isKindOfClass:[NSNumber class]]'),
    );
    expect(
      audioEffectSetEnabled,
      contains('- (void)audioEffectSetEnabled:(id)type enabled:(id)enabled'),
    );
    expect(
      audioEffectSetEnabled,
      contains('[type isKindOfClass:[NSString class]]'),
    );
    expect(audioEffectSetEnabled, contains('invalidAudioEffectType'));
    expect(audioEffectSetEnabled, contains('unsupportedAudioEffect'));
    expect(
      audioEffectSetEnabled,
      contains('[enabled isKindOfClass:[NSNumber class]]'),
    );
    expect(audioEffectSetEnabled, contains('invalidAudioEffectEnabled'));
    expect(
      audioEffectSetEnabled,
      contains('[(NSString *)type isEqualToString:@"DarwinEqualizer"]'),
    );
    expect(
      audioPlayer,
      isNot(contains('enabled:(BOOL)[request[@"enabled"] boolValue]')),
    );
    expect(audioPlayer, isNot(contains('type:(NSString *)request[@"type"]')));
    expect(audioPlayerHeader, contains('darwinAudioEffects'));
    expect(justAudioPlugin, contains('darwinAudioEffects'));
    expect(justAudioPlugin, contains('request[@"darwinAudioEffects"]'));

    expect(equalizer, contains('MTAudioProcessingTapCreate'));
    expect(equalizer, contains('MTAudioProcessingTapGetSourceAudio'));

    expect(uriAudioSource, contains('AVMutableAudioMix'));
    expect(uriAudioSource, contains('AVMutableAudioMixInputParameters'));
    expect(uriAudioSource, contains('audioTapProcessor'));
    expect(uriAudioSource, contains('tracksWithMediaType:AVMediaTypeAudio'));
    expect(
      uriAudioSource,
      isNot(contains('audioMixInputParametersWithTrack:nil')),
    );

    final preparePlayerItem2 = RegExp(
      r'- \(void\)preparePlayerItem2 \{([\s\S]*?)\n\}',
    ).firstMatch(uriAudioSource)!.group(1)!;
    expect(preparePlayerItem2, contains('[self createPlayerItem:_uri]'));

    expect(uriAudioSource, contains('[self attachTapToPlayerItem:item]'));

    expect(podspec, contains('MediaToolbox'));
  });
}

String _between(String source, String start, String end) {
  final startIndex = source.indexOf(start);
  expect(startIndex, isNonNegative, reason: 'Missing block start: $start');
  final endIndex = source.indexOf(end, startIndex + start.length);
  expect(endIndex, isNonNegative, reason: 'Missing block end: $end');
  return source.substring(startIndex, endIndex);
}
