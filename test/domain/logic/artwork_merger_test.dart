// test/domain/logic/artwork_merger_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:edmm/domain/models/track.dart';
import 'package:edmm/domain/logic/artwork_merger.dart';

Track audio(String title, String artist) => Track(
      id: 'a:$title', source: 'cloudinary', title: title,
      artistId: 'cloudinary:$artist', artistName: artist,
      durationMs: 1000, streamUrl: 'https://x/$title.m4a',
      metadata: const {'resourceType': 'video'});

Track image(String title, String artist, String url) => Track(
      id: 'i:$title', source: 'cloudinary', title: title,
      artistId: 'cloudinary:$artist', artistName: artist,
      durationMs: 0, artworkUrl: url, streamUrl: url,
      metadata: const {'resourceType': 'image'});

void main() {
  test('normalizeForMatching lowercases, strips ext and punctuation', () {
    expect(ArtworkMerger.normalizeForMatching('  Bloom!.m4a '), 'bloom');
  });

  test('merge fills artworkUrl by title/artist match', () {
    final merged = ArtworkMerger.merge(
      [audio('Bloom', 'Feint x DJ Sally')],
      [image('Bloom', 'Feint x DJ Sally', 'https://art/bloom.jpg')],
    );
    expect(merged.single.artworkUrl, 'https://art/bloom.jpg');
  });

  test('merge leaves artwork empty when no match', () {
    final merged = ArtworkMerger.merge([audio('Solo', 'X')], [image('Other', 'Y', 'u')]);
    expect(merged.single.artworkUrl, '');
  });

  test('merge preserves existing artwork', () {
    final withArt = audio('Bloom', 'Z').copyWith(artworkUrl: 'keep');
    final merged = ArtworkMerger.merge([withArt], [image('Bloom', 'Z', 'new')]);
    expect(merged.single.artworkUrl, 'keep');
  });
}
