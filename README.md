# Vibe Growth SDKs

Open-source client SDKs for the [Vibe Growth](https://vibegrowin.ai) mobile app
growth platform. This monorepo contains native iOS, native Android, Flutter,
and Unity packages that ship attribution, user identity, session tracking,
revenue tracking, and remote config to the Vibe Growth backend.

| Package | Path | Registry |
| --- | --- | --- |
| iOS (Swift) | [`ios/`](ios/) | Swift Package Manager |
| Android (Kotlin) | [`android/`](android/) | Maven Central |
| Flutter | [`flutter/`](flutter/) | [pub.dev](https://pub.dev) |
| Unity | [`unity/`](unity/) | UPM (Git URL / OpenUPM) |

Example apps for each platform live under [`examples/`](examples/).

**SDK version:** `2.1.0`

## Quickstart

### iOS (SwiftPM)

```swift
dependencies: [
    .package(url: "https://github.com/VibeGrowthPlatform/growth-sdk.git", from: "2.1.0"),
],
targets: [
    .target(name: "App", dependencies: [
        .product(name: "VibeGrowthSDK", package: "growth-sdk"),
    ]),
]
```

### Android (Gradle)

```kotlin
dependencies {
    implementation("com.vibegrowth:sdk:2.1.0")
}
```

### Flutter (`pubspec.yaml`)

```yaml
dependencies:
  vibegrowth_sdk: ^2.1.0
```

### Unity (`Packages/manifest.json`)

```json
{
  "dependencies": {
    "com.vibegrowth.sdk": "https://github.com/VibeGrowthPlatform/growth-sdk.git?path=unity#unity/v2.1.0"
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

Per-SDK independent releases use prefixed tags: `ios/vX.Y.Z`, `android/vX.Y.Z`,
`flutter/vX.Y.Z`, `unity/vX.Y.Z`. Each tag triggers the corresponding workflow
under `.github/workflows/`.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). Bug reports and pull requests are
welcome.

## License

MIT — see [LICENSE](LICENSE).
