import '../../domain/logic/artwork_merger.dart';
import '../../domain/models/track.dart';
import '../../domain/models/cloudinary_category.dart';
import '../../domain/repositories/track_repository.dart';
import '../../domain/result.dart';
import '../services/track_api_service.dart';

class RemoteTrackRepository implements TrackRepository {
  RemoteTrackRepository(this._api);
  final TrackApiService _api;
  final Map<String, List<Track>> _cache = {};

  @override
  Future<Result<List<Track>>> getCatalog({
    required CloudinaryCategory category,
    String query = '',
    bool forceRefresh = false,
  }) async {
    final normalizedQuery = query.trim();
    final key = '${category.wire}::$normalizedQuery';

    final cached = _cache[key];
    if (!forceRefresh && cached != null) return Ok(cached);

    try {
      final raw = await _api.fetchCatalog(category: category, query: normalizedQuery);
      final audio = <Track>[];
      final images = <Track>[];
      for (final track in raw) {
        final resourceType =
            (track.metadata['resourceType'] as String?)?.toLowerCase();
        if (resourceType == 'image') {
          images.add(track);
        } else {
          audio.add(track);
        }
      }
      final merged = ArtworkMerger.merge(audio, images);
      _cache[key] = merged;
      return Ok(merged);
    } on TrackApiException catch (e) {
      final code = e.statusCode;
      return Err(code != null ? ServerFailure(code) : NetworkFailure(e.cause ?? 'network'));
    } catch (e) {
      return Err(ParseFailure(e));
    }
  }
}
