# Vibe Growth Unity3D Basic Integration Example

This Unity sample contains `VibeGrowthInit.cs`, a bootstrap `MonoBehaviour`
that initializes the Unity SDK when the first scene starts. It is the package's
minimal example app path for validating that Unity calls reach the native
Android or iOS SDK bridge.

For repeatable real-backend validation of the full Unity SDK flow, use the
runnable project in `../unity-player-e2e/` and its
`scripts/run_player_e2e.sh` runner.

## Prerequisites

- Unity 2021.3+
- Android Build Support for Android player validation, or Xcode/iOS Build
  Support for iOS player validation
- Local Vibe Growth backend when verifying real ingestion
- `adb` for Android emulator/device installs

The Unity Editor uses `VibeGrowthEditorBridge`, which logs SDK calls but does
not send network traffic. Use an Android or iOS player build to verify backend
ingestion.

## Local Backend

Prepare the shared SDK E2E app from the repo root:

```bash
docker compose up -d --build postgres clickhouse redis backend
curl http://localhost:8000/api/readyz
docker compose exec -T backend python -m app.forge.scripts.seed_sdk_e2e_app
docker compose exec -T backend python -m app.release_tasks
```

Local test identity:

| Field | Value |
| --- | --- |
| App ID | `sm_app_sdk_e2e` |
| API key | `sk_live_sdk_e2e_local_only` |
| iOS Simulator base URL | `http://localhost:8000` |
| Android emulator base URL | `http://10.0.2.2:8000` |

## SDK Initialization

Import the sample from Unity Package Manager:

1. Open the project that consumes `com.vibegrowth.sdk`.
2. Select the Vibe Growth SDK package.
3. Import `Samples > Basic Integration`.
4. Attach `VibeGrowthInit` to a bootstrap GameObject in the first scene.

For local backend validation, edit the sample constants in
`VibeGrowthInit.cs` before building:

```csharp
VibeGrowthSDK.Initialize(
    appId: "sm_app_sdk_e2e",
    apiKey: "sk_live_sdk_e2e_local_only",
    onSuccess: () => Debug.Log("Vibe Growth initialized"),
    onError: (error) => Debug.LogError("Vibe Growth init failed: " + error),
    baseUrl: "http://10.0.2.2:8000"
);
```

Use `http://localhost:8000` for an iOS Simulator build, or a LAN URL for a
physical device.

## Run Steps

Android emulator:

1. Start an emulator.
2. Set `baseUrl` to `http://10.0.2.2:8000`.
3. Build and run the scene from Unity with Android as the active target.
4. Watch Logcat for `Vibe Growth initialized`.

iOS Simulator:

1. Set `baseUrl` to `http://localhost:8000`.
2. Build the Unity project for iOS.
3. Open the generated Xcode project.
4. Run it on a simulator and watch the Xcode console for
   `Vibe Growth initialized`.

## Expected Signals

The sample sends one SDK initialization request:

- `VibeGrowthSDK.Initialize` sends `POST /api/sdk/init`.
- The backend should persist or refresh one row in ClickHouse `devices` for
  app `sm_app_sdk_e2e`.

This basic sample does not call `SetUserId`, `TrackPurchase`,
`TrackAdRevenue`, `TrackSessionStart`, or `GetConfig`. The package root
README shows those SDK calls for extending the sample.

## Verify Backend Ingestion

After the player logs a successful initialization, query ClickHouse:

```bash
docker compose exec -T clickhouse clickhouse-client --database scalemonk --query \
  "SELECT device_id, platform, user_id, sdk_version FROM devices FINAL WHERE app_id = 'sm_app_sdk_e2e' ORDER BY updated_at DESC LIMIT 5"
```

Expected evidence:

- a recent `devices` row for `sm_app_sdk_e2e`
- `platform = android` for Android player builds or `platform = ios` for iOS
  player builds
- no revenue or session rows unless you extend the sample to call those SDK
  methods

## Automated Checks

The plain SDK validation script checks that the Unity package's vendored native
Android and iOS sources stay in sync with the top-level `android/` and `ios/` packages:

```bash
bash scripts/validate-sdks.sh
```

The real-backend E2E validation uses the runnable Unity player example:

```bash
bash scripts/validate-sdks.sh --e2e
```
