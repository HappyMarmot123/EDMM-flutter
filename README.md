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