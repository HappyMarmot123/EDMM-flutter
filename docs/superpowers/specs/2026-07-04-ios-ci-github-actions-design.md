# iOS CI (GitHub Actions) — 설계 문서

- 작성일: 2026-07-04
- 상태: **설계 승인 완료** — 구현 계획(writing-plans) 단계로 진행
- 범위: iOS 빌드 검증을 중심으로 한 GitHub Actions CI 구성. 서명/배포(TestFlight·App Store)는 범위 밖
- 선행 맥락: `docs/plans/2026-07-03-flutter-project-setup-plan.md` 4.5 / 9.4-1 (iOS CI 도입 보류분)

---

## 1. 배경과 목적

개발 환경이 Windows이므로 iOS 빌드를 로컬에서 검증할 수 없다(설치 계획 3.3, 4.5). 이 제약을
해소하기 위해 macOS 러너를 제공하는 GitHub Actions로 iOS 빌드를 자동 검증한다.

부수적으로, 현재 로컬에서만 수동 실행하는 `flutter analyze` / `flutter test` 회귀 방어도
CI로 편입해 커밋마다 자동 검증되도록 한다.

**핵심 목적**: `flutter build ios --no-codesign` 성공 여부를 커밋 단위로 자동 확인한다.

---

## 2. 확정된 결정 (사용자, 2026-07-04)

| # | 결정 항목 | 선택 | 근거 |
|---|---|---|---|
| 1 | 검증 범위 | **통합 CI** — analyze/test(ubuntu) + iOS 빌드(macOS) 2 job | macOS 분은 iOS 빌드에만 써 비용 절제, 회귀 방어 범위는 확대 |
| 2 | 실행 트리거 | **push(main) + PR(main) + workflow_dispatch** | 현재 main 직접 push 방식과 향후 PR 워크플로우 둘 다 커버 |
| 3 | Flutter 버전 | **3.44.4 정확히 고정** (stable) | 로컬(6장 실측)과 완전 일치 → "CI에서만 나는 회귀" 제거 |
| 4 | iOS 서명 | **`--no-codesign`** | Apple Developer 계정·인증서 없음. 목적은 빌드 검증뿐 |

---

## 3. 아키텍처

단일 워크플로우 파일 `.github/workflows/ci.yml`, 2개 job **병렬 실행**.

```
.github/workflows/ci.yml
├── job: analyze-and-test   (runs-on: ubuntu-latest)
│     ├─ actions/checkout
│     ├─ subosito/flutter-action  (flutter-version: 3.44.4, channel: stable, cache: true)
│     ├─ flutter pub get
│     ├─ flutter analyze
│     └─ flutter test
│
└── job: build-ios          (runs-on: macos-latest)
      ├─ actions/checkout
      ├─ subosito/flutter-action  (flutter-version: 3.44.4, channel: stable, cache: true)
      ├─ flutter pub get
      └─ flutter build ios --no-codesign
```

### 컴포넌트 경계

- **analyze-and-test job** — 무엇을: 정적 분석·단위/위젯 테스트. 의존: ubuntu 러너, Flutter SDK. iOS와 무관하게 독립 실행/판정.
- **build-ios job** — 무엇을: iOS 앱 번들을 서명 없이 컴파일해 빌드 가능성 검증. 의존: macOS 러너, Flutter SDK, CocoaPods(러너 기본 제공). 위 job과 상태 공유 없음(독립 병렬).

두 job은 서로 `needs` 의존을 두지 않는다 → 한 job 실패가 다른 job을 취소하지 않아, 한 번의 실행으로 두 종류 회귀를 모두 확인.

---

## 4. 트리거

```yaml
on:
  push:
    branches: [main]
  pull_request:
    branches: [main]
  workflow_dispatch:
```

---

## 5. 비용 통제

- **concurrency 그룹**: 브랜치 단위로 묶고 `cancel-in-progress: true` → 같은 브랜치에 새 push가 오면 진행 중인 이전 실행 취소, macOS 분 낭비 방지.
- macOS 러너(분당 과금 ubuntu의 약 10배)는 `build-ios` job에서만 사용.
- 캐시(`cache: true`)로 Flutter SDK/pub 의존성 반복 다운로드 절감.

---

## 6. 로컬 완료 기준과의 정합 (설치 계획 4.7)

| CI 단계 | 대응 완료 기준 |
|---|---|
| `flutter analyze` | 4.7-4 (경고 0건) |
| `flutter test` | 4.7-3 (위젯 테스트 통과) |
| `flutter build ios --no-codesign` | 4.5 (Windows에서 불가한 iOS 빌드 검증) — 이 CI의 핵심 목적 |

---

## 7. 성공 판정 기준

1. `.github/workflows/ci.yml` push 후 GitHub Actions에서 워크플로우가 트리거된다.
2. `analyze-and-test` job이 성공(analyze 경고 0건, 전체 테스트 통과)한다.
3. `build-ios` job이 성공(`--no-codesign` 빌드 완료)한다.
4. concurrency 취소·캐시 동작이 로그에서 확인된다.

---

## 8. 범위 밖 (YAGNI / 후속 사이클)

- iOS 코드 서명·프로비저닝, TestFlight/App Store 배포
- Android APK 빌드 job (로컬에서 이미 검증됨 — 설치 계획 9.2)
- 커버리지 리포트 업로드, 아티팩트 보관
- 매트릭스 다중 Flutter 버전
