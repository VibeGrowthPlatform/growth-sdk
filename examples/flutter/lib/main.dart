import 'package:flutter/material.dart';
import 'package:vibegrowth_sdk/vibegrowth_sdk.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await VibeGrowth.initialize(
      appId: 'sm_app_example',
      apiKey: 'sk_live_example_key',
      baseUrl: 'http://localhost:8000',
    );
    debugPrint('[VibeGrowth] SDK initialized');
  } catch (e) {
    debugPrint('[VibeGrowth] Init failed: $e');
  }

  runApp(const ExampleApp());
}

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vibe Growth Example',
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF1E293B),
        useMaterial3: true,
      ),
      home: const ExampleScreen(),
    );
  }
}

class ExampleScreen extends StatefulWidget {
  const ExampleScreen({super.key});

  @override
  State<ExampleScreen> createState() => _ExampleScreenState();
}

class _ExampleScreenState extends State<ExampleScreen> {
  final List<String> _log = [];
  final ScrollController _scrollController = ScrollController();

  void _addLog(String message) {
    final now = DateTime.now();
    final timestamp =
        '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}:'
        '${now.second.toString().padLeft(2, '0')}.'
        '${now.millisecond.toString().padLeft(3, '0')}';
    setState(() {
      _log.add('[$timestamp] $message');
    });
    debugPrint('[VGExample] $message');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _setUserId() async {
    final userId = 'user-${DateTime.now().millisecondsSinceEpoch}';
    await VibeGrowth.setUserId(userId);
    final retrieved = await VibeGrowth.getUserId();
    _addLog('setUserId($userId)');
    _addLog('getUserId() = $retrieved');
  }

  Future<void> _trackPurchase() async {
    await VibeGrowth.trackPurchase(
      pricePaid: 4.99,
      currency: 'USD',
      productId: 'gem_pack_100',
    );
    _addLog('trackPurchase(4.99, USD, gem_pack_100)');
  }

  Future<void> _trackAdRevenue() async {
    await VibeGrowth.trackAdRevenue(
      source: 'admob',
      revenue: 0.02,
      currency: 'USD',
    );
    _addLog('trackAdRevenue(admob, 0.02, USD)');
  }

  Future<void> _trackSessionStart() async {
    final now = DateTime.now().toUtc().toIso8601String();
    await VibeGrowth.trackSessionStart(sessionStart: now);
    _addLog('trackSessionStart($now)');
  }

  Future<void> _getConfig() async {
    try {
      final config = await VibeGrowth.getConfig();
      _addLog('getConfig() = $config');
    } catch (e) {
      _addLog('getConfig() error: $e');
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vibe Growth Example'),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SDK v2.1.0',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                Text(
                  'Base URL: http://localhost:8000',
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _ActionButton(label: 'Set User ID', onTap: _setUserId),
                const SizedBox(height: 8),
                _ActionButton(label: 'Track Purchase', onTap: _trackPurchase),
                const SizedBox(height: 8),
                _ActionButton(
                    label: 'Track Ad Revenue', onTap: _trackAdRevenue),
                const SizedBox(height: 8),
                _ActionButton(
                    label: 'Track Session Start', onTap: _trackSessionStart),
                const SizedBox(height: 8),
                _ActionButton(label: 'Get Config', onTap: _getConfig),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.only(left: 16, top: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'LOG OUTPUT',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.5,
                  color: Colors.grey.shade600,
                ),
              ),
            ),
          ),
          Expanded(
            child: _log.isEmpty
                ? Center(
                    child: Text(
                      'Tap a button to test SDK features',
                      style: TextStyle(
                          fontSize: 13, color: Colors.grey.shade500),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _log.length,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Text(
                          _log[index],
                          style: const TextStyle(
                            fontSize: 11,
                            fontFamily: 'monospace',
                            height: 1.4,
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _ActionButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.tonal(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: Text(label),
      ),
    );
  }
}
