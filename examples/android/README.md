# Vibe Growth SDK - Android Example App

This native Android example app demonstrates the Android SDK with the real local Vibe Growth backend. It includes an in-app HTTP control server so an agent or developer can drive the app from the host machine and verify backend persistence without manual tapping.

## What It Validates

- SDK initialization against a supplied backend URL
- user identification
- purchase revenue tracking
- ad revenue tracking
- session start tracking
- remote config fetch

The local end-to-end script verifies the resulting rows in ClickHouse tables:

- `devices`
- `revenue_events`
- `session_events`

## Prerequisites

- Docker / Docker Compose for the local backend stack
- Android SDK platform tools with `adb`
- a running Android emulator or connected device
- Java 17 for the Gradle build

For Android emulators, the app reaches the host backend through `http://10.0.2.2:8000`.

## Local Backend And Configuration

The repeatable E2E path uses the shared local SDK test identity:

| Field | Value |
| --- | --- |
| App ID | `sm_app_sdk_e2e` |
| API key | `sk_live_sdk_e2e_local_only` |
| Android emulator base URL | `http://10.0.2.2:8000` |
| Host backend URL | `http://localhost:8000` |

Prepare the local backend by running the Vibe Growth backend repo's `make dev`
and seeding the SDK E2E app (see that repo's README). Then verify:

```bash
curl http://localhost:8000/api/readyz
```

The control script also accepts explicit `base_url`, `app_id`, and `api_key`
arguments for runs against another backend app.

## Run The Full Local E2E Flow

From the repo root, with the Vibe Growth backend already running locally:

```bash
bash scripts/validate-android-example-e2e.sh
```

The script:

1. waits for `GET /api/readyz` on `http://localhost:8000`
2. installs this example app on the current Android emulator/device
3. forwards host port `8766` to the app control server
4. drives SDK calls through the running app
5. queries ClickHouse until the expected device, revenue, and session rows appear

Skip the app install when it is already present:

```bash
bash scripts/validate-android-example-e2e.sh --skip-install
```

## Build And Run Manually

```bash
cd examples/android
./gradlew --no-daemon :app:installDebug
adb shell am start -n com.vibegrowth.example/.MainActivity
adb forward tcp:8766 tcp:8766
```

The app does not initialize the SDK automatically. Initialize it from the UI or with the control script after the local backend is running and the SDK E2E app has been seeded.

## Control Protocol

```bash
examples/android/scripts/control_android_example.sh forward
examples/android/scripts/control_android_example.sh open
examples/android/scripts/control_android_example.sh initialize http://10.0.2.2:8000
examples/android/scripts/control_android_example.sh set-user-id android-user-123
examples/android/scripts/control_android_example.sh track-purchase 4.99 USD gem_pack_100
examples/android/scripts/control_android_example.sh track-ad-revenue admob 0.02 USD
examples/android/scripts/control_android_example.sh track-session-start 2026-04-10T10:00:00+00:00
examples/android/scripts/control_android_example.sh get-config
examples/android/scripts/control_android_example.sh status
```

Supported HTTP paths on the app control server:

```text
GET  /health
GET  /status
POST /initialize?base_url=<url>&app_id=<app_id>&api_key=<api_key>
POST /set-user-id?user_id=<id>
POST /track-purchase?amount=...&currency=...&product_id=...
POST /track-ad-revenue?source=...&revenue=...&currency=...
POST /track-session-start?session_start=<iso8601>
POST /get-config
POST /refresh
```

The host reaches the control server at `http://127.0.0.1:8766` after `adb forward tcp:8766 tcp:8766`.

## Expected Signals

The example sends the canonical native Android SDK requests:

- `initialize` sends `POST /api/sdk/init` and creates or refreshes a
  `devices` row with platform `android`.
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

## Verify Backend Ingestion

The full script verifies ClickHouse automatically. For manual runs, query the
local ClickHouse tables:

```bash
docker compose exec -T clickhouse clickhouse-client --database scalemonk --query \
  "SELECT device_id, platform, user_id FROM devices FINAL WHERE app_id = 'sm_app_sdk_e2e' ORDER BY updated_at DESC LIMIT 5"

docker compose exec -T clickhouse clickhouse-client --database scalemonk --query \
  "SELECT device_id, revenue_type, product_id, ad_source, amount, currency FROM revenue_events WHERE app_id = 'sm_app_sdk_e2e' ORDER BY received_at DESC LIMIT 5"

docker compose exec -T clickhouse clickhouse-client --database scalemonk --query \
  "SELECT device_id, user_id, is_first_session, session_start FROM session_events WHERE app_id = 'sm_app_sdk_e2e' ORDER BY received_at DESC LIMIT 5"
```

The successful E2E script prints the app ID, backend URL, control URL, generated
user ID, generated product ID, resolved device ID, and verified tables.
