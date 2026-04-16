# Vibe Growth Flutter Example

This Flutter app demonstrates the Flutter SDK on iOS Simulator, Android
emulator, and physical devices. It includes a small in-app HTTP control server
so host-side scripts can drive SDK calls and inspect runtime state.

## Prerequisites

- Flutter 3.10+ and Dart 3+
- Xcode for iOS Simulator runs
- Android SDK platform tools with `adb` for Android emulator/device runs
- Local Vibe Growth backend when verifying real ingestion

## Local Backend

Start the Vibe Growth backend (see the backend repo's `make dev`) and confirm it is ready:

```bash
curl http://localhost:8000/api/readyz
```

The app initializes with the credentials embedded in
`examples/flutter/lib/main.dart`:

| Field | Value |
| --- | --- |
| App ID | `sm_app_s8zfvx45e79b` |
| API key | `sk_live_l2f_w0ntg7CMWTSEDkzZ_iPpioB7Vfj9H-DHSd5DujM` |
| Default base URL | `http://localhost:8000` |

For local ingestion checks, the backend database must contain an active app with
that App ID and API key. The shared SDK E2E seed
(`app.forge.scripts.seed_sdk_e2e_app`) creates the native test identity
`sm_app_sdk_e2e`; it does not rewrite the Flutter example's embedded
credentials.

Backend reachability depends on the target:

- iOS Simulator: use `http://localhost:8000`.
- Android emulator: either initialize with `http://10.0.2.2:8000` or run
  `adb reverse tcp:8000 tcp:8000` before using `http://localhost:8000`.
- Physical device: use the host machine's LAN URL, for example
  `http://192.168.1.10:8000`.

## Run The App

```bash
cd examples/flutter
flutter pub get
flutter run -d <simulator-or-emulator-id>
```

The Control Server card shows whether the in-app server is listening. It binds
to port `8765`.

For host-driven Android emulator control, forward the control port:

```bash
adb forward tcp:8765 tcp:8765
```

## SDK Initialization And Configuration

The UI lets you edit the base URL before initialization. The app persists the
last base URL locally and uses the embedded App ID/API key above.

The host control script can initialize the SDK and override only the base URL:

```bash
examples/flutter/scripts/control_ios_example.sh initialize http://localhost:8000
```

Use `http://10.0.2.2:8000` for an Android emulator unless you have reversed
port `8000`.

## Control Protocol

The server speaks plain HTTP. Any method works; the script uses POST.

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

Example host sequence:

```bash
chmod +x examples/flutter/scripts/control_ios_example.sh
examples/flutter/scripts/control_ios_example.sh health
examples/flutter/scripts/control_ios_example.sh initialize http://localhost:8000
examples/flutter/scripts/control_ios_example.sh set-user-id flutter-example-user
examples/flutter/scripts/control_ios_example.sh track-purchase 4.99 USD gem_pack_100
examples/flutter/scripts/control_ios_example.sh track-ad-revenue admob 0.02 USD
examples/flutter/scripts/control_ios_example.sh track-session-start 2026-04-10T10:00:00+00:00
examples/flutter/scripts/control_ios_example.sh get-config
examples/flutter/scripts/control_ios_example.sh status
```

Script overrides:

- `VG_EXAMPLE_CONTROL_HOST` defaults to `127.0.0.1`.
- `VG_EXAMPLE_CONTROL_PORT` defaults to `8765`.
- `VG_EXAMPLE_BUNDLE_ID` defaults to `com.example.vibegrowthSdkExample`.

## Expected Signals

The example sends the canonical SDK backend requests:

- `initialize` sends `POST /api/sdk/init` and should create or refresh a
  `devices` row.
- `set-user-id` sends `POST /api/sdk/identify` and should update the device
  `user_id`.
- `track-purchase` sends `POST /api/sdk/revenue` with
  `revenue_type = purchase`, amount `4.99`, currency `USD`, and product
  `gem_pack_100`.
- `track-ad-revenue` sends `POST /api/sdk/revenue` with
  `revenue_type = ad_revenue`, source `admob`, amount `0.02`, and currency
  `USD`.
- `track-session-start` sends `POST /api/sdk/session`.
- `get-config` sends `GET /api/sdk/config`.

## Verify Backend Ingestion

Use the app ID and user ID from your run:

```bash
docker compose exec -T clickhouse clickhouse-client --database scalemonk --query \
  "SELECT device_id, platform, user_id FROM devices FINAL WHERE app_id = 'sm_app_s8zfvx45e79b' ORDER BY updated_at DESC LIMIT 5"

docker compose exec -T clickhouse clickhouse-client --database scalemonk --query \
  "SELECT device_id, revenue_type, product_id, ad_source, amount, currency FROM revenue_events WHERE app_id = 'sm_app_s8zfvx45e79b' ORDER BY received_at DESC LIMIT 5"

docker compose exec -T clickhouse clickhouse-client --database scalemonk --query \
  "SELECT device_id, user_id, is_first_session, session_start FROM session_events WHERE app_id = 'sm_app_s8zfvx45e79b' ORDER BY received_at DESC LIMIT 5"
```

For dashboard analytics state, start the full stack with `make dev`, open the
dashboard, and select the app that owns the Flutter example credentials. The
first SDK ingest path may enqueue cohort aggregation for SDK-sourced apps.

## Automated Checks

The general SDK validation command runs Flutter static analysis and tests:

```bash
bash scripts/validate-sdks.sh
```

`bash scripts/validate-sdks.sh --e2e` prepares the shared native SDK E2E backend
identity and still runs the Flutter analyze/test checks, but it does not launch
or drive this Flutter example app.
