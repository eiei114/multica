# Multica Android debug build fork notes

This fork/branch keeps the minimal local changes needed to build and run the
Expo mobile app on Android from source on Windows.

## Branch strategy

- Keep `origin` pointed at your fork.
- Keep the original Multica repository as `upstream`.
- If this checkout still has `origin=https://github.com/multica-ai/multica.git`,
  rename it first, then add your fork URL:

  ```powershell
  git remote rename origin upstream
  git remote add origin https://github.com/<you>/multica.git
  ```

- If `origin` already points at your fork, just add upstream:

  ```powershell
  git remote add upstream https://github.com/multica-ai/multica.git
  ```

- Keep Android-specific changes on an `android-build` branch.
- Rebase this branch onto upstream `main` when updating:

  ```powershell
  git fetch upstream
  git switch android-build
  git rebase upstream/main
  ```

Only keep source/build-system changes here. Do not commit generated files under
`apps/mobile/android/`, `node_modules/`, or built APKs.

## What this branch changes

- `.npmrc`: uses `node-linker=hoisted` to reduce Windows native-build path
  length problems.
- `apps/mobile/app.config.ts`: adds Android package IDs required by Expo
  prebuild.
- `scripts/build-android-debug.ps1`: Windows debug APK build helper.
- `scripts/run-mobile-prod.ps1`: starts Metro with production API env.

The output is a debug development-client APK, not a signed Play Store release.

## First-time build

From the repo root:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/build-android-debug.ps1 -Install
```

Default behavior:

- uses `APP_ENV=development` for native prebuild, so the app id remains
  `ai.multica.mobile.dev`
- pins generated Gradle wrapper to `8.14.3`
- builds `arm64-v8a` only
- writes APK to:

  ```text
  apps/mobile/android/app/build/outputs/apk/debug/app-debug.apk
  ```

If you do not want automatic install:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/build-android-debug.ps1
adb install -r apps/mobile/android/app/build/outputs/apk/debug/app-debug.apk
```

## Run against production Multica

Start Metro with the production env:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/run-mobile-prod.ps1
```

Then press `a` in the Expo terminal to open the connected Android device.

This uses:

```text
EXPO_PUBLIC_API_URL=https://api.multica.ai
EXPO_PUBLIC_WEB_URL=https://multica.ai
```

Google login on web and email-code login on mobile resolve to the same server
user when the email address matches, so production workspaces should appear.

## Normal update flow

For JavaScript-only app changes:

```powershell
git fetch upstream
git rebase upstream/main
pnpm install --ignore-scripts
powershell -ExecutionPolicy Bypass -File scripts/run-mobile-prod.ps1
```

No APK rebuild is needed unless native inputs changed.

## Automatic fork build flow

`.github/workflows/android-auto-build.yml` runs on the fork only
(`eiei114/multica`). It is intentionally not a general upstream workflow.

The workflow:

1. Checks out `android-build`.
2. Merges `upstream/main` into it.
3. Pushes the merge back to `origin/android-build` when upstream changed.
4. Builds a production Android release APK on GitHub Actions.
5. Uploads the APK as a workflow artifact.
6. Replaces the `android-latest` GitHub Release with:
   - `multica-android-latest.apk`
   - `android-update.json`

The build runs on Ubuntu with Gradle and Expo caches. Scheduled runs only build
when upstream changed mobile-relevant paths (`apps/mobile/`, `packages/core/`,
package manager files, or Android build scripts/workflow). Manual dispatch can
force a build.

The scheduled run is daily at `06:15 JST`.

For the scheduled run to work, the fork's default branch should be
`android-build`, because GitHub only runs scheduled workflows from the default
branch.

Manual run:

```powershell
gh workflow run android-auto-build.yml --repo eiei114/multica --ref android-build
```

The private fork APK uses this package id by default:

```text
ai.multica.mobile.eiei114
```

Release APKs are signed with the fixed private fork key stored in GitHub
Actions secrets:

```text
ANDROID_KEYSTORE_BASE64
ANDROID_KEYSTORE_PASSWORD
ANDROID_KEY_ALIAS
ANDROID_KEY_PASSWORD
```

The local backup for this personal fork lives outside the repository at:

```text
%USERPROFILE%\.multica-android-signing\
```

That means it installs separately from the current development-client APK
(`ai.multica.mobile.dev`). This is deliberate: the automated APK is a
standalone production bundle, while the dev APK is for Metro-based local work.

If the upstream merge conflicts, the workflow fails and leaves the branch
unchanged. Resolve locally:

```powershell
git fetch upstream
git switch android-build
git merge upstream/main
git push origin android-build
```

## Rebuild APK when native inputs change

Rebuild after changes to any of these:

- `apps/mobile/app.config.ts`
- Expo SDK / React Native / native dependencies
- Android permissions, manifest, Gradle, or config plugins
- anything requiring `expo prebuild`

Command:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/build-android-debug.ps1 -Install
powershell -ExecutionPolicy Bypass -File scripts/run-mobile-prod.ps1
```

## Useful options

Clean native regeneration:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/build-android-debug.ps1 -CleanPrebuild -Install
```

Skip dependency install when already current:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/build-android-debug.ps1 -SkipInstallDeps -Install
```

Try a different architecture only if needed:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/build-android-debug.ps1 -Architecture arm64-v8a
```

## Known Windows notes

- Use a short checkout path such as `C:\m\multica`.
- Use Android Studio JBR (`C:\Program Files\Android\Android Studio\jbr`) if
  `JAVA_HOME` is not already set.
- The script sets `ANDROID_HOME` to `%LOCALAPPDATA%\Android\Sdk` when present.
- x86 native builds can fail in React Native Reanimated on this setup; the
  script defaults to `arm64-v8a` for Pixel devices.
