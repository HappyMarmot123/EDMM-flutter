import 'package:flutter/foundation.dart';
import '../../../domain/models/track.dart';
import '../../../domain/repositories/track_repository.dart';
import '../../../domain/result.dart';

enum TrackListStatus { loading, data, empty, error }

class TrackListViewModel extends ChangeNotifier {
  TrackListViewModel(this._repo);
  final TrackRepository _repo;

  TrackListStatus status = TrackListStatus.loading;
  List<Track> tracks = const [];
  Failure? error;

  Future<void> load({bool forceRefresh = false}) async {
    status = TrackListStatus.loading;
    error = null;
    tracks = const [];
    notifyListeners();
    final result = await _repo.getTracks(forceRefresh: forceRefresh);
    switch (result) {
      case Ok(:final value):
        tracks = value;
        status = value.isEmpty ? TrackListStatus.empty : TrackListStatus.data;
      case Err(:final error):
        this.error = error;
        status = TrackListStatus.error;
    }
    notifyListeners();
  }
}
