# Vibe Growth SDK for Unity

Unity plugin for attribution, user identity, and revenue tracking.

**Requirements:** Unity 2021.3+, Android minSdk 21, iOS 14+

## Installation

Add to your `Packages/manifest.json`:

```json
{
  "dependencies": {
    "com.vibegrowth.sdk": "https://github.com/vibegrowth/vibegrowth-sdk-unity.git"
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
    }
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
    { "amount", 4.99 },
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
