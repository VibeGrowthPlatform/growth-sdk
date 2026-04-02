import 'dart:convert';

import 'package:flutter/services.dart';

class VibeGrowthMethodChannel {
  static const MethodChannel _channel =
      MethodChannel('com.vibegrowth.sdk/channel');

  Future<void> initialize(String appId, String apiKey, [String? baseUrl]) {
    return _channel.invokeMethod<void>('initialize', <String, dynamic>{
      'appId': appId,
      'apiKey': apiKey,
      if (baseUrl != null) 'baseUrl': baseUrl,
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

  Future<void> trackPurchase(
    double pricePaid,
    String currency, [
    String? productId,
  ]) {
    return _channel.invokeMethod<void>('trackPurchase', <String, dynamic>{
      'pricePaid': pricePaid,
      'currency': currency,
      if (productId != null) 'productId': productId,
    });
  }

  Future<void> trackAdRevenue(String source, double revenue, String currency) {
    return _channel.invokeMethod<void>('trackAdRevenue', <String, dynamic>{
      'source': source,
      'revenue': revenue,
      'currency': currency,
    });
  }

  Future<void> trackSessionStart(String sessionStart) {
    return _channel.invokeMethod<void>('trackSessionStart', <String, dynamic>{
      'sessionStart': sessionStart,
    });
  }

  Future<Map<String, dynamic>> getConfig() async {
    final json = await _channel.invokeMethod<String>('getConfig');
    if (json == null || json.isEmpty) {
      return <String, dynamic>{};
    }

    final decoded = jsonDecode(json);
    if (decoded is Map) {
      return decoded.map(
        (key, value) => MapEntry(key.toString(), value),
      );
    }

    return <String, dynamic>{};
  }
}
