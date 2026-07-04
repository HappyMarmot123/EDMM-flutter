# EDMM Flutter — 코어 재생 슬라이스 후속작업 (Follow-up)

## 메타데이터

| 항목 | 값 |
| --- | --- |
| 기준일 | 2026-07-04 |
| 단계 | 구현 완료 후 후속작업 정리 |
| 구현 HEAD | `82f0b45` (development, origin push 완료) |
| 선행 문서 | [스크리닝](2026-07-04-edmm-flutter-core-playback-screening.md) · [기획설계](2026-07-04-edmm-flutter-core-playback-design.md) · [코드베이스 정합](2026-07-04-edmm-flutter-core-playback-codebase.md) · [문서검토](2026-07-04-edmm-flutter-core-playback-review.md) · [구현계획](../plans/2026-07-04-edmm-flutter-core-playback.md) |
| 구현 상태 | 12 태스크 완료 · `flutter analyze` clean · `flutter test` 29/29 · 최종 전체 리뷰(opus) Important 1건(`mediaItem`) 수정 완료, Minor는 본 문서로 이관 |

> 우선순위: **A(릴리스 전 필수) → B(하드닝, 비차단) → C(다음 기능 마일스톤)**. B/C는 코어 재생의 기능 정확성에는 영향 없음.

---

## A. 릴리스 전 필수

자동 테스트로 커버 불가능한 영역. 코어 재생을 "완료"로 확신하려면 필수.

### A1. 실기기 수동 검증 (Android 에뮬/기기, 가능하면 iOS)

`flutter run` 후 아래 체크리스트:

- [ ] 목록 로드 → 트랙 탭 → 재생 시작
- [ ] 재생 / 일시정지 / 탐색(seek) / 이전 · 다음
- [ ] 앱 백그라운드 전환 후에도 **재생 지속**
- [ ] **잠금화면 / 알림 미디어 컨트롤** 노출 및 동작
- [ ] 잠금화면 / 알림에 **제목 · 아티스트 · 아트워크** 표시 (← `mediaItem` 수정 `82f0b45` 검증 포인트)
- [ ] **OS 스킵**(잠금화면 · 블루투스 버튼)이 실제로 곡을 이동
- [ ] iOS: `flutter run -d ios` 로 백그라운드 오디오 (Mac + Xcode 필요)

> 근거: [구현계획](../plans/2026-07-04-edmm-flutter-core-playback.md) Task 12 Step 8. 오디오 통합(`just_audio`+`audio_service`)은 순수 헬퍼만 단위 테스트되고 라이브 동작은 기기 검증 대상.

---

## B. 하드닝 패스 (Minor — 병합 비차단, 품질/견고성)

리뷰(태스크별 + 최종 opus)에서 나온 Minor findings. 하나의 하드닝 티켓으로 묶어 처리 권장.

### B-1. 견고성 · 설계

| 항목 | 위치 | 내용 |
| --- | --- | --- |
| `Uri.tryParse` 방어 | `lib/data/audio/playback_mapping.dart`(artUri), `lib/data/audio/just_audio_controller.dart` `loadQueue`(streamUrl) | `Uri.parse`는 잘못된 입력에 throw. `tryParse` + null 가드로 전환, null-streamUrl 트랙 skip |
| 스냅샷 동등성 | `lib/domain/playback/playback_snapshot.dart` | `==`/`hashCode` 추가 → 스트림 `.distinct()`로 중복 알림 제거 |
| 초기 상태 replay | `lib/data/audio/just_audio_controller.dart`(snapshot 스트림) | 현재 broadcast는 초기값 없음 → `PlayerScreen` 진입 시 다음 이벤트까지 빈 화면. seed 또는 BehaviorSubject |
| position StreamBuilder 분리 | `lib/ui/player/widgets/player_screen.dart` | `ListenableBuilder` 밖(keyed)으로 빼서 notify 시 슬라이더 순간 0 리셋 제거 |
| 시간 포맷 | `lib/ui/player/widgets/player_screen.dart` `_fmt` | `inMinutes` 사용 → 1시간 이상 트랙이 `60+:SS`. `H:MM:SS`로 |
| 죽은 코드 | `lib/domain/playback/*`, `lib/data/audio/playback_mapping.dart` | `PlaybackStatus.ready/.error` 미생성, `PlaybackSnapshot.error` 미채움. 채우거나 제거 |
| copyWith null-clear | `lib/domain/playback/playback_snapshot.dart` | `?? this.x`라 nullable을 null로 되돌릴 수 없음(현재 생성자로만 스냅샷 생성해 무해하나 잠재 트랩) |

### B-2. 테스트 보강

| 대상 | 미커버 경로 |
| --- | --- |
| `ArtworkMerger` (`test/domain/logic/`) | **publicId-stem 매칭(최우선 키)**, audio dedup-by-id, streamUrl-fallback 분기 |
| `Track.fromJson` (`test/domain/models/`) | null `streamUrl`, JSON 기본값(artworkUrl·metadata 부재) |
| `TrackApiService` (`test/data/services/`) | parse-failure 매처 `isNotNull` → `isA<TypeError>()` 정밀화 |
| `RemoteTrackRepository` (`test/data/repositories/`) | Network/Parse 실패 경로, imagesCalls 카운터로 캐시 시 image도 skip 확인 |
| `Result`/`Failure` (`test/domain/`) | NetworkFailure/ParseFailure 분기 입력 |
| `PlayerViewModel` (`test/ui/player/`) | `dispose()` teardown, seek/next/previous 위임 |
| `TrackListScreen` (`test/ui/track_list/`) | loading/empty/error 렌더, onPlay 큐 identity(`same`) |
| `PlayerScreen` (`test/ui/player/`) | tap 후 `pump()`, 트랙 null 시 title 표시 |

### B-3. 정리

- 죽은 ARB 키 `homeSetupDone` / `increment` 제거 + `flutter gen-l10n` — `lib/l10n/app_en.arb`, `app_ko.arb`
- `TrackListScreen`을 `StatelessWidget`화(리소스 없음) → dispose 일관성(현재 `PlayerScreen`만 VM dispose)
- 값 타입 `toString()`/`@immutable` — `lib/config/app_config.dart`, `lib/domain/result.dart`
- `RemoteTrackRepository`의 `NetworkFailure(e.cause ?? 'network')` 기본 문자열 재검토(스펙 외)

---

## C. 다음 기능 마일스톤 (설계상 Out-of-scope → 로드맵)

각 마일스톤은 자체 스펙 → 계획 → 구현 사이클 권장(현 슬라이스와 동일 프로세스).

| 우선 | 마일스톤 | 내용 | 웹 대응 |
| --- | --- | --- | --- |
| C1 | **라이브러리** | 최근 재생 · 즐겨찾기 · 플레이리스트 + **로컬 영속화**(Drift/Isar/sqflite 중 택1) | Dexie `recentPlaysRepo`/`favoritesRepo`/`playlistsRepo` |
| C2 | **검색 UI** | 엔드포인트 `q` 이미 지원 → 검색 화면 + 딥링크/시드 | `/search` 플로우, `trackSeedUtils` |
| C3 | **재생 확장** | 셔플 · EQ 프리셋 · 볼륨 컨트롤 | `features/audio` (EQ 필터 체인) |
| C4 | **영속 메타데이터 캐시** | 현재 인메모리 전용 → 앱 재시작·오프라인 대비 영속 캐시 | `trackCacheRepo` |
| C5 | **화려한 UI 이식** | 비주얼라이저 · 풀스크린 플레이어 · 아트워크 크로스페이드 · 앨범 톤 컬러 — 원래 "추후 작업"으로 명시된 시각 연출 | `features/audio` fullscreen, `fullscreenAudioVisualizer` |

> C1(라이브러리)이 자연스러운 다음 수직 슬라이스: 데이터 계층(Repository)과 재생 파이프라인이 이미 서 있어 최소 증분으로 확장 가능.

---

## 참고: 추적성

본 문서의 B 항목은 구현 중 태스크별 리뷰 + 최종 전체 브랜치 리뷰(opus, `06f072e..d56c817`)에서 도출된 Minor findings의 이관본이다. 최종 리뷰 판정은 **"Ready to merge — with fixes"**였고, 그 유일한 Important(`mediaItem` 미emit)는 `82f0b45`에서 해소되었다. B/C는 병합 비차단.
