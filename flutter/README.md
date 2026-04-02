# Vibe Growth SDK for Flutter

Flutter plugin for attribution, user identity, session tracking, and revenue tracking.

**Version:** 2.1.0

**Requirements:** Dart >= 3.0.0, Flutter >= 3.10.0, Android minSdk 21, iOS 14+

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  vibegrowth_sdk: ^2.1.0
```

Then run:

```bash
flutter pub get
```

## Usage

### Import

```dart
import 'package:vibegrowth_sdk/vibegrowth_sdk.dart';
```

### Initialize

```dart
await VibeGrowth.initialize(
  appId: 'your-app-id',
  apiKey: 'your-api-key',
  baseUrl: 'https://api.vibegrowth.com',
);
```

### Set User ID

```dart
await VibeGrowth.setUserId('user-123');
```

### Get User ID

```dart
String? userId = await VibeGrowth.getUserId();
```

### Track Purchase

```dart
await VibeGrowth.trackPurchase(
  pricePaid: 4.99,
  currency: 'USD',
);
```

### Track Ad Revenue

```dart
await VibeGrowth.trackAdRevenue(
  source: 'admob',
  revenue: 0.02,
  currency: 'USD',
);
```

### Track Session Start

```dart
await VibeGrowth.trackSessionStart(
  sessionStart: '2026-01-01T00:00:00Z',
);
```

### Fetch Remote Config

```dart
final config = await VibeGrowth.getConfig();
```

## Development

- Example app: `example/`
- Tests: `flutter test`
- Static analysis: `flutter analyze`
