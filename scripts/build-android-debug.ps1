<#
.SYNOPSIS
Build the Expo Android development-client APK on Windows.

.DESCRIPTION
This script captures the local Windows workarounds needed for the current
Multica mobile Android build:

- use a hoisted pnpm install to avoid very long native build paths
- generate the native Android project with Expo prebuild
- pin the generated Gradle wrapper to 8.14.3
- build only arm64-v8a by default to avoid x86 native-module failures

The produced APK is a debug development build. Use run-mobile-prod.ps1 to run
the JavaScript bundle against https://api.multica.ai.
#>

[CmdletBinding()]
param(
  [ValidateSet("development", "staging", "production")]
  [string]$AppEnvironment = "development",

  [string]$Architecture = "arm64-v8a",

  [switch]$CleanPrebuild,
  [switch]$SkipPrebuild,
  [switch]$SkipInstallDeps,
  [switch]$Install
)

$ErrorActionPreference = "Stop"

function Require-Command {
  param([string]$Name)
  if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
    throw "Required command not found: $Name"
  }
}

$RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
Set-Location $RepoRoot

Require-Command pnpm

if (-not $env:JAVA_HOME) {
  $androidStudioJbr = Join-Path $env:ProgramFiles "Android\Android Studio\jbr"
  if (Test-Path $androidStudioJbr) {
    $env:JAVA_HOME = $androidStudioJbr
  }
}

if (-not $env:ANDROID_HOME) {
  $defaultSdk = Join-Path $env:LOCALAPPDATA "Android\Sdk"
  if (Test-Path $defaultSdk) {
    $env:ANDROID_HOME = $defaultSdk
  }
}

if (-not $env:ANDROID_SDK_ROOT -and $env:ANDROID_HOME) {
  $env:ANDROID_SDK_ROOT = $env:ANDROID_HOME
}

if ($env:ANDROID_HOME) {
  $platformTools = Join-Path $env:ANDROID_HOME "platform-tools"
  if (Test-Path $platformTools) {
    $env:PATH = "$platformTools;$env:PATH"
  }
}

Write-Host "Repo: $RepoRoot"
Write-Host "APP_ENV: $AppEnvironment"
Write-Host "Architecture: $Architecture"
Write-Host "JAVA_HOME: $env:JAVA_HOME"
Write-Host "ANDROID_HOME: $env:ANDROID_HOME"

if (-not $SkipInstallDeps) {
  Write-Host "Installing dependencies with pnpm --ignore-scripts..."
  & pnpm install --ignore-scripts
}

$env:APP_ENV = $AppEnvironment

if (-not $SkipPrebuild) {
  Push-Location (Join-Path $RepoRoot "apps/mobile")
  try {
    $prebuildArgs = @("exec", "expo", "prebuild", "--platform", "android")
    if ($CleanPrebuild) {
      $prebuildArgs += "--clean"
    }
    Write-Host "Running: pnpm $($prebuildArgs -join ' ')"
    & pnpm @prebuildArgs
  }
  finally {
    Pop-Location
  }
}

$wrapperProperties = Join-Path $RepoRoot "apps/mobile/android/gradle/wrapper/gradle-wrapper.properties"
if (-not (Test-Path $wrapperProperties)) {
  throw "Gradle wrapper not found. Run without -SkipPrebuild first: $wrapperProperties"
}

$wrapperText = Get-Content $wrapperProperties -Raw
$patchedWrapperText = $wrapperText -replace "gradle-[0-9.]+-bin\.zip", "gradle-8.14.3-bin.zip"
if ($patchedWrapperText -ne $wrapperText) {
  Set-Content -Path $wrapperProperties -Value $patchedWrapperText -NoNewline
  Write-Host "Pinned Gradle wrapper to 8.14.3"
}

$androidDir = Join-Path $RepoRoot "apps/mobile/android"
Push-Location $androidDir
try {
  $gradlew = Join-Path $androidDir "gradlew.bat"
  if (-not (Test-Path $gradlew)) {
    throw "gradlew.bat not found: $gradlew"
  }

  Write-Host "Building debug APK..."
  & $gradlew assembleDebug "-PreactNativeArchitectures=$Architecture" --no-daemon --stacktrace
}
finally {
  Pop-Location
}

$apk = Join-Path $RepoRoot "apps/mobile/android/app/build/outputs/apk/debug/app-debug.apk"
if (-not (Test-Path $apk)) {
  throw "APK not found after build: $apk"
}

Write-Host "Built APK: $apk"

if ($Install) {
  Require-Command adb
  Write-Host "Installing APK on connected Android device..."
  & adb install -r $apk
}

