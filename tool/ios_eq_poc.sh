#!/usr/bin/env bash
set -euo pipefail

TRACK_ID="${TRACK_ID:-smoke-track}"
IOS_DEVICE_ID="${IOS_DEVICE_ID:-}"
CUSTOM_LINK="edmm:///track/${TRACK_ID}"
UNIVERSAL_LINK="https://edmm.vercel.app/track/${TRACK_ID}"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "This PoC must run on macOS with Xcode installed."
  exit 1
fi

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1"
    exit 1
  fi
}

section() {
  echo
  echo "== $1 =="
}

require_cmd flutter
require_cmd xcrun

section "Inspect just_audio Darwin effect support"
PUB_CACHE_DIR="${PUB_CACHE:-$HOME/.pub-cache}"
JUST_AUDIO_DIR="$(find "$PUB_CACHE_DIR/hosted" -type d -name 'just_audio-*' | sort | tail -n 1)"
PLATFORM_INTERFACE_DIR="$(find "$PUB_CACHE_DIR/hosted" -type d -name 'just_audio_platform_interface-*' | sort | tail -n 1)"

grep -R "darwinAudioEffects" "$JUST_AUDIO_DIR/lib" "$PLATFORM_INTERFACE_DIR/lib"
grep -R "AVQueuePlayer" "$JUST_AUDIO_DIR/darwin/just_audio/Sources/just_audio"
grep -R "AVAudioUnitEQ" "$JUST_AUDIO_DIR/darwin/just_audio/Sources/just_audio" || true

cat <<'NOTES'
AVAudioUnitEQ PoC gate:
- just_audio Darwin currently plays through AVQueuePlayer / AVPlayerItem.
- AVAudioUnitEQ belongs in an AVAudioEngine graph, not directly in AVQueuePlayer.
- If AVAudioUnitEQ is required, the PoC must fork/extend just_audio Darwin playback
  or replace the iOS backend with an AVAudioEngine-based streamer.
- A lighter fork route may use AVPlayerItem.audioMix + MTAudioProcessingTap, but
  that is custom DSP, not AVAudioUnitEQ.
NOTES

section "Flutter unit and platform tests"
flutter pub get
flutter test test/platform/deep_link_config_test.dart
flutter test test/domain/audio/audio_effects_controller_test.dart test/ui/player/player_screen_test.dart

section "iOS build gate"
flutter build ios --no-codesign

section "Simulator deep-link PoC"
xcrun simctl bootstatus booted || true
xcrun simctl openurl booted "$CUSTOM_LINK"
xcrun simctl openurl booted "$UNIVERSAL_LINK"

if [[ -n "$IOS_DEVICE_ID" ]]; then
  section "Optional iOS run target"
  flutter run -d "$IOS_DEVICE_ID"
else
  section "Optional iOS run target"
  echo "Set IOS_DEVICE_ID=<device-id> to run the app on a simulator or device."
fi

section "Manual iOS regression gates"
cat <<'CHECKS'
Run these checks on simulator and physical device after any iOS EQ fork/backend PoC:
- streaming source starts and seeks without stalling regressions
- background playback continues after locking the screen
- notification / lock-screen media controls still play, pause, next, previous
- artwork and current track metadata still appear in system UI
- interruption handling for calls, alarms, Bluetooth, and route changes
- EQ enabled state changes audible output and gain changes are reversible
CHECKS
