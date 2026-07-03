# edmm

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

1. 먼저 앱 실행 준비

  - flutter pub get                                                                                                          
  - flutter doctor (환경 점검)                                                                                               
                                                                                                                             
  2. 에뮬레이터/시뮬레이터/디바이스 준비                                                                                     
                                                                                                                             
  - 연결 가능한 장치 보기: flutter devices                                                                                   
  - 에뮬레이터 목록: flutter emulators                                                                                       
  - 에뮬레이터 실행: flutter emulators --launch <이름>                                                                       
                                                                                                                             
  3. 가장 기본 실행                                                                                                          
                                                                                                                             
  - 프로젝트 폴더에서: flutter run                                                                                           
  - 특정 장치 실행: flutter run -d <deviceId>                                                                                

  4. 플랫폼별 실행                                                                                                           
                                                                                                                             
  - Android: flutter run (또는 flutter run -d android)                                                                       
  - iOS: flutter run -d ios (Mac + Xcode 필요)                                                                               
  - 웹: flutter run -d chrome                                                                                                
  - Windows: flutter run -d windows                                                                                          
  - macOS: flutter run -d macos
  - Linux: flutter run -d linux                                                                                              
                                                                                                                             
  5. 실행 중 유용한 키
                                                                                                                             
  - r : Hot Reload                                                                                                           
  - R : Hot Restart                                                                                                          
  - iOS: flutter build ios
  - 웹: flutter build web

## CI / 빌드 검증 (GitHub Actions)

빌드 검증 파이프라인은 `.github/workflows/ci.yml`에 정의돼 있으며, 다음 이벤트에서 자동 실행된다.

- `main` 브랜치로 **PR을 열 때** (피처 브랜치 → `main`)
- `main`으로 **push**될 때
- Actions 탭에서 **수동 실행**(`workflow_dispatch`)

즉, 어떤 피처 브랜치에서 작업하든 **`main`으로 PR을 올리는 순간** 아래 검증이 자동으로 돈다.

| Job | 러너 | 하는 일 |
|---|---|---|
| `analyze-and-test` | ubuntu | `flutter analyze` + `flutter test` |
| `build-ios` | macOS | `flutter build ios --no-codesign` (서명 없는 iOS 빌드 검증) |
| `build-android` | ubuntu | `flutter build apk --release` (릴리스 APK 빌드 검증) |

세 job은 서로 의존 없이 병렬로 돈다. iOS만 macOS 러너를 쓰고(분당 과금이 높음), Android는 Linux에서 빌드되므로 저렴한 ubuntu 러너를 쓴다.

**iOS 빌드를 CI에 둔 이유**: iOS는 Windows 개발 환경에서 빌드할 수 없어, macOS 러너가 유일한 빌드 검증 수단이다.

**Android 빌드도 CI에서 검증한다**: 로컬 Windows에서도 `flutter build apk`로 빌드할 수 있지만, CI에서 릴리스 APK 빌드를 자동 검증해 Android 전용 회귀(Gradle/AGP, R8 등)를 조기에 잡는다.
