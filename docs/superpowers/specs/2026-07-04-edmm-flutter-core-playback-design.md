# EDMM Flutter — 코어 재생 슬라이스 기획설계 (Design)

## 메타데이터

| 항목 | 값 |
| --- | --- |
| 기준일 | 2026-07-04 |
| 단계 | ③ 기획설계 **(본 문서)** — 선행: [스크리닝](2026-07-04-edmm-flutter-core-playback-screening.md) |
| 이후(미착수) | ④ 코드베이스 기반 문서구체화 → ⑤ 문서검토 → ⑥ Task 분리 → ⑦ 구현 |
| 확정 결정 | BFF 재사용 · 코어 재생 슬라이스 · MVVM+Provider+Repository · **오디오=just_audio+audio_service** · **아트워크=image 병합 이식** |

> 본 문서는 **아키텍처·인터페이스 수준 설계**다. 정확한 파일 경로·시그니처의 코드베이스 정합은 ④에서, 실제 코드는 ⑥/⑦에서 확정한다.

---

## 1. 목표 & 범위

**목표.** EDMM 웹의 음악 재생 도메인을 Flutter로 이식하되 화려한 UI는 배제하고, **계층 분리·데이터 흐름·재생 파이프라인의 견고함과 성능**을 확보한다.

| In scope | Out of scope (이후 마일스톤) |
| --- | --- |
| 트랙 목록 조회(video+image 병합) | 검색 UI, 딥링크/시드 |
| 재생/일시정지/탐색/이전·다음 | 라이브러리(최근·즐겨찾기·플레이리스트) 영속화 |
| 백그라운드 재생 + OS 미디어 세션 | 셔플, EQ 프리셋, 볼륨 바 |
| 재생 상태 머신·에러/재시도 | 비주얼라이저, 풀스크린 연출, 픽셀 단위 UI |
| 아트워크 병합(잠금화면 아트 포함) | 로컬 영속 캐시(인메모리만) |

---

## 2. 아키텍처 개요

**계층과 단방향 의존성 규칙**: `UI → Domain ← Data`. UI는 `just_audio`/`http`/`audio_service`를 **직접 알지 못한다**(추상 인터페이스로만 접근). 도메인은 순수(플러그인·프레임워크 비의존).

```
┌───────────────── UI ─────────────────┐
│ TrackListScreen / PlayerScreen        │  StatefulWidget + ListenableBuilder
│   └ *ViewModel (ChangeNotifier)       │  화면 상태·명령
└───────────────┬───────────────────────┘
                │ 의존(주입)
┌───────────────▼──────── Domain ───────┐
│ models: Track, PlaybackSnapshot        │  순수 불변 모델(freezed)
│ abstractions: TrackRepository,         │  인터페이스(구현 비의존)
│               AudioController          │
│ logic: ArtworkMerger (pure)            │  키 매칭 병합(순수·테스트대상)
└───────────────▲──────────────┬────────┘
                │ 구현           │ 구현
┌───────────────┴──── Data ─────▼────────┐
│ RemoteTrackRepository → TrackApiService(http) │
│ JustAudioController → just_audio + audio_service │
└────────────────────────────────────────┘
```

각 유닛은 **무엇을/어떻게/무엇에 의존** 3문장으로 설명 가능해야 하며, 내부 교체 시 소비처가 깨지지 않아야 한다(인터페이스 경계).

---

## 3. 폴더 구조 (현 스캐폴드 확장)

```
lib/
  config/
    app_config.dart              # BFF baseUrl, 타임아웃 등 환경값
  domain/
    models/
      track.dart                 # freezed Track (+fromJson), Duration 헬퍼
      playback_snapshot.dart     # freezed 재생 상태 스냅샷
    repositories/
      track_repository.dart      # 추상: getTracks()
    audio/
      audio_controller.dart      # 추상: 재생 명령 + 상태 스트림
    logic/
      artwork_merger.dart        # 순수 함수: video+image 병합
    result.dart                  # freezed sealed Result<T> (Ok/Err) + Failure
  data/
    services/
      track_api_service.dart     # http GET /video, /image
    repositories/
      remote_track_repository.dart
    audio/
      just_audio_controller.dart # AudioController 구현 (just_audio+audio_service)
  ui/
    core/themes/theme.dart       # (기존)
    track_list/
      view_model/track_list_view_model.dart
      widgets/track_list_screen.dart      # Routes.trackList '/'
    player/
      view_model/player_view_model.dart
      widgets/player_screen.dart          # Routes.player '/player'
  routing/router.dart, routes.dart
  l10n/…                         # (기존)
  main.dart                      # async: AudioService.init → MultiProvider → runApp
```
> `ui/home/*`(카운터)는 `track_list`로 대체한다.

---

## 4. 도메인 계층

### 4.1 `Track` (근거: 2.8 실측 스키마, 웹 `entities/track/model.ts`)

```dart
@freezed
class Track with _$Track {
  const Track._();
  const factory Track({
    required String id,
    required String source,          // "cloudinary"
    required String title,
    required String artistId,
    required String artistName,
    String? albumName,
    @Default('') String artworkUrl,  // 병합 후 채워짐
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
> 서버가 `filterPlayable=true`로 이미 필터링하므로 `isPlayable`은 방어적 보조 수단.

### 4.2 `Result<T>` / `Failure`
프레임워크 예외를 도메인 경계에서 흡수하기 위한 sealed 타입. Repository는 예외를 던지지 않고 `Result`를 반환한다.

```dart
sealed class Result<T> { const Result(); }
class Ok<T>  extends Result<T> { final T value;      const Ok(this.value); }
class Err<T> extends Result<T> { final Failure error; const Err(this.error); }
// Failure: network / parse / server(status) / unknown
```

### 4.3 `PlaybackSnapshot`
UI에 노출할 재생 상태의 단일 스냅샷(불변). 위치(position)는 고빈도 갱신이므로 **스냅샷에서 분리**해 별도 스트림으로 노출(→ §9 성능).

```dart
@freezed  // 예시
class PlaybackSnapshot {
  Track? currentTrack; PlaybackStatus status;   // idle/loading/ready/playing/paused/completed/error
  Duration duration; int? queueIndex; bool hasNext; bool hasPrevious; Failure? error;
}
```

### 4.4 `ArtworkMerger` (순수 로직 — 웹 `useCloudinaryTracks.ts` 병합 이식)

**입력**: `audioTracks`(artwork 빈 값), `imageTracks`(artwork 채움). **출력**: artwork가 채워진 `audioTracks`.

- `normalizeForMatching(s)`: `trim → toLowerCase → 확장자(.xxx) 제거 → 공백 1칸 축약 → 문자/숫자/공백 외 제거 → trim`.
- `buildMatchKeys(track)` → Set: `publicId basename stem`, `title`, `"title album"`, `"artist title"`, `"title artist"`, `artist`, `album` (정규화 적용, 빈 값 제외).
- 병합: 이미지들을 (key→imageId) 인덱스로 구성(먼저 등록된 key 우선). 각 오디오 트랙의 키를 **정의 순서대로** 조회해 첫 매칭 이미지의 `artworkUrl(∥streamUrl)`을 채운다. 오디오가 이미 artwork를 가지면 유지.

> 엣지케이스(부분 매칭·중복 키·미매칭)가 많아 **TDD 대상**. 픽스처는 실 API 응답에서 추출.

---

## 5. 데이터 계층

### 5.1 `TrackApiService` (근거: 2.8 실측 엔드포인트)

| 메서드 | 요청 | 반환 |
| --- | --- | --- |
| `fetchAudioTracks()` | `GET {base}/api/cloudinary/tracks/video?filterPlayable=true` | `List<Track>` (32건, artwork 공백) |
| `fetchImageTracks()` | `GET {base}/api/cloudinary/tracks/image` | `List<Track>` (33건, artwork 채움) |

- `base` = `AppConfig.bffBaseUrl` (`https://edmm.vercel.app`).
- 타임아웃 적용, 비200 시 `Failure.server(status)` 유발용 예외, JSON 파싱 실패 시 `Failure.parse`.

### 5.2 `RemoteTrackRepository`
```dart
abstract class TrackRepository { Future<Result<List<Track>>> getTracks({bool forceRefresh}); }
```
- 흐름: `fetchAudioTracks()` ∥ `fetchImageTracks()` **병렬** → `ArtworkMerger.merge()` → 인메모리 캐시 저장 → `Ok(list)`.
- 캐시: 최초 성공 결과를 메모리에 보관(재조회 억제), `forceRefresh`로 무효화. (영속 캐시는 이후 마일스톤.)
- 예외는 전부 `Err(Failure…)`로 변환 — 상위(ViewModel)는 예외를 보지 않는다.

---

## 6. 재생 계층 (핵심)

### 6.1 `AudioController` (도메인 추상) / `JustAudioController` (구현)

```dart
abstract class AudioController {
  Stream<PlaybackSnapshot> get snapshot;     // 상태(위치 제외)
  Stream<Duration> get position;             // 고빈도 위치 (분리)
  Future<void> loadQueue(List<Track> tracks, {int initialIndex});
  Future<void> play();  Future<void> pause();
  Future<void> seek(Duration to);
  Future<void> next();  Future<void> previous();
  Future<void> dispose();
}
```

- **구현**: `audio_service`의 `BaseAudioHandler`(+ `QueueHandler`/`SeekHandler`) 내부에 `just_audio` `AudioPlayer`. 큐는 `ConcatenatingAudioSource`(각 `AudioSource.uri(track.streamUrl)`).
- `just_audio`의 `positionStream`/`durationStream`/`playerStateStream`/`currentIndexStream`을 구독해 `PlaybackSnapshot`·`position`으로 매핑.
- **MediaItem 매핑**(잠금화면/알림): `title`, `artist=artistName`, `duration`, `artUri = 병합된 artworkUrl`(§4.4로 채워짐) → 아트워크가 OS 컨트롤에도 표시됨.

### 6.2 상태 머신

```
        loadQueue
 idle ─────────────▶ loading ──ready──▶ ready
                        │                 │ play
                        │ error           ▼
                        ▼            playing ⇄ paused   (pause/play)
                      error             │ 곡 끝
                        ▲               ▼
                (any)───┘           completed ──(next 자동/수동)──▶ loading
  * error → (retry) → loadQueue
```
매핑: `just_audio ProcessingState(idle/loading/buffering/ready/completed)` + `playing:bool` → `PlaybackStatus`. 소스 오류 → `error` + `Failure`.

### 6.3 플랫폼 설정 (구현 Task로 명시)
- **Android**: `audio_service` foreground service·권한을 `AndroidManifest.xml`에 등록, 알림 채널.
- **iOS**: `Info.plist`에 `UIBackgroundModes: [audio]`, 오디오 세션 카테고리.

---

## 7. UI 계층 & 라우팅

현 관례 준수: View=`StatefulWidget`(생성자 `viewModel` 주입, `dispose`에서 정리), `ListenableBuilder` 리빌드, ViewModel=`ChangeNotifier`, 라우터가 진입 시 생성·주입.

### 7.1 `Routes`
```dart
abstract final class Routes {
  static const String trackList = '/';
  static const String player = '/player';
}
```

### 7.2 `TrackListViewModel` / `TrackListScreen`
- VM: `load()` → `repo.getTracks()` → 상태 `loading/data(list)/empty/error`. `onSelect(index)` → `audio.loadQueue(list, initialIndex:index)` + `play()` → `/player` 이동.
- View: `ListView.builder`(가상화), 행=제목·아티스트·(아트워크 썸네일). 상태별 렌더 + 재시도 버튼.

### 7.3 `PlayerViewModel` / `PlayerScreen`
- VM: `audio.snapshot` 구독 → `notifyListeners`. 명령 위임: play/pause/seek/next/previous. `position`은 별도 노출(슬라이더 전용).
- View(무장식 Material): 아트워크(플레이스홀더 fallback), 제목/아티스트, **seek 슬라이더(StreamBuilder<Duration> position)**, play/pause·prev·next, 에러 시 재시도.

---

## 8. DI / 조립 (`main.dart`)

```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final controller = await AudioService.init(builder: () => JustAudioController(...));
  runApp(MultiProvider(providers: [
    Provider<AppConfig>(...),
    Provider<TrackApiService>(...),
    Provider<TrackRepository>(...),        // RemoteTrackRepository
    Provider<AudioController>.value(value: controller),
  ], child: const EdmmApp()));
}
```
- ViewModel은 라우트 진입 시 `context.read<…>()`로 의존성 조회 후 생성(현 라우터 패턴 유지).
- `EdmmApp`은 기존 `MaterialApp.router`·테마·l10n 유지.

---

## 9. 에러 / 로딩 / 회복 · 10. 성능 · 11. 테스트

### 9. 에러/로딩/회복
- 목록: `Result` → `loading/data/empty/error(+재시도)`. 재시도는 `getTracks(forceRefresh:true)`.
- 재생: 소스/네트워크 오류 → `PlaybackStatus.error` + `Failure` 바인딩 → UI 재시도(현재 곡 재로드).
- 부분 실패 내성: image 조회 실패 시에도 **오디오 목록은 렌더**(아트워크만 공백) — 병합은 best-effort.

### 10. 성능 설계 (사용자 우선순위)
- **위치 스트림 분리**: position 틱은 슬라이더만 리빌드(`StreamBuilder`), 전체 화면 리빌드 금지.
- `ListView.builder` 가상화 + `const` 위젯 + 필요한 곳만 `ListenableBuilder`/`context.select`.
- 인메모리 캐시로 재조회 억제, video·image **병렬** 조회로 지연 최소화.
- CDN 프로그레시브 스트리밍(just_audio) — 전체 다운로드 대기 없음.
- 아트워크는 `.m4a`와 무관한 별도 image URL이므로 목록은 지연 로딩(썸네일) 처리.

### 11. 테스트 전략 (TDD 우선순위: 병합 > repo > VM)
| 대상 | 방식 |
| --- | --- |
| `ArtworkMerger` | 순수 함수 단위 테스트(실 응답 픽스처, 매칭·미매칭·중복 키 케이스) |
| `Track.fromJson` | 실 응답 픽스처 역직렬화 |
| `TrackApiService` | mock http client(200/비200/파싱실패) |
| `RemoteTrackRepository` | fake service — 병렬·병합·캐시·`Result` 변환 |
| ViewModel | fake repo/controller — 상태 전이·명령 위임 |
| `AudioController` | 추상화로 ViewModel을 실제 오디오 없이 검증 |

---

## 12. 신규 의존성 & 플랫폼 설정

| 추가 | 용도 |
| --- | --- |
| `just_audio` | 오디오 재생 엔진(스트리밍·큐·seek) |
| `audio_service` | 백그라운드 재생 + OS 미디어 세션(잠금화면/알림/헤드셋) |
| (기존) `http`, `provider`, `go_router`, `freezed`, `json_serializable`, `intl` | 재사용 |

플랫폼: AndroidManifest(foreground service·알림), iOS Info.plist(`UIBackgroundModes: audio`). CI 3-job(analyze·test·iOS·Android) 유지.

---

## 13. 가드레일 판정

| 가드레일 | 상태 | 근거 |
| --- | :---: | --- |
| 범위(Scope) | PASS | 코어 재생 슬라이스로 한정, In/Out 명시(§1). |
| 근거(Evidence) | PASS | 엔드포인트·병합 알고리즘·현 코드 관례를 실측/인용(2.8, `useCloudinaryTracks.ts`, 스캐폴드 파일). |
| 모순(Contradiction) | PASS | 시크릿 모순은 BFF로, 아트워크 공백은 병합으로 해소. 위치 고빈도 리빌드는 스트림 분리로 예방. |
| 가독성(Readability) | PASS | 계층도·인터페이스 스케치·표로 구조화, 플레이스홀더 없음. |
| **종합 Verdict** | **PASS** | 아키텍처·인터페이스·데이터/재생 흐름·성능·테스트까지 설계 완료. |

---

## 14. 다음 단계 — **여기서 정지 (STOP)**

승인 시 **④ 코드베이스 기반 문서구체화**로 진행하며 다룰 것:
1. 정확한 파일 경로·클래스 시그니처를 현 스캐폴드에 정합(`pubspec` 버전, l10n 키, 라우터 주입 지점).
2. `pubspec.yaml`에 추가할 의존성 버전, Android/iOS 설정 파일의 정확한 diff 지점 식별.
3. 병합 알고리즘·상태 머신의 테스트 픽스처·케이스 목록 구체화.

> 승인 없이는 ④ 이후로 진행하지 않는다.
