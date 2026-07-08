import 'dart:async';
import 'package:routeros_api/routeros_api.dart';

class RouterService {
  final String host;
  final int port;
  final String username;
  final String password;

  bool _connected = false;
  RouterOSClient? _client;

  Completer<bool>? _connectCompleter;

  final Map<String, dynamic> _cache = {};
  final Map<String, DateTime> _cacheTimestamps = {};
  static const Duration _cacheDuration = Duration(seconds: 120);
  static const Duration _connectTimeout = Duration(seconds: 7);
  static const Duration _commandTimeout = Duration(seconds: 10);

  RouterService({
    required this.host,
    this.port = 8728,
    required this.username,
    required this.password,
  });

  // ==================== الاتصال ====================
  Future<bool> connect({bool forceReconnect = false}) async {
    if (!forceReconnect && _connected && _client != null) {
      return true;
    }

    if (_connectCompleter != null) {
      return _connectCompleter!.future;
    }

    _connectCompleter = Completer<bool>();

    try {
      if (forceReconnect) {
        _client?.close();
        _client = null;
        _connected = false;
      }

      for (int i = 0; i < 3; i++) {
        try {
          _client?.close();
          _client = RouterOSClient(
            host: host,
            user: username,
            password: password,
          );

          await _client!.connect().timeout(_connectTimeout);

          _connected = true;
          if (!_connectCompleter!.isCompleted) {
            _connectCompleter!.complete(true);
          }
          return true;
        } catch (_) {
          _connected = false;
          await Future.delayed(Duration(seconds: i + 1));
        }
      }

      _client?.close();
      _client = null;
      _connected = false;

      if (!_connectCompleter!.isCompleted) {
        _connectCompleter!.complete(false);
      }
      return false;
    } catch (e) {
      _connected = false;
      _client?.close();
      _client = null;

      if (!_connectCompleter!.isCompleted) {
        _connectCompleter!.completeError(e);
      }
      return false;
    } finally {
      _connectCompleter = null;
    }
  }

  Future<void> _ensureConnected() async {
    if (_connected && _client != null) return;

    final ok = await connect();
    if (!ok || _client == null) {
      throw Exception('Not connected');
    }
  }

  // ==================== معالجة الردود ====================
  List<Map<String, dynamic>> _normalizeResponse(dynamic response) {
    if (response is List) {
      return response.map((row) {
        if (row is Map<String, dynamic>) {
          return Map<String, dynamic>.from(row);
        }
        if (row is Map) {
          return row.map((key, value) => MapEntry(key.toString(), value));
        }
        return <String, dynamic>{'value': row.toString()};
      }).toList();
    }

    if (response is Map) {
      return [
        response.map((key, value) => MapEntry(key.toString(), value)),
      ];
    }

    return [];
  }

  // ==================== إرسال الأوامر ====================
  Future<List<Map<String, dynamic>>> sendCommand(
    String command, {
    Map<String, dynamic>? params,
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

    await _ensureConnected();

    for (int i = 0; i < 3; i++) {
      try {
        dynamic response;

        if (params == null || params.isEmpty) {
          response = await _client!.execute(command).timeout(_commandTimeout);
        } else {
          final sentence = <String>[
            command,
            ...params.entries.map((e) => '=${e.key}=${e.value}'),
          ];
          response = await _client!.talk(sentence).timeout(_commandTimeout);
        }

        final converted = _normalizeResponse(response);

        if (useCache) {
          _cache[cacheKey] = converted;
          _cacheTimestamps[cacheKey] = DateTime.now();
        }

        return converted;
      } catch (_) {
        _connected = false;

        if (i < 2) {
          await connect(forceReconnect: true);
          await Future.delayed(Duration(milliseconds: 300 * (i + 1)));
        }
      }
    }

    throw Exception('Failed after retries');
  }

  void clearCache() {
    _cache.clear();
    _cacheTimestamps.clear();
  }

  // ==================== دوال مساعدة للحصول على بيانات محددة ====================
  Future<Map<String, double>> getPortCurrentRate(String interfaceName) async {
    final result = await sendCommand(
      '/interface/monitor-traffic',
      params: {
        'interface': interfaceName,
        'once': '',
      },
      useCache: false,
    );

    if (result.isNotEmpty) {
      final row = result.first;

      final rxBits = double.tryParse(row['rx-bits-per-second']?.toString() ?? '') ?? 0;
      final txBits = double.tryParse(row['tx-bits-per-second']?.toString() ?? '') ?? 0;
      final totalBits = double.tryParse(row['bits-per-second']?.toString() ?? '') ?? 0;

      if (rxBits > 0 || txBits > 0) {
        return {
          'rx-bits-per-second': rxBits,
          'tx-bits-per-second': txBits,
        };
      }

      if (totalBits > 0) {
        return {
          'rx-bits-per-second': totalBits / 2,
          'tx-bits-per-second': totalBits / 2,
        };
      }
    }

    return {
      'rx-bits-per-second': 0,
      'tx-bits-per-second': 0,
    };
  }

  // ==================== ستريمات المراقبة ====================
  Stream<double> monitorTrafficStream(String interface) async* {
    while (_connected && _client != null) {
      try {
        final data = await getPortCurrentRate(interface);
        final totalMbps = ((data['rx-bits-per-second'] ?? 0) + (data['tx-bits-per-second'] ?? 0)) / 1000000;
        yield totalMbps;
      } catch (_) {
        yield 0;
      }
      await Future.delayed(const Duration(seconds: 1));
    }
  }

  Stream<Map<String, double>> monitorTrafficDetailsStream(String interface) async* {
    while (_connected && _client != null) {
      try {
        final data = await getPortCurrentRate(interface);
        yield data;
      } catch (_) {
        yield {
          'rx-bits-per-second': 0,
          'tx-bits-per-second': 0,
        };
      }
      await Future.delayed(const Duration(seconds: 1));
    }
  }

  // ==================== دوال جلب البيانات المختلفة ====================
  Future<List<Map<String, dynamic>>> getSystemHealth() =>
      sendCommand('/system/health/print', useCache: true);

  Future<List<Map<String, dynamic>>> getInterfaceList() =>
      sendCommand('/interface/print', useCache: true);

  Future<List<Map<String, dynamic>>> getSystemResource() =>
      sendCommand('/system/resource/print', useCache: true);

  Future<List<Map<String, dynamic>>> getHotspotActive() =>
      sendCommand('/ip/hotspot/active/print', useCache: true);

  Future<List<Map<String, dynamic>>> getHotspotUsers() =>
      sendCommand('/ip/hotspot/user/print', useCache: true);

  Future<List<Map<String, dynamic>>> getHotspotProfiles() =>
      sendCommand('/ip/hotspot/user/profile/print', useCache: true);

  Future<List<Map<String, dynamic>>> getPppActive() =>
      sendCommand('/ppp/active/print', useCache: true);

  Future<List<Map<String, dynamic>>> getPppSecrets() =>
      sendCommand('/ppp/secret/print', useCache: true);

  Future<List<Map<String, dynamic>>> getPppProfiles() =>
      sendCommand('/ppp/profile/print', useCache: true);

  Future<List<Map<String, dynamic>>> getSimpleQueue() =>
      sendCommand('/queue/simple/print', useCache: true);

  Future<List<Map<String, dynamic>>> getUserManagerUsers() =>
      sendCommand('/tool/user-manager/user/print', useCache: true);

  Future<List<Map<String, dynamic>>> getUserManagerSessions() =>
      sendCommand('/tool/user-manager/session/print', useCache: true);

  // ==================== الإنهاء ====================
  void disconnect() {
    _client?.close();
    _client = null;
    _connected = false;
    clearCache();
  }

  bool get isConnected => _connected;
}
