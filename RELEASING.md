# Releasing

All four packages (iOS, Android, Flutter, Unity) ship together under a single
version. A release is one `vX.Y.Z` tag on `main` — every platform workflow in
`.github/workflows/` runs concurrently off that tag.

## Release checklist

1. Update the version to `X.Y.Z` across these files (grep for the current
   version to find them):
   - `ios/Sources/VibeGrowthSDK/VibeGrowthSDK.swift` — `sdkVersion`
   - `android/build.gradle.kts` — `version`
   - `android/src/main/kotlin/com/vibegrowth/sdk/VibeGrowthSDK.kt` — `SDK_VERSION`
   - `flutter/pubspec.yaml` — `version`
   - `flutter/ios/vibegrowth_sdk.podspec` — `s.version`
   - `flutter/ios/Classes/VibeGrowthSDK.swift` — `sdkVersion`
   - `flutter/android/build.gradle` — `version`
   - `flutter/android/src/main/kotlin/com/vibegrowth/sdk/VibeGrowthSDK.kt` — `SDK_VERSION`
   - `unity/package.json` — `version`
   - `unity/Runtime/Internal/VibeGrowthEditorBridge.cs` — `SdkVersion`
   - `unity/Plugins/iOS/Sources/VibeGrowthSDK.swift` — `sdkVersion`
   - `unity/Plugins/Android/src/main/kotlin/com/vibegrowth/sdk/VibeGrowthSDK.kt` — `SDK_VERSION`
   - Top-level `README.md` and each package README install snippets
   - Example app `SDK v…` strings

2. Confirm the repo is clean and all tests pass:
   ```bash
   bash scripts/validate-sdks.sh
   ```

3. Commit the version bump on `main`:
   ```bash
   git commit -am "Release vX.Y.Z"
   git push origin main
   ```

4. Tag and push:
   ```bash
   git tag vX.Y.Z
   git push origin vX.Y.Z
   ```

5. Create a GitHub Release for the tag with a changelog:
   ```bash
   gh release create vX.Y.Z --generate-notes
   ```

## What each channel picks up

| Channel | How it reacts to the tag |
| --- | --- |
| iOS (SwiftPM) | SwiftPM resolves the tag directly. Nothing to publish. |
| Unity (Git URL) | Consumers pin to the tag in `manifest.json`. Nothing to publish. |
| Android (JitPack) | JitPack lazily builds on first install request; `jitpack.yml` drives the build off the `android/` Gradle project. |
| Flutter (pub.dev) | Requires a manual publish (see below). |

## Flutter publish (manual for now)

pub.dev publishing is interactive the first time. Run from your workstation:

```bash
cd flutter
dart pub login      # one-time OAuth in browser
dart pub publish
```

Once the package is live on pub.dev, add this repo as a trusted publisher under
**Package admin → Trusted publisher** on pub.dev and wire an action to publish
from tag workflows via OIDC — no stored credentials.

## Follow-ups

- **Maven Central** for Android (today we ship via JitPack). Requires a
  Sonatype OSSRH namespace (`ai.vibegrowin` or similar), GPG signing key in
  repo secrets, and a `publishToSonatype closeAndReleaseSonatypeStagingRepository`
  Gradle step in `android.yml`.
- **OpenUPM** for Unity. Submit the package once via the OpenUPM dashboard;
  subsequent tags are picked up automatically.
- **Automated Flutter publishing** via pub.dev GitHub OIDC once the first
  manual publish is done.
