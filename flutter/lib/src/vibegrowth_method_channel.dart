import 'package:flutter/services.dart';

class VibeGrowthMethodChannel {
  static const MethodChannel _channel =
      MethodChannel('com.vibegrowth.sdk/channel');

  Future<void> initialize(String appId, String apiKey) {
    return _channel.invokeMethod<void>('initialize', <String, dynamic>{
      'appId': appId,
      'apiKey': apiKey,
    });
  }

  Future<void> setUserId(String userId) {
    return _channel.invokeMethod<void>('setUserId', <String, dynamic>{
      'userId': userId,
    });
  }

  Future<String?> getUserId() {
    return _channel.invokeMethod<String?>('getUserId');
  }

  Future<void> trackPurchase(double amount, String currency, String productId) {
    return _channel.invokeMethod<void>('trackPurchase', <String, dynamic>{
      'amount': amount,
      'currency': currency,
      'productId': productId,
    });
  }

  Future<void> trackAdRevenue(String source, double revenue, String currency) {
    return _channel.invokeMethod<void>('trackAdRevenue', <String, dynamic>{
      'source': source,
      'revenue': revenue,
      'currency': currency,
    });
  }
}
