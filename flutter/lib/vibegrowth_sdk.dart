library vibegrowth_sdk;

import 'src/vibegrowth_method_channel.dart';

class VibeGrowth {
  static final VibeGrowthMethodChannel _channel = VibeGrowthMethodChannel();

  VibeGrowth._();

  static Future<void> initialize({
    required String appId,
    required String apiKey,
    String? baseUrl,
  }) {
    return _channel.initialize(appId, apiKey, baseUrl);
  }

  static Future<void> setUserId(String userId) {
    return _channel.setUserId(userId);
  }

  static Future<String?> getUserId() {
    return _channel.getUserId();
  }

  static Future<void> trackPurchase({
    required double pricePaid,
    required String currency,
    String? productId,
  }) {
    return _channel.trackPurchase(pricePaid, currency, productId);
  }

  static Future<void> trackAdRevenue({
    required String source,
    required double revenue,
    required String currency,
  }) {
    return _channel.trackAdRevenue(source, revenue, currency);
  }

  static Future<void> trackSessionStart({
    required String sessionStart,
  }) {
    return _channel.trackSessionStart(sessionStart);
  }

  @Deprecated('Use trackSessionStart instead.')
  static Future<void> trackSession({
    required String sessionStart,
    int? sessionDurationMs,
  }) {
    return _channel.trackSessionStart(sessionStart);
  }

  static Future<Map<String, dynamic>> getConfig() {
    return _channel.getConfig();
  }
}
