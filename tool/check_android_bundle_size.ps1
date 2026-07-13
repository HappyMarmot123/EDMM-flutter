[CmdletBinding()]
param(
  [string]$BundlePath = "build/app/outputs/bundle/release/app-release.aab",
  [string]$BudgetPath = (Join-Path $PSScriptRoot "android_bundle_size_budget.json"),
  [string]$SymbolsPath = "build/symbols/android",
  [string]$ReportPath = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $BundlePath -PathType Leaf)) {
  throw "Android App Bundle not found: $BundlePath"
}
if (-not (Test-Path -LiteralPath $BudgetPath -PathType Leaf)) {
  throw "Bundle size budget not found: $BudgetPath"
}

Add-Type -AssemblyName System.IO.Compression.FileSystem

$resolvedBundle = (Resolve-Path -LiteralPath $BundlePath).Path
$budget = Get-Content -LiteralPath $BudgetPath -Raw | ConvertFrom-Json
$zip = [System.IO.Compression.ZipFile]::OpenRead($resolvedBundle)
$requiredBundleEntries = @(
  "base/lib/armeabi-v7a/libapp.so",
  "base/lib/armeabi-v7a/libflutter.so",
  "base/lib/arm64-v8a/libapp.so",
  "base/lib/arm64-v8a/libflutter.so",
  "base/lib/x86_64/libapp.so",
  "base/lib/x86_64/libflutter.so"
)
$requiredSymbolFiles = @(
  "app.android-arm.symbols",
  "app.android-arm64.symbols",
  "app.android-x64.symbols"
)

try {
  function Get-CompressedBytesByPrefix([string]$Prefix) {
    $sum = ($zip.Entries |
      Where-Object { $_.FullName.StartsWith($Prefix, [System.StringComparison]::Ordinal) } |
      Measure-Object -Property CompressedLength -Sum).Sum
    if ($null -eq $sum) { return [long]0 }
    return [long]$sum
  }

  $actual = [ordered]@{
    bundleBytes = [long](Get-Item -LiteralPath $resolvedBundle).Length
    debugSymbolMetadataBytes = Get-CompressedBytesByPrefix "BUNDLE-METADATA/com.android.tools.build.debugsymbols/"
    allNativeBytes = Get-CompressedBytesByPrefix "base/lib/"
    arm64NativeBytes = Get-CompressedBytesByPrefix "base/lib/arm64-v8a/"
    dexBytes = Get-CompressedBytesByPrefix "base/dex/"
    assetsBytes = Get-CompressedBytesByPrefix "base/assets/"
    resourcesBytes = (Get-CompressedBytesByPrefix "base/res/") +
      (Get-CompressedBytesByPrefix "base/resources.pb")
    rootBytes = Get-CompressedBytesByPrefix "base/root/"
  }
  $actual.estimatedArm64BaseBytes =
    $actual.arm64NativeBytes +
    $actual.dexBytes +
    $actual.assetsBytes +
    $actual.resourcesBytes +
    $actual.rootBytes

  $bundleEntryNames = [System.Collections.Generic.HashSet[string]]::new(
    [System.StringComparer]::Ordinal
  )
  foreach ($entry in $zip.Entries) {
    [void]$bundleEntryNames.Add($entry.FullName)
  }
  $missingBundleEntries = @(
    $requiredBundleEntries | Where-Object { -not $bundleEntryNames.Contains($_) }
  )

  $rows = foreach ($property in $budget.metrics.PSObject.Properties) {
    $name = $property.Name
    $rule = $property.Value
    if (-not $actual.Contains($name)) {
      throw "Unknown bundle size metric in budget: $name"
    }
    $regressionLimit = [long]$rule.baselineBytes + [long]$rule.maxGrowthBytes
    $effectiveLimit = [Math]::Min([long]$rule.limitBytes, $regressionLimit)
    $actualBytes = [long]$actual[$name]
    [pscustomobject][ordered]@{
      name = $name
      label = [string]$rule.label
      actualBytes = $actualBytes
      baselineBytes = [long]$rule.baselineBytes
      growthBytes = $actualBytes - [long]$rule.baselineBytes
      limitBytes = [long]$rule.limitBytes
      regressionLimitBytes = $regressionLimit
      effectiveLimitBytes = $effectiveLimit
      passed = $actualBytes -le $effectiveLimit
    }
  }
} finally {
  $zip.Dispose()
}

$missingSymbolFiles = @(
  $requiredSymbolFiles | Where-Object {
    -not (Test-Path -LiteralPath (Join-Path $SymbolsPath $_) -PathType Leaf)
  }
)
$structurePassed =
  $missingBundleEntries.Count -eq 0 -and $missingSymbolFiles.Count -eq 0

$display = $rows | ForEach-Object {
  [pscustomobject]@{
    Metric = $_.label
    ActualMiB = [Math]::Round($_.actualBytes / 1MB, 2)
    BaselineMiB = [Math]::Round($_.baselineBytes / 1MB, 2)
    GrowthMiB = [Math]::Round($_.growthBytes / 1MB, 2)
    GateMiB = [Math]::Round($_.effectiveLimitBytes / 1MB, 2)
    Result = if ($_.passed) { "PASS" } else { "FAIL" }
  }
}

Write-Host ($display | Format-Table -AutoSize | Out-String)
if ($structurePassed) {
  Write-Host "AAB ABI completeness and split debug symbols: PASS"
} else {
  Write-Host "AAB ABI completeness and split debug symbols: FAIL"
  if ($missingBundleEntries.Count -gt 0) {
    Write-Host "Missing AAB entries: $($missingBundleEntries -join ', ')"
  }
  if ($missingSymbolFiles.Count -gt 0) {
    Write-Host "Missing Dart symbol files: $($missingSymbolFiles -join ', ')"
  }
}

$sizePassed = -not ($rows | Where-Object { -not $_.passed })
$passed = $sizePassed -and $structurePassed
$report = [pscustomobject][ordered]@{
  schemaVersion = 1
  generatedAtUtc = [DateTime]::UtcNow.ToString("o")
  bundlePath = $resolvedBundle
  buildProfile = [string]$budget.buildProfile
  passed = $passed
  sizePassed = $sizePassed
  structurePassed = $structurePassed
  requiredBundleEntries = $requiredBundleEntries
  missingBundleEntries = $missingBundleEntries
  requiredSymbolFiles = $requiredSymbolFiles
  missingSymbolFiles = $missingSymbolFiles
  metrics = @($rows)
  note = "estimatedArm64BaseBytes is an AAB-entry regression proxy, not a Play Console download-size estimate."
}

if ($ReportPath.Trim().Length -gt 0) {
  $reportDirectory = Split-Path -Parent $ReportPath
  if ($reportDirectory -and -not (Test-Path -LiteralPath $reportDirectory)) {
    New-Item -ItemType Directory -Path $reportDirectory -Force | Out-Null
  }
  $report | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $ReportPath -Encoding utf8
}

if ($env:GITHUB_STEP_SUMMARY) {
  $summary = @(
    "## Android App Bundle size gate"
    ""
    "| Metric | Actual MiB | Baseline MiB | Growth MiB | Gate MiB | Result |"
    "|---|---:|---:|---:|---:|---|"
  )
  foreach ($row in $display) {
    $summary += "| $($row.Metric) | $($row.ActualMiB) | $($row.BaselineMiB) | $($row.GrowthMiB) | $($row.GateMiB) | $($row.Result) |"
  }
  $summary += ""
  $summary += "ABI and split-symbol structure: $(if ($structurePassed) { 'PASS' } else { 'FAIL' })"
  $summary -join [Environment]::NewLine | Add-Content -LiteralPath $env:GITHUB_STEP_SUMMARY -Encoding utf8
}

if (-not $passed) {
  Write-Error "Android App Bundle size budget exceeded. Review the report before changing the baseline or limits."
  exit 1
}

Write-Host "Android App Bundle size budget passed."
