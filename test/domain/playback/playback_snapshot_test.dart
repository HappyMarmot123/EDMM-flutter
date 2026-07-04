import 'package:flutter_test/flutter_test.dart';
import 'package:edmm/domain/playback/playback_snapshot.dart';

void main() {
  test('defaults and isPlaying', () {
    const s = PlaybackSnapshot();
    expect(s.status, PlaybackStatus.idle);
    expect(s.isPlaying, isFalse);
    expect(s.copyWith(status: PlaybackStatus.playing).isPlaying, isTrue);
  });
}
