# Vibe Growth SDK for Unity

Unity plugin for attribution, user identity, session tracking, and revenue tracking.

**Version:** 2.1.0

**Requirements:** Unity 2021.3+, Android minSdk 21, iOS 14+

## Installation

Add to your `Packages/manifest.json`:

```json
{
  "dependencies": {
    "com.vibegrowth.sdk": "https://github.com/VibeGrowthPlatform/growth-sdk.git?path=unity#unity/v2.1.0"
  }
}
```

## Usage

### Import

```csharp
using VibeGrowth;
```

### Initialize

```csharp
VibeGrowthSDK.Initialize(
    "your-app-id",
    "your-api-key",
    onSuccess: () => {
        Debug.Log("Vibe Growth SDK initialized");
    },
    onError: (error) => {
        Debug.LogError("Init failed: " + error);
    },
    baseUrl: "https://api.vibegrowin.ai"
);
```

### Set User ID

```csharp
VibeGrowthSDK.SetUserId("user-123");
```

### Get User ID

```csharp
string userId = VibeGrowthSDK.GetUserId();
```

### Track Purchase

```csharp
VibeGrowthSDK.TrackPurchase(new Dictionary<string, object> {
    { "pricePaid", 4.99 },
    { "currency", "USD" },
    { "productId", "com.example.gems_pack" }
});
```

### Track Ad Revenue

```csharp
VibeGrowthSDK.TrackAdRevenue(new Dictionary<string, object> {
    { "source", "admob" },
    { "revenue", 0.02 },
    { "currency", "USD" }
});
```

### Track Session Start

```csharp
VibeGrowthSDK.TrackSessionStart("2026-01-01T00:00:00Z");
```

### Fetch Remote Config

```csharp
VibeGrowthSDK.GetConfig(
    onSuccess: (configJson) => Debug.Log("Config: " + configJson),
    onError: (error) => Debug.LogError("Config failed: " + error)
);
```

## Development

- Basic sample: `../examples/unity-basic/README.md`
- Runnable real-backend example: `../examples/unity-player-e2e/README.md`
- Runtime code is backed by vendored native sources from `../android/` and `../ios/` (kept in sync by `scripts/validate-sdks.sh`).

### Real-Backend E2E

With the Vibe Growth backend running locally on `http://localhost:8000` (see the
backend repo's `make dev`), from the repo root run:

```bash
bash scripts/validate-sdks.sh --e2e
```

This builds and runs the Unity example player app and verifies the resulting
device, revenue, session, and config state through ClickHouse and the SDK
config endpoint. To run only the Unity portion:

```bash
examples/unity-player-e2e/scripts/run_player_e2e.sh
```
