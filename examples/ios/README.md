# Vibe Growth SDK - iOS Example App

A minimal SwiftUI app that demonstrates every Vibe Growth SDK feature with an interactive button panel, live log output, and a host-driven HTTP control server for repeatable local validation.

## Features Demonstrated

- **SDK Initialization** -- called at app launch with the seeded local SDK e2e app by default
- **Set User ID** -- assigns a timestamped user ID and verifies retrieval
- **Get User ID** -- reads the currently stored user ID
- **Track Purchase** -- sends a manual purchase event (4.99 USD, gem_pack_100)
- **Track Ad Revenue** -- sends an ad revenue event (AdMob, 0.02 USD)
- **Track Session Start** -- tracks a session start with the current ISO 8601 timestamp
- **Get Config** -- fetches remote configuration from the backend
- **HTTP Control Server** -- accepts host commands on port `8766` for simulator automation

Auto-purchase tracking via StoreKit is enabled by default.

## Prerequisites

- Xcode 15+
- iOS 15+ simulator or device
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)

## Build and Run

```bash
cd examples/ios

# Generate the Xcode project from project.yml
xcodegen generate

# Build for simulator
xcodebuild -project VGExampleApp.xcodeproj \
  -scheme VGExampleApp \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  build

# Or open in Xcode and run
open VGExampleApp.xcodeproj
```

The app allows cleartext HTTP for local backend validation. It is intended for the iOS Simulator first; a physical device must be able to reach the backend host over the network.

## Configuration

The app initializes the SDK through `ExampleViewModel` with these defaults:

| Parameter | Value |
|-----------|-------|
| App ID | `sm_app_sdk_e2e` |
| API Key | `sk_live_sdk_e2e_local_only` |
| Base URL | `http://localhost:8000` |

To test against the local backend, prepare the seeded SDK e2e app first. The repeatable path is:

```bash
bash scripts/validate-sdks.sh --e2e
```

For manual app runs, start the Vibe Growth backend (see the backend repo's `make dev`) and seed the SDK E2E app per its README. The example reads these defaults but any reachable Vibe Growth API will work.

The example also reads `VIBEGROWTH_SDK_E2E_APP_ID`, `VIBEGROWTH_SDK_E2E_API_KEY`, `VIBEGROWTH_SDK_E2E_BASE_URL`, and the shared `/tmp/vibegrowth-sdk-e2e.json` file written by `scripts/validate-sdks.sh --e2e` when those are available. The generated E2E config uses `http://127.0.0.1:8000` for host/JVM tests; the iOS simulator example normalizes that value to `[::1]` before issuing SDK requests.

## Control Protocol

When the app launches, it starts a plain HTTP control server on port `8766`. On the iOS Simulator this is reachable from the host at `http://127.0.0.1:8766`.

```text
GET  /health
GET  /status
POST /initialize?base_url=<url>
POST /set-user-id?user_id=<id>
POST /track-purchase?amount=...&currency=...&product_id=...
POST /track-ad-revenue?source=...&revenue=...&currency=...
POST /track-session-start?session_start=<iso8601>
POST /get-config
POST /refresh
```

Use the bundled script from the repo root:

```bash
examples/ios/scripts/control_ios_example.sh health
examples/ios/scripts/control_ios_example.sh set-user-id ios-example-user
examples/ios/scripts/control_ios_example.sh track-purchase 4.99 USD gem_pack_100
examples/ios/scripts/control_ios_example.sh track-ad-revenue admob 0.02 USD
examples/ios/scripts/control_ios_example.sh track-session-start 2026-04-06T10:00:00+00:00
examples/ios/scripts/control_ios_example.sh get-config
```

Each command returns JSON with command status, elapsed time, and the app's runtime state snapshot.

## Expected Signals

The example sends the canonical native iOS SDK requests:

- `initialize` sends `POST /api/sdk/init` and creates or refreshes a
  `devices` row with platform `ios`.
- `set-user-id` sends `POST /api/sdk/identify` and updates the device
  `user_id`.
- `track-purchase` sends `POST /api/sdk/revenue` with
  `revenue_type = purchase`, amount `4.99`, currency `USD`, and product
  `gem_pack_100` unless overridden.
- `track-ad-revenue` sends `POST /api/sdk/revenue` with
  `revenue_type = ad_revenue`, source `admob`, amount `0.02`, and currency
  `USD`.
- `track-session-start` sends `POST /api/sdk/session`.
- `get-config` sends `GET /api/sdk/config`.

## End-to-End Verification

The SDK validation script generates the Xcode project, builds the example, and runs `VGExampleAppTests/ExampleAppEndToEndTest.swift` when macOS and Xcode are available:

```bash
bash scripts/validate-sdks.sh --e2e
```

That test drives the same `ExampleViewModel` methods used by the app, then polls ClickHouse to verify the device, user id, purchase revenue, ad revenue, session, and config-fetch path against the real local backend.

Manual ClickHouse checks can be run with:

```bash
docker compose exec -T clickhouse clickhouse-client --database scalemonk --query \
  "SELECT device_id, platform, user_id FROM devices FINAL WHERE app_id = 'sm_app_sdk_e2e' ORDER BY updated_at DESC LIMIT 5"

docker compose exec -T clickhouse clickhouse-client --database scalemonk --query \
  "SELECT device_id, revenue_type, product_id, amount FROM revenue_events WHERE app_id = 'sm_app_sdk_e2e' ORDER BY received_at DESC LIMIT 5"

docker compose exec -T clickhouse clickhouse-client --database scalemonk --query \
  "SELECT device_id, is_first_session, session_start FROM session_events WHERE app_id = 'sm_app_sdk_e2e' ORDER BY received_at DESC LIMIT 5"
```

## Project Structure

```text
examples/ios/
  project.yml                      # XcodeGen project definition
  scripts/control_ios_example.sh    # Host control script for simulator automation
  VGExampleApp/
    VGExampleApp.swift             # App entry point
    ExampleConfiguration.swift      # Local/e2e configuration source
    ExampleControlServer.swift      # In-app HTTP control server
    ExampleViewModel.swift         # ViewModel wrapping all SDK calls with logging
    ContentView.swift              # SwiftUI interface with buttons and log view
  VGExampleAppTests/
    ExampleAppEndToEndTest.swift   # Real-backend example-app e2e validation
```

The `VGExampleApp.xcodeproj` is generated by XcodeGen and should not be committed.
