# EDMM Flutter 모바일앱 — 프로젝트 설치 및 세팅 계획

- 작성일: 2026-07-03 / 최종 갱신: 2026-07-04
- 상태: **전 단계 완료** — 세팅 사이클 종료, 잔여 항목은 9.3 참조
- 범위: Flutter 프로젝트 생성·환경 세팅까지. 앱 도메인/기능 기획은 이 문서의 범위가 아님 (사용자 지시로 보류)

---

## 0. 개발 파이프라인과 가드레일

```
아이디어 제안 → 스크리닝 → 기획설계 → 코드베이스 기반 문서구체화 → 문서검토 → 작업 Task 분리 → 구현진행
     [완료]      [완료]      [완료]              [완료]              [완료]        [완료]       [완료]
```

각 단계는 아래 가드레일을 통과해야 다음 단계로 진행한다. 불명확하면 즉시 질문하고 멈춘다.

| 가드레일 | 검증 내용 |
|---|---|
| 범위 | 해당 단계에서 결정할 것만 다루는가. 범위 밖 결정을 미리 하지 않았는가 |
| 근거 | 각 결정에 출처(공식 문서, 실측 데이터)가 있는가 |
| 모순 | 이전 단계 결정·기존 환경과 충돌하지 않는가 |
| 가독성 | 제3자가 문서만 읽고 같은 결론에 도달할 수 있는가 |
| 판정 | PASS / BLOCKED(사유 명시 후 질문) |

---

## 1. 사전 리서치 요약 (2026-07-03 기준)

### 1.1 Flutter 최신 버전

- 최신 스테이블: **3.44.4** (2026-06-24 릴리스), Dart 3.12.2
  - 출처: Flutter 공식 릴리스 피드(releases_windows.json) 실측 조회
- 현재 PC 설치 버전: 3.29.3 → `flutter upgrade`로 업그레이드 필요
- 3.44 주요 변경(Google I/O 2026):
  - **Agentic Hot Reload**: 코딩 에이전트가 실행 중인 앱에 자동 연결·핫리로드 (Claude/Codex 워크플로우와 직결)
  - Material/Cupertino 코어 프레임워크에서 동결, 향후 독립 패키지로 분리 예정
  - iOS/macOS 기본 의존성 관리가 Swift Package Manager로 전환
  - Impeller Vulkan 지원 개선, 위젯 프리뷰어(`@Preview`) 사용 가능
  - 출처: [Flutter 3.44 릴리스 노트](https://docs.flutter.dev/release/release-notes/release-notes-3.44.0), [What's new in Flutter 3.44](https://blog.flutter.dev/whats-new-in-flutter-3-44-b0cc1ad3c527)

### 1.2 아키텍처 트렌드

- Flutter 팀 공식 권장: **MVVM + 레이어드 아키텍처** (UI 레이어 / Data 레이어, 복잡할 때만 Domain 레이어 추가)
  - View ↔ ViewModel 1:1 관계, 위젯은 "dumb"하게 유지
  - Repository 패턴(데이터 접근 격리) + Service 클래스(외부 API 래핑, 무상태)
  - 단방향 데이터 흐름(Data → UI), 불변 데이터 모델
  - 출처: [공식 아키텍처 가이드](https://docs.flutter.dev/app-architecture/guide), [공식 권장사항](https://docs.flutter.dev/app-architecture/recommendations), [Compass 샘플 앱](https://github.com/flutter/samples/tree/main/compass_app)
- 폴더 구조 트렌드: **feature-first** (타입별이 아닌 기능별 그룹핑)

### 1.3 디자인패턴 / 상태관리 트렌드

| 선택지 | 2026 포지션 | 비고 |
|---|---|---|
| Riverpod 3 | 신규 프로젝트 주류. 컴파일 타임 안전성, 낮은 보일러플레이트 | unified Ref, 자동 재시도, 실험적 오프라인 퍼시스턴스 |
| Bloc 9 | 엔터프라이즈/규제 산업 표준. 명시적 이벤트→상태 전환 | 보일러플레이트 많음, 이벤트 추적 강함 |
| provider + ChangeNotifier | 공식 가이드 기본. 의존성 최소, SDK 내장 개념 활용 | Flutter 팀 Compass 샘플이 이 방식 |
| signals | 성능 극한 최적화용 신흥 옵션 | 세밀한 반응성, 생태계는 아직 작음 |

- 공통 패턴: Repository, Command(사용자 이벤트 표준화), 불변 모델(freezed), DI(provider), 라우팅은 **go_router**(공식: "90% 앱에 권장")
- 출처: [상태관리 옵션 공식 문서](https://docs.flutter.dev/data-and-backend/state-mgmt/options), [Riverpod vs Bloc 2026 비교](https://flutterstudio.dev/blog/bloc-vs-riverpod.html)

---

## 2. [1단계] 아이디어 제안 — 세팅 접근안 3개

### A안. 공식 가이드 표준 스택 (채택)

- `flutter create` 기본 생성 + 공식 아키텍처 가이드 그대로: MVVM 레이어드, provider(DI/상태), go_router, freezed(불변 모델), http 패키지
- 장점: 공식 문서·Compass 샘플·설치된 flutter/skills 10종과 완전 일치. 학습 곡선 최소. 서드파티 종속 최소
- 단점: provider+ChangeNotifier는 대규모 앱에서 Riverpod 대비 보일러플레이트/수동 관리 증가

### B안. Riverpod 3 스택

- A안의 레이어드 구조 + 상태관리·DI를 Riverpod 3(코드 생성)로 대체
- 장점: 2026 신규 프로젝트 주류, 컴파일 타임 안전성, 테스트 오버라이드 용이
- 단점: 공식 가이드 예제·flutter/skills 문서와 표기법이 달라 매핑 비용 발생. 코드 생성 의존

### C안. very_good_cli 템플릿

- VGV 템플릿으로 생성(Bloc, 멀티 flavor, 100% 커버리지 세팅 내장)
- 장점: CI/flavor/l10n 등 프로덕션 설정 즉시 확보
- 단점: Bloc 강제, 템플릿 규약 학습 필요, 1인 초기 개발에 과함

---

## 3. [2단계] 스크리닝

### 3.1 확정된 제약 조건 (사용자 결정, 2026-07-03)

1. 앱 도메인: **보류** — 프로젝트 설치·세팅에 집중
2. 타깃 플랫폼: **Android + iOS 동시**
3. 아키텍처/상태관리: **공식 가이드 그대로** (A안 선택)
4. 데이터: **REST API를 Flutter에서 직접 호출** (http 패키지)

### 3.2 스크리닝 판정

| 항목 | 판정 | 근거 |
|---|---|---|
| A안 (공식 표준 스택) | **PASS** | 사용자가 직접 선택. 공식 문서 근거 확보. 설치된 flutter/skills와 정합 |
| B안 (Riverpod 3) | DROP | 트렌드 우위는 있으나 사용자가 공식 가이드를 선택. 추후 전환 가능성만 기록 |
| C안 (very_good_cli) | DROP | Bloc 강제가 제약 3과 모순. 초기 규모에 과잉 |

### 3.3 가드레일 점검 (아이디어 제안·스크리닝 단계)

| 가드레일 | 결과 | 비고 |
|---|---|---|
| 범위 | PASS | 설치·세팅 결정만 다룸. 도메인 기획은 의도적으로 제외 |
| 근거 | PASS | 모든 버전·권장사항에 공식 문서/실측 출처 명시 |
| 모순 | PASS | 유의점 2건 해소: ① 위젯 프리뷰 스킬은 Flutter 3.29.3과 비호환 → 본 계획의 3.44.4 업그레이드로 해소 ② iOS 빌드는 Windows에서 불가 → 4.4에 대응 방침 명시 |
| 가독성 | PASS | 표·단계 구분으로 제3자 재현 가능 |
| 종합 | **PASS** | 기획설계 단계 진행 가능 (사용자 승인 필요) |

---

## 4. 설치 및 세팅 실행 계획 (기획설계 단계에서 확정 후 실행)

### 4.1 SDK 업그레이드

1. `flutter upgrade` → 3.44.4 / Dart 3.12.2 확인
2. `flutter doctor` 재검증 (Android toolchain 정상 유지 확인)

### 4.2 프로젝트 생성

```bash
flutter create --org <org.id> --platforms android,ios --project-name edmm .
```

- **[입력 대기]** `--org` 번들 ID(예: `com.example` 형식) — 기획설계 단계에서 확정 필요
- 기존 `.agents/skills/`, `docs/`와 충돌 없음 (flutter create는 기존 파일 보존)
- 생성 직후 `git init` + 최초 커밋 (이후 모든 단계는 git 이력으로 추적)

### 4.3 아키텍처 골격 (공식 가이드 기준)

```
lib/
├── main.dart
├── ui/
│   ├── core/            # 공용 위젯, 테마 (공식 권장: /widgets/ 대신 /core/)
│   └── <feature>/       # feature-first
│       ├── view_model/  #   <Feature>ViewModel
│       └── widgets/     #   <Feature>Screen + 하위 위젯
├── domain/
│   └── models/          # freezed 불변 모델
├── data/
│   ├── repositories/    # <Entity>Repository (abstract + 환경별 구현)
│   └── services/        # <Name>ApiService (REST 호출, 무상태)
├── routing/             # go_router 설정
└── config/              # 환경 설정, DI 조립
```

### 4.4 필수 패키지

| 용도 | 패키지 | 근거 |
|---|---|---|
| DI/상태 | provider | 공식 강력 권장 |
| 라우팅 | go_router | 공식 권장 (90% 앱) |
| 불변 모델 | freezed + json_serializable | 공식 조건부 권장 |
| REST | http | 제약 4 + flutter-use-http-package 스킬 정합 |
| 린트 | flutter_lints | 공식 권장 |
| 다국어 | flutter_localizations + intl | flutter-setup-localization 스킬 정합 |

### 4.5 iOS 대응 (Windows 개발 환경)

- 코드는 처음부터 iOS 포함으로 작성(플랫폼 분기 최소화)
- 빌드·실검증: Mac 확보 전까지 **Codemagic 또는 GitHub Actions(macos runner)** CI로 빌드 검증
- **[입력 대기]** CI 서비스 선택 — 기획설계 단계에서 확정

### 4.6 에이전트 도구 연동

- Dart MCP 서버(`dart mcp-server`)를 Claude/Codex 양쪽에 등록 → flutter-fix-layout-issues, flutter-add-integration-test 스킬 완전 활용
- 3.44 Agentic Hot Reload로 에이전트가 실행 중 앱에 직접 연결하는 워크플로우 확인

### 4.7 실행 확인 (완료 기준)

1. Android 에뮬레이터/실기기에서 `flutter run` 성공
2. 핫리로드 동작 확인
3. `flutter test` 기본 위젯 테스트 통과
4. `flutter analyze` 경고 0건

---

## 5. [3단계] 기획설계 확정 (2026-07-04)

사용자 입력으로 미해결 2건 해소:

1. 번들 ID: **com.edmm** → 앱 패키지 `com.edmm.edmm`
2. iOS CI: **보류** — 코드는 iOS 포함으로 작성, 빌드 검증 CI는 기능 개발 진행 후 도입

## 6. [4단계] 코드베이스 기반 문서구체화 — 실측 기록 (2026-07-04)

| 항목 | 계획 | 실측 결과 |
|---|---|---|
| Flutter 업그레이드 | 3.44.4 | **완료** — 3.44.4 / Dart 3.12.2 / DevTools 2.57.0 |
| Android SDK | 35.0.1 유지 가정 | **계획과 차이**: Flutter 3.44는 SDK 36 요구 → `sdkmanager`로 platforms;android-36 + build-tools;36.0.0 설치, doctor PASS |
| 프로젝트 생성 | flutter create | **완료** — 75개 파일 생성, `com.edmm.edmm`, android/ios 플랫폼 |
| git | init + 최초 커밋 | **완료** — `main` 브랜치, 최초 커밋 05a1fcc (스킬·문서 포함 79 파일) |
| 에뮬레이터 | 미확인 | Pixel_7, flutter_emulator 2개 확인됨 |

구현 골격(4.3)은 홈 피처 1개를 기준으로 최소 구현한다. `data/`, `domain/`은 첫 실제 피처에서
파일이 생기는 시점에 채워지며, 이 단계에서는 REST 호출 지점을 예약하는 구조만 잡는다 (YAGNI).

## 7. [5단계] 문서검토 — 가드레일 점검 (2026-07-04)

| 가드레일 | 결과 | 비고 |
|---|---|---|
| 범위 | PASS | 세팅·골격까지만. 도메인 기능 미포함 유지 |
| 근거 | PASS | 모든 실측값은 명령 출력 기준 (doctor, create, git log) |
| 모순 | PASS | 계획 대비 차이 1건(SDK 36 요구) 발견·해소·기록. 잔여 모순 없음 |
| 가독성 | PASS | 계획(4장) vs 실측(6장) 분리로 추적 가능 |
| 종합 | **PASS** | Task 분리 → 구현진행 |

## 8. [6단계] 작업 Task 분리

1. ~~Flutter 3.44.4 업그레이드 + doctor 검증~~ (완료)
2. ~~프로젝트 생성(com.edmm) + git 초기화~~ (완료)
3. 패키지 설치: provider, go_router, http, freezed, json_serializable, l10n, lints
4. MVVM 골격 + 홈 화면 + l10n(ko/en) + 위젯 테스트
5. 검증: analyze 0건 / test 통과 / apk 빌드 / 에뮬레이터 기동 → 최종 커밋

## 9. [7단계] 구현진행 기록 (2026-07-04 완료)

### 9.1 구현 내역

- 패키지: provider 6.1.5, go_router 17.3.0, http 1.6.0, intl 0.20.2(flutter_localizations 고정),
  freezed_annotation 3.1.0, json_annotation 4.12.0 / dev: build_runner, freezed 4.0.0-dev.3, json_serializable
  - 참고: freezed는 analyzer 13 호환을 위해 4.0 dev 채널로 해석됨. 모델 코드젠 도입 시 안정 버전 재확인 필요
- 구현 구조 (계획 4.3 대비 홈 피처 1개 최소 구현):
  - `lib/main.dart` — EdmmApp(MaterialApp.router), 전역 DI 조립 지점 예약
  - `lib/routing/` — appRouter(go_router), Routes 상수
  - `lib/ui/core/themes/theme.dart` — light/dark ColorScheme.fromSeed
  - `lib/ui/home/` — HomeViewModel(ChangeNotifier) + HomeScreen (View↔VM 1:1, 라우트에서 VM 주입)
  - `lib/l10n/` — app_en.arb, app_ko.arb + gen-l10n (l10n.yaml)
  - `data/`, `domain/`, `config/`는 첫 데이터 피처에서 생성 (YAGNI, 6장 방침)
- 테스트: `test/widget_test.dart` — 홈 렌더링 + 카운터 증가 위젯 테스트

### 9.2 검증 결과 (4.7 완료 기준 대비)

| 기준 | 결과 |
|---|---|
| flutter analyze | **PASS** — No issues found |
| flutter test | **PASS** — All tests passed |
| APK 빌드 | **PASS** — app-debug.apk 261.2s (NDK 28.2 자동 설치 포함) |
| 에뮬레이터 기동 | **PASS** — Pixel_7(emulator-5554)에서 com.edmm.edmm topResumedActivity·화면 렌더링 스크린샷 확인 |
| 핫리로드 | 보류 — 대화형 세션 필요. Dart MCP 서버 연동(4.6) 시 Agentic Hot Reload로 검증 예정 |

### 9.3 잔여 항목 (다음 사이클로 이월)

1. Dart MCP 서버를 Claude/Codex에 등록 (4.6)
2. iOS CI 도입 (기획설계에서 보류 결정)
3. 앱 도메인(EDMM 기능) 정의 → 새 파이프라인 사이클로 진행
