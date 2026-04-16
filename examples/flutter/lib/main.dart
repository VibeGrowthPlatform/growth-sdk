import 'dart:async';
import 'dart:convert';
import 'dart:io'
    show
        ContentType,
        File,
        HttpHeaders,
        HttpRequest,
        HttpServer,
        HttpStatus,
        InternetAddress,
        NetworkInterface,
        Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vibegrowth_sdk/vibegrowth_sdk.dart';

const String _kAppId = 'sm_app_s8zfvx45e79b';
const String _kApiKey = 'sk_live_l2f_w0ntg7CMWTSEDkzZ_iPpioB7Vfj9H-DHSd5DujM';
const String _kBaseUrl = 'http://localhost:8000';
const String _kSdkVersion = '0.0.1';
const int _kControlPort = 8765;
const MethodChannel _exampleStorageChannel =
    MethodChannel('com.vibegrowth.sdk/channel');

enum InitStatus { notStarted, initializing, ready, failed }

class InitResult {
  final InitStatus status;
  final String? error;
  final DateTime timestamp;

  InitResult({
    required this.status,
    this.error,
    required this.timestamp,
  });

  bool get success => status == InitStatus.ready;
}

class AutomationActivity {
  final String command;
  final String status;
  final String? detail;
  final String rawUrl;
  final DateTime timestamp;

  const AutomationActivity({
    required this.command,
    required this.status,
    required this.rawUrl,
    required this.timestamp,
    this.detail,
  });
}

class ExampleAutomationCommand {
  final String name;
  final Map<String, String> params;
  final String rawUrl;

  const ExampleAutomationCommand({
    required this.name,
    required this.params,
    required this.rawUrl,
  });

  String? param(String key) {
    final value = params[key];
    if (value == null) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  double? doubleParam(String key) {
    final value = param(key);
    return value == null ? null : double.tryParse(value);
  }
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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
  final TextEditingController _baseUrlController =
      TextEditingController(text: _kBaseUrl);

  InitResult _initResult = InitResult(
    status: InitStatus.notStarted,
    timestamp: DateTime.now(),
  );
  String _baseUrl = _kBaseUrl;
  String? _userId;
  Map<String, dynamic>? _config;
  String? _configError;
  DateTime? _runtimeRefreshedAt;
  bool _runtimeLoading = false;
  AutomationActivity? _lastAutomation;
  final List<AutomationActivity> _automationHistory = [];
  int _automationCommandCount = 0;
  HttpServer? _controlServer;
  List<String> _controlHosts = [];
  String? _controlServerError;

  @override
  void initState() {
    super.initState();
    unawaited(_bootstrapExample());
  }

  Future<void> _bootstrapExample() async {
    await _restoreSavedBaseUrl();
    await _startControlServer();
  }

  Future<void> _startControlServer() async {
    try {
      final server = await HttpServer.bind(
        InternetAddress.anyIPv6,
        _kControlPort,
        v6Only: false,
      );
      _controlServer = server;
      _controlHosts = await _discoverControlHosts();
      server.listen((request) {
        unawaited(_handleControlHttpRequest(request));
      });
      if (!mounted) return;
      setState(() {
        _controlServerError = null;
      });
      await _writeControlServerStatus(<String, dynamic>{
        'status': 'listening',
        'port': _kControlPort,
        'hosts': _controlHosts,
        'timestamp': DateTime.now().toIso8601String(),
      });
      _addLog('control server listening on port $_kControlPort');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _controlServerError = e.toString();
      });
      await _writeControlServerStatus(<String, dynamic>{
        'status': 'failed',
        'port': _kControlPort,
        'error': e.toString(),
        'timestamp': DateTime.now().toIso8601String(),
      });
      _addLog('control server failed: $e');
    }
  }

  Future<void> _writeControlServerStatus(Map<String, dynamic> payload) async {
    try {
      final home = Platform.environment['HOME'];
      if (home == null || home.isEmpty) return;
      final file = File('$home/Documents/control-server-status.json');
      await file.parent.create(recursive: true);
      await file.writeAsString(jsonEncode(payload));
    } catch (_) {
      // Ignore status file write errors during debugging.
    }
  }

  Future<List<String>> _discoverControlHosts() async {
    try {
      final interfaces = await NetworkInterface.list(
        includeLoopback: false,
        includeLinkLocal: false,
      );
      final hosts = <String>{};
      for (final interface in interfaces) {
        for (final address in interface.addresses) {
          final host = address.address;
          if (host.contains(':')) {
            hosts.add('[${host.split('%').first}]');
          } else {
            hosts.add(host);
          }
        }
      }
      return hosts.toList()..sort();
    } catch (_) {
      return const <String>[];
    }
  }

  Future<void> _restoreSavedBaseUrl() async {
    try {
      final saved = await _exampleStorageChannel
          .invokeMethod<String>('getExampleBaseUrl');
      final value = saved?.trim();
      if (!mounted || value == null || value.isEmpty) return;
      setState(() {
        _baseUrl = value;
        _baseUrlController.text = value;
      });
      _addLog('restored saved Base URL: $value');
    } catch (_) {
      // Keep the built-in default if local persistence is unavailable.
    }
  }

  Future<void> _persistBaseUrlDraft(String value) async {
    try {
      await _exampleStorageChannel.invokeMethod<void>(
        'setExampleBaseUrl',
        <String, dynamic>{'baseUrl': value.trim()},
      );
    } catch (_) {
      // Keep the field usable even if persistence fails.
    }
  }

  Future<void> _refreshRuntimeInfo() async {
    if (!_initResult.success) {
      setState(() {
        _runtimeRefreshedAt = DateTime.now();
      });
      return;
    }
    setState(() => _runtimeLoading = true);
    String? userId;
    Map<String, dynamic>? config;
    String? configError;
    try {
      userId = await VibeGrowth.getUserId();
    } catch (e) {
      userId = null;
    }
    try {
      config = await VibeGrowth.getConfig();
    } catch (e) {
      configError = e.toString();
    }
    if (!mounted) return;
    setState(() {
      _userId = userId;
      _config = config;
      _configError = configError;
      _runtimeRefreshedAt = DateTime.now();
      _runtimeLoading = false;
    });
  }

  Future<void> _initializeSdk() async {
    if (_initResult.status == InitStatus.initializing) return;
    if (_initResult.success) {
      _addLog('SDK already initialized; restart the app to change Base URL.');
      return;
    }

    final baseUrl = _normalizedBaseUrl();
    if (baseUrl == null) {
      final message = 'Enter a valid HTTP or HTTPS Base URL.';
      setState(() {
        _initResult = InitResult(
          status: InitStatus.failed,
          error: message,
          timestamp: DateTime.now(),
        );
      });
      _addLog('initialize() skipped: $message');
      return;
    }

    final startedAt = DateTime.now();
    setState(() {
      _baseUrl = baseUrl;
      _config = null;
      _configError = null;
      _runtimeRefreshedAt = null;
      _runtimeLoading = false;
      _initResult = InitResult(
        status: InitStatus.initializing,
        timestamp: startedAt,
      );
    });
    await _persistBaseUrlDraft(baseUrl);
    _addLog('initialize(baseUrl: $baseUrl)');

    try {
      await VibeGrowth.initialize(
        appId: _kAppId,
        apiKey: _kApiKey,
        baseUrl: baseUrl,
      );
      if (!mounted) return;
      setState(() {
        _initResult = InitResult(
          status: InitStatus.ready,
          timestamp: startedAt,
        );
      });
      _addLog('SDK initialized');
      await _refreshRuntimeInfo();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _initResult = InitResult(
          status: InitStatus.failed,
          error: e.toString(),
          timestamp: startedAt,
        );
        _runtimeRefreshedAt = DateTime.now();
      });
      _addLog('initialize() error: $e');
      debugPrint('[VibeGrowth] Init failed: $e');
    }
  }

  Future<Map<String, dynamic>> _executeAutomationCommand(
      ExampleAutomationCommand command) async {
    final startedAt = DateTime.now();
    _recordAutomation(
      command: command.name,
      status: 'running',
      rawUrl: command.rawUrl,
      detail: 'Executing remote command',
      incrementCount: true,
    );
    _addLog('automation received: ${command.name}');

    String resultStatus;
    String? resultDetail;
    String? resultError;
    Map<String, dynamic> resultData = const <String, dynamic>{};

    try {
      switch (command.name) {
        case 'initialize':
          final baseUrl = command.param('base_url') ??
              command.param('baseUrl') ??
              command.param('url');
          if (baseUrl != null) {
            _baseUrlController.text = baseUrl;
            await _persistBaseUrlDraft(baseUrl);
          }
          await _initializeSdk();
          resultStatus = _initResult.success ? 'completed' : 'failed';
          resultDetail =
              'init=${_initResult.status.name} baseUrl=$_baseUrl';
          resultError = _initResult.error;
          resultData = <String, dynamic>{
            'initStatus': _initResult.status.name,
            'baseUrl': _baseUrl,
          };
          break;
        case 'set-user-id':
          final requestedUserId = command.param('user_id') ??
              command.param('userId') ??
              command.param('value');
          await _runAutomatedSdkAction(
              () => _setUserId(userId: requestedUserId));
          resultStatus = 'completed';
          resultDetail =
              'userId=${_userId ?? requestedUserId ?? '(generated)'}';
          resultData = <String, dynamic>{
            'userId': _userId,
            'requestedUserId': requestedUserId,
          };
          break;
        case 'track-purchase':
          final amount = command.doubleParam('amount') ?? 4.99;
          final currency = command.param('currency') ?? 'USD';
          final productId = command.param('product_id') ?? 'gem_pack_100';
          await _runAutomatedSdkAction(() => _trackPurchase(
                pricePaid: amount,
                currency: currency,
                productId: productId,
              ));
          resultStatus = 'completed';
          resultDetail = 'purchase=$amount $currency productId=$productId';
          resultData = <String, dynamic>{
            'amount': amount,
            'currency': currency,
            'productId': productId,
          };
          break;
        case 'track-ad-revenue':
          final source = command.param('source') ?? 'admob';
          final revenue = command.doubleParam('revenue') ?? 0.02;
          final currency = command.param('currency') ?? 'USD';
          await _runAutomatedSdkAction(() => _trackAdRevenue(
                source: source,
                revenue: revenue,
                currency: currency,
              ));
          resultStatus = 'completed';
          resultDetail = 'adRevenue=$revenue $currency source=$source';
          resultData = <String, dynamic>{
            'source': source,
            'revenue': revenue,
            'currency': currency,
          };
          break;
        case 'track-session-start':
          final sessionStart = command.param('session_start');
          await _runAutomatedSdkAction(
              () => _trackSessionStart(sessionStart: sessionStart));
          resultStatus = 'completed';
          resultDetail = 'sessionStart=${sessionStart ?? '(now)'}';
          resultData = <String, dynamic>{
            'sessionStart': sessionStart,
          };
          break;
        case 'get-config':
          await _runAutomatedSdkAction(_getConfig);
          resultStatus = _configError == null ? 'completed' : 'failed';
          resultDetail = 'configLoaded=${_config != null}';
          resultError = _configError;
          resultData = <String, dynamic>{
            'config': _config,
          };
          break;
        case 'refresh':
        case 'status':
          await _refreshRuntimeInfo();
          resultStatus = 'completed';
          resultDetail =
              'init=${_initResult.status.name} baseUrl=$_baseUrl userId=${_userId ?? '(none)'}';
          resultData = <String, dynamic>{
            'initStatus': _initResult.status.name,
            'baseUrl': _baseUrl,
            'userId': _userId,
            'config': _config,
          };
          _addLog('status $resultDetail');
          break;
        default:
          resultStatus = 'ignored';
          resultDetail = 'Command not supported';
          _addLog('automation command not supported: ${command.name}');
      }
    } catch (e) {
      resultStatus = 'failed';
      resultError = e.toString();
      resultDetail = resultError;
      _addLog('automation failed: $e');
    }

    _recordAutomation(
      command: command.name,
      status: resultStatus,
      rawUrl: command.rawUrl,
      detail: resultDetail,
    );

    final finishedAt = DateTime.now();
    return <String, dynamic>{
      'ok': resultStatus == 'completed',
      'command': command.name,
      'status': resultStatus,
      'detail': resultDetail,
      if (resultError != null) 'error': resultError,
      'data': resultData,
      'rawUrl': command.rawUrl,
      'startedAt': startedAt.toIso8601String(),
      'finishedAt': finishedAt.toIso8601String(),
      'elapsedMs': finishedAt.difference(startedAt).inMilliseconds,
      'state': _statusPayload(),
    };
  }

  Future<void> _handleControlHttpRequest(HttpRequest request) async {
    final path = request.uri.path;
    if (path == '/health') {
      await _writeJsonResponse(
        request,
        HttpStatus.ok,
        <String, dynamic>{'ok': true},
      );
      return;
    }

    if (path == '/status') {
      await _writeJsonResponse(request, HttpStatus.ok, _statusPayload());
      return;
    }

    final commandName = path.startsWith('/') ? path.substring(1) : path;
    if (commandName.isEmpty) {
      await _writeJsonResponse(
        request,
        HttpStatus.notFound,
        <String, dynamic>{'ok': false, 'error': 'Missing command path'},
      );
      return;
    }

    final params = <String, String>{};
    request.uri.queryParameters.forEach((key, value) {
      params[key] = value;
    });
    final command = ExampleAutomationCommand(
      name: commandName,
      params: params,
      rawUrl: request.uri.toString(),
    );
    final result = await _executeAutomationCommand(command);
    final statusCode = switch (result['status']) {
      'completed' => HttpStatus.ok,
      'ignored' => HttpStatus.badRequest,
      _ => HttpStatus.internalServerError,
    };
    await _writeJsonResponse(request, statusCode, result);
  }

  Map<String, dynamic> _statusPayload() {
    return <String, dynamic>{
      'ok': true,
      'initStatus': _initResult.status.name,
      'baseUrl': _baseUrl,
      'userId': _userId,
      'commandCount': _automationCommandCount,
      'lastCommand': _lastAutomation == null
          ? null
          : <String, dynamic>{
              'command': _lastAutomation!.command,
              'status': _lastAutomation!.status,
              'detail': _lastAutomation!.detail,
              'timestamp': _lastAutomation!.timestamp.toIso8601String(),
            },
    };
  }

  Future<void> _writeJsonResponse(
    HttpRequest request,
    int statusCode,
    Map<String, dynamic> payload,
  ) async {
    request.response.statusCode = statusCode;
    request.response.headers.contentType = ContentType.json;
    request.response.headers.set(HttpHeaders.cacheControlHeader, 'no-store');
    request.response.write(jsonEncode(payload));
    await request.response.close();
  }

  void _recordAutomation({
    required String command,
    required String status,
    required String rawUrl,
    String? detail,
    bool incrementCount = false,
  }) {
    final activity = AutomationActivity(
      command: command,
      status: status,
      rawUrl: rawUrl,
      detail: detail,
      timestamp: DateTime.now(),
    );

    setState(() {
      _lastAutomation = activity;
      if (incrementCount) {
        _automationCommandCount += 1;
      }
      _automationHistory.insert(0, activity);
      if (_automationHistory.length > 5) {
        _automationHistory.removeRange(5, _automationHistory.length);
      }
    });
  }

  void _addLog(String message) {
    final now = DateTime.now();
    final timestamp = '${now.hour.toString().padLeft(2, '0')}:'
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

  Future<void> _runSdkAction(Future<void> Function() action) async {
    if (!_initResult.success) {
      _addLog('Initialize the SDK before running actions.');
      return;
    }

    try {
      await action();
    } catch (e) {
      _addLog('Action error: $e');
    }
  }

  Future<void> _runAutomatedSdkAction(Future<void> Function() action) async {
    if (!_initResult.success) {
      _addLog('automation auto-initializing SDK first');
      await _initializeSdk();
    }

    if (!_initResult.success) {
      throw StateError(
          'SDK initialization is not ready: ${_initResult.error ?? _initResult.status.name}');
    }

    // Intentionally propagate SDK errors so they surface in the automation
    // HTTP response rather than being swallowed by _runSdkAction.
    await action();
  }

  Future<void> _setUserId({String? userId}) async {
    final resolvedUserId =
        userId ?? 'user-${DateTime.now().millisecondsSinceEpoch}';
    await VibeGrowth.setUserId(resolvedUserId);
    final retrieved = await VibeGrowth.getUserId();
    _addLog('setUserId($resolvedUserId)');
    _addLog('getUserId() = $retrieved');
    await _refreshRuntimeInfo();
  }

  Future<void> _trackPurchase({
    double pricePaid = 4.99,
    String currency = 'USD',
    String? productId,
  }) async {
    await VibeGrowth.trackPurchase(
      pricePaid: pricePaid,
      currency: currency,
      productId: productId,
    );
    _addLog('trackPurchase($pricePaid, $currency, ${productId ?? '(none)'})');
  }

  Future<void> _trackAdRevenue({
    String source = 'admob',
    double revenue = 0.02,
    String currency = 'USD',
  }) async {
    await VibeGrowth.trackAdRevenue(
      source: source,
      revenue: revenue,
      currency: currency,
    );
    _addLog('trackAdRevenue($source, $revenue, $currency)');
  }

  Future<void> _trackSessionStart({String? sessionStart}) async {
    final now = sessionStart ?? DateTime.now().toUtc().toIso8601String();
    await VibeGrowth.trackSessionStart(sessionStart: now);
    _addLog('trackSessionStart($now)');
  }

  Future<void> _getConfig() async {
    try {
      final config = await VibeGrowth.getConfig();
      _addLog('getConfig() = $config');
      if (mounted) {
        setState(() {
          _config = config;
          _configError = null;
          _runtimeRefreshedAt = DateTime.now();
        });
      }
    } catch (e) {
      _addLog('getConfig() error: $e');
    }
  }

  @override
  void dispose() {
    unawaited(_controlServer?.close(force: true));
    _baseUrlController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  String _maskApiKey(String key) {
    if (key.length <= 8) return '••••';
    return '${key.substring(0, 8)}…${key.substring(key.length - 2)}';
  }

  String _formatTime(DateTime t) {
    return '${t.hour.toString().padLeft(2, '0')}:'
        '${t.minute.toString().padLeft(2, '0')}:'
        '${t.second.toString().padLeft(2, '0')}';
  }

  String _platformLabel() {
    try {
      return '${Platform.operatingSystem} ${Platform.operatingSystemVersion}';
    } catch (_) {
      return 'unknown';
    }
  }

  String? _normalizedBaseUrl() {
    final value = _baseUrlController.text.trim();
    final uri = Uri.tryParse(value);
    if (uri == null ||
        !uri.hasScheme ||
        uri.host.isEmpty ||
        (uri.scheme != 'http' && uri.scheme != 'https')) {
      return null;
    }
    return value.endsWith('/') && value.length > '${uri.scheme}://'.length
        ? value.substring(0, value.length - 1)
        : value;
  }

  @override
  Widget build(BuildContext context) {
    final sdkReady = _initResult.success;
    final initInFlight = _initResult.status == InitStatus.initializing;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vibe Growth Example'),
        actions: [
          IconButton(
            tooltip: 'Refresh runtime info',
            onPressed: _runtimeLoading ? null : _refreshRuntimeInfo,
            icon: _runtimeLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          _AutomationActivityCard(
            activity: _lastAutomation,
            history: _automationHistory,
            commandCount: _automationCommandCount,
            formatTime: _formatTime,
          ),
          const SizedBox(height: 12),
          _ServerUrlCard(
            controller: _baseUrlController,
            canEdit: !sdkReady && !initInFlight,
            initInFlight: initInFlight,
            sdkReady: sdkReady,
            onChanged: _persistBaseUrlDraft,
            onInitialize: _initializeSdk,
          ),
          const SizedBox(height: 12),
          _SdkInfoCard(
            initResult: _initResult,
            sdkVersion: _kSdkVersion,
            appId: _kAppId,
            apiKeyMasked: _maskApiKey(_kApiKey),
            baseUrl: _baseUrl,
            platform: _platformLabel(),
            dartVersion: _dartVersion(),
            buildMode: _buildMode(),
          ),
          const SizedBox(height: 12),
          _RuntimeStateCard(
            userId: _userId,
            config: _config,
            configError: _configError,
            refreshedAt: _runtimeRefreshedAt,
            formatTime: _formatTime,
          ),
          const SizedBox(height: 16),
          _SectionLabel(text: 'Actions'),
          const SizedBox(height: 8),
          _ActionButton(
            label: 'Set User ID',
            onTap: sdkReady ? () => _runSdkAction(_setUserId) : null,
          ),
          const SizedBox(height: 8),
          _ActionButton(
            label: 'Track Purchase',
            onTap: sdkReady ? () => _runSdkAction(_trackPurchase) : null,
          ),
          const SizedBox(height: 8),
          _ActionButton(
            label: 'Track Ad Revenue',
            onTap: sdkReady ? () => _runSdkAction(_trackAdRevenue) : null,
          ),
          const SizedBox(height: 8),
          _ActionButton(
            label: 'Track Session Start',
            onTap: sdkReady ? () => _runSdkAction(_trackSessionStart) : null,
          ),
          const SizedBox(height: 8),
          _ActionButton(
            label: 'Get Config',
            onTap: sdkReady ? () => _runSdkAction(_getConfig) : null,
          ),
          const SizedBox(height: 16),
          _ControlServerCard(
            port: _kControlPort,
            hosts: _controlHosts,
            error: _controlServerError,
          ),
          const SizedBox(height: 16),
          _SectionLabel(text: 'Log Output'),
          const SizedBox(height: 8),
          _LogPanel(log: _log, scrollController: _scrollController),
        ],
      ),
    );
  }

  String _buildMode() {
    if (kReleaseMode) return 'release';
    if (kProfileMode) return 'profile';
    return 'debug';
  }

  String _dartVersion() {
    // Platform.version is e.g. "3.5.0 (stable) (Tue Jul 30 ...) on macos_arm64"
    try {
      final v = Platform.version;
      final firstSpace = v.indexOf(' ');
      return firstSpace > 0 ? v.substring(0, firstSpace) : v;
    } catch (_) {
      return 'unknown';
    }
  }
}

class _SdkInfoCard extends StatelessWidget {
  final InitResult initResult;
  final String sdkVersion;
  final String appId;
  final String apiKeyMasked;
  final String baseUrl;
  final String platform;
  final String dartVersion;
  final String buildMode;

  const _SdkInfoCard({
    required this.initResult,
    required this.sdkVersion,
    required this.appId,
    required this.apiKeyMasked,
    required this.baseUrl,
    required this.platform,
    required this.dartVersion,
    required this.buildMode,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ok = initResult.success;
    final isInitializing = initResult.status == InitStatus.initializing;
    final isIdle = initResult.status == InitStatus.notStarted;
    final statusColor = switch (initResult.status) {
      InitStatus.ready => Colors.green.shade600,
      InitStatus.initializing => Colors.orange.shade700,
      InitStatus.failed => Colors.red.shade600,
      InitStatus.notStarted => Colors.grey.shade600,
    };
    final statusLabel = switch (initResult.status) {
      InitStatus.ready => 'SDK Initialized',
      InitStatus.initializing => 'Initializing SDK',
      InitStatus.failed => 'SDK Init Failed',
      InitStatus.notStarted => 'SDK Not Initialized',
    };
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: statusColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                statusLabel,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: statusColor,
                ),
              ),
              const Spacer(),
              Text(
                'v$sdkVersion',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          if ((isIdle || isInitializing) && initResult.error == null) ...[
            const SizedBox(height: 6),
            Text(
              isInitializing
                  ? 'Waiting for the current initialize() call to finish.'
                  : 'Set the Base URL above, then initialize the SDK.',
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade700,
              ),
            ),
          ],
          if (!ok && initResult.error != null) ...[
            const SizedBox(height: 6),
            Text(
              initResult.error!,
              style: TextStyle(
                fontSize: 11,
                color: Colors.red.shade700,
                fontFamily: 'monospace',
              ),
            ),
          ],
          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 10),
          _KvRow(label: 'App ID', value: appId),
          _KvRow(label: 'API Key', value: apiKeyMasked),
          _KvRow(label: 'Base URL', value: baseUrl),
          _KvRow(label: 'Platform', value: platform),
          _KvRow(label: 'Dart', value: dartVersion),
          _KvRow(label: 'Build', value: buildMode),
        ],
      ),
    );
  }
}

class _ServerUrlCard extends StatelessWidget {
  final TextEditingController controller;
  final bool canEdit;
  final bool initInFlight;
  final bool sdkReady;
  final ValueChanged<String> onChanged;
  final Future<void> Function() onInitialize;

  const _ServerUrlCard({
    required this.controller,
    required this.canEdit,
    required this.initInFlight,
    required this.sdkReady,
    required this.onChanged,
    required this.onInitialize,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Server URL',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: controller,
            enabled: canEdit,
            keyboardType: TextInputType.url,
            onChanged: onChanged,
            decoration: const InputDecoration(
              labelText: 'Base URL',
              hintText: 'http://192.168.1.10:8000',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            sdkReady
                ? 'The SDK is initialized for this app session. Restart the app to use a different URL.'
                : 'Use http://localhost:8000 on iOS Simulator. On Android emulator, use http://10.0.2.2:8000 or reverse port 8000. For a physical device, use your Mac LAN IP.',
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: canEdit ? onInitialize : null,
              child: initInFlight
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(sdkReady ? 'SDK Initialized' : 'Initialize SDK'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ControlServerCard extends StatelessWidget {
  final int port;
  final List<String> hosts;
  final String? error;

  const _ControlServerCard({
    required this.port,
    required this.hosts,
    required this.error,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Control Server',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          if (error != null)
            Text(
              error!,
              style: TextStyle(
                fontSize: 11,
                color: Colors.red.shade700,
                fontFamily: 'monospace',
              ),
            )
          else if (hosts.isEmpty)
            Text(
              'Listening on port $port. Waiting for a network address.',
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade700,
              ),
            )
          else ...[
            Text(
              'HTTP control is live on port $port.',
              style: const TextStyle(fontSize: 11),
            ),
            const SizedBox(height: 8),
            for (final host in hosts)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: SelectableText(
                  'http://$host:$port/status',
                  style: const TextStyle(
                    fontSize: 11,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _AutomationActivityCard extends StatelessWidget {
  final AutomationActivity? activity;
  final List<AutomationActivity> history;
  final int commandCount;
  final String Function(DateTime) formatTime;

  const _AutomationActivityCard({
    required this.activity,
    required this.history,
    required this.commandCount,
    required this.formatTime,
  });

  Color _statusColor(String status) {
    switch (status) {
      case 'completed':
        return Colors.green.shade600;
      case 'running':
        return Colors.orange.shade700;
      case 'failed':
        return Colors.red.shade600;
      default:
        return Colors.grey.shade600;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final currentStatus = activity?.status ?? 'idle';
    final currentColor = _statusColor(currentStatus);
    return Container(
      decoration: BoxDecoration(
        color: currentColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: currentColor.withValues(alpha: 0.45)),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Automation Activity',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              Text(
                '$commandCount command${commandCount == 1 ? '' : 's'}',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (activity == null)
            Text(
              'No automation commands received yet.',
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade800,
              ),
            )
          else ...[
            Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: _statusColor(activity!.status),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${activity!.command} (${activity!.status})',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _statusColor(activity!.status),
                  ),
                ),
                const Spacer(),
                Text(
                  formatTime(activity!.timestamp),
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: currentColor.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                activity!.command.toUpperCase(),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: currentColor,
                  fontFamily: 'monospace',
                ),
              ),
            ),
            if (activity!.detail != null) ...[
              const SizedBox(height: 6),
              Text(
                activity!.detail!,
                style:
                    const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
              ),
            ],
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(6),
              ),
              child: SelectableText(
                activity!.rawUrl,
                style: const TextStyle(
                  fontSize: 11,
                  fontFamily: 'monospace',
                  height: 1.4,
                ),
              ),
            ),
          ],
          if (history.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Text(
              'Recent Commands',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            for (final item in history)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '${formatTime(item.timestamp)}  ${item.command}  ${item.status}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _RuntimeStateCard extends StatelessWidget {
  final String? userId;
  final Map<String, dynamic>? config;
  final String? configError;
  final DateTime? refreshedAt;
  final String Function(DateTime) formatTime;

  const _RuntimeStateCard({
    required this.userId,
    required this.config,
    required this.configError,
    required this.refreshedAt,
    required this.formatTime,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final encoder = const JsonEncoder.withIndent('  ');
    String configBody;
    if (configError != null) {
      configBody = configError!;
    } else if (config == null) {
      configBody = '(not loaded)';
    } else if (config!.isEmpty) {
      configBody = '{}';
    } else {
      try {
        configBody = encoder.convert(config);
      } catch (_) {
        configBody = config.toString();
      }
    }
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Runtime State',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              if (refreshedAt != null)
                Text(
                  'updated ${formatTime(refreshedAt!)}',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey.shade600,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          _KvRow(label: 'User ID', value: userId ?? '(none)'),
          const SizedBox(height: 10),
          Text(
            'CONFIG',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              configBody,
              style: TextStyle(
                fontSize: 11,
                fontFamily: 'monospace',
                height: 1.4,
                color: configError != null ? Colors.red.shade700 : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _KvRow extends StatelessWidget {
  final String label;
  final String value;

  const _KvRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 78,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.5,
        color: Colors.grey.shade600,
      ),
    );
  }
}

class _LogPanel extends StatelessWidget {
  final List<String> log;
  final ScrollController scrollController;

  const _LogPanel({required this.log, required this.scrollController});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      height: 220,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(12),
      child: log.isEmpty
          ? Center(
              child: Text(
                'Tap a button to test SDK features',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            )
          : ListView.builder(
              controller: scrollController,
              itemCount: log.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    log[index],
                    style: const TextStyle(
                      fontSize: 11,
                      fontFamily: 'monospace',
                      height: 1.4,
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final Future<void> Function()? onTap;

  const _ActionButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.tonal(
        onPressed: onTap == null ? null : () => onTap!(),
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
