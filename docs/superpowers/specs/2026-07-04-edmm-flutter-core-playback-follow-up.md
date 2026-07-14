# EDMM Flutter — 원본 웹앱 재파악 기반 후속작업

## 메타데이터

| 항목 | 값 |
| --- | --- |
| 재작성일 | 2026-07-07 |
| 대상 문서 | `docs/superpowers/specs/2026-07-04-edmm-flutter-core-playback-follow-up.md` |
| 원본 웹앱 코드베이스 | `C:\Users\SR83\test\EDMM` |
| Flutter 코드베이스 | `C:\Users\SR83\test\EDMM-flutter` |
| 목적 | 기존 코어 재생 후속작업 문서를 최신 EDMM 웹앱 기능 기준으로 다시 정렬한다. |
| 현재 판정 | 코드베이스 파악 PASS, 문서 재작성 PASS |

이 문서는 Flutter 코어 재생 슬라이스 완료 후 남은 일을 단순 하드닝 목록으로 보지 않는다. 원본 EDMM 웹앱은 Cloudinary 카탈로그, 검색 shell, 로컬 라이브러리, 상세/deep link, 고급 오디오 UI, fallback/observability까지 확장되어 있으므로 Flutter 후속작업은 "원본 웹앱 parity를 향한 단계별 이식"으로 재정의한다.

---

## 1. 단계 가드레일

| 단계 | 범위 | 근거 | 모순 | 가독성 | 상태 |
| --- | --- | --- | --- | --- | --- |
| 코드베이스 파악 | 원본 EDMM 웹앱과 현재 Flutter 앱의 음악 기능 표면만 비교한다. | 파일 구조, 핵심 구현 파일, 기존 원본 스펙 문서를 확인했다. | 기존 Flutter 문서의 B/C 항목과 원본 웹앱 최신 기능을 분리했다. | 기능군별 표로 요약한다. | PASS |
| 문서 재작성 | 코드 변경 없이 후속작업 문서만 갱신한다. | 원본 구현 파일과 Flutter 구현 파일을 근거 행에 연결한다. | 원본 웹앱의 web-only 구현을 Flutter에 그대로 복사한다고 쓰지 않는다. | 우선순위, 포함/제외 범위, BLOCKED 기준을 분리한다. | PASS |

BLOCKED 조건:

- 원본 웹앱 parity가 "네이티브 UX로 재해석"인지 "웹앱 픽셀/동작 복제"인지 결정이 필요한 경우
- Cloudinary API/BFF를 Flutter가 직접 호출해야 하는지, 별도 Flutter용 BFF를 둘지 결정이 필요한 경우
- 사용자 데이터 저장소를 Drift/Isar/sqflite 중 무엇으로 할지 결정 없이는 다음 계획을 쓸 수 없는 경우
- 원본 웹앱의 Sentry/observability 정책을 Flutter에 동일하게 적용할지 제품 결정이 필요한 경우

현재 문서화 단계에서는 위 조건이 즉시 작업을 막지 않는다. 각 항목은 후속 구현 스펙의 의사결정 포인트로 분리한다.

---

## 2. 원본 EDMM 웹앱 파악 결과

| 기능군 | 현재 원본 웹앱 상태 | 근거 |
| --- | --- | --- |
| Cloudinary 도메인 모델 | `TrackSource`는 `cloudinary`이고 `Track`은 `id`, `title`, `artistName`, `artworkUrl`, `durationMs`, `streamUrl`, `metadata`를 가진다. 이미지 리소스는 `isPlayable`에서 제외된다. | `src/entities/track/model.ts:1`, `src/entities/track/model.ts:3`, `src/entities/track/model.ts:14` |
| Cloudinary API | `/api/cloudinary/tracks`, `/video`, `/image`가 있고 `q`, `resourceType`, `filterPlayable`, `category`, `cacheVersion`을 처리한다. | `src/app/api/cloudinary/tracks/route.ts:33`, `src/app/api/cloudinary/tracks/video/route.ts:10`, `src/app/api/cloudinary/tracks/image/route.ts:10` |
| Cloudinary client/cache | 서버 client는 Cloudinary Admin Search, 카테고리 폴더, query token, cache policy, playable filter를 다룬다. | `src/shared/api/cloudinary/cloudinaryClient.ts:151`, `src/shared/api/cloudinary/cloudinaryClient.ts:173`, `src/shared/api/cloudinary/cloudinaryClient.ts:195` |
| Search shell | `/search`는 `view`와 `track` query param을 해석하고 `SearchView`가 `MusicShell`을 렌더한다. | `src/app/search/page.tsx:16`, `src/app/search/page.tsx:24`, `src/views/search/index.tsx:13`, `src/views/search/index.tsx:19` |
| MusicShell | Pop/EDM 카탈로그를 각각 조회하고, 검색어 기반 조회, recent view, fallback 상태, 선택 track scroll/seed를 관리한다. | `src/widgets/musicShell/index.tsx:206`, `src/widgets/musicShell/index.tsx:281`, `src/widgets/musicShell/index.tsx:289`, `src/widgets/musicShell/index.tsx:305`, `src/widgets/musicShell/index.tsx:316`, `src/widgets/musicShell/index.tsx:397` |
| 로컬 라이브러리 | Dexie DB에 favorites, playlists, playlistTracks, recentPlays, trackCache, audioSettings 테이블이 있다. | `src/shared/db/edmmDB.ts:4`, `src/shared/db/edmmDB.ts:10`, `src/shared/db/edmmDB.ts:16`, `src/shared/db/edmmDB.ts:23`, `src/shared/db/edmmDB.ts:29`, `src/shared/db/edmmDB.ts:35` |
| 라이브러리 화면 | `LibraryView`는 favorites와 recent plays ID를 읽고 cached tracks로 hydrate한다. | `src/views/library/index.tsx:16`, `src/views/library/index.tsx:17`, `src/views/library/index.tsx:40`, `src/views/library/index.tsx:73` |
| 상세/deep link | `TrackDetailView`는 cached track을 불러오고, `/search?track=`와 연계되는 route-level selection flow가 있다. | `src/views/trackDetail/index.tsx:152`, `src/views/trackDetail/index.tsx:163`, `src/app/search/page.tsx:25`, `src/views/search/index.tsx:22` |
| 오디오 엔진 | provider가 queue, currentTrack, duration, buffering, volume, mute, shuffle, playbackError를 소유한다. track cache와 recent play 기록도 여기서 수행한다. | `src/shared/providers/audioPlayerProvider.tsx:72`, `src/shared/providers/audioPlayerProvider.tsx:74`, `src/shared/providers/audioPlayerProvider.tsx:75`, `src/shared/providers/audioPlayerProvider.tsx:108`, `src/shared/providers/audioPlayerProvider.tsx:156`, `src/shared/providers/audioPlayerProvider.tsx:195`, `src/shared/providers/audioPlayerProvider.tsx:331` |
| 미디어 세션/백그라운드 | Web Media Session, visibility/pagehide/pageshow playback lifecycle, crossfade duration을 가진다. | `src/shared/providers/audioPlayerProvider.tsx:44`, `src/shared/providers/audioPlayerProvider.tsx:504`, `src/shared/providers/audioPlayerProvider.tsx:515` |
| 고급 플레이어 UI | Desktop fullscreen player, fullscreen event, playback error feedback, volume controls, track-zone deep link가 있다. | `src/features/audio/ui/audioPlayer.tsx:28`, `src/features/audio/ui/audioPlayer.tsx:90`, `src/features/audio/ui/audioPlayer.tsx:127`, `src/features/audio/ui/audioPlayer.tsx:179`, `src/features/audio/ui/audioPlayer.tsx:231` |
| EQ/비주얼라이저 | EQ preset controller, equalizer panel, canvas visualizer, album palette, fullscreen visualizer가 구현되어 있다. | `src/features/audio/hooks/useEqualizerPresetController.ts:13`, `src/features/audio/components/equalizerPanel.tsx:19`, `src/features/audio/components/audioVisualizer.tsx:43`, `src/features/audio/components/visualizers/albumColorPalette.ts:96`, `src/features/audio/components/fullscreenAudioVisualizer.tsx:48` |
| 실패 UX/관측성 | 2026-07-05 문서와 구현은 catalog/search fallback, recent/cache unavailable, sanitized Sentry context를 기준선으로 삼는다. | `docs/superpowers/specs/2026-07-05-catalog-search-fallback-hardening-design.md` |

---

## 3. 현재 Flutter 앱 파악 결과

| 기능군 | 현재 Flutter 상태 | 근거 |
| --- | --- | --- |
| 기술 스택 | `provider`, `go_router`, `http`, `freezed`, `json_serializable`, `just_audio`, `audio_service`를 사용한다. | `pubspec.yaml:39`, `pubspec.yaml:40`, `pubspec.yaml:41`, `pubspec.yaml:43`, `pubspec.yaml:44`, `pubspec.yaml:45`, `pubspec.yaml:46` |
| 앱 composition | `main.dart`에서 `AudioService.init<JustAudioController>` 후 `TrackApiService`, `RemoteTrackRepository`, `AudioController`를 provider로 주입한다. | `lib/main.dart:19`, `lib/main.dart:28`, `lib/main.dart:30` |
| 라우팅 | 현재 `GoRouter`는 track list와 player route 중심이다. list tap은 `audio.loadQueue` 후 player route로 이동한다. | `lib/routing/router.dart:12`, `lib/routing/router.dart:19`, `lib/routing/router.dart:22`, `lib/routing/router.dart:32` |
| Track 모델 | 원본 모델과 유사한 `Track`을 Freezed로 정의했고 `isPlayable`은 `streamUrl`과 `metadata.resourceType != image`를 본다. | `lib/domain/models/track.dart:8`, `lib/domain/models/track.dart:27` |
| Cloudinary 조회 | audio endpoint는 `/api/cloudinary/tracks/video?filterPlayable=true`, image endpoint는 `/api/cloudinary/tracks/image`만 호출한다. 검색어, 카테고리, all resource query는 없다. | `lib/data/services/track_api_service.dart:20`, `lib/data/services/track_api_service.dart:23` |
| artwork 병합 | audio와 image를 받아 `ArtworkMerger.merge`로 병합한다. image fetch 실패는 빈 목록으로 흡수된다. | `lib/data/repositories/remote_track_repository.dart:18`, `lib/data/repositories/remote_track_repository.dart:20`, `lib/data/repositories/remote_track_repository.dart:22` |
| 캐시 | `RemoteTrackRepository`는 인메모리 `_cache`만 가진다. 앱 재시작, offline, favorites/recent/playlists 영속화는 없다. | `lib/data/repositories/remote_track_repository.dart:7`, `lib/data/repositories/remote_track_repository.dart:13` |
| 재생 컨트롤 | `JustAudioController`는 queue load, play/pause/seek/next/previous, OS skip, mediaItem emit을 처리한다. | `lib/data/audio/just_audio_controller.dart:36`, `lib/data/audio/just_audio_controller.dart:52`, `lib/data/audio/just_audio_controller.dart:56`, `lib/data/audio/just_audio_controller.dart:64`, `lib/data/audio/just_audio_controller.dart:81` |
| UI | `TrackListScreen`은 단순 list, `PlayerScreen`은 artwork/title/artist/seek/prev/play/next 중심이다. | `lib/ui/track_list/widgets/track_list_screen.dart:6`, `lib/ui/player/widgets/player_screen.dart:5` |
| 테스트 | 현재 테스트는 core playback slice의 모델, repository, service, playback mapping, track list/player view model/screen에 집중되어 있다. | `test/domain/models/track_test.dart`, `test/data/repositories/remote_track_repository_test.dart`, `test/ui/player/player_screen_test.dart` |

판정: Flutter 앱은 "Cloudinary-backed native core playback"까지 도달했다. 원본 웹앱의 "music app shell parity"는 아직 시작 단계다.

---

## 4. 모순 정리

| 이전 문서 내용 | 최신 원본 기준 재판정 | 처리 |
| --- | --- | --- |
| 라이브러리, 검색 UI, 셔플/EQ/비주얼라이저를 C 로드맵으로 묶음 | 원본 웹앱에서는 이미 핵심 음악 경험의 일부다. 특히 `/search` shell이 canonical route다. | C 로드맵에서 parity 마일스톤으로 승격한다. |
| B 하드닝은 병합 비차단 minor | 네이티브 재생 안정성에는 여전히 필요하지만, 웹앱 parity와 별도 축이다. | "P0 네이티브 재생 안정화"로 유지한다. |
| 검색 UI는 endpoint `q` 지원만 언급 | 원본은 `q`뿐 아니라 `category`, `resourceType`, `filterPlayable`, stale fallback, recent view를 함께 다룬다. | 검색을 단순 text field가 아니라 catalog/search shell로 재정의한다. |
| 라이브러리는 Drift/Isar/sqflite 중 택1로만 표현 | 원본은 favorites, playlists, recentPlays, trackCache, audioSettings까지 테이블 경계가 확정되어 있다. | 저장소 선택 전에도 도메인/테이블 parity 범위를 명확히 한다. |
| 화려한 UI 이식은 "추후" | 원본은 fullscreen player, album palette, canvas visualizer, EQ, volume/mute, shuffle이 구현 상태다. | 오디오 UX parity 마일스톤으로 분리한다. |

---

## 5. 후속작업 우선순위

### P0. 네이티브 재생 안정화

목표: 현재 Flutter 코어 재생이 Android/iOS에서 릴리스 가능한 수준인지 먼저 닫는다.

필수 작업:

- Android 에뮬레이터/실기기에서 목록 로드, track tap, play/pause, seek, previous/next 검증
- 백그라운드 전환 후 재생 지속 검증
- 잠금화면/알림 media controls, title/artist/artwork 표시 검증
- OS skip, Bluetooth media button 동작 검증
- `Uri.tryParse` 방어, null/invalid streamUrl skip, snapshot seed/replay, position stream 분리, 1시간 이상 time format 수정

PASS 기준:

- Flutter 앱이 현재 Cloudinary audio queue를 정상 load/play한다.
- OS media controls가 실제 queue index를 이동한다.
- invalid media URL이 앱 전체 crash로 이어지지 않는다.

BLOCKED 기준:

- `audio_service`/`just_audio` 조합에서 특정 플랫폼 권한 또는 foreground service 설정 결정이 필요한 경우
- iOS 검증 환경이 없어 iOS background audio를 완료 판정할 수 없는 경우

### P1. Cloudinary Catalog/Search Shell

목표: 원본 `/search`의 핵심 browsing 경험을 Flutter의 첫 music surface로 만든다.

범위:

- Pop/EDM 카테고리 탭 또는 segmented control
- 검색어 입력과 debounce
- `/api/cloudinary/tracks`의 `q`, `resourceType=all`, `category`, `filterPlayable`, `cacheVersion` parity
- video/image 병합 유지
- loading, empty, error, stale-data 상태 구분
- 선택 track과 현재 재생 track의 list highlight

근거:

- 원본 `MusicShell`은 pop/edm 카탈로그를 각각 조회하고 검색어 기반 active view를 구성한다.
- Flutter는 현재 `/video?filterPlayable=true`와 `/image`만 호출한다.

PASS 기준:

- Flutter에서 Pop/EDM 카탈로그 전환과 검색이 가능하다.
- 검색 실패와 검색 결과 없음이 다른 UI 상태로 보인다.
- 검색 중에도 현재 재생 queue가 불필요하게 초기화되지 않는다.

BLOCKED 기준:

- Flutter가 원본 Next.js BFF를 그대로 base URL로 호출할지, Flutter 전용 API gateway를 둘지 결정이 필요한 경우
- Cloudinary category taxonomy가 `pop`/`edm` 외에 확장되어 있어 모바일 IA 결정이 필요한 경우

### P2. 로컬 라이브러리와 영속 캐시

목표: 원본 Dexie 저장소를 Flutter local persistence로 이식한다.

범위:

- `trackCache`: Cloudinary track payload 저장과 bulk hydrate
- `recentPlays`: 최근 재생 ID, 중복 제거, 최대 개수 제한
- `favorites`: favorite toggle과 favorite list
- `playlists`, `playlistTracks`: playlist 생성과 track 추가
- `audioSettings`: EQ preset, volume/mute 같은 사용자 설정 저장

저장소 후보:

- Drift: query/testability가 좋고 relational table parity에 강하다.
- Isar: object store UX가 좋지만 relation parity를 직접 설계해야 한다.
- sqflite: 단순하지만 repository boilerplate가 늘어난다.

권장: Drift. 원본 Dexie schema가 table 중심이고 `favorites`, `playlistTracks`, `recentPlays`, `trackCache`, `audioSettings` 경계가 명확하다.

PASS 기준:

- 앱 재시작 후 최근 재생, 즐겨찾기, cached track detail이 유지된다.
- cache 실패가 catalog browsing과 playback을 막지 않는다.
- favorites/recent view가 실제 empty와 storage unavailable을 구분한다.

BLOCKED 기준:

- 암호화 저장, 백업 제외, 데이터 보존 정책 같은 제품/플랫폼 결정이 필요한 경우

### P3. Track Detail, Deep Link, Selection Recovery

목표: 원본의 right aside/detail route 개념을 Flutter 내비게이션과 화면 구조에 맞게 이식한다.

범위:

- track detail 화면 또는 adaptive side panel
- artwork/title/artist/album/source/duration/metadata 표시
- `/track/:id` 또는 앱 내부 deep link 대응
- `?track=`에 해당하는 selection seed/recovery 정책을 Flutter route extra/path parameter로 재해석
- visible list, cached track, first playable fallback 순서 정의

PASS 기준:

- 목록에서 선택한 track의 detail이 재생 여부와 독립적으로 표시된다.
- cached track이 있으면 catalog 재조회 전에도 detail을 복구한다.
- 복구 실패는 list 전체 error가 아니라 detail 영역의 unavailable 상태로 제한된다.

BLOCKED 기준:

- Flutter 앱의 target platform별 deep link scheme/app link 정책 결정이 필요한 경우

### P4. 고급 오디오 UX Parity

목표: 원본 웹앱의 오디오 사용감을 Flutter에 맞게 단계적으로 이식한다.

범위:

- shuffle queue
- volume/mute controls
- EQ preset과 저장
- playback error feedback와 retry
- fullscreen player 또는 expanded now-playing surface
- artwork crossfade
- album artwork 기반 palette 추출
- audio visualizer
- mobile mini-player/expanded-player 분리

PASS 기준:

- 기본 playback controls와 advanced controls가 같은 `AudioController` state를 공유한다.
- shuffle, volume, EQ preset은 앱 재시작 후에도 기대한 상태로 복구된다.
- visualizer는 audio analyser 미지원 플랫폼에서 비차단 fallback을 가진다.

BLOCKED 기준:

- Flutter에서 선택한 audio backend가 실시간 frequency data를 안정적으로 제공하지 못하는 경우
- iOS/Android EQ 구현 방식이 플랫폼별로 갈라져 공통 UX 결정을 먼저 해야 하는 경우

### P5. Fallback/Observability Parity

목표: 원본 2026-07-05 catalog/search fallback hardening을 Flutter에도 반영한다.

범위:

- catalog initial failure와 refetch failure 구분
- stale successful tracks 유지
- search empty와 search error 분리
- local storage unavailable과 실제 empty 분리
- retry/clear search/all catalog 이동 action
- sanitized error context

PASS 기준:

- query 원문, media URL, artwork URL을 crash/error telemetry에 보내지 않는다.
- catalog 실패가 player, selected detail, cached recent 탐색을 막지 않는다.
- fallback 상태는 테스트로 고정된다.

BLOCKED 기준:

- Flutter telemetry provider를 Sentry로 확정하지 않았거나 privacy payload 정책이 미정인 경우

### P6. 테스트와 수동 검증 체계

목표: 원본 웹앱의 테스트 밀도에 맞춰 Flutter 회귀 안전망을 확장한다.

범위:

- repository/service/model 단위 테스트
- catalog/search shell widget test
- local persistence repository test
- player view model/controller test
- detail/deep link route test
- Android 수동 검증 checklist
- iOS 수동 검증 checklist

PASS 기준:

- 각 parity 마일스톤은 실패 test, 구현, pass test 순서로 닫는다.
- 릴리스 전에는 Android 실기기 또는 에뮬레이터 수동 playback checklist가 완료된다.

BLOCKED 기준:

- 테스트에서 Cloudinary/네트워크에 직접 의존해야만 검증 가능한 구조가 되는 경우

---

## 6. 이전 B 하드닝 유지 항목

아래 항목은 원본 웹앱 parity와 별개로 현재 Flutter 코어 재생 품질을 위해 유지한다.

| 항목 | 위치 | 조치 |
| --- | --- | --- |
| invalid URI 방어 | `lib/data/audio/just_audio_controller.dart`, `lib/data/audio/playback_mapping.dart` | `Uri.tryParse`와 playable filter로 crash 방지 |
| snapshot replay | `lib/data/audio/just_audio_controller.dart` | player 화면 진입 시 초기 snapshot 제공 |
| snapshot equality | `lib/domain/playback/playback_snapshot.dart` | 중복 rebuild 방지 |
| position rebuild 분리 | `lib/ui/player/widgets/player_screen.dart` | slider 순간 reset 방지 |
| long duration format | `lib/ui/player/widgets/player_screen.dart` | `H:MM:SS` 지원 |
| nullable copyWith 정책 | `lib/domain/playback/playback_snapshot.dart` | nullable clear semantics 명확화 |
| dead status 정리 | `lib/domain/playback/*`, `lib/data/audio/playback_mapping.dart` | 미생성 status를 채우거나 제거 |
| ARB unused key 정리 | `lib/l10n/app_en.arb`, `lib/l10n/app_ko.arb` | 사용하지 않는 key 제거 후 l10n 재생성 |

---

## 7. 후속 문서 분리 권장

이 문서는 전체 parity 지도다. 구현은 아래처럼 독립 스펙으로 나누는 것이 안전하다.

| 순서 | 권장 스펙 문서 | 목적 |
| --- | --- | --- |
| 1 | `docs/superpowers/specs/2026-07-07-edmm-flutter-native-playback-hardening.md` | P0 네이티브 재생 안정화 |
| 2 | `docs/superpowers/specs/2026-07-07-edmm-flutter-catalog-search-shell.md` | P1 catalog/search shell |
| 3 | `docs/superpowers/specs/2026-07-07-edmm-flutter-local-library-cache.md` | P2 local persistence |
| 4 | `docs/superpowers/specs/2026-07-07-edmm-flutter-track-detail-deeplink.md` | P3 detail/deep link |
| 5 | `docs/superpowers/specs/2026-07-07-edmm-flutter-advanced-audio-ux.md` | P4 advanced player |
| 6 | `docs/superpowers/specs/2026-07-07-edmm-flutter-fallback-observability.md` | P5 fallback/telemetry |

---

## 8. 최종 가드레일 판정

| 가드레일 | 상태 | 근거 |
| --- | --- | --- |
| 범위 | PASS | 원본 EDMM 웹앱의 음악 기능과 현재 Flutter 음악 기능의 parity gap만 다뤘다. 랜딩, Next.js infra, 외부 API 재도입은 제외했다. |
| 근거 | PASS | 원본 `Track`, Cloudinary API/client/hook, `MusicShell`, Dexie repositories, audio provider/player, route/detail, 기존 스펙 문서를 확인했다. Flutter는 pubspec, routing, service, repository, audio controller, list/player UI를 확인했다. |
| 모순 | PASS | 기존 문서의 하드닝 항목은 유지하고, 원본 웹앱에서 이미 구현된 기능은 낮은 우선순위 backlog가 아니라 parity 마일스톤으로 승격했다. |
| 가독성 | PASS | 파악 결과, 모순 정리, 우선순위, PASS/BLOCKED, 후속 문서 분리를 별도 섹션으로 나눴다. |

문서화 단계 결론: PASS.
