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

## Run The Full Local E2E Flow

From the repo root:

```bash
make validate-android-example-e2e
```

Equivalent direct command:

```bash
bash scripts/validate-android-example-e2e.sh
```

The script:

1. starts `postgres`, `clickhouse`, `redis`, and `backend`
2. waits for `GET /api/readyz`
3. seeds the SDK E2E app (`sm_app_sdk_e2e`)
4. runs ClickHouse release tasks
5. installs this example app on the current Android emulator/device
6. forwards host port `8766` to the app control server
7. drives SDK calls through the running app
8. queries ClickHouse until the expected device, revenue, and session rows appear

Use these options when the backend or app is already prepared:

```bash
bash scripts/validate-android-example-e2e.sh --skip-backend
bash scripts/validate-android-example-e2e.sh --skip-install
```

## Build And Run Manually

```bash
cd vibegrowth-sdk-native/examples/android
./gradlew --no-daemon :app:installDebug
adb shell am start -n com.vibegrowth.example/.MainActivity
adb forward tcp:8766 tcp:8766
```

The app does not initialize the SDK automatically. Initialize it from the UI or with the control script after the local backend is running and the SDK E2E app has been seeded.

## Control Protocol

```bash
vibegrowth-sdk-native/examples/android/scripts/control_android_example.sh forward
vibegrowth-sdk-native/examples/android/scripts/control_android_example.sh open
vibegrowth-sdk-native/examples/android/scripts/control_android_example.sh initialize http://10.0.2.2:8000
vibegrowth-sdk-native/examples/android/scripts/control_android_example.sh set-user-id android-user-123
vibegrowth-sdk-native/examples/android/scripts/control_android_example.sh track-purchase 4.99 USD gem_pack_100
vibegrowth-sdk-native/examples/android/scripts/control_android_example.sh track-ad-revenue admob 0.02 USD
vibegrowth-sdk-native/examples/android/scripts/control_android_example.sh track-session-start 2026-04-10T10:00:00+00:00
vibegrowth-sdk-native/examples/android/scripts/control_android_example.sh get-config
vibegrowth-sdk-native/examples/android/scripts/control_android_example.sh status
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

## Local Backend Identity

The repeatable E2E path uses the shared SDK test identity:

- app id: `sm_app_sdk_e2e`
- API key: `sk_live_sdk_e2e_local_only`

These are local-only credentials seeded by `app.forge.scripts.seed_sdk_e2e_app`.
