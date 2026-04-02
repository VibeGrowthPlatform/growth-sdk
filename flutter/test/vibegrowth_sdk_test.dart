import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vibegrowth_sdk/vibegrowth_sdk.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.vibegrowth.sdk/channel');
  final calls = <MethodCall>[];

  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.method == 'getConfig') {
        return '{"feature_flag":true}';
      }
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('initialize forwards optional baseUrl', () async {
    await VibeGrowth.initialize(
      appId: 'app-id',
      apiKey: 'api-key',
      baseUrl: 'http://localhost:8000',
    );

    expect(calls.single.method, 'initialize');
    expect(calls.single.arguments, <String, dynamic>{
      'appId': 'app-id',
      'apiKey': 'api-key',
      'baseUrl': 'http://localhost:8000',
    });
  });

  test('getConfig decodes JSON response', () async {
    final config = await VibeGrowth.getConfig();

    expect(config, <String, dynamic>{'feature_flag': true});
  });

  test('trackPurchase forwards pricePaid and optional productId', () async {
    await VibeGrowth.trackPurchase(
      pricePaid: 4.99,
      currency: 'USD',
    );

    expect(calls.single.method, 'trackPurchase');
    expect(calls.single.arguments, <String, dynamic>{
      'pricePaid': 4.99,
      'currency': 'USD',
    });
  });

  test('trackSessionStart forwards sessionStart only', () async {
    await VibeGrowth.trackSessionStart(
      sessionStart: '2026-01-01T00:00:00Z',
    );

    expect(calls.single.method, 'trackSessionStart');
    expect(calls.single.arguments, <String, dynamic>{
      'sessionStart': '2026-01-01T00:00:00Z',
    });
  });
}
