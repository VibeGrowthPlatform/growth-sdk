import 'package:flutter/material.dart';
import 'package:vibegrowth_sdk/vibegrowth_sdk.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await VibeGrowth.initialize(
    appId: 'example-app-id',
    apiKey: 'example-api-key',
    baseUrl: 'http://localhost:8000',
  );
  runApp(const ExampleApp());
}

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Vibe Growth SDK Example')),
        body: Center(
          child: ElevatedButton(
            onPressed: () async {
              await VibeGrowth.trackPurchase(
                pricePaid: 4.99,
                currency: 'USD',
                productId: 'premium_monthly',
              );
            },
            child: const Text('Track Purchase'),
          ),
        ),
      ),
    );
  }
}
