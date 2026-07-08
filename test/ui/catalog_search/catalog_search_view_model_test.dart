import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:edmm/domain/audio/audio_controller.dart';
import 'package:edmm/domain/models/cloudinary_category.dart';
import 'package:edmm/domain/models/track.dart';
import 'package:edmm/domain/playback/playback_snapshot.dart';
import 'package:edmm/domain/repositories/track_repository.dart';
import 'package:edmm/domain/result.dart';
import 'package:edmm/domain/telemetry/catalog_search_telemetry.dart';
import 'package:edmm/ui/catalog_search/view_model/catalog_search_view_model.dart';

Track _t(String id) => Track(
  id: id,
  source: 'cloudinary',
  title: 'Song $id',
  artistId: 'a',
  artistName: 'A',
  durationMs: 1,
  streamUrl: 'u',
  metadata: const {'resourceType': 'video'},
);

class _Repo implements TrackRepository {
  _Repo(this.handler);
  Result<List<Track>> Function(CloudinaryCategory category, String query)
  handler;
  final List<String> calls = [];

  @override
  Future<Result<List<Track>>> getCatalog({
    required CloudinaryCategory category,
    String query = '',
    bool forceRefresh = false,
  }) async {
    calls.add('${category.wire}|$query');
    return handler(category, query);
  }
}

class _Audio implements AudioController {
  final snap = StreamController<PlaybackSnapshot>.broadcast();
  @override
  Stream<PlaybackSnapshot> get snapshot => snap.stream;
  @override
  Stream<Duration> get position => Stream<Duration>.empty();
  @override
  bool get isShuffleEnabled => false;
  @override
  double get volume => 1.0;
  @override
  Future<void> loadQueue(List<Track> tracks, {int initialIndex = 0}) async {}
  @override
  Future<void> setShuffleEnabled(bool enabled) async {}
  @override
  Future<void> setVolume(double volume) async {}
  @override
  Future<void> setMute(bool muted) async {}
  @override
  Future<void> play() async {}
  @override
  Future<void> pause() async {}
  @override
  Future<void> seek(Duration position) async {}
  @override
  Future<void> next() async {}
  @override
  Future<void> previous() async {}
  @override
  Future<void> dispose() async => snap.close();
}

class _TelemetryRecorder extends CatalogSearchTelemetrySink {
  final events = <CatalogSearchTelemetryEvent>[];

  @override
  void emit(CatalogSearchTelemetryEvent event) => events.add(event);

  void clear() => events.clear();
}

CatalogSearchViewModel _vm(
  _Repo repo,
  _Audio audio, {
  CatalogView? initialView,
  String? initialTrackId,
  CatalogSearchTelemetrySink? telemetry,
}) => CatalogSearchViewModel(
  repo,
  audio,
  initialView: initialView,
  initialTrackId: initialTrackId,
  telemetry: telemetry,
  searchDebounce: Duration.zero,
);

Future<void> _tick() => Future<void>.delayed(const Duration(milliseconds: 20));

void main() {
  test('init loads active view and fills counts for both catalogs', () async {
    final repo = _Repo(
      (c, q) =>
          Ok(c == CloudinaryCategory.pop ? [_t('1'), _t('2')] : [_t('9')]),
    );
    final vm = _vm(repo, _Audio());
    await vm.init();
    expect(vm.status, CatalogStatus.data);
    expect(vm.tracks.length, 2);
    expect(vm.counts[CatalogView.pop], 2);
    expect(vm.counts[CatalogView.edm], 1);
  });

  test(
    'seed selects the view whose catalog contains the initial track',
    () async {
      final repo = _Repo(
        (c, q) => Ok(c == CloudinaryCategory.edm ? [_t('x')] : [_t('1')]),
      );
      final vm = _vm(repo, _Audio(), initialTrackId: 'x');
      await vm.init();
      expect(vm.view, CatalogView.edm);
      expect(vm.selectedTrackId, 'x');
    },
  );

  test('setView switches catalog and loads it', () async {
    final repo = _Repo(
      (c, q) => Ok(c == CloudinaryCategory.edm ? [_t('9')] : [_t('1')]),
    );
    final vm = _vm(repo, _Audio());
    await vm.init();
    await vm.setView(CatalogView.edm);
    expect(vm.view, CatalogView.edm);
    expect(vm.tracks.single.id, '9');
  });

  test('setQuery debounces to a single search with the final value', () async {
    final repo = _Repo((c, q) => Ok(q == 'house' ? [_t('h')] : [_t('1')]));
    final vm = CatalogSearchViewModel(
      repo,
      _Audio(),
      initialView: CatalogView.pop,
      searchDebounce: const Duration(milliseconds: 60),
    );
    await vm.init();
    repo.calls.clear();

    vm.setQuery('h');
    vm.setQuery('ho');
    vm.setQuery('house');
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(repo.calls, isEmpty); // 아직 디바운스 중

    await Future<void>.delayed(const Duration(milliseconds: 60));
    expect(repo.calls, ['pop|house']);
    expect(vm.tracks.single.id, 'h');
  });

  test('empty result with a query -> searchEmpty; clearing -> data', () async {
    final repo = _Repo((c, q) => Ok(q == 'zzz' ? <Track>[] : [_t('1')]));
    final vm = _vm(repo, _Audio());
    await vm.init();
    expect(vm.status, CatalogStatus.data);

    vm.setQuery('zzz');
    await _tick();
    expect(vm.status, CatalogStatus.searchEmpty);

    vm.clearSearch();
    await _tick();
    expect(vm.status, CatalogStatus.data);
  });

  test('error keeps the last successful list as stale data', () async {
    var fail = false;
    final repo = _Repo(
      (c, q) =>
          fail ? const Err<List<Track>>(NetworkFailure('x')) : Ok([_t('1')]),
    );
    final vm = _vm(repo, _Audio());
    await vm.init();
    expect(vm.tracks.single.id, '1');

    fail = true;
    await vm.retry();
    expect(vm.status, CatalogStatus.error);
    expect(vm.tracks.single.id, '1'); // stale 유지
    expect(vm.error, isA<NetworkFailure>());
  });

  test('failure emits classified events and stale fallback metadata', () async {
    var fail = false;
    final repo = _Repo(
      (c, q) =>
          fail ? const Err<List<Track>>(NetworkFailure('x')) : Ok([_t('1')]),
    );
    final telemetry = _TelemetryRecorder();
    final vm = _vm(repo, _Audio(), telemetry: telemetry);
    await vm.init();
    telemetry.clear();

    fail = true;
    await vm.retry();

    final failureEvents = telemetry.events
        .where((event) => event.name == CatalogSearchTelemetryEventNames.failed)
        .toList();
    final fallbackEvents = telemetry.events
        .where(
          (event) =>
              event.name == CatalogSearchTelemetryEventNames.staleFallbackUsed,
        )
        .toList();

    expect(failureEvents, hasLength(1));
    expect(fallbackEvents, hasLength(1));
    expect(vm.status, CatalogStatus.error);
    expect(vm.tracks.single.id, '1'); // stale 유지

    final failure = failureEvents.single.payload;
    expect(failure['failure_category'], 'network');
    expect(failure['failure_retryable'], isTrue);
    expect(failure['query_length'], 0);
    expect(failure['error_state'], 'error_with_stale');
    expect(failure['stale_fallback'], isTrue);
  });

  test('retry request is classified and emitted separately', () async {
    final repo = _Repo((c, q) => const Err<List<Track>>(ServerFailure(503)));
    final telemetry = _TelemetryRecorder();
    final vm = _vm(repo, _Audio(), telemetry: telemetry);
    await vm.init();
    telemetry.clear();

    await vm.retry();

    final requested = telemetry.events.lastWhere(
      (event) => event.name == CatalogSearchTelemetryEventNames.requested,
    );
    final retry = telemetry.events.firstWhere(
      (event) => event.name == CatalogSearchTelemetryEventNames.retryRequested,
    );

    expect(requested.payload['is_retry'], isTrue);
    expect(requested.payload['force_refresh'], isTrue);
    expect(retry.payload['is_retry'], isTrue);
    expect(retry.payload['force_refresh'], isTrue);
    expect(vm.error, isA<ServerFailure>());
  });

  test('failure state is classified as retryable by status code', () async {
    final repo = _Repo((c, q) => const Err<List<Track>>(ServerFailure(404)));
    final telemetry = _TelemetryRecorder();
    final vm = _vm(repo, _Audio(), telemetry: telemetry);

    await vm.init();

    final failureEvents = telemetry.events
        .where((event) => event.name == CatalogSearchTelemetryEventNames.failed)
        .toList();
    expect(failureEvents, hasLength(1));
    expect(failureEvents.single.payload['failure_category'], 'server');
    expect(failureEvents.single.payload['failure_status_code'], 404);
    expect(failureEvents.single.payload['failure_retryable'], isFalse);
    expect(vm.status, CatalogStatus.error);
  });

  test('snapshot stream updates current track id and playing flag', () async {
    final audio = _Audio();
    final vm = _vm(_Repo((c, q) => Ok([_t('1')])), audio);
    await vm.init();
    audio.snap.add(
      PlaybackSnapshot(currentTrack: _t('1'), status: PlaybackStatus.playing),
    );
    await _tick();
    expect(vm.currentTrackId, '1');
    expect(vm.isCurrentPlaying, isTrue);
  });
}
