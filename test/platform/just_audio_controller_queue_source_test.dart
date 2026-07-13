import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

File _projectFile(String relativePath) {
  var directory = Directory.current;
  while (true) {
    final candidate = File('${directory.path}/$relativePath');
    if (candidate.existsSync()) return candidate;
    final parent = directory.parent;
    if (parent.path == directory.path) {
      throw StateError('Project file not found: $relativePath');
    }
    directory = parent;
  }
}

void main() {
  test('queue loads are serialized and stale generations cannot commit', () {
    final source = _projectFile(
      'lib/data/audio/just_audio_controller.dart',
    ).readAsStringSync();

    expect(source, contains('Future<void> _loadTail'));
    expect(source, contains('final generation = ++_loadGeneration'));
    expect(source, contains('final operation = _loadTail.then'));
    expect(source, contains('if (generation != _loadGeneration) return false'));
    expect(
      source.indexOf('await _player.setAudioSources'),
      lessThan(source.indexOf('_tracks = nextTracks')),
    );
  });
}
