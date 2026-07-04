import '../../domain/logic/artwork_merger.dart';
import '../../domain/models/track.dart';
import '../../domain/repositories/track_repository.dart';
import '../../domain/result.dart';
import '../services/track_api_service.dart';

class RemoteTrackRepository implements TrackRepository {
  RemoteTrackRepository(this._api);
  final TrackApiService _api;
  List<Track>? _cache;

  @override
  Future<Result<List<Track>>> getTracks({bool forceRefresh = false}) async {
    final cached = _cache;
    if (!forceRefresh && cached != null) return Ok(cached);

    // 이미지는 best-effort: 실패 시 빈 목록으로 병합.
    final imagesFuture = _api.fetchImageTracks().catchError((_) => <Track>[]);
    try {
      final audio = await _api.fetchAudioTracks();
      final images = await imagesFuture;
      final merged = ArtworkMerger.merge(audio, images);
      _cache = merged;
      return Ok(merged);
    } on TrackApiException catch (e) {
      final code = e.statusCode;
      return Err(code != null ? ServerFailure(code) : NetworkFailure(e.cause ?? 'network'));
    } catch (e) {
      return Err(ParseFailure(e));
    }
  }
}
