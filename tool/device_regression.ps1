param(
  [string]$TrackId = "smoke-track",
  [string]$PackageName = "com.edmm.edmm",
  [string]$WebBaseUrl = "https://edmm.vercel.app",
  [switch]$SkipAndroid,
  [switch]$SkipIos
)

$ErrorActionPreference = "Continue"

function Has-Command($Name) {
  return $null -ne (Get-Command $Name -ErrorAction SilentlyContinue)
}

function Run-Step($Title, [scriptblock]$Step) {
  Write-Host ""
  Write-Host "== $Title =="
  & $Step
}

$customTrackUrl = "edmm:///track/$TrackId"
# Default universal/app link target: https://edmm.vercel.app/track/<track-id>
$webTrackUrl = "$WebBaseUrl/track/$TrackId"

Run-Step "Flutter devices" {
  flutter devices
}

if (-not $SkipAndroid) {
  if (Has-Command "adb") {
    Run-Step "Android custom scheme deep link" {
      adb shell am start -W `
        -a android.intent.action.VIEW `
        -c android.intent.category.BROWSABLE `
        -d $customTrackUrl `
        $PackageName
    }

    Run-Step "Android HTTPS App Link" {
      adb shell am start -W `
        -a android.intent.action.VIEW `
        -c android.intent.category.BROWSABLE `
        -d $webTrackUrl `
        $PackageName
    }

    Run-Step "Android app link verification state" {
      adb shell pm get-app-links $PackageName
    }

    Run-Step "Android notification and media controls smoke" {
      adb shell cmd media_session dispatch play
      Start-Sleep -Seconds 1
      adb shell cmd media_session dispatch pause
      adb shell cmd media_session dispatch next
      adb shell cmd media_session dispatch previous
      adb shell dumpsys media_session | Select-String $PackageName
    }
  } else {
    Write-Host "adb not found; Android device regression skipped."
  }
}

if (-not $SkipIos) {
  if (Has-Command "xcrun") {
    Run-Step "iOS custom scheme deep link" {
      xcrun simctl openurl booted $customTrackUrl
    }

    Run-Step "iOS Universal Link" {
      xcrun simctl openurl booted $webTrackUrl
    }
  } else {
    Write-Host "xcrun not found; iOS simulator regression skipped."
  }
}

Write-Host ""
Write-Host "Manual regression checks still required on physical devices:"
Write-Host "- background playback after locking the screen"
Write-Host "- notification transport controls and current track title"
Write-Host "- artwork shown in notification/lock screen"
Write-Host "- interruption handling for calls, alarms, Bluetooth, and route changes"
