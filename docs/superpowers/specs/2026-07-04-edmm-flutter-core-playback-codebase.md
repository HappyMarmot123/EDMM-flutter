# EDMM Flutter — 코어 재생 슬라이스 코드베이스 정합 (Codebase Elaboration)

## 메타데이터

| 항목 | 값 |
| --- | --- |
| 기준일 | 2026-07-04 |
| 단계 | ④ 코드베이스 기반 문서구체화 **(본 문서)** — 선행: [기획설계](2026-07-04-edmm-flutter-core-playback-design.md) |
| 목적 | ③ 설계를 **현 스캐폴드의 실제 파일·버전·플랫폼 설정**에 정합. 모든 항목은 실측 근거를 가진다. |
| 이후(미착수) | ⑤ 문서검토 → ⑥ Task 분리 → ⑦ 구현 |

> 본 문서는 "무엇을 어디에 어떤 버전으로" 확정한다. 실제 코드 작성은 ⑦.

---

## 1. 툴체인·의존성 매트릭스 (실측: `pubspec.lock`, pub.dev)

| 항목 | 현재 | 판정 |
| --- | --- | --- |
| Dart SDK | `>=3.12.2 <4.0.0` | OK |
| Flutter | `>=3.38.0` | OK (기본 minSdk 24) |
| provider | 6.1.5+1 | 재사용 |
| go_router | 17.3.0 | 재사용 |
| http | 1.6.0 | 재사용(BFF GET) |
| intl | 0.20.2 | 재사용 |
| freezed | **4.0.0-dev.3** | ⚠️ dev 프리릴리스(§3 주의) |
| freezed_annotation | 3.1.0 | 재사용 |
| json_serializable / json_annotation | 6.14.0 / 4.12.0 | 재사용(직렬화) |
| build_runner | 2.15.0 | 재사용(codegen) |

### 신규 의존성 (pub.dev 실측 최신)

| 패키지 | 버전 | 게시자 | 용도 |
| --- | --- | --- | --- |
| `just_audio` | **^0.10.6** | ryanheise.com | 재생 엔진(스트리밍·큐·seek) |
| `audio_service` | **^0.18.19** | ryanheise.com | 백그라운드 재생 + OS 미디어 세션 |

> 두 패키지 모두 동일 저자(ryanheise)로 상호 연동이 설계 전제. 정확한 해석 버전은 ⑦에서 `flutter pub add` 후 `pubspec.lock`으로 고정.

---

## 2. `pubspec.yaml` diff (⑦에서 적용)

```yaml
dependencies:
  # (기존 유지: flutter, flutter_localizations, cupertino_icons,
  #  provider, go_router, http, intl, freezed_annotation, json_annotation)
  just_audio: ^0.10.6        # 추가
  audio_service: ^0.18.19    # 추가
```
> dev_dependencies 변경 없음(build_runner/freezed/json_serializable 이미 존재).

---

## 3. freezed 4.0.0-dev.3 구문 주의 (근거: `pubspec.lock` L216-223)

- 현 스캐폴드는 freezed **4.0.0-dev.3**(프리릴리스)에 고정돼 있다. freezed 3.x+부터 모델은 `abstract class ... with _$T` 형태를 요구한다. ③의 `class Track with _$Track` 스케치는 **`abstract class Track with _$Track`**로 정정한다.
- `Result<T>`는 freezed 대신 **손수 작성한 Dart 3 `sealed class`**로 두어 dev 프리릴리스 리스크에서 분리(§ 도메인). 
- ⑦ 착수 시 `dart run build_runner build`로 생성 성공을 먼저 검증(프리릴리스 매크로/코드젠 동작 확인).

---

## 4. 파일 매니페스트 (신규/변경, 현 `lib/` 정합)

| 경로 | 신규/변경 | 책임 |
| --- | :---: | --- |
| `lib/config/app_config.dart` | 신규 | `bffBaseUrl='https://edmm.vercel.app'`, 타임아웃 |
| `lib/domain/result.dart` | 신규 | `sealed Result<T>`(Ok/Err) + `Failure` |
| `lib/domain/models/track.dart` | 신규 | `abstract class Track`(freezed) + `fromJson`·`duration`·`isPlayable` |
| `lib/domain/models/playback_snapshot.dart` | 신규 | 재생 상태 스냅샷(위치 제외) |
| `lib/domain/repositories/track_repository.dart` | 신규 | 추상: `getTracks()` |
| `lib/domain/audio/audio_controller.dart` | 신규 | 추상: 명령 + `snapshot`/`position` 스트림 |
| `lib/domain/logic/artwork_merger.dart` | 신규 | 순수 병합(웹 키매칭 이식) |
| `lib/data/services/track_api_service.dart` | 신규 | http GET `/video`,`/image` |
| `lib/data/repositories/remote_track_repository.dart` | 신규 | 병렬조회→병합→캐시→Result |
| `lib/data/audio/just_audio_controller.dart` | 신규 | `AudioController` 구현(just_audio+audio_service `BaseAudioHandler`) |
| `lib/ui/track_list/view_model/track_list_view_model.dart` | 신규 | 목록 상태·선택 |
| `lib/ui/track_list/widgets/track_list_screen.dart` | 신규 | `/` 화면 |
| `lib/ui/player/view_model/player_view_model.dart` | 신규 | 재생 상태·명령 |
| `lib/ui/player/widgets/player_screen.dart` | 신규 | `/player` 화면 |
| `lib/routing/routes.dart` | **변경** | `player='/player'` 추가 |
| `lib/routing/router.dart` | **변경** | 라우트 2개 + `context.read()` 주입 |
| `lib/main.dart` | **변경** | `async` + `AudioService.init` + MultiProvider |
| `lib/ui/home/**` | **삭제** | 카운터 플레이스홀더 제거(→ track_list 대체) |
| `test/**` | 신규 | §11(설계) 테스트 매트릭스 |

> `ui/home/widgets/home_screen.dart`의 `@Preview` 패턴은 `track_list_screen.dart`/`player_screen.dart`에 동일 방식으로 재적용(프리뷰 로컬라이제이션 헬퍼 포함).

---

## 5. Android 설정 diff (근거: 실제 파일 확인)

**5.1 `android/app/src/main/AndroidManifest.xml`** — 현재 서비스/권한 없음. audio_service 0.18 요구사항 추가:

- 루트 `<manifest>`에 `xmlns:tools` 추가.
- `<application>` 밖(상단)에 권한:
  ```xml
  <uses-permission android:name="android.permission.WAKE_LOCK"/>
  <uses-permission android:name="android.permission.FOREGROUND_SERVICE"/>
  <uses-permission android:name="android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK"/>
  ```
- `<application>` 안에 서비스·리시버:
  ```xml
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

**5.2 `android/app/src/main/kotlin/com/edmm/edmm/MainActivity.kt`** — 현재 `FlutterActivity`.
```kotlin
// 변경: 알림 클릭 시 기존 엔진으로 복귀시키려면 권장
import com.ryanheise.audioservice.AudioServiceActivity
class MainActivity : AudioServiceActivity()
```

**5.3 SDK**: `minSdk = flutter.minSdkVersion`(Flutter 3.38 기본 24) ≥ audio_service 21 요구 → **변경 불필요**. Java 17 이미 설정.

> 위 스니펫은 audio_service 0.18 셋업 기준. ⑦에서 해당 버전 문서와 대조해 정확 문자열 확정.

---

## 6. iOS 설정 diff (근거: 실제 파일 확인)

**6.1 `ios/Runner/Info.plist`** — 현재 `UIBackgroundModes` 없음. 추가:
```xml
<key>UIBackgroundModes</key>
<array><string>audio</string></array>
```
**6.2 `AppDelegate.swift`** — 모던 implicit-engine(`didInitializeImplicitFlutterEngine`에서 `GeneratedPluginRegistrant.register`) 사용 중 → audio_service iOS 플러그인은 자동 등록되므로 **코드 변경 불필요**. SceneDelegate 기반 템플릿과도 무관(백그라운드 오디오는 앱 레벨 `UIBackgroundModes`로 동작).

---

## 7. l10n 신규 키 (근거: 현 `app_en.arb`/`app_ko.arb`, 키 3개)

`generate:true` + `l10n.yaml` 설정됨 → arb 편집 후 재생성. 추가 키:

| key | en | ko |
| --- | --- | --- |
| `trackListTitle` | Tracks | 트랙 |
| `tracksLoadError` | Couldn't load tracks | 트랙을 불러오지 못했습니다 |
| `tracksEmpty` | No tracks | 트랙이 없습니다 |
| `retry` | Retry | 다시 시도 |
| `nowPlaying` | Now Playing | 재생 중 |
| `unknownArtist` | Unknown artist | 알 수 없는 아티스트 |
| `playbackError` | Playback failed | 재생에 실패했습니다 |

> 기존 `homeSetupDone`/`increment`는 home 삭제와 함께 제거 후보(문자열만 남겨도 무해 — ⑦ 판단).

---

## 8. 라우팅·DI 정합 (근거: 현 `router.dart`/`main.dart`)

- `router.dart`: 현재 `HomeScreen(viewModel: HomeViewModel())` 단일 라우트. → `Routes.trackList`/`Routes.player` 2개로 교체, 각 진입 시 `context.read<TrackRepository>()`/`context.read<AudioController>()`로 VM 생성(현 주석의 의도 그대로).
- `main.dart`: 현재 동기 `runApp(EdmmApp())`. → `Future<void> main() async { WidgetsFlutterBinding.ensureInitialized(); final c = await AudioService.init(builder: ...); runApp(MultiProvider(...)); }`. `EdmmApp`의 `MaterialApp.router`/테마/l10n은 유지.

---

## 9. 근거 인덱스 (재현 가능)

| 사실 | 출처 |
| --- | --- |
| 엔드포인트 200/JSON, 32/33건 | `curl` 실측(2026-07-04, 스크리닝 2.8) |
| 병합 알고리즘 | 웹 `src/features/cloudinary/hooks/useCloudinaryTracks.ts` |
| 도메인 스키마 | 웹 `src/entities/track/model.ts` + 실 응답 |
| 패키지 버전 | pub.dev 검색(just_audio 0.10.6, audio_service 0.18.19) |
| 툴체인 버전 | `pubspec.lock` |
| 플랫폼 설정 현황 | `AndroidManifest.xml`, `MainActivity.kt`, `Info.plist`, `AppDelegate.swift` |

---

## 10. 가드레일 판정

| 가드레일 | 상태 | 근거 |
| --- | :---: | --- |
| 범위 | PASS | 코어 슬라이스 정합만 다룸, 신규 기능 없음. |
| 근거 | PASS | 모든 버전·경로·설정을 실제 파일/pub.dev로 확인(§9). |
| 모순 | PASS | freezed dev 프리릴리스 리스크를 §3로 격리, minSdk 요구 충족 확인. |
| 가독성 | PASS | 파일 매니페스트·diff·키 표로 구조화. |
| **종합** | **PASS** | ⑤ 문서검토로 진행 가능. |

---

## 11. 다음 단계 — **STOP**
승인 시 ⑤ 문서검토(전체 문서 일관성·누락·가드레일 교차검증) → ⑥ Task 분리.
