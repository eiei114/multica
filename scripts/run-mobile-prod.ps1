<#
.SYNOPSIS
Start the mobile development server against production Multica API.

.DESCRIPTION
Use this after installing the debug development-client APK produced by
build-android-debug.ps1. The native APK can remain a development build; this
script serves the JavaScript bundle with apps/mobile/.env.production.
#>

[CmdletBinding()]
param(
  [ValidateSet("lan", "localhost", "tunnel")]
  [string]$HostMode = "lan",

  [switch]$OpenAndroid
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

if (-not $env:ANDROID_HOME) {
  $defaultSdk = Join-Path $env:LOCALAPPDATA "Android\Sdk"
  if (Test-Path $defaultSdk) {
    $env:ANDROID_HOME = $defaultSdk
  }
}

if ($env:ANDROID_HOME) {
  $platformTools = Join-Path $env:ANDROID_HOME "platform-tools"
  if (Test-Path $platformTools) {
    $env:PATH = "$platformTools;$env:PATH"
  }
}

Write-Host "Starting production Metro for mobile..."
Write-Host "API: https://api.multica.ai"
Write-Host "Host mode: $HostMode"
Write-Host "Tip: press 'a' in the Expo terminal to open the connected Android device."

if ($OpenAndroid) {
  Write-Host "-OpenAndroid requested. Expo still owns the interactive terminal; press 'a' if it does not open automatically."
}

& pnpm -C apps/mobile dev:prod -- --host $HostMode

