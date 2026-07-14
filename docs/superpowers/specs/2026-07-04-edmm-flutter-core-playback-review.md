# EDMM Flutter — 코어 재생 슬라이스 문서검토 (Review)

## 메타데이터

| 항목 | 값 |
| --- | --- |
| 기준일 | 2026-07-04 |
| 단계 | ⑤ 문서검토 **(본 문서)** |
| 검토 대상 | ② [스크리닝](2026-07-04-edmm-flutter-core-playback-screening.md) · ③ [기획설계](2026-07-04-edmm-flutter-core-playback-design.md) · ④ [코드베이스 정합](2026-07-04-edmm-flutter-core-playback-codebase.md) |
| 목적 | 문서 간 **일관성·누락·모순·근거·가독성**을 교차검증하고 ⑥ Task 분리 준비도를 판정 |

---

## 1. 검토 방법

각 문서를 5개 가드레일(범위·근거·모순·가독성·완결성)로 교차 스캔하고, **문서 간 정합성**(스크리닝 결정 → 설계 반영 → 코드베이스 정합)을 추적한다. 발견은 심각도(🔴 블로킹 / 🟡 조치필요 / 🟢 정보)로 분류한다.

---

## 2. 발견 사항 (Findings)

| # | 심각도 | 발견 | 조치/해소 |
| --- | :---: | --- | --- |
| F1 | 🟢 | 스크리닝 2.8.2는 아트워크를 "결정 필요(플레이스홀더 vs 병합)"로 남겨둠 | ③에서 **image 병합**으로 확정됨. 스크리닝에 전방 참조 노트 추가(본 검토에서 반영). |
| F2 | 🟢 | ③ §4.1 `Track` 스케치가 `class Track with _$Track` | ④ §3에서 freezed 4.x 구문 **`abstract class`**로 정정 완료(문서 정합). |
| F3 | 🟡 | `ui/home/**` 삭제 시 **`test/widget_test.dart`**('home screen … counter increments')가 깨짐 (실측: grep 확인) | ⑥ Task에 **위젯 테스트 교체**(home 제거 + track_list/player 테스트 신설)를 명시 항목으로 포함. |
| F4 | 🟡 | ④ §5 audio_service Android 매니페스트/`AudioServiceActivity` 스니펫은 0.18 일반 셋업 기준 | ⑦ 착수 시 설치된 `audio_service` 버전 문서와 **문자열 대조** 후 확정(Task 명시). |
| F5 | 🟡 | freezed **4.0.0-dev.3** 프리릴리스 고정(코드젠 안정성 미검증) | ⑥ 첫 코드젠 Task에서 `build_runner build` **선검증** 게이트. 실패 시 안정 버전 조정은 별도 판단. |
| F6 | 🟢 | 엔드포인트: 스크리닝 탐침은 `/tracks?resourceType=all&filterPlayable=true`(32), 설계/구현 기준은 `/video?filterPlayable=true`(32)+`/image`(33) | 웹 병합이 `/video`+`/image`를 쓰므로 **구현 기준을 후자로 확정**. 둘 다 실측 200 확인 — 모순 아님. |

> 🔴 블로킹 없음. 🟡 3건은 모두 ⑥ Task로 추적되면 해소.

---

## 3. 문서 간 정합성 추적

| 스크리닝 결정 | 설계 반영(③) | 코드베이스 정합(④) | 일치 |
| --- | --- | --- | --- |
| BFF 재사용 | `TrackApiService`가 BFF GET | `app_config.bffBaseUrl` + http 1.6.0 | ✅ |
| 코어 재생 슬라이스 | In/Out 범위표 | 파일 매니페스트가 범위 내 파일만 | ✅ |
| MVVM+Provider+Repo | 계층도·인터페이스 | 현 라우터/main 관례에 매핑 | ✅ |
| just_audio+audio_service | `AudioController`/`JustAudioController` | 버전·플랫폼 설정 diff | ✅ |
| image 병합 | `ArtworkMerger`(순수) | 웹 알고리즘 이식 명시 | ✅ |

---

## 4. 플레이스홀더·모호성 스캔

- **플레이스홀더(TBD/TODO)**: 없음. 코드 스케치의 `...`는 "⑦에서 확정" 명시된 의도적 생략.
- **모호성**: 위치(position) 갱신 처리(전체 리빌드 vs 슬라이더만), 에러 경계(예외 vs Result), 아트워크 미매칭 처리 — 모두 단일 해석으로 확정됨.
- **범위 크립**: 없음(라이브러리·EQ·비주얼라이저 등은 일관되게 Out).

---

## 5. 가드레일 종합 판정

| 문서 | 범위 | 근거 | 모순 | 가독성 | 완결성 | Verdict |
| --- | :---: | :---: | :---: | :---: | :---: | :---: |
| ② 스크리닝 | P | P | P | P | P | **PASS** |
| ③ 기획설계 | P | P | P | P | P | **PASS** |
| ④ 코드베이스 | P | P | P | P | P | **PASS** |
| **전체** | | | | | | **PASS** (🟡 F3–F5는 ⑥에서 추적) |

---

## 6. Task 분리 준비도

**READY.** 설계·인터페이스·파일 매니페스트·플랫폼 diff·테스트 매트릭스가 확정되어, 독립적이고 검증 가능한 작업 단위로 분해할 근거가 충분하다. ⑥에서 반드시 반영할 항목:

1. F3 — home 제거 + 위젯 테스트 교체를 하나의 정합 Task로.
2. F4 — audio_service 플랫폼 설정은 "설치→버전 문서 대조→적용" 순.
3. F5 — 첫 codegen 성공을 초기 게이트 Task로.
4. 의존성 방향(도메인이 먼저, data/ui가 뒤)에 맞춘 **작업 순서**.

---

## 7. Verdict & 다음 단계

**종합 PASS** — 🔴 블로킹 없음. ⑥ Task 분리로 진행 가능.

> 승인 없이는 ⑦ 구현으로 진행하지 않는다.
