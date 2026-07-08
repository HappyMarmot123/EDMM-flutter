import '../models/track.dart';
import '../models/cloudinary_category.dart';
import '../result.dart';

abstract class TrackRepository {
  Future<Result<List<Track>>> getCatalog({
    required CloudinaryCategory category,
    String query = '',
    bool forceRefresh = false,
  });
}
