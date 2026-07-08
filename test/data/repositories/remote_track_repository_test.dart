import 'package:flutter_test/flutter_test.dart';
import 'package:edmm/domain/models/cloudinary_category.dart';
import 'package:edmm/domain/models/track.dart';
import 'package:edmm/domain/repositories/track_repository.dart';
import 'package:edmm/domain/result.dart';
import 'package:edmm/data/repositories/remote_track_repository.dart';
import 'package:edmm/data/services/track_api_service.dart';

Track _audio(String id) => Track(
      id: id,
      source: 'cloudinary',
      title: id,
      artistId: 'a',
      artistName: 'A',
      durationMs: 1,
      streamUrl: 'u',
      metadata: const {'resourceType': 'video'},
    );

class _FakeApi implements TrackApiService {
  _FakeApi(this.next);
  final Map<String, List<Track>> Function() next;
  int callCount = 0;

  @override
  Future<List<Track>> fetchCatalog({
    required CloudinaryCategory category,
    String query = '',
  }) async {
    callCount += 1;
    return next()['${category.wire}|$query']!;
  }
}

void main() {
  test('merges audio and image tracks and caches by category/query', () async {
    final api = _FakeApi(() => {
          'pop|': [_audio('Bloom')],
          'pop|ambient': [_audio('Ambient')],
        });
    final TrackRepository repo = RemoteTrackRepository(api);
    final r1 = await repo.getCatalog(category: CloudinaryCategory.pop, query: '');
    expect(r1, isA<Ok<List<Track>>>());
    expect((r1 as Ok<List<Track>>).value.single.id, 'Bloom');

    final r2 = await repo.getCatalog(category: CloudinaryCategory.pop, query: 'ambient');
    expect((r2 as Ok<List<Track>>).value.single.id, 'Ambient');

    final r3 = await repo.getCatalog(category: CloudinaryCategory.pop, query: '');
    expect((r3 as Ok<List<Track>>).value.single.id, 'Bloom');
    expect(api.callCount, 2);
  });

  test('audio failure yields Err(ServerFailure)', () async {
    final api = _FakeApi(() => throw TrackApiException(statusCode: 500));
    final TrackRepository repo = RemoteTrackRepository(api);
    final r = await repo.getCatalog(category: CloudinaryCategory.edm);
    expect(r, isA<Err<List<Track>>>());
    expect((r as Err<List<Track>>).error, isA<ServerFailure>());
  });
}
