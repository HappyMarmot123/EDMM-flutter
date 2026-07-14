import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../domain/audio/audio_controller.dart';
import '../../../domain/models/cloudinary_category.dart';
import '../../../domain/models/track.dart';
import '../../../domain/repositories/track_repository.dart';
import '../../../domain/repositories/local_library_repository.dart';
import '../../../domain/result.dart';
import '../../../domain/playback/playback_snapshot.dart';
import '../../../domain/telemetry/catalog_search_telemetry.dart';

enum CatalogView { pop, edm, recent }

enum CatalogStatus { loading, data, empty, searchEmpty, error }

class CatalogSearchViewModel extends ChangeNotifier {
  CatalogSearchViewModel(
    this._repo,
    this._audio,
    this._localLibrary, {
    CatalogView? initialView,
    String? initialTrackId,
    CatalogSearchTelemetrySink? telemetry,
    this.searchDebounce = const Duration(milliseconds: 400),
  }) : _initialTrackId = initialTrackId,
       selectedTrackId = initialTrackId,
       _view = initialView ?? CatalogView.pop,
       _hasExplicitInitialView = initialView != null,
       _telemetry = telemetry ?? const NoopCatalogSearchTelemetrySink();

  final TrackRepository _repo;
  final AudioController _audio;
  final LocalLibraryRepository _localLibrary;
  final String? _initialTrackId;
  final bool _hasExplicitInitialView;
  final Duration searchDebounce;
  final CatalogSearchTelemetrySink _telemetry;

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
  bool _disposed = false;
  int _requestGeneration = 0;

  CatalogView get view => _view;

  Future<void> init() async {
    _snapshotSub ??= _audio.snapshot.listen((snapshot) {
      final nextCurrentTrackId = snapshot.currentTrack?.id;
      final nextIsPlaying = snapshot.isPlaying;
      final changed =
          currentTrackId != nextCurrentTrackId ||
          isCurrentPlaying != nextIsPlaying;
      if (!changed) return;
      currentTrackId = nextCurrentTrackId;
      isCurrentPlaying = nextIsPlaying;
      notifyListeners();
    });

    await Future.wait([
      _runPrefetch(() => _prefetchBaseCatalog(CatalogView.pop)),
      _runPrefetch(() => _prefetchBaseCatalog(CatalogView.edm)),
      _runPrefetch(_prefetchRecentCount),
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
    final category = view._remoteCategory;
    if (category == null) return;

    final result = await _repo.getCatalog(category: category, query: '');
    if (result case Ok(:final value)) {
      final ids = value.map((track) => track.id).toSet();
      _baseIdsByView = {..._baseIdsByView, view: ids};
      counts = {...counts, view: ids.length};
      notifyListeners();
    }
  }

  Future<void> _prefetchRecentCount() async {
    final recentIds = await _localLibrary.getRecentTrackIds();
    final cachedTracks = await _localLibrary.getCachedTracks(recentIds);
    counts = {...counts, CatalogView.recent: cachedTracks.length};
    notifyListeners();
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

  Future<void> retry() => _loadCurrent(forceRefresh: true, isRetry: true);

  Future<void> _loadCurrent({
    bool forceRefresh = false,
    bool isRetry = false,
  }) async {
    final requestGeneration = ++_requestGeneration;
    final requestedView = _view;
    final requestedQuery = _appliedQuery;
    _telemetry.emit(
      CatalogSearchTelemetryEvent(
        name: CatalogSearchTelemetryEventNames.requested,
        payload: CatalogSearchTelemetryPayload.base(
          view: requestedView.name,
          query: requestedQuery,
          isRetry: isRetry,
          forceRefresh: forceRefresh,
        ),
      ),
    );
    if (isRetry) {
      _telemetry.emit(
        CatalogSearchTelemetryEvent(
          name: CatalogSearchTelemetryEventNames.retryRequested,
          payload: {
            ...CatalogSearchTelemetryPayload.base(
              view: requestedView.name,
              query: requestedQuery,
              isRetry: true,
              forceRefresh: forceRefresh,
            ),
          },
        ),
      );
    }

    // 이미 보여줄 목록이 있으면(검색어 입력/탭 재로드) 스피너로 깜빡이지 않는다.
    if (tracks.isEmpty) {
      status = CatalogStatus.loading;
    }
    error = null;
    notifyListeners();

    final category = requestedView._remoteCategory;
    if (category == null) {
      try {
        await _loadRecent(
          generation: requestGeneration,
          view: requestedView,
          query: requestedQuery,
        );
      } catch (cause) {
        if (_isActiveRequest(
          requestGeneration,
          requestedView,
          requestedQuery,
        )) {
          _applyRecentFailure(requestedView, requestedQuery, cause);
        }
      }
      if (!_isActiveRequest(requestGeneration, requestedView, requestedQuery)) {
        return;
      }
      notifyListeners();
      return;
    }

    final result = await _repo.getCatalog(
      category: category,
      query: requestedQuery,
      forceRefresh: forceRefresh,
    );
    if (!_isActiveRequest(requestGeneration, requestedView, requestedQuery)) {
      return;
    }

    switch (result) {
      case Ok(:final value):
        _lastSuccessful = {..._lastSuccessful, requestedView: value};
        _telemetry.emit(
          CatalogSearchTelemetryEvent(
            name: CatalogSearchTelemetryEventNames.succeeded,
            payload: CatalogSearchTelemetryPayload.successPayload(
              view: requestedView.name,
              query: requestedQuery,
              resultCount: value.length,
            ),
          ),
        );
        tracks = value;
        error = null;
        if (value.isEmpty) {
          status = requestedQuery.isEmpty
              ? CatalogStatus.empty
              : CatalogStatus.searchEmpty;
        } else {
          status = CatalogStatus.data;
        }
      case Err(error: final failure):
        final hadStale = _lastSuccessful.containsKey(requestedView);
        final staleTracks = _lastSuccessful[requestedView];

        if (hadStale) {
          tracks = staleTracks ?? const [];
          _telemetry.emit(
            CatalogSearchTelemetryEvent(
              name: CatalogSearchTelemetryEventNames.staleFallbackUsed,
              payload: {
                ...CatalogSearchTelemetryPayload.base(
                  view: requestedView.name,
                  query: requestedQuery,
                ),
                CatalogSearchTelemetryPayload.staleFallback: true,
                CatalogSearchTelemetryPayload.resultCount:
                    staleTracks?.length ?? 0,
              },
            ),
          );
        } else {
          tracks = const [];
        }

        error = failure;
        status = CatalogStatus.error;
        final failurePayload = CatalogSearchTelemetryPayload.failurePayload(
          view: requestedView.name,
          query: requestedQuery,
          failure: failure,
          staleFallback: hadStale,
        );
        _telemetry.emit(
          CatalogSearchTelemetryEvent(
            name: CatalogSearchTelemetryEventNames.failed,
            payload: {
              ...failurePayload,
              CatalogSearchTelemetryPayload.errorState: hadStale
                  ? 'error_with_stale'
                  : 'error_without_stale',
            },
          ),
        );
    }

    notifyListeners();
  }

  Future<void> _loadRecent({
    required int generation,
    required CatalogView view,
    required String query,
  }) async {
    final recentIds = await _localLibrary.getRecentTrackIds();
    final cachedTracks = await _localLibrary.getCachedTracks(recentIds);
    if (!_isActiveRequest(generation, view, query)) return;
    final filteredTracks = _filterLocalTracks(cachedTracks, query);

    _lastSuccessful = {..._lastSuccessful, CatalogView.recent: cachedTracks};
    counts = {...counts, CatalogView.recent: cachedTracks.length};
    tracks = filteredTracks;
    error = null;
    status = filteredTracks.isEmpty
        ? (query.isEmpty ? CatalogStatus.empty : CatalogStatus.searchEmpty)
        : CatalogStatus.data;
    _telemetry.emit(
      CatalogSearchTelemetryEvent(
        name: CatalogSearchTelemetryEventNames.succeeded,
        payload: CatalogSearchTelemetryPayload.successPayload(
          view: view.name,
          query: query,
          resultCount: filteredTracks.length,
        ),
      ),
    );
  }

  Future<void> _runPrefetch(Future<void> Function() action) async {
    try {
      await action();
    } catch (_) {
      // Counts and seed detection are best-effort; the active load owns errors.
    }
  }

  void _applyRecentFailure(CatalogView view, String query, Object cause) {
    final failure = ParseFailure(cause);
    final staleTracks = _lastSuccessful[view];
    final hadStale = staleTracks != null;
    tracks = _filterLocalTracks(staleTracks ?? const [], query);
    error = failure;
    status = CatalogStatus.error;
    _telemetry.emit(
      CatalogSearchTelemetryEvent(
        name: CatalogSearchTelemetryEventNames.failed,
        payload: {
          ...CatalogSearchTelemetryPayload.failurePayload(
            view: view.name,
            query: query,
            failure: failure,
            staleFallback: hadStale,
          ),
          CatalogSearchTelemetryPayload.errorState: hadStale
              ? 'error_with_stale'
              : 'error_without_stale',
        },
      ),
    );
  }

  bool _isActiveRequest(int generation, CatalogView view, String query) =>
      !_disposed &&
      generation == _requestGeneration &&
      view == _view &&
      query == _appliedQuery;

  List<Track> _filterLocalTracks(List<Track> source, String query) {
    final normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.isEmpty) return source;
    return source
        .where((track) => _matchesLocalQuery(track, normalizedQuery))
        .toList(growable: false);
  }

  bool _matchesLocalQuery(Track track, String query) {
    return track.id.toLowerCase().contains(query) ||
        track.title.toLowerCase().contains(query) ||
        track.artistName.toLowerCase().contains(query);
  }

  @override
  void notifyListeners() {
    if (_disposed) return;
    super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _requestGeneration += 1;
    _debounce?.cancel();
    _snapshotSub?.cancel();
    super.dispose();
  }
}

extension on CatalogView {
  CloudinaryCategory? get _remoteCategory => switch (this) {
    CatalogView.pop => CloudinaryCategory.pop,
    CatalogView.edm => CloudinaryCategory.edm,
    CatalogView.recent => null,
  };
}
