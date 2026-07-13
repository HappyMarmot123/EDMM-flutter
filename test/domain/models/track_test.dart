// test/domain/models/track_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:edmm/domain/models/track.dart';

void main() {
  final json = <String, dynamic>{
    'id': 'cloudinary:abc',
    'source': 'cloudinary',
    'title': 'Bloom',
    'artistId': 'cloudinary:Feint x DJ Sally',
    'artistName': 'Feint x DJ Sally',
    'albumName': 'media-pipeline',
    'artworkUrl': '',
    'durationMs': 219413,
    'streamUrl': 'https://res.cloudinary.com/db5yvwr1y/video/upload/x.m4a',
    'metadata': {
      'resourceType': 'video',
      'publicId': 'edmm/media-pipeline/Feint x DJ Sally - Bloom',
    },
  };

  test('fromJson maps all fields', () {
    final t = Track.fromJson(json);
    expect(t.id, 'cloudinary:abc');
    expect(t.title, 'Bloom');
    expect(t.durationMs, 219413);
    expect(t.duration, const Duration(milliseconds: 219413));
    expect(t.metadata['resourceType'], 'video');
  });

  test('isPlayable true for audio with streamUrl, false for image', () {
    expect(Track.fromJson(json).isPlayable, isTrue);
    final image = Track.fromJson({
      ...json,
      'metadata': {'resourceType': 'image'},
    });
    expect(image.isPlayable, isFalse);
    final noStream = Track.fromJson({...json, 'streamUrl': ''});
    expect(noStream.isPlayable, isFalse);
  });

  test('isPlayable requires an absolute HTTP(S) stream URL', () {
    final relative = Track.fromJson({...json, 'streamUrl': '/audio/x.m4a'});
    final opaque = Track.fromJson({...json, 'streamUrl': 'u'});
    final ftp = Track.fromJson({...json, 'streamUrl': 'ftp://audio/x.m4a'});
    final https = Track.fromJson({
      ...json,
      'streamUrl': 'https://audio.example/x.m4a',
    });

    expect(relative.isPlayable, isFalse);
    expect(opaque.isPlayable, isFalse);
    expect(ftp.isPlayable, isFalse);
    expect(https.isPlayable, isTrue);
  });
}
