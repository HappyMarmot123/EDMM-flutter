import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../domain/audio/audio_controller.dart';
import '../../../domain/models/cloudinary_category.dart';
import '../../../domain/models/track.dart';
import '../../../domain/repositories/track_repository.dart';
import '../../../domain/result.dart';
import '../../../domain/playback/playback_snapshot.dart';

enum CatalogView { pop, edm }

enum CatalogStatus { loading, data, empty, searchEmpty, error }

class CatalogSearchViewModel extends ChangeNotifier {
  CatalogSearchViewModel(
    this._repo,
    this._audio, {
    CatalogView? initialView,
    String? initialTrackId,
    this.searchDebounce = const Duration(milliseconds: 400),
  })  : _initialTrackId = initialTrackId,
        selectedTrackId = initialTrackId,
        _view = initialView ?? CatalogView.pop,
        _hasExplicitInitialView = initialView != null;

  final TrackRepository _repo;
  final AudioController _audio;
  final String? _initialTrackId;
  final bool _hasExplicitInitialView;
  final Duration searchDebounce;

  CatalogView _view;
  String query = '';
  String _appliedQuery = '';

  CatalogStatus status = CatalogStatus.loading;
  List<Track> tracks = const [];
  Map<CatalogView, List<Track>> _lastSuccessful = const {};
  Map<CatalogView, Set<String>> _baseIdsByView = const {};
  Map<CatalogView, int> counts = const {};
  String? selectedTrackId;
  String? currentTrackId;
  bool isCurrentPlaying = false;
  Failure? error;

  Timer? _debounce;
  StreamSubscription<PlaybackSnapshot>? _snapshotSub;

  CatalogView get view => _view;

  Future<void> init() async {
    _snapshotSub ??= _audio.snapshot.listen((snapshot) {
      final nextCurrentTrackId = snapshot.currentTrack?.id;
      final nextIsPlaying = snapshot.isPlaying;
      final changed = currentTrackId != nextCurrentTrackId ||
          isCurrentPlaying != nextIsPlaying;
      if (!changed) return;
      currentTrackId = nextCurrentTrackId;
      isCurrentPlaying = nextIsPlaying;
      notifyListeners();
    });

    await Future.wait([
      _prefetchBaseCatalog(CatalogView.pop),
      _prefetchBaseCatalog(CatalogView.edm),
    ]);

    if (_initialTrackId != null && !_hasExplicitInitialView) {
      final inEdm = (_baseIdsByView[CatalogView.edm] ?? const <String>{})
          .contains(_initialTrackId);
      if (inEdm) {
        _view = CatalogView.edm;
      }
    }

    await _loadCurrent();
  }

  Future<void> _prefetchBaseCatalog(CatalogView view) async {
    final result = await _repo.getCatalog(
      category: view._toCloudinaryCategory,
      query: '',
    );
    if (result case Ok(:final value)) {
      final ids = value.map((track) => track.id).toSet();
      _baseIdsByView = {..._baseIdsByView, view: ids};
      counts = {...counts, view: ids.length};
      notifyListeners();
    }
  }

  Future<void> setView(CatalogView next) async {
    if (next == _view) return;
    _view = next;
    _appliedQuery = query.trim();
    selectedTrackId = null;
    tracks = _lastSuccessful[_view] ?? const [];
    await _loadCurrent();
  }

  void setQuery(String value) {
    query = value;
    final trimmed = query.trim();
    _debounce?.cancel();
    if (trimmed.isEmpty) {
      _appliedQuery = '';
      unawaited(_loadCurrent());
      return;
    }
    _debounce = Timer(searchDebounce, () {
      if (_appliedQuery == trimmed) return;
      _appliedQuery = trimmed;
      unawaited(_loadCurrent());
    });
  }

  void clearSearch() {
    setQuery('');
  }

  Future<void> retry() => _loadCurrent(forceRefresh: true);

  Future<void> _loadCurrent({bool forceRefresh = false}) async {
    // 이미 보여줄 목록이 있으면(검색어 입력/탭 재로드) 스피너로 깜빡이지 않는다.
    if (tracks.isEmpty) {
      status = CatalogStatus.loading;
    }
    error = null;
    notifyListeners();

    final result = await _repo.getCatalog(
      category: _view._toCloudinaryCategory,
      query: _appliedQuery,
      forceRefresh: forceRefresh,
    );

    switch (result) {
      case Ok(:final value):
        _lastSuccessful = {..._lastSuccessful, _view: value};
        tracks = value;
        error = null;
        if (value.isEmpty) {
          status = _appliedQuery.isEmpty
              ? CatalogStatus.empty
              : CatalogStatus.searchEmpty;
        } else {
          status = CatalogStatus.data;
        }
      case Err(error: final failure):
        error = failure;
        tracks = _lastSuccessful[_view] ?? const [];
        status = CatalogStatus.error;
    }

    notifyListeners();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _snapshotSub?.cancel();
    super.dispose();
  }
}

extension on CatalogView {
  CloudinaryCategory get _toCloudinaryCategory => switch (this) {
        CatalogView.pop => CloudinaryCategory.pop,
        CatalogView.edm => CloudinaryCategory.edm,
      };
}
