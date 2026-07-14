# EDMM Flutter 코어 재생 슬라이스 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** EDMM 웹의 음악 재생 도메인을 Flutter 모바일 앱의 "코어 재생 수직 슬라이스"(목록·재생·백그라운드·미디어세션)로 이식한다.

**Architecture:** 계층형 MVVM(UI→Domain←Data) + Provider DI + Repository. UI는 `just_audio`/`http`를 직접 모르고 추상 인터페이스(`AudioController`, `TrackRepository`)로만 접근한다. 데이터는 배포된 BFF(`/video`,`/image`)를 병렬 조회 후 순수 `ArtworkMerger`로 아트워크를 병합한다.

**Tech Stack:** Flutter ≥3.38 / Dart ≥3.12.2, `just_audio ^0.10.6`, `audio_service ^0.18.19`, `provider`, `go_router`, `http`, `freezed`(4.0.0-dev.3) + `json_serializable`.

**연계 문서:** [스크리닝](../specs/2026-07-04-edmm-flutter-core-playback-screening.md) · [기획설계](../specs/2026-07-04-edmm-flutter-core-playback-design.md) · [코드베이스 정합](../specs/2026-07-04-edmm-flutter-core-playback-codebase.md) · [문서검토](../specs/2026-07-04-edmm-flutter-core-playback-review.md)

## Global Constraints

- Dart SDK `>=3.12.2 <4.0.0`, Flutter `>=3.38.0`. 신규 의존성은 `just_audio ^0.10.6`, `audio_service ^0.18.19` 두 개로 한정.
- freezed는 **4.0.0-dev.3**(프리릴리스). 모델은 `abstract class T with _$T` 구문. `Result`/`Failure`/`PlaybackSnapshot`은 freezed 대신 **손수 작성한 Dart 3 `sealed`/일반 클래스**로 둔다.
- BFF base URL = `https://edmm.vercel.app`. 오디오 엔드포인트 = `/api/cloudinary/tracks/video?filterPlayable=true`(오디오), `/api/cloudinary/tracks/image`(아트워크).
- 화려한 UI 금지 — 무장식 Material 위젯만. 성능: **position 갱신은 슬라이더만 리빌드**(전체 화면 리빌드 금지).
- 아키텍처: UI→Domain←Data 단방향, ViewModel=`ChangeNotifier`, View=`StatefulWidget`(생성자 주입, `dispose` 정리) — 현 스캐폴드 관례 유지.
- image 조회 실패는 **best-effort**(빈 목록으로 병합), 오디오 조회 실패만 에러로 취급.
- 각 태스크는 `flutter test <파일>`로 통과 확인 후 커밋. 전체 게이트는 `flutter analyze`(무경고) + `flutter test`(전체 통과).

---

### Task 1: 도메인 기반 — AppConfig · Result · Failure

**Files:**
- Create: `lib/config/app_config.dart`
- Create: `lib/domain/result.dart`
- Test: `test/domain/result_test.dart`

**Interfaces:**
- Produces:
  - `class AppConfig { final String bffBaseUrl; final Duration timeout; const AppConfig({this.bffBaseUrl = 'https://edmm.vercel.app', this.timeout = const Duration(seconds: 15)}); }`
  - `sealed class Result<T>`; `class Ok<T> extends Result<T> { final T value; const Ok(this.value); }`; `class Err<T> extends Result<T> { final Failure error; const Err(this.error); }`
  - `sealed class Failure`; `class NetworkFailure extends Failure { final Object cause; }`; `class ServerFailure extends Failure { final int statusCode; }`; `class ParseFailure extends Failure { final Object cause; }`

- [ ] **Step 1: Write the failing test**

```dart
// test/domain/result_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:edmm/domain/result.dart';

void main() {
  test('Ok holds value, Err holds failure, switch discriminates', () {
    Result<int> ok = const Ok(42);
    Result<int> err = Err(ServerFailure(502));

    String describe(Result<int> r) => switch (r) {
      Ok(:final value) => 'ok:$value',
      Err(:final error) => switch (error) {
        ServerFailure(:final statusCode) => 'server:$statusCode',
        NetworkFailure() => 'network',
        ParseFailure() => 'parse',
      },
    };

    expect(describe(ok), 'ok:42');
    expect(describe(err), 'server:502');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/domain/result_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:edmm/domain/result.dart'`.

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/config/app_config.dart
class AppConfig {
  const AppConfig({
    this.bffBaseUrl = 'https://edmm.vercel.app',
    this.timeout = const Duration(seconds: 15),
  });
  final String bffBaseUrl;
  final Duration timeout;
}
```

```dart
// lib/domain/result.dart
sealed class Result<T> {
  const Result();
}

class Ok<T> extends Result<T> {
  const Ok(this.value);
  final T value;
}

class Err<T> extends Result<T> {
  const Err(this.error);
  final Failure error;
}

sealed class Failure {
  const Failure();
}

class NetworkFailure extends Failure {
  const NetworkFailure(this.cause);
  final Object cause;
}

class ServerFailure extends Failure {
  const ServerFailure(this.statusCode);
  final int statusCode;
}

class ParseFailure extends Failure {
  const ParseFailure(this.cause);
  final Object cause;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/domain/result_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/config/app_config.dart lib/domain/result.dart test/domain/result_test.dart
git commit -m "feat: add AppConfig and Result/Failure domain foundations"
```

---

### Task 2: Track 모델 (freezed/json codegen 게이트)

> ⑤ 검토 F5: 이 태스크가 **첫 코드젠**이다. `build_runner`가 freezed 4.0.0-dev.3에서 정상 생성되는지 여기서 검증한다.

**Files:**
- Create: `lib/domain/models/track.dart`
- Test: `test/domain/models/track_test.dart`

**Interfaces:**
- Consumes: (없음)
- Produces: `abstract class Track` — 필드 `id, source, title, artistId, artistName, albumName?, artworkUrl(String, 기본 ''), durationMs(int), streamUrl?, metadata(Map<String,dynamic>, 기본 {})`; `factory Track.fromJson(Map<String,dynamic>)`; `Duration get duration`; `bool get isPlayable`; freezed 생성 `copyWith`.

- [ ] **Step 1: Write the failing test**

```dart
// test/domain/models/track_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:edmm/domain/models/track.dart';

void main() {
  final json = <String, dynamic>{
    'id': 'cloudinary:abc',
    'source': 'cloudinary',
    'title': 'Bloom',
    'artistId': 'cloudinary:Feint x DJ Sally',
    'artistName': 'Feint x DJ Sally',
    'albumName': 'media-pipeline',
    'artworkUrl': '',
    'durationMs': 219413,
    'streamUrl': 'https://res.cloudinary.com/db5yvwr1y/video/upload/x.m4a',
    'metadata': {'resourceType': 'video', 'publicId': 'edmm/media-pipeline/Feint x DJ Sally - Bloom'},
  };

  test('fromJson maps all fields', () {
    final t = Track.fromJson(json);
    expect(t.id, 'cloudinary:abc');
    expect(t.title, 'Bloom');
    expect(t.durationMs, 219413);
    expect(t.duration, const Duration(milliseconds: 219413));
    expect(t.metadata['resourceType'], 'video');
  });

  test('isPlayable true for audio with streamUrl, false for image', () {
    expect(Track.fromJson(json).isPlayable, isTrue);
    final image = Track.fromJson({...json, 'metadata': {'resourceType': 'image'}});
    expect(image.isPlayable, isFalse);
    final noStream = Track.fromJson({...json, 'streamUrl': ''});
    expect(noStream.isPlayable, isFalse);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/domain/models/track_test.dart`
Expected: FAIL — URI 없음.

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/domain/models/track.dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'track.freezed.dart';
part 'track.g.dart';

@freezed
abstract class Track with _$Track {
  const Track._();
  const factory Track({
    required String id,
    required String source,
    required String title,
    required String artistId,
    required String artistName,
    String? albumName,
    @Default('') String artworkUrl,
    required int durationMs,
    String? streamUrl,
    @Default(<String, dynamic>{}) Map<String, dynamic> metadata,
  }) = _Track;

  factory Track.fromJson(Map<String, dynamic> json) => _$TrackFromJson(json);

  Duration get duration => Duration(milliseconds: durationMs);

  bool get isPlayable =>
      (streamUrl?.trim().isNotEmpty ?? false) &&
      (metadata['resourceType'] as String?)?.toLowerCase() != 'image';
}
```

- [ ] **Step 4: Run codegen (게이트) then the test**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: `track.freezed.dart`, `track.g.dart` 생성, 에러 없음. (실패 시 여기서 멈추고 freezed 버전 이슈를 별도 판단 — F5.)
Run: `flutter test test/domain/models/track_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/domain/models/track.dart lib/domain/models/track.freezed.dart lib/domain/models/track.g.dart test/domain/models/track_test.dart
git commit -m "feat: add Track domain model with json + freezed codegen"
```

---

### Task 3: ArtworkMerger (순수 병합 — 웹 키매칭 이식)

**Files:**
- Create: `lib/domain/logic/artwork_merger.dart`
- Test: `test/domain/logic/artwork_merger_test.dart`

**Interfaces:**
- Consumes: `Track` (Task 2)
- Produces: `class ArtworkMerger` with `static List<Track> merge(List<Track> audio, List<Track> images)`, `static String normalizeForMatching(String)`, `static Set<String> buildMatchKeys(Track)`.

- [ ] **Step 1: Write the failing test**

```dart
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/domain/logic/artwork_merger_test.dart`
Expected: FAIL — URI 없음.

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/domain/logic/artwork_merger.dart
import '../models/track.dart';

class ArtworkMerger {
  static final _ext = RegExp(r'\.[a-z0-9]+$');
  static final _spaces = RegExp(r'\s+');
  static final _nonAlnum = RegExp(r'[^\p{L}\p{N}\s]', unicode: true);

  static String normalizeForMatching(String value) {
    var v = value.trim().toLowerCase();
    v = v.replaceAll(_ext, '');
    v = v.replaceAll(_spaces, ' ');
    v = v.replaceAll(_nonAlnum, '');
    return v.trim();
  }

  static String? _publicIdStem(Track t) {
    final pid = t.metadata['publicId'] ?? t.metadata['public_id'];
    if (pid is! String || pid.trim().isEmpty) return null;
    final segs = pid.split('/').where((s) => s.isNotEmpty).toList();
    final base = segs.isNotEmpty ? segs.last : pid;
    return normalizeForMatching(base);
  }

  static Set<String> buildMatchKeys(Track t) {
    final keys = <String>{};
    final stem = _publicIdStem(t);
    final title = normalizeForMatching(t.title);
    final artist = normalizeForMatching(t.artistName);
    final album = t.albumName == null ? '' : normalizeForMatching(t.albumName!);
    if (stem != null && stem.isNotEmpty) keys.add(stem);
    if (title.isNotEmpty) {
      keys.add(title);
      if (album.isNotEmpty) keys.add('$title $album'.trim());
      if (artist.isNotEmpty) {
        keys.add('$artist $title'.trim());
        keys.add('$title $artist'.trim());
      }
    }
    if (artist.isNotEmpty) keys.add(artist);
    if (album.isNotEmpty) keys.add(album);
    return keys;
  }

  static List<Track> merge(List<Track> audio, List<Track> images) {
    final imageByKey = <String, Track>{};
    for (final img in images) {
      for (final k in buildMatchKeys(img)) {
        imageByKey.putIfAbsent(k, () => img);
      }
    }
    final seen = <String>{};
    final deduped = audio.where((a) => seen.add(a.id)).toList();
    return deduped.map((a) {
      if (a.artworkUrl.isNotEmpty) return a;
      for (final k in buildMatchKeys(a)) {
        final img = imageByKey[k];
        if (img != null) {
          final art = img.artworkUrl.isNotEmpty ? img.artworkUrl : (img.streamUrl ?? '');
          return a.copyWith(artworkUrl: art);
        }
      }
      return a;
    }).toList();
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/domain/logic/artwork_merger_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/domain/logic/artwork_merger.dart test/domain/logic/artwork_merger_test.dart
git commit -m "feat: add ArtworkMerger porting web key-match merge"
```

---

### Task 4: TrackApiService (BFF HTTP)

**Files:**
- Create: `lib/data/services/track_api_service.dart`
- Test: `test/data/services/track_api_service_test.dart`

**Interfaces:**
- Consumes: `Track` (T2), `AppConfig` (T1)
- Produces:
  - `class TrackApiException implements Exception { final int? statusCode; final Object? cause; TrackApiException({this.statusCode, this.cause}); }`
  - `class TrackApiService { TrackApiService(http.Client client, AppConfig config); Future<List<Track>> fetchAudioTracks(); Future<List<Track>> fetchImageTracks(); }` — 비200 → `TrackApiException(statusCode)`, 네트워크/파싱 오류 → `TrackApiException(cause)`.

- [ ] **Step 1: Write the failing test**

```dart
// test/data/services/track_api_service_test.dart
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:edmm/config/app_config.dart';
import 'package:edmm/data/services/track_api_service.dart';

const _config = AppConfig();

List<Map<String, dynamic>> _one(String rt) => [
      {'id': 'x', 'source': 'cloudinary', 'title': 'T', 'artistId': 'a',
       'artistName': 'A', 'durationMs': 1000, 'streamUrl': 'u',
       'metadata': {'resourceType': rt}},
    ];

void main() {
  test('fetchAudioTracks hits /video?filterPlayable=true and parses', () async {
    late Uri seen;
    final svc = TrackApiService(
      MockClient((req) async { seen = req.url; return http.Response(jsonEncode(_one('video')), 200); }),
      _config,
    );
    final tracks = await svc.fetchAudioTracks();
    expect(seen.path, '/api/cloudinary/tracks/video');
    expect(seen.queryParameters['filterPlayable'], 'true');
    expect(tracks.single.title, 'T');
  });

  test('non-200 throws TrackApiException with statusCode', () async {
    final svc = TrackApiService(MockClient((req) async => http.Response('{"error":"x"}', 502)), _config);
    expect(() => svc.fetchImageTracks(),
        throwsA(isA<TrackApiException>().having((e) => e.statusCode, 'statusCode', 502)));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/data/services/track_api_service_test.dart`
Expected: FAIL — URI 없음.

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/data/services/track_api_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../config/app_config.dart';
import '../../domain/models/track.dart';

class TrackApiException implements Exception {
  TrackApiException({this.statusCode, this.cause});
  final int? statusCode;
  final Object? cause;
  @override
  String toString() => 'TrackApiException(statusCode: $statusCode, cause: $cause)';
}

class TrackApiService {
  TrackApiService(this._client, this._config);
  final http.Client _client;
  final AppConfig _config;

  Future<List<Track>> fetchAudioTracks() =>
      _get('/api/cloudinary/tracks/video?filterPlayable=true');

  Future<List<Track>> fetchImageTracks() => _get('/api/cloudinary/tracks/image');

  Future<List<Track>> _get(String path) async {
    final uri = Uri.parse('${_config.bffBaseUrl}$path');
    final http.Response res;
    try {
      res = await _client.get(uri).timeout(_config.timeout);
    } catch (e) {
      throw TrackApiException(cause: e);
    }
    if (res.statusCode != 200) {
      throw TrackApiException(statusCode: res.statusCode);
    }
    try {
      final list = jsonDecode(res.body) as List<dynamic>;
      return list
          .map((e) => Track.fromJson(e as Map<String, dynamic>))
          .toList(growable: false);
    } catch (e) {
      throw TrackApiException(cause: e);
    }
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/data/services/track_api_service_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/data/services/track_api_service.dart test/data/services/track_api_service_test.dart
git commit -m "feat: add TrackApiService for BFF video/image endpoints"
```

---

### Task 5: TrackRepository + RemoteTrackRepository

**Files:**
- Create: `lib/domain/repositories/track_repository.dart`
- Create: `lib/data/repositories/remote_track_repository.dart`
- Test: `test/data/repositories/remote_track_repository_test.dart`

**Interfaces:**
- Consumes: `Track` (T2), `ArtworkMerger` (T3), `TrackApiService`/`TrackApiException` (T4), `Result`/`Failure` (T1)
- Produces:
  - `abstract class TrackRepository { Future<Result<List<Track>>> getTracks({bool forceRefresh = false}); }`
  - `class RemoteTrackRepository implements TrackRepository { RemoteTrackRepository(TrackApiService api); }` — 오디오∥이미지 병렬, 이미지 실패는 빈 목록, 오디오 실패는 `Err`, 성공 시 병합·인메모리 캐시.

- [ ] **Step 1: Write the failing test**

```dart
// test/data/repositories/remote_track_repository_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:edmm/domain/models/track.dart';
import 'package:edmm/domain/repositories/track_repository.dart';
import 'package:edmm/domain/result.dart';
import 'package:edmm/data/repositories/remote_track_repository.dart';
import 'package:edmm/data/services/track_api_service.dart';

Track _audio(String t) => Track(id: t, source: 'cloudinary', title: t, artistId: 'a',
    artistName: 'A', durationMs: 1, streamUrl: 'u', metadata: const {'resourceType': 'video'});
Track _image(String t, String url) => Track(id: 'i$t', source: 'cloudinary', title: t,
    artistId: 'a', artistName: 'A', durationMs: 0, artworkUrl: url, streamUrl: url,
    metadata: const {'resourceType': 'image'});

class _FakeApi implements TrackApiService {
  _FakeApi({required this.audio, required this.images});
  final List<Track> Function() audio;
  final List<Track> Function() images;
  int audioCalls = 0;
  @override
  Future<List<Track>> fetchAudioTracks() async { audioCalls++; return audio(); }
  @override
  Future<List<Track>> fetchImageTracks() async => images();
}

void main() {
  test('merges artwork and caches (no refetch without forceRefresh)', () async {
    final api = _FakeApi(audio: () => [_audio('Bloom')], images: () => [_image('Bloom', 'art')]);
    final repo = RemoteTrackRepository(api);

    final r1 = await repo.getTracks();
    expect(r1, isA<Ok<List<Track>>>());
    expect((r1 as Ok<List<Track>>).value.single.artworkUrl, 'art');

    await repo.getTracks();
    expect(api.audioCalls, 1); // cached

    await repo.getTracks(forceRefresh: true);
    expect(api.audioCalls, 2);
  });

  test('image failure is best-effort; audio still returned', () async {
    final api = _FakeApi(audio: () => [_audio('Solo')], images: () => throw TrackApiException(statusCode: 500));
    final repo = RemoteTrackRepository(api);
    final r = await repo.getTracks();
    expect((r as Ok<List<Track>>).value.single.title, 'Solo');
  });

  test('audio failure yields Err(ServerFailure)', () async {
    final api = _FakeApi(audio: () => throw TrackApiException(statusCode: 502), images: () => []);
    final repo = RemoteTrackRepository(api);
    final r = await repo.getTracks();
    expect(r, isA<Err<List<Track>>>());
    expect((r as Err<List<Track>>).error, isA<ServerFailure>());
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/data/repositories/remote_track_repository_test.dart`
Expected: FAIL — URI 없음.

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/domain/repositories/track_repository.dart
import '../models/track.dart';
import '../result.dart';

abstract class TrackRepository {
  Future<Result<List<Track>>> getTracks({bool forceRefresh = false});
}
```

```dart
// lib/data/repositories/remote_track_repository.dart
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
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/data/repositories/remote_track_repository_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/domain/repositories/track_repository.dart lib/data/repositories/remote_track_repository.dart test/data/repositories/remote_track_repository_test.dart
git commit -m "feat: add TrackRepository with parallel fetch, merge, cache"
```

---

### Task 6: PlaybackSnapshot · AudioController (도메인)

**Files:**
- Create: `lib/domain/playback/playback_snapshot.dart`
- Create: `lib/domain/audio/audio_controller.dart`
- Test: `test/domain/playback/playback_snapshot_test.dart`

**Interfaces:**
- Consumes: `Track` (T2), `Failure` (T1)
- Produces:
  - `enum PlaybackStatus { idle, loading, ready, playing, paused, completed, error }`
  - `class PlaybackSnapshot { const PlaybackSnapshot({Track? currentTrack, PlaybackStatus status, Duration duration, int? queueIndex, bool hasNext, bool hasPrevious, Failure? error}); bool get isPlaying; PlaybackSnapshot copyWith({...}); }`
  - `abstract class AudioController { Stream<PlaybackSnapshot> get snapshot; Stream<Duration> get position; Future<void> loadQueue(List<Track> tracks, {int initialIndex}); Future<void> play(); Future<void> pause(); Future<void> seek(Duration position); Future<void> next(); Future<void> previous(); Future<void> dispose(); }`

- [ ] **Step 1: Write the failing test**

```dart
// test/domain/playback/playback_snapshot_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:edmm/domain/playback/playback_snapshot.dart';

void main() {
  test('defaults and isPlaying', () {
    const s = PlaybackSnapshot();
    expect(s.status, PlaybackStatus.idle);
    expect(s.isPlaying, isFalse);
    expect(s.copyWith(status: PlaybackStatus.playing).isPlaying, isTrue);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/domain/playback/playback_snapshot_test.dart`
Expected: FAIL — URI 없음.

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/domain/playback/playback_snapshot.dart
import '../models/track.dart';
import '../result.dart';

enum PlaybackStatus { idle, loading, ready, playing, paused, completed, error }

class PlaybackSnapshot {
  const PlaybackSnapshot({
    this.currentTrack,
    this.status = PlaybackStatus.idle,
    this.duration = Duration.zero,
    this.queueIndex,
    this.hasNext = false,
    this.hasPrevious = false,
    this.error,
  });

  final Track? currentTrack;
  final PlaybackStatus status;
  final Duration duration;
  final int? queueIndex;
  final bool hasNext;
  final bool hasPrevious;
  final Failure? error;

  bool get isPlaying => status == PlaybackStatus.playing;

  PlaybackSnapshot copyWith({
    Track? currentTrack,
    PlaybackStatus? status,
    Duration? duration,
    int? queueIndex,
    bool? hasNext,
    bool? hasPrevious,
    Failure? error,
  }) => PlaybackSnapshot(
        currentTrack: currentTrack ?? this.currentTrack,
        status: status ?? this.status,
        duration: duration ?? this.duration,
        queueIndex: queueIndex ?? this.queueIndex,
        hasNext: hasNext ?? this.hasNext,
        hasPrevious: hasPrevious ?? this.hasPrevious,
        error: error ?? this.error,
      );
}
```

```dart
// lib/domain/audio/audio_controller.dart
import '../models/track.dart';
import '../playback/playback_snapshot.dart';

abstract class AudioController {
  Stream<PlaybackSnapshot> get snapshot;
  Stream<Duration> get position;
  Future<void> loadQueue(List<Track> tracks, {int initialIndex = 0});
  Future<void> play();
  Future<void> pause();
  Future<void> seek(Duration position);
  Future<void> next();
  Future<void> previous();
  Future<void> dispose();
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/domain/playback/playback_snapshot_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/domain/playback/playback_snapshot.dart lib/domain/audio/audio_controller.dart test/domain/playback/playback_snapshot_test.dart
git commit -m "feat: add PlaybackSnapshot and AudioController interface"
```

---

### Task 7: just_audio+audio_service 구현 + 플랫폼 설정

> 실제 재생/백그라운드는 기기 검증 대상. 여기서는 **순수 매핑 헬퍼**(ProcessingState→상태, Track→MediaItem)를 TDD로 검증하고, 컨트롤러 결선과 플랫폼 설정을 적용한다. ⑤ F4: 매니페스트/plist는 설치된 audio_service 버전 문서와 대조 후 확정.

**Files:**
- Modify: `pubspec.yaml` (deps 추가)
- Create: `lib/data/audio/playback_mapping.dart`
- Create: `lib/data/audio/just_audio_controller.dart`
- Modify: `android/app/src/main/AndroidManifest.xml`
- Modify: `android/app/src/main/kotlin/com/edmm/edmm/MainActivity.kt`
- Modify: `ios/Runner/Info.plist`
- Test: `test/data/audio/playback_mapping_test.dart`

**Interfaces:**
- Consumes: `Track` (T2), `PlaybackStatus`/`PlaybackSnapshot` (T6), `AudioController` (T6)
- Produces:
  - `PlaybackStatus mapProcessingState(ProcessingState state, bool playing)`
  - `MediaItem toMediaItem(Track track)`
  - `class JustAudioController extends BaseAudioHandler with QueueHandler, SeekHandler implements AudioController`

- [ ] **Step 1: Add dependencies**

Run: `flutter pub add just_audio audio_service`
Expected: `pubspec.yaml`에 `just_audio: ^0.10.6`, `audio_service: ^0.18.19` 추가, `flutter pub get` 성공.

- [ ] **Step 2: Write the failing test (pure mapping)**

```dart
// test/data/audio/playback_mapping_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart' show ProcessingState;
import 'package:edmm/domain/models/track.dart';
import 'package:edmm/domain/playback/playback_snapshot.dart';
import 'package:edmm/data/audio/playback_mapping.dart';

void main() {
  test('mapProcessingState maps just_audio states', () {
    expect(mapProcessingState(ProcessingState.idle, false), PlaybackStatus.idle);
    expect(mapProcessingState(ProcessingState.loading, false), PlaybackStatus.loading);
    expect(mapProcessingState(ProcessingState.buffering, true), PlaybackStatus.loading);
    expect(mapProcessingState(ProcessingState.ready, true), PlaybackStatus.playing);
    expect(mapProcessingState(ProcessingState.ready, false), PlaybackStatus.paused);
    expect(mapProcessingState(ProcessingState.completed, false), PlaybackStatus.completed);
  });

  test('toMediaItem carries artwork uri when present', () {
    final t = Track(id: 'x', source: 'cloudinary', title: 'T', artistId: 'a',
        artistName: 'A', albumName: 'Al', durationMs: 1000, streamUrl: 'u',
        artworkUrl: 'https://art/x.jpg', metadata: const {});
    final m = toMediaItem(t);
    expect(m.title, 'T');
    expect(m.artist, 'A');
    expect(m.artUri.toString(), 'https://art/x.jpg');
    expect(m.duration, const Duration(milliseconds: 1000));
  });
}
```

- [ ] **Step 3: Run test to verify it fails**

Run: `flutter test test/data/audio/playback_mapping_test.dart`
Expected: FAIL — `playback_mapping.dart` 없음.

- [ ] **Step 4: Implement mapping + controller**

```dart
// lib/data/audio/playback_mapping.dart
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart' show ProcessingState;
import '../../domain/models/track.dart';
import '../../domain/playback/playback_snapshot.dart';

PlaybackStatus mapProcessingState(ProcessingState state, bool playing) {
  switch (state) {
    case ProcessingState.idle:
      return PlaybackStatus.idle;
    case ProcessingState.loading:
    case ProcessingState.buffering:
      return PlaybackStatus.loading;
    case ProcessingState.ready:
      return playing ? PlaybackStatus.playing : PlaybackStatus.paused;
    case ProcessingState.completed:
      return PlaybackStatus.completed;
  }
}

MediaItem toMediaItem(Track track) => MediaItem(
      id: track.streamUrl ?? track.id,
      title: track.title,
      artist: track.artistName,
      album: track.albumName,
      duration: track.duration,
      artUri: track.artworkUrl.isNotEmpty ? Uri.parse(track.artworkUrl) : null,
    );
```

```dart
// lib/data/audio/just_audio_controller.dart
import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import '../../domain/audio/audio_controller.dart';
import '../../domain/models/track.dart' as domain;
import '../../domain/playback/playback_snapshot.dart';
import 'playback_mapping.dart';

class JustAudioController extends BaseAudioHandler
    with QueueHandler, SeekHandler
    implements AudioController {
  JustAudioController() {
    _player.playbackEventStream.listen(_broadcastState);
    _player.positionStream.listen(_positionController.add);
    _player.durationStream.listen((_) => _emitSnapshot());
    _player.currentIndexStream.listen((_) => _emitSnapshot());
    _player.playerStateStream.listen((_) => _emitSnapshot());
  }

  final AudioPlayer _player = AudioPlayer();
  final _snapshotController = StreamController<PlaybackSnapshot>.broadcast();
  final _positionController = StreamController<Duration>.broadcast();
  List<domain.Track> _tracks = const [];

  @override
  Stream<PlaybackSnapshot> get snapshot => _snapshotController.stream;
  @override
  Stream<Duration> get position => _positionController.stream;

  @override
  Future<void> loadQueue(List<domain.Track> tracks, {int initialIndex = 0}) async {
    _tracks = tracks;
    queue.add(tracks.map(toMediaItem).toList());
    await _player.setAudioSource(
      ConcatenatingAudioSource(
        children: [
          for (final t in tracks) AudioSource.uri(Uri.parse(t.streamUrl ?? '')),
        ],
      ),
      initialIndex: initialIndex,
    );
    _emitSnapshot();
  }

  @override
  Future<void> play() => _player.play();
  @override
  Future<void> pause() => _player.pause();
  @override
  Future<void> seek(Duration position) => _player.seek(position);
  @override
  Future<void> next() => _player.seekToNext();
  @override
  Future<void> previous() => _player.seekToPrevious();

  @override
  Future<void> dispose() async {
    await _player.dispose();
    await _snapshotController.close();
    await _positionController.close();
  }

  void _emitSnapshot() {
    final index = _player.currentIndex;
    final current = (index != null && index >= 0 && index < _tracks.length)
        ? _tracks[index]
        : null;
    _snapshotController.add(PlaybackSnapshot(
      currentTrack: current,
      status: mapProcessingState(_player.processingState, _player.playing),
      duration: _player.duration ?? Duration.zero,
      queueIndex: index,
      hasNext: _player.hasNext,
      hasPrevious: _player.hasPrevious,
    ));
  }

  void _broadcastState(PlaybackEvent event) {
    playbackState.add(playbackState.value.copyWith(
      controls: [MediaControl.skipToPrevious, if (_player.playing) MediaControl.pause else MediaControl.play, MediaControl.skipToNext],
      systemActions: const {MediaAction.seek},
      processingState: const {
        ProcessingState.idle: AudioProcessingState.idle,
        ProcessingState.loading: AudioProcessingState.loading,
        ProcessingState.buffering: AudioProcessingState.buffering,
        ProcessingState.ready: AudioProcessingState.ready,
        ProcessingState.completed: AudioProcessingState.completed,
      }[_player.processingState]!,
      playing: _player.playing,
      updatePosition: _player.position,
      queueIndex: event.currentIndex,
    ));
  }
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/data/audio/playback_mapping_test.dart`
Expected: PASS.

- [ ] **Step 6: Apply Android platform config**

`android/app/src/main/AndroidManifest.xml` — 루트 태그에 `xmlns:tools="http://schemas.android.com/tools"` 추가, `<application>` 앞에 권한, 안에 서비스/리시버 추가:

```xml
<uses-permission android:name="android.permission.WAKE_LOCK"/>
<uses-permission android:name="android.permission.FOREGROUND_SERVICE"/>
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK"/>
```
```xml
<!-- inside <application> -->
<service android:name="com.ryanheise.audioservice.AudioService"
    android:foregroundServiceType="mediaPlayback"
    android:exported="true" tools:ignore="Instantiatable">
  <intent-filter><action android:name="android.media.browse.MediaBrowserService"/></intent-filter>
</service>
<receiver android:name="com.ryanheise.audioservice.MediaButtonReceiver"
    android:exported="true" tools:ignore="Instantiatable">
  <intent-filter><action android:name="android.intent.action.MEDIA_BUTTON"/></intent-filter>
</receiver>
```

`android/app/src/main/kotlin/com/edmm/edmm/MainActivity.kt`:
```kotlin
package com.edmm.edmm

import com.ryanheise.audioservice.AudioServiceActivity

class MainActivity : AudioServiceActivity()
```

- [ ] **Step 7: Apply iOS platform config**

`ios/Runner/Info.plist` — `<dict>` 안에 추가:
```xml
<key>UIBackgroundModes</key>
<array><string>audio</string></array>
```

- [ ] **Step 8: Verify build + analyze, then commit**

Run: `flutter analyze`
Expected: 무경고(플랫폼 스니펫이 설치 버전과 맞는지 확인 — F4).
Run: `flutter test test/data/audio/playback_mapping_test.dart`
Expected: PASS.

```bash
git add pubspec.yaml pubspec.lock lib/data/audio/ test/data/audio/ android/ ios/Runner/Info.plist
git commit -m "feat: add just_audio+audio_service controller and platform config"
```

---

### Task 8: TrackListViewModel

**Files:**
- Create: `lib/ui/track_list/view_model/track_list_view_model.dart`
- Test: `test/ui/track_list/track_list_view_model_test.dart`

**Interfaces:**
- Consumes: `TrackRepository` (T5), `Track` (T2), `Result`/`Failure` (T1)
- Produces:
  - `enum TrackListStatus { loading, data, empty, error }`
  - `class TrackListViewModel extends ChangeNotifier { TrackListViewModel(TrackRepository repo); TrackListStatus status; List<Track> tracks; Failure? error; Future<void> load({bool forceRefresh}); }`

- [ ] **Step 1: Write the failing test**

```dart
// test/ui/track_list/track_list_view_model_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:edmm/domain/models/track.dart';
import 'package:edmm/domain/repositories/track_repository.dart';
import 'package:edmm/domain/result.dart';
import 'package:edmm/ui/track_list/view_model/track_list_view_model.dart';

class _Repo implements TrackRepository {
  _Repo(this.result);
  Result<List<Track>> result;
  @override
  Future<Result<List<Track>>> getTracks({bool forceRefresh = false}) async => result;
}

Track _t(String id) => Track(id: id, source: 'cloudinary', title: id, artistId: 'a',
    artistName: 'A', durationMs: 1, streamUrl: 'u', metadata: const {});

void main() {
  test('load -> data when non-empty', () async {
    final vm = TrackListViewModel(_Repo(Ok([_t('1')])));
    await vm.load();
    expect(vm.status, TrackListStatus.data);
    expect(vm.tracks.length, 1);
  });

  test('load -> empty when empty', () async {
    final vm = TrackListViewModel(_Repo(const Ok<List<Track>>([])));
    await vm.load();
    expect(vm.status, TrackListStatus.empty);
  });

  test('load -> error on Err', () async {
    final vm = TrackListViewModel(_Repo(const Err<List<Track>>(ServerFailure(502))));
    await vm.load();
    expect(vm.status, TrackListStatus.error);
    expect(vm.error, isA<ServerFailure>());
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/ui/track_list/track_list_view_model_test.dart`
Expected: FAIL — URI 없음.

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/ui/track_list/view_model/track_list_view_model.dart
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
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/ui/track_list/track_list_view_model_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/ui/track_list/view_model/track_list_view_model.dart test/ui/track_list/track_list_view_model_test.dart
git commit -m "feat: add TrackListViewModel"
```

---

### Task 9: PlayerViewModel

**Files:**
- Create: `lib/ui/player/view_model/player_view_model.dart`
- Test: `test/ui/player/player_view_model_test.dart`

**Interfaces:**
- Consumes: `AudioController` (T6), `PlaybackSnapshot` (T6)
- Produces:
  - `class PlayerViewModel extends ChangeNotifier { PlayerViewModel(AudioController audio); PlaybackSnapshot snapshot; Stream<Duration> get position; Future<void> playPause(); Future<void> seek(Duration to); Future<void> next(); Future<void> previous(); }`

- [ ] **Step 1: Write the failing test**

```dart
// test/ui/player/player_view_model_test.dart
import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:edmm/domain/audio/audio_controller.dart';
import 'package:edmm/domain/models/track.dart';
import 'package:edmm/domain/playback/playback_snapshot.dart';
import 'package:edmm/ui/player/view_model/player_view_model.dart';

class _FakeAudio implements AudioController {
  final _snap = StreamController<PlaybackSnapshot>.broadcast();
  final _pos = StreamController<Duration>.broadcast();
  int plays = 0, pauses = 0;
  @override Stream<PlaybackSnapshot> get snapshot => _snap.stream;
  @override Stream<Duration> get position => _pos.stream;
  @override Future<void> play() async => plays++;
  @override Future<void> pause() async => pauses++;
  @override Future<void> seek(Duration position) async {}
  @override Future<void> next() async {}
  @override Future<void> previous() async {}
  @override Future<void> loadQueue(List<Track> tracks, {int initialIndex = 0}) async {}
  @override Future<void> dispose() async {}
}

void main() {
  test('mirrors snapshot stream and notifies', () async {
    final audio = _FakeAudio();
    final vm = PlayerViewModel(audio);
    var notified = 0;
    vm.addListener(() => notified++);
    audio._snap.add(const PlaybackSnapshot(status: PlaybackStatus.playing));
    await Future<void>.delayed(Duration.zero);
    expect(vm.snapshot.status, PlaybackStatus.playing);
    expect(notified, greaterThan(0));
  });

  test('playPause delegates based on current status', () async {
    final audio = _FakeAudio();
    final vm = PlayerViewModel(audio);
    audio._snap.add(const PlaybackSnapshot(status: PlaybackStatus.paused));
    await Future<void>.delayed(Duration.zero);
    await vm.playPause();
    expect(audio.plays, 1);
    audio._snap.add(const PlaybackSnapshot(status: PlaybackStatus.playing));
    await Future<void>.delayed(Duration.zero);
    await vm.playPause();
    expect(audio.pauses, 1);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/ui/player/player_view_model_test.dart`
Expected: FAIL — URI 없음.

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/ui/player/view_model/player_view_model.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../domain/audio/audio_controller.dart';
import '../../../domain/playback/playback_snapshot.dart';

class PlayerViewModel extends ChangeNotifier {
  PlayerViewModel(this._audio) {
    _sub = _audio.snapshot.listen((s) {
      snapshot = s;
      notifyListeners();
    });
  }

  final AudioController _audio;
  late final StreamSubscription<PlaybackSnapshot> _sub;

  PlaybackSnapshot snapshot = const PlaybackSnapshot();
  Stream<Duration> get position => _audio.position;

  Future<void> playPause() => snapshot.isPlaying ? _audio.pause() : _audio.play();
  Future<void> seek(Duration to) => _audio.seek(to);
  Future<void> next() => _audio.next();
  Future<void> previous() => _audio.previous();

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/ui/player/player_view_model_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/ui/player/view_model/player_view_model.dart test/ui/player/player_view_model_test.dart
git commit -m "feat: add PlayerViewModel mirroring AudioController"
```

---

### Task 10: TrackListScreen + l10n 키

**Files:**
- Modify: `lib/l10n/app_en.arb`, `lib/l10n/app_ko.arb`
- Create: `lib/ui/track_list/widgets/track_list_screen.dart`
- Test: `test/ui/track_list/track_list_screen_test.dart`

**Interfaces:**
- Consumes: `TrackListViewModel`/`TrackListStatus` (T8), `Track` (T2)
- Produces: `class TrackListScreen extends StatefulWidget { const TrackListScreen({required TrackListViewModel viewModel, required void Function(List<Track> queue, int index) onPlay}); }`

- [ ] **Step 1: Add l10n keys**

`lib/l10n/app_en.arb` — 추가: `"trackListTitle": "Tracks"`, `"tracksLoadError": "Couldn't load tracks"`, `"tracksEmpty": "No tracks"`, `"retry": "Retry"`.
`lib/l10n/app_ko.arb` — 추가: `"trackListTitle": "트랙"`, `"tracksLoadError": "트랙을 불러오지 못했습니다"`, `"tracksEmpty": "트랙이 없습니다"`, `"retry": "다시 시도"`.
Run: `flutter gen-l10n`
Expected: `app_localizations*.dart` 재생성.

- [ ] **Step 2: Write the failing test**

```dart
// test/ui/track_list/track_list_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:edmm/l10n/app_localizations.dart';
import 'package:edmm/domain/models/track.dart';
import 'package:edmm/domain/repositories/track_repository.dart';
import 'package:edmm/domain/result.dart';
import 'package:edmm/ui/track_list/view_model/track_list_view_model.dart';
import 'package:edmm/ui/track_list/widgets/track_list_screen.dart';

class _Repo implements TrackRepository {
  _Repo(this.result);
  final Result<List<Track>> result;
  @override
  Future<Result<List<Track>>> getTracks({bool forceRefresh = false}) async => result;
}

Track _t(String id) => Track(id: id, source: 'cloudinary', title: 'Song $id',
    artistId: 'a', artistName: 'Artist', durationMs: 1, streamUrl: 'u', metadata: const {});

Widget _host(Widget child) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    );

void main() {
  testWidgets('renders rows and fires onPlay on tap', (tester) async {
    final vm = TrackListViewModel(_Repo(Ok([_t('1'), _t('2')])));
    await vm.load();
    List<Track>? playedQueue;
    int? playedIndex;
    await tester.pumpWidget(_host(TrackListScreen(
      viewModel: vm,
      onPlay: (q, i) { playedQueue = q; playedIndex = i; },
    )));
    await tester.pump();
    expect(find.text('Song 1'), findsOneWidget);
    await tester.tap(find.text('Song 2'));
    expect(playedIndex, 1);
    expect(playedQueue!.length, 2);
  });
}
```

- [ ] **Step 3: Run test to verify it fails**

Run: `flutter test test/ui/track_list/track_list_screen_test.dart`
Expected: FAIL — `track_list_screen.dart` 없음.

- [ ] **Step 4: Write minimal implementation**

```dart
// lib/ui/track_list/widgets/track_list_screen.dart
import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';
import '../../../domain/models/track.dart';
import '../view_model/track_list_view_model.dart';

class TrackListScreen extends StatefulWidget {
  const TrackListScreen({super.key, required this.viewModel, required this.onPlay});
  final TrackListViewModel viewModel;
  final void Function(List<Track> queue, int index) onPlay;

  @override
  State<TrackListScreen> createState() => _TrackListScreenState();
}

class _TrackListScreenState extends State<TrackListScreen> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.trackListTitle)),
      body: ListenableBuilder(
        listenable: widget.viewModel,
        builder: (context, _) {
          final vm = widget.viewModel;
          switch (vm.status) {
            case TrackListStatus.loading:
              return const Center(child: CircularProgressIndicator());
            case TrackListStatus.empty:
              return Center(child: Text(l10n.tracksEmpty));
            case TrackListStatus.error:
              return Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(l10n.tracksLoadError),
                  TextButton(
                    onPressed: () => vm.load(forceRefresh: true),
                    child: Text(l10n.retry),
                  ),
                ]),
              );
            case TrackListStatus.data:
              return ListView.builder(
                itemCount: vm.tracks.length,
                itemBuilder: (context, i) {
                  final t = vm.tracks[i];
                  return ListTile(
                    leading: t.artworkUrl.isEmpty
                        ? const Icon(Icons.music_note)
                        : Image.network(t.artworkUrl, width: 48, height: 48,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(Icons.music_note)),
                    title: Text(t.title),
                    subtitle: Text(t.artistName),
                    onTap: () => widget.onPlay(vm.tracks, i),
                  );
                },
              );
          }
        },
      ),
    );
  }
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/ui/track_list/track_list_screen_test.dart`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/l10n/ lib/ui/track_list/widgets/track_list_screen.dart test/ui/track_list/track_list_screen_test.dart
git commit -m "feat: add TrackListScreen with list/empty/error states"
```

---

### Task 11: PlayerScreen + l10n 키

**Files:**
- Modify: `lib/l10n/app_en.arb`, `lib/l10n/app_ko.arb`
- Create: `lib/ui/player/widgets/player_screen.dart`
- Test: `test/ui/player/player_screen_test.dart`

**Interfaces:**
- Consumes: `PlayerViewModel` (T9), `PlaybackSnapshot`/`PlaybackStatus` (T6), `AudioController` (T6)
- Produces: `class PlayerScreen extends StatefulWidget { const PlayerScreen({required PlayerViewModel viewModel}); }`

- [ ] **Step 1: Add l10n keys**

`app_en.arb` 추가: `"nowPlaying": "Now Playing"`, `"unknownArtist": "Unknown artist"`.
`app_ko.arb` 추가: `"nowPlaying": "재생 중"`, `"unknownArtist": "알 수 없는 아티스트"`.
Run: `flutter gen-l10n`

- [ ] **Step 2: Write the failing test**

```dart
// test/ui/player/player_screen_test.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:edmm/l10n/app_localizations.dart';
import 'package:edmm/domain/audio/audio_controller.dart';
import 'package:edmm/domain/models/track.dart';
import 'package:edmm/domain/playback/playback_snapshot.dart';
import 'package:edmm/ui/player/view_model/player_view_model.dart';
import 'package:edmm/ui/player/widgets/player_screen.dart';

class _FakeAudio implements AudioController {
  final snap = StreamController<PlaybackSnapshot>.broadcast();
  final pos = StreamController<Duration>.broadcast();
  int plays = 0;
  @override Stream<PlaybackSnapshot> get snapshot => snap.stream;
  @override Stream<Duration> get position => pos.stream;
  @override Future<void> play() async => plays++;
  @override Future<void> pause() async {}
  @override Future<void> seek(Duration position) async {}
  @override Future<void> next() async {}
  @override Future<void> previous() async {}
  @override Future<void> loadQueue(List<Track> tracks, {int initialIndex = 0}) async {}
  @override Future<void> dispose() async {}
}

Widget _host(Widget child) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    );

void main() {
  testWidgets('shows current track title and play triggers controller', (tester) async {
    final audio = _FakeAudio();
    final vm = PlayerViewModel(audio);
    await tester.pumpWidget(_host(PlayerScreen(viewModel: vm)));
    final track = Track(id: 'x', source: 'cloudinary', title: 'Bloom', artistId: 'a',
        artistName: 'Feint', durationMs: 1000, streamUrl: 'u', metadata: const {});
    audio.snap.add(PlaybackSnapshot(currentTrack: track, status: PlaybackStatus.paused,
        duration: const Duration(seconds: 1)));
    await tester.pump();
    expect(find.text('Bloom'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.play_arrow));
    expect(audio.plays, 1);
  });
}
```

- [ ] **Step 3: Run test to verify it fails**

Run: `flutter test test/ui/player/player_screen_test.dart`
Expected: FAIL — `player_screen.dart` 없음.

- [ ] **Step 4: Write minimal implementation**

```dart
// lib/ui/player/widgets/player_screen.dart
import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';
import '../../../domain/playback/playback_snapshot.dart';
import '../view_model/player_view_model.dart';

class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key, required this.viewModel});
  final PlayerViewModel viewModel;

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  @override
  void dispose() {
    widget.viewModel.dispose();
    super.dispose();
  }

  String _fmt(Duration d) =>
      '${d.inMinutes.toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.nowPlaying)),
      body: ListenableBuilder(
        listenable: widget.viewModel,
        builder: (context, _) {
          final s = widget.viewModel.snapshot;
          final track = s.currentTrack;
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  child: Center(
                    child: (track != null && track.artworkUrl.isNotEmpty)
                        ? Image.network(track.artworkUrl,
                            errorBuilder: (_, __, ___) => const Icon(Icons.album, size: 160))
                        : const Icon(Icons.album, size: 160),
                  ),
                ),
                Text(track?.title ?? '', style: Theme.of(context).textTheme.titleLarge),
                Text(track?.artistName ?? l10n.unknownArtist),
                const SizedBox(height: 16),
                StreamBuilder<Duration>(
                  stream: widget.viewModel.position,
                  builder: (context, snap) {
                    final pos = snap.data ?? Duration.zero;
                    final total = s.duration.inMilliseconds == 0 ? 1 : s.duration.inMilliseconds;
                    return Column(children: [
                      Slider(
                        value: pos.inMilliseconds.clamp(0, total).toDouble(),
                        max: total.toDouble(),
                        onChanged: (v) =>
                            widget.viewModel.seek(Duration(milliseconds: v.round())),
                      ),
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Text(_fmt(pos)),
                        Text(_fmt(s.duration)),
                      ]),
                    ]);
                  },
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(iconSize: 40, icon: const Icon(Icons.skip_previous),
                        onPressed: widget.viewModel.previous),
                    IconButton(
                      iconSize: 56,
                      icon: Icon(s.isPlaying ? Icons.pause : Icons.play_arrow),
                      onPressed: widget.viewModel.playPause,
                    ),
                    IconButton(iconSize: 40, icon: const Icon(Icons.skip_next),
                        onPressed: widget.viewModel.next),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/ui/player/player_screen_test.dart`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/l10n/ lib/ui/player/widgets/player_screen.dart test/ui/player/player_screen_test.dart
git commit -m "feat: add PlayerScreen with separated position stream"
```

---

### Task 12: 앱 조립 — 라우팅·DI·home 제거·게이트

> ⑤ 검토 F3: `ui/home/**` 삭제로 기존 `test/widget_test.dart`(home/counter)가 깨진다. 이 태스크에서 함께 교체한다.

**Files:**
- Modify: `lib/routing/routes.dart`, `lib/routing/router.dart`, `lib/main.dart`
- Delete: `lib/ui/home/view_model/home_view_model.dart`, `lib/ui/home/widgets/home_screen.dart`
- Replace: `test/widget_test.dart`

**Interfaces:**
- Consumes: 모든 이전 태스크(`AppConfig`, `TrackApiService`, `RemoteTrackRepository`, `JustAudioController`, `TrackListScreen`, `PlayerScreen`, VMs).

- [ ] **Step 1: Update routes**

```dart
// lib/routing/routes.dart
abstract final class Routes {
  static const String trackList = '/';
  static const String player = '/player';
}
```

- [ ] **Step 2: Update router (DI 주입)**

```dart
// lib/routing/router.dart
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../domain/audio/audio_controller.dart';
import '../domain/repositories/track_repository.dart';
import '../ui/player/view_model/player_view_model.dart';
import '../ui/player/widgets/player_screen.dart';
import '../ui/track_list/view_model/track_list_view_model.dart';
import '../ui/track_list/widgets/track_list_screen.dart';
import 'routes.dart';

final GoRouter appRouter = GoRouter(
  routes: [
    GoRoute(
      path: Routes.trackList,
      builder: (context, state) {
        final repo = context.read<TrackRepository>();
        final audio = context.read<AudioController>();
        return TrackListScreen(
          viewModel: TrackListViewModel(repo)..load(),
          onPlay: (queue, index) async {
            await audio.loadQueue(queue, initialIndex: index);
            await audio.play();
            if (context.mounted) context.go(Routes.player);
          },
        );
      },
    ),
    GoRoute(
      path: Routes.player,
      builder: (context, state) =>
          PlayerScreen(viewModel: PlayerViewModel(context.read<AudioController>())),
    ),
  ],
);
```

- [ ] **Step 3: Update main.dart (async init + MultiProvider)**

```dart
// lib/main.dart
import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import 'config/app_config.dart';
import 'data/audio/just_audio_controller.dart';
import 'data/repositories/remote_track_repository.dart';
import 'data/services/track_api_service.dart';
import 'domain/audio/audio_controller.dart';
import 'domain/repositories/track_repository.dart';
import 'l10n/app_localizations.dart';
import 'routing/router.dart';
import 'ui/core/themes/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const config = AppConfig();
  final AudioController audio = await AudioService.init(
    builder: JustAudioController.new,
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.edmm.edmm.audio',
      androidNotificationChannelName: 'EDMM playback',
      androidNotificationOngoing: true,
    ),
  );
  final api = TrackApiService(http.Client(), config);
  final TrackRepository repo = RemoteTrackRepository(api);

  runApp(MultiProvider(
    providers: [
      Provider<AppConfig>.value(value: config),
      Provider<TrackApiService>.value(value: api),
      Provider<TrackRepository>.value(value: repo),
      Provider<AudioController>.value(value: audio),
    ],
    child: const EdmmApp(),
  ));
}

class EdmmApp extends StatelessWidget {
  const EdmmApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: appRouter,
    );
  }
}
```

- [ ] **Step 4: Delete home placeholder**

```bash
git rm lib/ui/home/view_model/home_view_model.dart lib/ui/home/widgets/home_screen.dart
```

- [ ] **Step 5: Replace widget_test.dart (F3)**

```dart
// test/widget_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:edmm/l10n/app_localizations.dart';
import 'package:edmm/domain/models/track.dart';
import 'package:edmm/domain/repositories/track_repository.dart';
import 'package:edmm/domain/result.dart';
import 'package:edmm/ui/track_list/view_model/track_list_view_model.dart';
import 'package:edmm/ui/track_list/widgets/track_list_screen.dart';

class _Repo implements TrackRepository {
  @override
  Future<Result<List<Track>>> getTracks({bool forceRefresh = false}) async =>
      const Ok<List<Track>>([]);
}

void main() {
  testWidgets('track list renders empty state without home placeholder', (tester) async {
    final vm = TrackListViewModel(_Repo());
    await vm.load();
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: TrackListScreen(viewModel: vm, onPlay: (_, __) {}),
    ));
    await tester.pump();
    expect(find.text('No tracks'), findsOneWidget);
  });
}
```

- [ ] **Step 6: Full gate — analyze + all tests**

Run: `flutter analyze`
Expected: 무경고.
Run: `flutter test`
Expected: 전체 PASS(home 참조 잔존 없음).

- [ ] **Step 7: Commit**

```bash
git add lib/routing/ lib/main.dart test/widget_test.dart
git commit -m "feat: wire routing, DI, remove home placeholder"
```

- [ ] **Step 8: Manual device verification (F4 — 자동 테스트 불가 영역)**

Run: `flutter run -d <android-emulator>` 후 확인:
- 목록 로드 → 트랙 탭 → 플레이어에서 재생/일시정지/탐색/이전·다음 동작.
- 앱 백그라운드 전환 후에도 재생 지속, 알림/잠금화면 미디어 컨트롤 노출·동작(아트워크 표시).
- (Mac 가용 시) `flutter run -d <ios>`로 iOS 백그라운드 오디오 확인.

---

## Self-Review

**1. Spec coverage** (설계 §·검토 findings → 태스크):
- BFF 데이터/병합: T4·T5·T3 ✅ · Track 모델: T2 ✅ · 재생 엔진/백그라운드/미디어세션: T6·T7 ✅ · 목록/플레이어 UI: T8–T11 ✅ · 라우팅/DI: T12 ✅ · 성능(position 분리): T11(StreamBuilder) ✅ · 에러/재시도: T5·T8·T10 ✅ · F3(home 제거+테스트 교체): T12 ✅ · F4(플랫폼 대조/기기검증): T7·T12 ✅ · F5(codegen 게이트): T2 ✅.
- Out-of-scope(라이브러리·EQ·비주얼라이저·셔플)는 태스크 없음 — 의도적.

**2. Placeholder scan:** "TODO/TBD/적절히 처리" 없음. 모든 코드 스텝에 실제 코드 포함. (audio_service 매니페스트는 실제 XML 제공 + 버전 대조는 검증 스텝으로 명시.)

**3. Type consistency:** `Result`/`Ok`/`Err`(`value`/`error`), `TrackApiException(statusCode)`, `TrackRepository.getTracks({forceRefresh})`, `AudioController`(loadQueue/play/pause/seek/next/previous/snapshot/position), `PlaybackSnapshot.isPlaying/copyWith`, `TrackListStatus`, `onPlay(List<Track>, int)` — 전 태스크 시그니처 일치 확인.

---

## Execution Handoff

이 계획은 사용자 지시(⑥ Task 분리까지)에 따라 **작성까지만** 수행하며, ⑦ 구현은 **별도 승인** 후 진행한다.
