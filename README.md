# Vibe Growth SDKs

Open-source client SDKs for the [Vibe Growth](https://vibegrowin.ai) mobile app
growth platform. This monorepo contains native iOS, native Android, Flutter,
and Unity packages that ship attribution, user identity, session tracking,
revenue tracking, and remote config to the Vibe Growth backend.

| Package | Path | Distribution |
| --- | --- | --- |
| iOS (Swift) | [`ios/`](ios/) | Swift Package Manager (GitHub) |
| Android (Kotlin) | [`android/`](android/) | [JitPack](https://jitpack.io) |
| Flutter | [`flutter/`](flutter/) | [pub.dev](https://pub.dev/packages/vibegrowth_sdk) |
| Unity | [`unity/`](unity/) | UPM via Git URL |

Example apps for each platform live under [`examples/`](examples/).

**SDK version:** `0.0.1` — all four packages are released together under the
same version. See [RELEASING.md](RELEASING.md) for the release flow.

## Quickstart

### iOS (SwiftPM)

```swift
dependencies: [
    .package(url: "https://github.com/VibeGrowthPlatform/growth-sdk.git", from: "0.0.1"),
],
targets: [
    .target(name: "App", dependencies: [
        .product(name: "VibeGrowthSDK", package: "growth-sdk"),
    ]),
]
```

### Android (Gradle, via JitPack)

```kotlin
// settings.gradle.kts
dependencyResolutionManagement {
    repositories {
        maven { url = uri("https://jitpack.io") }
    }
}

// build.gradle.kts
dependencies {
    implementation("com.github.VibeGrowthPlatform.growth-sdk:android:v0.0.1")
}
```

(The `.repo:module` form is JitPack's convention for monorepos. Maven Central
publication is planned for a future release and will simplify the
coordinates.)

### Flutter (`pubspec.yaml`)

```yaml
dependencies:
  vibegrowth_sdk: ^0.0.1
```

### Unity (`Packages/manifest.json`)

```json
{
  "dependencies": {
    "com.vibegrowth.sdk": "https://github.com/VibeGrowthPlatform/growth-sdk.git?path=unity#v0.0.1"
  }
}
```

See each package's local README for initialization and API details.

## Architecture

The iOS and Android packages hold the canonical native implementations. The
Flutter and Unity packages vendor the native sources — `scripts/validate-sdks.sh`
runs a sync check to keep the copies identical. Treat the native packages as
the source of truth when updating SDK behavior.

## Repository layout

```
ios/        # Swift Package (VibeGrowthSDK)
android/    # Gradle library (AAR)
flutter/    # Flutter plugin (vibegrowth_sdk)
unity/      # Unity Package Manager package (com.vibegrowth.sdk)
examples/
  ios/                 # SwiftUI example with host control server
  android/             # Android example with host control server
  flutter/             # Flutter example with host control server
  unity-basic/         # Minimal Unity sample
  unity-player-e2e/    # Runnable Unity E2E harness
scripts/
  validate-sdks.sh                     # Build/test + vendored-source sync check
  validate-android-example-e2e.sh      # Real-backend Android example E2E
```

## Development

```bash
bash scripts/validate-sdks.sh          # build, test, vendoring sync
bash scripts/validate-sdks.sh --e2e    # also run real-backend E2E (requires backend running locally)
```

Real-backend E2E assumes a Vibe Growth backend reachable at
`http://localhost:8000` with the SDK E2E app seeded. See the Vibe Growth backend
repo for how to bring it up (`make dev`).

## Releasing

All four packages share one version. A release is a single `vX.Y.Z` tag
pushed on `main`; every platform's workflow in `.github/workflows/` fires
concurrently. See [RELEASING.md](RELEASING.md) for the full flow.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). Bug reports and pull requests are
welcome.

## License

MIT — see [LICENSE](LICENSE).
