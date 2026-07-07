# EDMM Flutter 기존 작업물 재작업 감사

## 메타데이터

| 항목 | 값 |
| --- | --- |
| 작성일 | 2026-07-07 |
| 대상 Flutter 코드베이스 | `C:\Users\SR83\test\EDMM-flutter` |
| 기준 원본 웹앱 | `C:\Users\SR83\test\EDMM` |
| 진행방식 | Subagent-Driven |
| 목적 | 기존 Flutter 작업물을 `KEEP / REWORK / REPLACE / BLOCKED`로 분류하고, 원본 EDMM 웹앱 parity 기준의 재작업 범위를 확정한다. |

## 판정 규칙

| 판정 | 의미 |
| --- | --- |
| KEEP | 현재 책임과 구조가 유효하며, 다음 단계에서 그대로 기반으로 쓴다. |
| REWORK | 책임은 유지하지만 원본 웹앱 parity 또는 네이티브 품질 기준에 맞게 확장/수정한다. |
| REPLACE | 현재 구현이 목표와 맞지 않아 새 구현 또는 새 디자인 시스템으로 교체한다. |
| BLOCKED | 제품/플랫폼/운영 결정 없이는 구현 방향을 확정할 수 없다. |

---

## 1. Subagent-Driven 실행 기록

| Subagent | 범위 | 결과 |
| --- | --- | --- |
| 원본 웹앱 baseline explorer | `C:\Users\SR83\test\EDMM`만 읽기 전용 감사 | Cloudinary catalog/search, MusicShell, Dexie local library/cache, route/deep link/detail, audio provider, fullscreen/visualizer/EQ, fallback/observability를 parity target으로 식별 |
| Flutter 구현물 explorer | `C:\Users\SR83\test\EDMM-flutter\lib` 읽기 전용 감사 | core playback 구조는 KEEP, API/search/routing/UI/theme/local persistence는 REWORK/REPLACE로 분류 |
| Flutter 문서/테스트 explorer | `docs`, `test`, `l10n` 읽기 전용 감사 | 기존 core playback 문서/테스트 일부는 KEEP, 구현 전 상태로 남은 문서와 부족한 테스트는 REWORK로 분류 |

Subagent 결과를 그대로 최종 판정으로 쓰지 않고, 중복/충돌을 통합해 아래 감사표로 확정한다.

---

## 2. 단계별 게이트

| 단계 | 범위 | 근거 | 모순 | 가독성 | 상태 |
| --- | --- | --- | --- | --- | --- |
| 아이디어 제안 | 기존 Flutter 작업물이 폐기 대상인지, 재작업 대상인지 분류한다. | 원본 웹앱은 이미 Cloudinary search shell, local library, advanced player까지 구현되어 있다. | "코어 재생 완료"와 "웹앱 parity 완료"를 같은 말로 보지 않는다. | 감사 목적과 판정 규칙을 먼저 고정했다. | PASS |
| 스크리닝 | Flutter core playback 기반과 parity 미달 영역을 분리한다. | `just_audio`/`audio_service` 기반 재생은 동작 기반이 있고, 검색/라이브러리/UI parity는 아직 없다. | 유지 가능한 기반까지 교체하지 않는다. | KEEP/REWORK/REPLACE/BLOCKED 표로 분류한다. | PASS |
| 기획설계 | 재작업을 feature rewrite가 아니라 parity roadmap으로 나눈다. | 원본 기능군이 Cloudinary, MusicShell, Dexie, detail, audio UX, observability로 나뉜다. | 웹 전용 구현을 Flutter에 그대로 복사한다고 가정하지 않는다. | 단계별 task와 blocker를 분리한다. | PASS |
| 코드베이스 기반 문서구체화 | 원본과 Flutter의 실제 파일 근거로 판정한다. | Subagent 3개와 로컬 확인을 결합했다. | 확인하지 않은 기능을 구현 완료로 쓰지 않는다. | 각 판정에 파일 근거를 붙였다. | PASS |
| 문서검토 | 문서 자체가 다음 구현 계획의 기준으로 충분한지 점검한다. | 판정 규칙, 감사표, task 분리, 회귀 실행 섹션이 있다. | BLOCKED를 숨기지 않고 별도 섹션으로 올렸다. | 후속 실행자가 읽을 수 있게 섹션을 고정했다. | PASS |
| 작업 Task 분리 | 재작업 실행 순서를 독립 task로 분리한다. | P0 playback hardening 이후 P1 catalog/search부터 확장하는 순서가 안전하다. | local persistence와 advanced audio UX를 한 task에 섞지 않는다. | 각 task에 목표/대상/출구 조건을 둔다. | BLOCKED |
| 구현진행 | 이번 작업의 구현 범위는 감사 문서 생성이다. | 코드 변경 없이 `docs/superpowers/specs/2026-07-07-edmm-flutter-rework-audit.md`를 작성한다. | 앱 코드를 수정했다고 주장하지 않는다. | 문서 산출물 위치를 명시한다. | PASS |
| 회귀 실행 | 문서 작성 후 Flutter static/test 회귀를 실행한다. | `flutter analyze`, `flutter test`를 실행했다. | 문서만 바꿨더라도 기존 작업물 상태 확인을 회귀로 기록한다. | 실행 명령과 결과를 명확히 남긴다. | PASS |

BLOCKED 게이트:

아래 항목은 감사 문서 생성을 막지는 않지만, Task 3 이후 실제 parity 구현 착수를 막는 의사결정 게이트다. 따라서 위 단계표에서 `작업 Task 분리`는 task 목록 작성까지는 가능하나, 실행 착수 관점에서는 `BLOCKED`로 판정한다.

- 원본 `/track/[id]`처럼 Flutter도 "검색 화면 seeded detail"로 맞출지, 별도 native detail route로 확장할지 결정 필요
- EQ는 원본의 `flat`/`bass` preset parity만 맞출지, 10-band 조절 UI까지 노출할지 결정 필요
- Flutter observability backend를 Sentry로 맞출지, event schema만 맞출지 결정 필요
- Cloudinary/BFF base URL을 prod 고정으로 둘지, 환경별 config로 분리할지 결정 필요

---

## 3. 원본 웹앱 Parity 기준선

| 영역 | 원본 웹앱 기준 | Flutter 재작업 의미 |
| --- | --- | --- |
| Cloudinary catalog/search | `/api/cloudinary/tracks`가 `q`, `resourceType`, `filterPlayable`, `category`, cache version을 처리한다. 클라이언트는 `resourceType: all`에서 video/image를 분리하고 artwork fallback 병합 후 캐시한다. | 단순 `/video` + `/image` 호출을 catalog/search query model로 확장한다. |
| MusicShell/search UX | `/search`가 `view`와 `track` query를 받아 `pop`, `edm`, `recent`, 검색어, selected/current track, list/detail aside를 통합한다. | Flutter 첫 음악 surface를 단순 list가 아니라 search shell로 재작업한다. |
| Local library/cache | Dexie `edmm` DB에 `favorites`, `playlists`, `playlistTracks`, `recentPlays`, `trackCache`, `audioSettings`가 있다. | Flutter local persistence 계층을 도입한다. Drift 우선 검토. |
| Route/deep-link/detail | 원본 `/track/[id]`는 독립 상세 페이지가 아니라 `/search?track=<id>` redirect다. | Flutter detail/deep link 정책은 BLOCKED 결정 후 구현한다. |
| Audio provider/player | 전역 provider가 current track, queue, playbackQueue, time, duration, volume, mute, shuffle, playbackError, cache/recent 기록을 관리한다. | 현재 `AudioController`를 유지하되 state surface를 확장한다. |
| Audio engine | web은 AudioContext/analyser, transition/crossfade, dual slot, EQ filter chain을 가진다. | Flutter에서 가능한 기능과 플랫폼 fallback을 재해석한다. |
| Fullscreen/visualizer/EQ | desktop/mobile fullscreen, artwork palette backdrop, canvas visualizer, `flat`/`bass` EQ preset, 10-band filter가 있다. | Flutter advanced player milestone로 분리한다. |
| Fallback/observability | catalog fetch failed, search fallback used, IndexedDB unavailable, selected track unavailable, playback error taxonomy가 있다. | Flutter telemetry와 fallback UX 설계가 필요하다. |

---

## 4. Flutter 구현물 감사

| 대상 | 판정 | 근거 | 재작업 방향 |
| --- | --- | --- | --- |
| `lib/main.dart` | KEEP | `AudioService`, `TrackApiService`, `TrackRepository`, `AudioController` DI 구조가 분리되어 있다. | DI 구조 유지. provider 수가 늘면 composition만 정리한다. |
| `lib/config/app_config.dart` | REWORK | BFF URL이 prod URL로 고정되어 있다. | dev/prod/flavor 또는 dart-define 기반 config로 분리한다. |
| `lib/domain/models/track.dart` | KEEP | 원본 `Track`에 필요한 핵심 필드를 이미 담는다. | metadata typed accessor만 필요 시 추가한다. |
| `Track.isPlayable` | REWORK | `streamUrl`과 `metadata.resourceType != image`만 본다. | Cloudinary/BFF playable policy, invalid URL, unavailable 상태를 반영한다. |
| `lib/domain/result.dart` | KEEP | Network/Server/Parse 실패 모델이 있다. | observability phase에서 taxonomy 확장 검토. |
| `lib/domain/repositories/track_repository.dart` | REWORK | `getTracks` 단일 목록 계약뿐이다. | query/category/resourceType/detail/cache contract로 확장한다. |
| `lib/data/services/track_api_service.dart` | REWORK | `/video?filterPlayable=true`, `/image`만 호출한다. | `/api/cloudinary/tracks?q=&resourceType=all&category=` parity로 확장한다. |
| `lib/data/repositories/remote_track_repository.dart` | REWORK | audio/image 병합 기반은 유효하지만 `_cache` 단일 인메모리 캐시뿐이다. | stale/cache/fallback/local persistence와 분리한다. |
| `lib/domain/logic/artwork_merger.dart` | REWORK | 휴리스틱 병합은 유용하지만 케이스 커버가 부족하다. | publicId stem, dedupe, streamUrl fallback, real fixture 테스트 보강. |
| `lib/domain/audio/audio_controller.dart` | KEEP | playback abstraction이 명확하다. | volume/shuffle/error/retry가 필요하면 확장한다. |
| `lib/domain/playback/playback_snapshot.dart` | REWORK | player 상태 기반은 있으나 equality/replay/null-clear 정책 보강 필요. | snapshot replay, equality, explicit error 상태 정리. |
| `lib/data/audio/just_audio_controller.dart` | REWORK | OS media control 기반은 유효하지만 invalid `Uri.parse(t.streamUrl ?? '')` 위험이 있다. | playable filter, `Uri.tryParse`, queue load error handling, seed snapshot 추가. |
| `lib/data/audio/playback_mapping.dart` | KEEP | `MediaItem`과 processing state mapping 기반이 있다. | artwork URI parse 방어만 보강한다. |
| `lib/routing/router.dart`, `lib/routing/routes.dart` | REWORK | 현재 `/` list와 `/player` 중심이다. | `/search`, category/query state, detail/deep link route를 재설계한다. |
| `lib/ui/track_list/view_model/track_list_view_model.dart` | KEEP | loading/data/empty/error/forceRefresh 기반이 있다. | search shell VM으로 확장하거나 별도 VM을 만든다. |
| `lib/ui/track_list/widgets/track_list_screen.dart` | REWORK | 단순 `ListTile` 목록이다. | catalog/search shell, tabs, search input, fallback state, current/selected highlight 추가. |
| `lib/ui/player/view_model/player_view_model.dart` | KEEP | audio controller를 감싸는 얇은 VM 구조가 적절하다. | advanced controls 추가 시 메서드 확장. |
| `lib/ui/player/widgets/player_screen.dart` | REWORK | 기본 artwork/title/artist/seek/prev/play/next만 있다. | mini/expanded player, volume, shuffle, error feedback, long duration format, visual layer로 확장. |
| `lib/ui/core/themes/theme.dart` | REPLACE | 기본 Material indigo seed theme이다. | EDMM rose/black native design tokens와 component theme로 교체. |
| `lib/l10n/app_en.arb`, `lib/l10n/app_ko.arb` | REWORK | 코어 문구는 있으나 setup 잔재와 누락 키가 있다. | obsolete key 제거, search/library/player/fallback/error 문구 추가. |
| generated l10n files | KEEP | gen-l10n 구조가 정상이다. | ARB 수정 후 재생성만 수행. |

---

## 5. 문서/테스트 감사

| 대상 | 판정 | 근거 | 조치 |
| --- | --- | --- | --- |
| `docs/superpowers/specs/2026-07-04-edmm-flutter-core-playback-screening.md` | KEEP | BFF 재사용, core playback slice, MVVM 결정이 유효하다. | 역사적 기준 문서로 유지. |
| `docs/superpowers/specs/2026-07-04-edmm-flutter-core-playback-design.md` | KEEP | 1차 core playback architecture와 테스트 전략이 유효하다. | core playback 기준선 문서로 유지. |
| `docs/superpowers/specs/2026-07-04-edmm-flutter-core-playback-codebase.md` | REWORK | 구현 전 상태 문구가 남아 있다. | 구현 완료 이후 감사/정합 문서로 갱신. |
| `docs/superpowers/specs/2026-07-04-edmm-flutter-core-playback-review.md` | REWORK | 리뷰 전 상태와 현재 테스트 상태가 어긋난다. | 완료/미완료 findings를 현재 기준으로 재작성. |
| `docs/superpowers/plans/2026-07-04-edmm-flutter-core-playback.md` | REWORK | 계획서가 구현 전 핸드오프 상태로 남아 있다. | 실행 완료/이월/폐기 task로 체크포인트 갱신. |
| `docs/superpowers/specs/2026-07-04-edmm-flutter-core-playback-follow-up.md` | REWORK | 이번 parity 재작성으로 방향은 맞췄지만 제품 결정 BLOCKED가 있다. | 본 감사 문서와 연결하고 후속 스펙으로 분리. |
| `docs/superpowers/specs/2026-07-04-ios-ci-github-actions-design.md` | KEEP | analyze/test/iOS build 회귀 전략 기준으로 유효하다. | CI 구현 전까지 유지. |
| `docs/superpowers/plans/2026-07-04-ios-ci-github-actions.md` | REWORK | 로컬 경로/상태가 현재 환경과 다를 수 있다. | 실제 CI 상태 확인 후 갱신. |
| `test/domain/result_test.dart` | KEEP | Result/Failure 기본 계약을 고정한다. | 유지. |
| `test/domain/models/track_test.dart` | KEEP | Track JSON, duration, playable 판정을 검증한다. | playable 정책 확장 시 보강. |
| `test/domain/logic/artwork_merger_test.dart` | REWORK | 병합 핵심만 있고 edge coverage가 부족하다. | publicId stem, dedupe, fallback, fixture 추가. |
| `test/data/services/track_api_service_test.dart` | REWORK | 현재 endpoint 기준은 맞지만 search/category parity가 없다. | 새 query contract에 맞춰 확장. |
| `test/data/repositories/remote_track_repository_test.dart` | REWORK | 기본 병합/캐시는 검증하나 stale/local fallback이 없다. | repository split 후 보강. |
| `test/data/audio/playback_mapping_test.dart` | KEEP | MediaItem artwork와 state mapping을 검증한다. | URI 방어 추가 시 보강. |
| `test/domain/playback/playback_snapshot_test.dart` | REWORK | 최소 상태만 검증한다. | equality, replay, error/null-clear 정책 추가. |
| `test/ui/track_list/track_list_view_model_test.dart` | KEEP | list VM 기본 상태를 검증한다. | shell VM이 생기면 별도 테스트 추가. |
| `test/ui/track_list/track_list_screen_test.dart` | KEEP | list render와 onPlay queue/index 전달을 검증한다. | shell 재작업 전까지 core regression으로 유지. |
| `test/ui/player/player_view_model_test.dart` | REWORK | playPause 중심이다. | seek/next/previous/dispose/error 위임 보강. |
| `test/ui/player/player_screen_test.dart` | REWORK | 현재 트랙/재생 버튼만 검증한다. | seek/prev/next/null track/error/long duration 추가. |
| `test/widget_test.dart` | KEEP | 기본 empty state smoke test로 유효하다. | route/shell 변경 시 갱신. |

---

## 6. 작업 Task 분리

### Task 1. Core Playback Audit Sync

목표: 이미 구현된 core playback 문서와 계획의 상태를 현재 코드 기준으로 갱신한다.

대상:

- `docs/superpowers/specs/2026-07-04-edmm-flutter-core-playback-codebase.md`
- `docs/superpowers/specs/2026-07-04-edmm-flutter-core-playback-review.md`
- `docs/superpowers/plans/2026-07-04-edmm-flutter-core-playback.md`

출구 조건:

- 완료된 task, 이월된 task, 폐기된 task가 구분된다.
- 기존 "구현 전" 문구가 현재 상태와 충돌하지 않는다.

### Task 2. Native Playback Hardening

목표: core playback 기반을 유지하면서 crash/UX 위험을 줄인다.

대상:

- `lib/data/audio/just_audio_controller.dart`
- `lib/data/audio/playback_mapping.dart`
- `lib/domain/playback/playback_snapshot.dart`
- `lib/ui/player/widgets/player_screen.dart`
- 관련 테스트

출구 조건:

- invalid URI가 queue load crash로 이어지지 않는다.
- snapshot seed/replay와 equality가 정리된다.
- seek/prev/next/player screen 회귀 테스트가 보강된다.

### Task 3. Catalog/Search Shell Spec

목표: 원본 `MusicShell` parity를 Flutter native screen 구조로 구체화한다.

대상:

- 새 스펙 문서
- `TrackApiService` query contract
- repository/view model/screen 분할 설계

출구 조건:

- `q`, `category`, `resourceType`, fallback state, selected/current track 정책이 확정된다.
- BLOCKED 항목이 있으면 질문으로 멈춘다.

### Task 4. Local Library Persistence Spec

목표: Dexie schema parity를 Flutter persistence로 옮길 설계를 확정한다.

대상:

- favorites
- playlists / playlistTracks
- recentPlays
- trackCache
- audioSettings

출구 조건:

- Drift/Isar/sqflite 중 선택이 결정된다.
- local failure가 catalog/playback을 막지 않는 정책이 확정된다.

### Task 5. Player UX Parity Spec

목표: advanced player 기능을 native UX로 나눈다.

대상:

- mini/expanded player
- volume/mute
- shuffle
- playback error feedback
- fullscreen/visualizer/EQ

출구 조건:

- EQ scope와 visualizer 가능 범위가 확정된다.
- platform fallback 정책이 문서화된다.

### Task 6. Fallback/Observability Spec

목표: 원본 fallback/observability taxonomy를 Flutter에 맞게 확정한다.

대상:

- catalog fetch failed
- search fallback used
- local storage unavailable
- selected track unavailable
- playback error

출구 조건:

- Sentry 사용 여부 또는 동일 event schema의 대체 sink가 확정된다.
- query 원문/media URL/artwork URL 전송 금지 규칙이 테스트 가능하게 정리된다.

---

## 7. 구현진행

이번 단계에서 실제로 구현한 것은 코드가 아니라 감사 문서다.

생성:

- `docs/superpowers/specs/2026-07-07-edmm-flutter-rework-audit.md`

수정:

- 없음

코드 변경:

- 없음

---

## 8. 회귀 실행

실행 대상:

- `flutter analyze`
- `flutter test`

실행 결과:

| 명령 | 상태 | 근거 |
| --- | --- | --- |
| `flutter analyze` | PASS | `No issues found! (ran in 37.0s)` |
| `flutter test` | PASS | `+29: All tests passed!` |

수동 회귀는 아직 실행하지 않는다. Android/iOS 기기 재생, 백그라운드, 알림/잠금화면 media controls, artwork 표시는 별도 native playback hardening task의 종료 조건으로 둔다.

---

## 9. 최종 판정

| 항목 | 판정 |
| --- | --- |
| 기존 core playback 코드 | KEEP + REWORK |
| 기존 단순 list/player UI | REWORK |
| 현재 theme | REPLACE |
| 기존 core playback 문서 | KEEP + REWORK |
| 기존 테스트 | KEEP + REWORK |
| 원본 웹앱 parity 전체 | BLOCKED 항목 포함, 단계별 스펙 필요 |

결론:

기존 작업물은 폐기 대상이 아니다. 다만 "완료된 앱"이 아니라 "core playback 기반"으로 낮춰서 보고, 원본 EDMM 웹앱 parity를 위해 search shell, local library, detail/deep link, advanced player, fallback/observability를 별도 재작업해야 한다.
