import 'dart:async';
import 'package:router_os_client/router_os_client.dart';

class RouterService {
  final String host;
  final int port;
  final String username;
  final String password;
  bool _connected = false;
  RouterOSClient? _client;

  // ---------- التخزين المؤقت (120 ثانية = دقيقتين) ----------
  final Map<String, dynamic> _cache = {};
  final Map<String, DateTime> _cacheTimestamps = {};
  static const Duration _cacheDuration = Duration(seconds: 120);

  RouterService({
    required this.host,
    this.port = 8728,
    required this.username,
    required this.password,
  });

  Future<bool> connect() async {
    for (int i = 0; i < 3; i++) {
      try {
        _client = RouterOSClient(
          address: host,
          user: username,
          password: password,
          port: port,
          useSsl: port == 8729,
          verbose: false,
        );
        _connected = await _client!.login();
        return _connected;
      } catch (_) {
        await Future.delayed(Duration(seconds: i + 1));
      }
    }
    _connected = false;
    return false;
  }

  Future<List<Map<String, dynamic>>> sendCommand(
    String command, {
    Map<String, dynamic>? params,
    bool usePost = false,
    bool useCache = false,
  }) async {
    final cacheKey = '$command${params?.toString() ?? ''}';
    if (useCache &&
        _cache.containsKey(cacheKey) &&
        _cacheTimestamps.containsKey(cacheKey)) {
      final age = DateTime.now().difference(_cacheTimestamps[cacheKey]!);
      if (age < _cacheDuration) {
        return _cache[cacheKey] as List<Map<String, dynamic>>;
      }
    }

    if (!_connected || _client == null) throw Exception('Not connected');
    for (int i = 0; i < 3; i++) {
      try {
        final Map<String, String>? args = params?.map(
          (key, value) => MapEntry(key, value.toString()),
        );
        final List<Map<String, String>> result =
            await _client!.talk(command, args);
        final converted = result
            .map((e) => e.map((k, v) => MapEntry(k, v as dynamic)))
            .toList();

        if (useCache) {
          _cache[cacheKey] = converted;
          _cacheTimestamps[cacheKey] = DateTime.now();
        }
        return converted;
      } catch (_) {
        await Future.delayed(Duration(seconds: i + 1));
      }
    }
    throw Exception('Failed after retries');
  }

  void clearCache() {
    _cache.clear();
    _cacheTimestamps.clear();
  }

  // ---------- دوال المراقبة والسرعة ----------
  Stream<double> monitorTrafficStream(String interface) async* {
    while (_connected) {
      try {
        final data = await getPortCurrentRate(interface);
        final totalMbps = ((data['rx-bits-per-second'] ?? 0) +
                (data['tx-bits-per-second'] ?? 0)) /
            1000000;
        yield totalMbps;
      } catch (_) {
        yield 0;
      }
      await Future.delayed(const Duration(seconds: 1));
    }
  }

  Future<Map<String, double>> getPortCurrentRate(String interfaceName) async {
    final result = await sendCommand(
      '/interface/monitor-traffic',
      params: {'interface': interfaceName, 'once': ''},
    );
    if (result.isNotEmpty) {
      final bits =
          double.tryParse(result.first['bits-per-second']?.toString() ?? '0') ??
              0;
      return {
        'rx-bits-per-second': bits / 2,
        'tx-bits-per-second': bits / 2,
      };
    }
    return {'rx-bits-per-second': 0, 'tx-bits-per-second': 0};
  }

  // ---------- دوال النظام ----------
  Future<List<Map<String, dynamic>>> getSystemHealth() =>
      sendCommand('/system/health/print');

  Future<List<Map<String, dynamic>>> getInterfaceList() =>
      sendCommand('/interface/print');

  Future<List<Map<String, dynamic>>> getSystemResource() =>
      sendCommand('/system/resource/print');

  // ---------- هوتسبوت ----------
  Future<List<Map<String, dynamic>>> getHotspotActive() =>
      sendCommand('/ip/hotspot/active/print', useCache: true);

  Future<List<Map<String, dynamic>>> getHotspotUsers() =>
      sendCommand('/ip/hotspot/user/print', useCache: true);

  Future<List<Map<String, dynamic>>> getHotspotProfiles() =>
      sendCommand('/ip/hotspot/user/profile/print', useCache: true);

  // ---------- PPP ----------
  Future<List<Map<String, dynamic>>> getPppActive() =>
      sendCommand('/ppp/active/print', useCache: true);

  Future<List<Map<String, dynamic>>> getPppSecrets() =>
      sendCommand('/ppp/secret/print', useCache: true);

  // ---------- Simple Queue ----------
  Future<List<Map<String, dynamic>>> getSimpleQueue() =>
      sendCommand('/queue/simple/print', useCache: true);

  // ---------- User Manager ----------
  Future<List<Map<String, dynamic>>> getUserManagerUsers() =>
      sendCommand('/tool/user-manager/user/print', useCache: true);

  Future<List<Map<String, dynamic>>> getUserManagerSessions() =>
      sendCommand('/tool/user-manager/session/print', useCache: true);

  void disconnect() {
    _client?.close();
    _client = null;
    _connected = false;
    clearCache();
  }

  bool get isConnected => _connected;
}
