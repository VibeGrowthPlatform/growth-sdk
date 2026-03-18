# Vibe Growth Native SDK

Shared native Android (Kotlin) and iOS (Swift) layers for attribution, user
identity, and revenue tracking. These native libraries are consumed by the
Flutter and Unity SDK plugins via source inclusion.

## Package Layout

### Android (`android/`)

Gradle library (AGP 8.1.4, Kotlin 1.9.22, compileSdk 34, minSdk 21).

```
src/main/kotlin/com/vibegrowth/sdk/
  VibeGrowthConfig.kt         # Configuration data class (appId, apiKey, baseUrl)
  VibeGrowthSDK.kt            # Main singleton entry point
  attribution/
    InstallReferrerHelper.kt  # Google Play Install Referrer collection
  identity/
    UserIdentityManager.kt    # Device ID generation + user ID persistence
  network/
    ApiClient.kt              # HttpURLConnection-based HTTP client
    ApiEndpoints.kt           # API path constants
  persistence/
    PreferencesStore.kt       # SharedPreferences wrapper
  revenue/
    RevenueTracker.kt         # Purchase and ad revenue event tracking
```

### iOS (`ios/`)

Swift Package (swift-tools-version 5.9, platform iOS 14+).

```
Sources/VibeGrowthSDK/
  VibeGrowthConfig.swift         # Configuration class (@objc, NSObject)
  VibeGrowthSDK.swift            # Main singleton entry point
  Attribution/
    AdServicesHelper.swift       # Apple Search Ads attribution (AdServices)
  Identity/
    UserIdentityManager.swift    # Device ID generation + user ID persistence
  Network/
    ApiClient.swift              # URLSession-based HTTP client
    ApiEndpoints.swift           # API path constants
  Persistence/
    UserDefaultsStore.swift      # UserDefaults wrapper
  Revenue/
    RevenueTracker.swift         # Purchase and ad revenue event tracking
```

## How Flutter/Unity Consume the Native Code

Both Flutter and Unity use **source inclusion** (not prebuilt binaries):

- **Flutter Android**: Kotlin files are copied into `vibegrowth-sdk-flutter/android/src/main/kotlin/com/vibegrowth/sdk/`
- **Flutter iOS**: Swift files are copied into `vibegrowth-sdk-flutter/ios/Classes/` and included via podspec `s.source_files`
- **Unity Android**: Kotlin files are copied into `vibegrowth-sdk-unity/Plugins/Android/src/main/kotlin/com/vibegrowth/sdk/`
- **Unity iOS**: Swift files are copied into `vibegrowth-sdk-unity/Plugins/iOS/Sources/` preserving subdirectory structure

## Backend API Endpoints

All endpoints are prefixed with `/api/sdk` and require a Bearer token in the `Authorization` header.

### POST /api/sdk/init

Initialize a device session.

**Headers:**
```
Content-Type: application/json
Authorization: Bearer <api_key>
```

**Request Body:**
```json
{
  "app_id": "your-app-id",
  "device_id": "uuid-device-id",
  "platform": "android",
  "sdk_version": "1.0.0",
  "attribution": { "install_referrer": "utm_source=google" }
}
```

**Response:**
```json
{
  "status": "ok",
  "device_id": "uuid-device-id",
  "created_at": "2026-01-01T00:00:00+00:00"
}
```

### POST /api/sdk/identify

Associate a user ID with a device.

**Headers:**
```
Content-Type: application/json
Authorization: Bearer <api_key>
```

**Request Body:**
```json
{
  "app_id": "your-app-id",
  "device_id": "uuid-device-id",
  "user_id": "user-123"
}
```

**Response:**
```json
{
  "status": "ok"
}
```

### POST /api/sdk/revenue

Track a revenue event (purchase or ad revenue).

**Headers:**
```
Content-Type: application/json
Authorization: Bearer <api_key>
```

**Request Body:**
```json
{
  "app_id": "your-app-id",
  "device_id": "uuid-device-id",
  "user_id": "user-123",
  "revenue_type": "purchase",
  "amount": 4.99,
  "currency": "USD",
  "product_id": "com.example.gems_pack",
  "ad_source": null,
  "timestamp": null
}
```

**Response:**
```json
{
  "status": "ok",
  "event_id": "uuid-event-id"
}
```

### GET /api/sdk/config

Retrieve SDK configuration.

**Headers:**
```
Authorization: Bearer <api_key>
```

**Response:**
```json
{
  "status": "ok",
  "config": {}
}
```
