# EDMM 웹 → Flutter 모바일 이식 — 아이디어 제안 & 스크리닝

## 메타데이터

| 항목 | 값 |
| --- | --- |
| 기준일 | 2026-07-04 |
| 단계 | ① 아이디어 제안 → ② 스크리닝 **(본 문서에서 여기까지)** |
| 이후 단계(미착수) | ③ 기획설계 → ④ 코드베이스 기반 문서구체화 → ⑤ 문서검토 → ⑥ Task 분리 → ⑦ 구현 |
| 원본 | `C:\Users\a6r79\EDMM` — EDMM 웹(Next.js 16, React 19, FSD) |
| 대상 | `C:\Users\a6r79\edmm-flutter` — Flutter(스캐폴드 완료) |
| 확정 결정 | (A) 배포된 웹 API를 BFF로 재사용 · (B) 코어 재생 슬라이스 · (C) MVVM + Provider + Repository 확정 |

> 스코프 원칙: **화려한 UI 재현은 이후 작업.** 본 이식의 1차 목표는 **아키텍처·데이터 계층·재생 파이프라인의 견고함과 성능**이다.

---

## 1. 아이디어 제안 (Idea Proposal)

### 1.1 목적

EDMM 웹의 **음악 재생 도메인**을 Flutter 모바일 앱으로 이식한다. 원본의 시각적 연출(비주얼라이저, 풀스크린 크로스페이드, 리퀴드 글래스 등)은 배제하고, **도메인 모델·상태 전이·데이터 흐름**을 Flutter의 계층형 MVVM으로 재구성해 "성능 중심으로 기능을 완벽히 구현"하는 토대를 만든다.

### 1.2 무엇을 만드는가 (범위)

**In scope — 코어 재생 수직 슬라이스**

- 트랙 목록 조회(원격 BFF) → 목록 렌더
- 플레이어: 재생 / 일시정지 / 탐색(seek) / 이전·다음
- 백그라운드 재생 + OS 미디어 컨트롤(잠금화면·알림·헤드셋)
- 재생 상태 전이(intent → prepare → transition → playing/paused/failed → retry)의 견고한 모델링
- 에러/로딩/회복 정책(목록·재생 실패 시 fallback·재시도)

**Out of scope — 이후 마일스톤으로 연기 (deferred)**

- 검색 UI(엔드포인트는 `q` 지원하나 이번엔 목록 중심), 딥링크/시드 로직
- 라이브러리(최근 재생·즐겨찾기·플레이리스트) 로컬 영속화
- 셔플, EQ 프리셋, 볼륨 바(모바일은 하드웨어 볼륨 관례)
- 비주얼라이저, 풀스크린 크로스페이드, 앨범 톤 컬러 추출 등 시각 연출
- 화려한 UI/애니메이션 픽셀 단위 재현

### 1.3 성공 기준 (측정 가능)

1. 앱 실행 → 원격에서 재생 가능한 트랙 목록을 받아 렌더한다.
2. 트랙 선택 → 재생/일시정지/탐색/이전·다음이 모두 동작한다.
3. 앱을 백그라운드로 보내도 재생이 지속되고, 잠금화면/알림의 미디어 컨트롤로 제어된다.
4. 재생 실패(네트워크·소스 오류) 시 앱이 죽지 않고 오류 상태 → 재시도 경로를 제공한다.
5. `flutter analyze` 무경고 + 각 계층(Repository/ViewModel)의 단위 테스트 통과.

---

## 2. 스크리닝 (Screening)

### 2.1 확정 결정 요약

| # | 결정 | 선택 | 핵심 근거 |
| --- | --- | --- | --- |
| A | 데이터 소스 | **배포된 웹 API를 읽기 전용 BFF로 재사용** | 시크릿 노출 불가 모순을 해소하는 유일한 저비용 경로 |
| B | MVP 범위 | **코어 재생 수직 슬라이스** | 아키텍처를 끝단까지 검증하는 최소 단위 |
| C | 아키텍처 | **MVVM + Provider + Repository 확정** | 현 스캐폴드와 일치, 플러터 공식 앱 아키텍처 가이드 형태 |

### 2.2 데이터 소스 전략 — BFF 재사용

**모순 및 해소.** 웹은 서버 라우트가 `CLOUDINARY_API_SECRET`으로 Cloudinary Admin API를 호출한다(`cloudinaryClient.ts:62-73, 178, 202`). 모바일 앱 바이너리에는 이 시크릿을 안전하게 담을 수 없다. → **이미 배포된 Next.js API 라우트를 읽기 전용 BFF로 재사용**하면 시크릿은 서버에만 남고 앱은 정규화된 JSON만 소비한다.

**엔드포인트 계약 (근거: `src/app/api/cloudinary/tracks/route.ts`)**

- `GET /api/cloudinary/tracks`
  - 쿼리: `q`(검색, 기본 ""), `resourceType`(`video|image|all`, 기본 `all`), `filterPlayable`(`true|false`, 선택)
  - 응답 `200`: `Track[]` (아래 도메인 모델 배열)
  - 응답 `500`: 서버 설정 누락, `502`: 업스트림 실패 — 형식 `{ "error": string }`
- 변형: `/api/cloudinary/tracks/image`, `/api/cloudinary/tracks/video`

**도메인 모델 (근거: `src/entities/track/model.ts`)**

```ts
Track {
  id: string; source: "cloudinary"; title: string;
  artistId: string; artistName: string; albumName?: string;
  artworkUrl: string; durationMs: number;
  streamUrl?: string; metadata: Record<string, unknown>;
}
// isPlayable: streamUrl 존재 && metadata.resourceType != "image"
```

**성능상 이점.** 트랙 **메타데이터**만 BFF에서 받고, 실제 **오디오 스트림은 `Track.streamUrl`(Cloudinary CDN)에서 직접** 재생한다. 오디오 바이트가 BFF를 경유하지 않으므로 대역폭·지연이 유리하다.

```
Flutter App ──GET /api/cloudinary/tracks──▶ Vercel(Next API) ──secret──▶ Cloudinary Admin API
   │                                                              (메타데이터만)
   └────────────audio stream (streamUrl)──────────────────────▶ Cloudinary CDN
```

**리스크 & 완화**

- 앱이 웹 배포 가용성에 결합됨 → 메타데이터 로컬 캐시 + 재시도/타임아웃(이후 라이브러리 단계에서 영속 캐시 강화).
- 엔드포인트 공개 여부·레이트리밋 미확인 → **기획설계 진입 전 실제 200/JSON 응답 확인**(아래 2.7).
- 네이티브 앱은 브라우저 CORS 비대상이라 CORS는 문제 아님(단, WAF/봇 차단 가능성은 확인 대상).

### 2.3 MVP 기능 범위 — 웹 → 모바일 매핑

| 웹 기능(근거: `docs/architecture/README.md`) | 이번 슬라이스 | 비고 |
| --- | :---: | --- |
| 트랙 목록 조회(`useCloudinaryTracks`) | ✅ In | `filterPlayable=true`로 재생 가능 트랙만 |
| 재생/일시정지/탐색/이전·다음 | ✅ In | Provider 소유 재생 상태를 ViewModel/Service로 대응 |
| 백그라운드 재생 + MediaSession(§6 `useMediaSession`) | ✅ In | 모바일 OS 미디어 세션으로 구현 |
| 재생 상태 전이·재시도(§10.2) | ✅ In | 명시적 상태로 모델링 |
| 검색 UI / 딥링크·시드(§5) | ❌ Out | 엔드포인트 `q`는 이후 활용 |
| 라이브러리: 최근 재생·즐겨찾기·플레이리스트(§7.3) | ❌ Out | 다음 마일스톤(로컬 DB) |
| 셔플 / EQ 프리셋 / 볼륨 바 | ❌ Out | 모바일은 하드웨어 볼륨 |
| 비주얼라이저 / 풀스크린 연출(§8) | ❌ Out | 시각 연출은 이후 |

### 2.4 아키텍처 방향 — 계층형 MVVM (웹 FSD → Flutter)

현 스캐폴드가 이미 채택한 **UI · Domain · Data 계층 분리 + MVVM(ViewModel = `ChangeNotifier`) + Provider DI + Repository**를 확정·강화한다(근거: `pubspec.yaml`의 provider/go_router/freezed, `lib/main.dart` 주석 "Repository/Service가 생기면 MultiProvider로 전역 DI", `lib/ui/home/...` 구조).

| 웹(FSD) | Flutter 계층 | 책임 |
| --- | --- | --- |
| `entities` | `domain/models` | 순수 도메인 모델(`Track`) — freezed 불변 모델 |
| `shared/api`, `shared/db` | `data/services`, `data/repositories` | 원격 API 클라이언트 · Repository(캐시 경계) |
| `features`, `widgets`, `views` | `ui/<feature>/{view_model,widgets}` | 화면 상태·로직(ViewModel) + View |
| `shared/providers`(재생 상태) | `data/services/audio_*` + ViewModel | 재생 엔진 소유 서비스 + 화면 상태 |
| `app`(routing) | `routing/` | go_router 라우팅 |

```
View(위젯) ──watch──▶ ViewModel(ChangeNotifier) ──▶ Repository ──▶ Service(원격 API / 오디오 엔진)
        ▲ 주입(Provider DI)                 ▲ 도메인 모델 반환
```

- 단일 책임·명확한 경계: View는 렌더만, ViewModel은 화면 상태, Repository는 데이터 획득·캐시, Service는 외부 I/O(HTTP·오디오).
- 각 유닛은 "무엇을 하는가 / 어떻게 쓰는가 / 무엇에 의존하는가"를 독립적으로 설명·테스트 가능해야 한다.

### 2.5 기술 실현성 (개념 검증 — 정확한 패키지는 ③ 기획설계에서 확정)

| 관심사 | 현 스캐폴드 | 이식 후보 방향 |
| --- | --- | --- |
| 도메인 직렬화 | `freezed`, `json_serializable` 존재 | `Track[]` JSON → 불변 Dart 모델 (그대로 활용) |
| 네트워크 | `http` 존재 | `http`로 BFF GET, 인터셉트/재시도는 얇은 클라이언트로 |
| 재생 엔진 | 없음 | **재생·탐색·큐 + 백그라운드 + OS 미디어 세션**을 제공하는 오디오 스택 도입 필요(§2.7 오픈 이슈) |
| DI / 상태 | `provider` 존재 | ViewModel·Repository·Service를 MultiProvider로 조립 |
| 라우팅 | `go_router` 존재 | 목록 → 플레이어 라우팅 |
| i18n | `l10n`(en/ko) 존재 | 그대로 활용 |

> 재생 엔진 관련 패키지 도입은 스코프상 **기획설계 단계의 결정 사항**이며, 본 스크리닝은 "모바일에서 백그라운드 재생 + OS 미디어 컨트롤이 표준적으로 실현 가능"까지만 판정한다.

### 2.6 리스크 & 완화

| 리스크 | 영향 | 완화 |
| --- | --- | --- |
| ~~BFF 엔드포인트 공개·안정성 미확인~~ | — | **해소**: 2.8 실측(200/공개 JSON, 32건) |
| 웹 배포 가용성에 결합 | 오프라인/장애 시 목록 공백 | 메타데이터 캐시 + 재시도, 이후 영속 캐시 |
| 백그라운드 재생 플랫폼 설정(Android foreground service / iOS background audio) | 미설정 시 백그라운드 중단 | 오디오 스택 도입 시 매니페스트/Info.plist 설정을 Task로 명시 |
| ~~`streamUrl` 호스트/포맷 미검증~~ | — | **해소**: 2.8 실측(`res.cloudinary.com`, `.m4a`/AAC, 네이티브 지원) |
| 아트워크 미제공(playable 0/32) | 미디어 세션 아트워크 공백 | 2.8.2 — 플레이스홀더(권장) 또는 image 병합 |

### 2.7 가정 & 확인 필요 (③ 기획설계의 입력)

- **[검증완료]** 엔드포인트 도달성·계약·`streamUrl` 포맷 → **2.8 참조**(2026-07-04 실측).
- **[가정]** 대상 플랫폼 = iOS + Android(현 CI 구성 근거). 웹/데스크톱은 범위 밖.
- **[가정]** 인증/로그인 없음(웹도 공개 재생 중심) — 실측에서 무인증 200 확인.
- **[결정 위임]** 오디오 스택·네트워크 클라이언트·로컬 캐시 저장소의 구체 패키지는 ③에서 확정.
- **[결정 필요]** 아트워크 처리 전략 → **2.8.2 참조**.

### 2.8 API 검증 결과 (2026-07-04 실측)

**Verdict: PASS** — 배포된 BFF는 무인증 공개 JSON을 반환하며 모바일에서 그대로 소비 가능하다.

#### 2.8.1 검증된 계약

| 항목 | 실측 결과 |
| --- | --- |
| 도달성 | `GET https://edmm.vercel.app/api/cloudinary/tracks?resourceType=all&filterPlayable=true` → **200 OK** |
| 인증 | 없음(공개), `Content-Type: application/json`, `Cache-Control: public, max-age=300`, Vercel 서빙 |
| 응답 형태 | `Track[]` — **재생 가능 트랙 32건**, 필수 필드 32/32 채워짐(id·source·title·artistId·artistName·durationMs·streamUrl·metadata) |
| `streamUrl` | 32/32 `res.cloudinary.com`(CDN), 컨테이너 **`.m4a`(AAC)** → **iOS·Android 네이티브 코덱 지원** |
| `durationMs` | 32/32 유효(124,212–329,352 ms ≈ 2–5.5분) |
| `resourceType` | 전부 `video`(오디오를 Cloudinary video 리소스로 저장) |

→ 2.6의 "`streamUrl` 호스트/포맷 미검증", 2.2의 "엔드포인트 공개 여부 미확인" 리스크 **해소**.

#### 2.8.2 발견: 아트워크는 별도 리소스에 있음 (③에서 결정)

- `filterPlayable=true` 응답의 **`artworkUrl`은 0/32(전부 빈 문자열)**. 재생 트랙 자체에는 아트워크가 없다.
- `resourceType=image` 응답은 **33건 전부 `artworkUrl` 채워짐(33/33)**, 오디오 트랙과 **제목·아티스트로 매칭**됨(예: `Bloom` / `Feint x DJ Sally`). 즉 아트워크는 image 리소스에 있고, 웹은 오디오+이미지를 **클라이언트에서 병합**한다(`useCloudinaryTracks`).
- **선택지 (③에서 확정):**
  - (a) **코어 슬라이스는 플레이스홀더 아트워크**로 진행하고 병합은 이후 마일스톤 — UI 연기 원칙에 부합(권장 후보).
  - (b) image 엔드포인트를 추가 호출해 title/artist(또는 publicId)로 **병합 로직 이식** — 잠금화면 미디어 세션 아트워크까지 원할 때.
- 영향: (a) 선택 시 OS 미디어 컨트롤의 아트워크만 비게 되며, 재생 기능 자체에는 영향 없음.
- **확정(③ 기획설계)**: **(b) image 병합 이식** 선택됨 → `ArtworkMerger`(웹 키매칭 알고리즘 이식)로 설계.

---

## 3. 가드레일 판정

| 가드레일 | 상태 | 판정 근거 |
| --- | :---: | --- |
| **범위(Scope)** | PASS | 코어 재생 수직 슬라이스로 한정, In/Out 명시(2.2·2.3). UI 재현은 명시적으로 연기. |
| **근거(Evidence)** | PASS | 원본 아키텍처 문서·엔드포인트 라우트·도메인 모델·현 스캐폴드 파일을 직접 인용. |
| **모순(Contradiction)** | PASS | "시크릿 임베드 불가" 모순을 BFF 재사용으로 해소, 잔여 리스크는 2.6·2.7로 격리. |
| **가독성(Readability)** | PASS | 단계·표·다이어그램으로 구조화, 플레이스홀더 없음. |
| **종합 Verdict** | **PASS** | 3대 결정(데이터·범위·아키텍처) 확정 + 2.8 API 실측으로 데이터 계약·재생 소스 검증 완료. 잔여는 아트워크 전략(2.8.2, ③에서 결정)뿐. |

---

## 4. 다음 단계 — **여기서 정지 (STOP)**

사용자 지시에 따라 **스크리닝까지만** 진행하고 멈춘다. 승인 시 다음은 **③ 기획설계**이며, 그때 다룰 항목:

1. 아트워크 전략 확정(2.8.2: 플레이스홀더 vs image 병합).
2. 오디오 스택/네트워크/캐시 패키지 선정 및 폴더 구조(`lib/domain`, `lib/data`, `lib/ui`) 확정.
3. 재생 상태 머신·Repository 인터페이스·에러 정책의 상세 설계.
4. Dart `Track` 모델 정의(2.8 실측 스키마 기준: `metadata`는 `Map<String, dynamic>`).

> 승인 없이는 ③ 이후로 진행하지 않는다.
