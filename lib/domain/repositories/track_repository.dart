import '../models/track.dart';
import '../result.dart';

abstract class TrackRepository {
  Future<Result<List<Track>>> getTracks({bool forceRefresh = false});
}
