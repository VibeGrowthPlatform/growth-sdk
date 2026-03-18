library vibegrowth_sdk;

import 'src/vibegrowth_method_channel.dart';

class VibeGrowth {
  static final VibeGrowthMethodChannel _channel = VibeGrowthMethodChannel();

  VibeGrowth._();

  static Future<void> initialize({
    required String appId,
    required String apiKey,
  }) {
    return _channel.initialize(appId, apiKey);
  }

  static Future<void> setUserId(String userId) {
    return _channel.setUserId(userId);
  }

  static Future<String?> getUserId() {
    return _channel.getUserId();
  }

  static Future<void> trackPurchase({
    required double amount,
    required String currency,
    required String productId,
  }) {
    return _channel.trackPurchase(amount, currency, productId);
  }

  static Future<void> trackAdRevenue({
    required String source,
    required double revenue,
    required String currency,
  }) {
    return _channel.trackAdRevenue(source, revenue, currency);
  }
}
