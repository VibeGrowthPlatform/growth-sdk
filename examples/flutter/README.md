# Vibe Growth Flutter Example

This example app exposes an HTTP control server so an agent can drive it
end-to-end from the host machine. It is built for the **iOS Simulator** and
**Android emulator** first — a physical device is supported but not
required.

## Running the app

```bash
cd vibegrowth-sdk-flutter/example
flutter run -d <simulator-or-emulator-id>
```

When the app boots, it starts an HTTP server on port `8765` bound to all
interfaces. On the iOS Simulator this port is reachable from the host Mac
at `http://127.0.0.1:8765` directly. For an Android emulator, forward the
port with:

```bash
adb reverse tcp:8765 tcp:8765
```

The Control Server card in the app shows the bound interfaces and any
startup error.

## Control Protocol

The server speaks plain HTTP. Each command is a path under the server
root, with parameters passed as query string. Any HTTP method works; the
control script uses POST.

```text
GET  /health                               → {"ok": true}
GET  /status                               → current runtime snapshot
POST /initialize?base_url=<url>            → init SDK (optionally rewriting base URL)
POST /set-user-id?user_id=<id>             → sets or auto-generates the user id
POST /track-purchase?amount=...&currency=...&product_id=...
POST /track-ad-revenue?source=...&revenue=...&currency=...
POST /track-session-start?session_start=<iso8601>
POST /get-config                           → refreshes and returns the server config
POST /refresh                              → refreshes runtime state
```

### Response shape

Command responses carry the per-command result inline rather than making
you poll `/status` afterwards:

```json
{
  "ok": true,
  "command": "track-purchase",
  "status": "completed",
  "detail": "purchase=4.99 USD productId=gem_pack_100",
  "data": {
    "amount": 4.99,
    "currency": "USD",
    "productId": "gem_pack_100"
  },
  "rawUrl": "/track-purchase?amount=4.99&currency=USD&product_id=gem_pack_100",
  "startedAt": "2026-04-09T18:22:11.904Z",
  "finishedAt": "2026-04-09T18:22:12.158Z",
  "elapsedMs": 254,
  "state": {
    "ok": true,
    "initStatus": "ready",
    "baseUrl": "http://localhost:8000",
    "userId": "user-1712683329158",
    "commandCount": 4,
    "lastCommand": { "command": "track-purchase", "status": "completed", "detail": "...", "timestamp": "..." }
  }
}
```

HTTP status codes:

- `200` — `status == "completed"`
- `400` — `status == "ignored"` (unknown command)
- `500` — `status == "failed"` (SDK threw, init failed, etc.)

When a command fails, the response includes an `error` field with the
exception message.

## Mac Control Script

```bash
chmod +x vibegrowth-sdk-flutter/example/scripts/control_ios_example.sh
vibegrowth-sdk-flutter/example/scripts/control_ios_example.sh initialize http://localhost:8000
vibegrowth-sdk-flutter/example/scripts/control_ios_example.sh set-user-id test-user-123
vibegrowth-sdk-flutter/example/scripts/control_ios_example.sh track-purchase 4.99 USD gem_pack_100
vibegrowth-sdk-flutter/example/scripts/control_ios_example.sh status
```

The script prints the full JSON result body to stdout, and exits non-zero
if the underlying HTTP call fails. Override the target with:

- `VG_EXAMPLE_CONTROL_HOST` — default `127.0.0.1`. Set to the device LAN IP
  when driving a physical device.
- `VG_EXAMPLE_CONTROL_PORT` — default `8765`.
- `VG_EXAMPLE_BUNDLE_ID` — default `com.example.vibegrowthSdkExample`, used
  by `open` to relaunch the app on a booted simulator via `xcrun simctl`.

## Autonomous Verification

After driving a command, verify the backend received and persisted what
you expect by querying the local databases or the SDK routes directly:

- `initialize` → `POST /api/sdk/init`
- `set-user-id` → `POST /api/sdk/identify`
- `track-purchase` / `track-ad-revenue` → `POST /api/sdk/revenue`
- `track-session-start` → `POST /api/sdk/session`
- `get-config` → `GET /api/sdk/config`

For local Docker dev, the backend is on `http://localhost:8000`.
