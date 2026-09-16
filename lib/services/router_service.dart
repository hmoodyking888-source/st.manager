import 'dart:async';
import 'package:routeros_api/routeros_api.dart';

/// خدمة للتواصل مع جهاز RouterOS عبر واجهة API.
class RouterService {
  final String host;
  final int port;
  final String username;
  final String password;

  bool _connected = false;
  RouterOSClient? _client;

  Completer<bool>? _connectCompleter;

  bool _commandLocked = false;
  final List<Completer<void>> _commandQueue = [];

  final Map<String, dynamic> _cache = {};
  final Map<String, DateTime> _cacheTimestamps = {};

  final Map<String, dynamic> _persistentCache = {};
  final Map<String, DateTime> _persistentCacheTimestamps = {};

  static const Duration _cacheDuration = Duration(seconds: 120);

  static const Duration _connectTimeout = Duration(seconds: 5);
  static const Duration _commandTimeout = Duration(seconds: 12);
  static const Duration _trafficTimeout = Duration(seconds: 4);

  final Map<String, Map<String, double>> _trafficCache = {};
  DateTime? _trafficCacheTime;
  static const Duration _trafficCacheDuration = Duration(milliseconds: 900);

  final Map<String, Completer<Map<String, double>>> _trafficFetchCompleters =
      {};

  RouterService({
    required this.host,
    this.port = 8728,
    required this.username,
    required this.password,
  });

  Future<bool> connect({bool forceReconnect = false}) async {
    if (!forceReconnect && _connected && _client != null) {
      return true;
    }

    if (_connectCompleter != null) {
      return _connectCompleter!.future;
    }

    _connectCompleter = Completer<bool>();
    final localCompleter = _connectCompleter!;

    try {
      if (forceReconnect) {
        _safeCloseClient();
      }

      const delays = [500, 1000, 2000];

      for (int i = 0; i < 3; i++) {
        try {
          _safeCloseClient();

          _client = RouterOSClient(
            host: host,
            user: username,
            password: password,
          );

          await _client!.connect().timeout(_connectTimeout);

          _connected = true;
          if (!localCompleter.isCompleted) {
            localCompleter.complete(true);
          }
          return true;
        } catch (_) {
          _connected = false;
          _safeCloseClient();

          if (i < 2) {
            await Future.delayed(Duration(milliseconds: delays[i]));
          }
        }
      }

      _connected = false;
      if (!localCompleter.isCompleted) {
        localCompleter.complete(false);
      }
      return false;
    } catch (e) {
      _connected = false;
      _safeCloseClient();
      if (!localCompleter.isCompleted) {
        localCompleter.complete(false);
      }
      return false;
    } finally {
      if (_connectCompleter == localCompleter) {
        _connectCompleter = null;
      }
    }
  }

  void _safeCloseClient() {
    try {
      _client?.close();
    } catch (_) {}
    _client = null;
  }

  Future<void> _ensureConnected() async {
    if (_connected && _client != null) return;
    final ok = await connect();
    if (!ok || _client == null) {
      throw Exception('Not connected to $host');
    }
  }

  Future<void> _acquireLock() async {
    if (!_commandLocked) {
      _commandLocked = true;
      return;
    }
    final completer = Completer<void>();
    _commandQueue.add(completer);
    await completer.future;
  }

  void _releaseLock() {
    if (_commandQueue.isNotEmpty) {
      final next = _commandQueue.removeAt(0);
      if (!next.isCompleted) next.complete();
    } else {
      _commandLocked = false;
    }
  }

  static const int _maxConcurrentTraffic = 5;
  int _activeTrafficRequests = 0;
  final List<Completer<void>> _trafficWaitQueue = [];

  Future<void> _acquireTrafficSlot() async {
    if (_activeTrafficRequests < _maxConcurrentTraffic) {
      _activeTrafficRequests++;
      return;
    }
    final completer = Completer<void>();
    _trafficWaitQueue.add(completer);
    await completer.future;
    _activeTrafficRequests++;
  }

  void _releaseTrafficSlot() {
    _activeTrafficRequests--;
    if (_trafficWaitQueue.isNotEmpty) {
      final next = _trafficWaitQueue.removeAt(0);
      if (!next.isCompleted) next.complete();
    }
  }

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

  Future<List<Map<String, dynamic>>> sendCommand(
    String command, {
    Map<String, dynamic>? params,
    bool usePost = false,
    bool useCache = false,
    bool persistent = false,
  }) async {
    final cacheKey = '$command${params?.toString() ?? ''}';

    final activeCache = persistent ? _persistentCache : _cache;
    final activeCacheTimestamps =
        persistent ? _persistentCacheTimestamps : _cacheTimestamps;

    if (useCache &&
        activeCache.containsKey(cacheKey) &&
        activeCacheTimestamps.containsKey(cacheKey)) {
      final age = DateTime.now().difference(activeCacheTimestamps[cacheKey]!);
      if (age < _cacheDuration) {
        return activeCache[cacheKey] as List<Map<String, dynamic>>;
      }
    }

    await _acquireLock();

    try {
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
            activeCache[cacheKey] = converted;
            activeCacheTimestamps[cacheKey] = DateTime.now();
          }

          return converted;
        } catch (_) {
          _connected = false;

          if (i < 2) {
            _releaseLock();
            await connect(forceReconnect: true);
            await Future.delayed(Duration(milliseconds: 300 * (i + 1)));
            await _acquireLock();
          }
        }
      }

      throw Exception('Failed after retries: $command');
    } finally {
      _releaseLock();
    }
  }

  Future<List<Map<String, dynamic>>> _sendTrafficCommand(
    String command,
    Map<String, dynamic> params,
  ) async {
    await _acquireTrafficSlot();

    try {
      await _ensureConnected();

      final sentence = <String>[
        command,
        ...params.entries.map((e) => '=${e.key}=${e.value}'),
      ];

      final response = await _client!.talk(sentence).timeout(_trafficTimeout);

      return _normalizeResponse(response);
    } catch (_) {
      return [];
    } finally {
      _releaseTrafficSlot();
    }
  }

  void clearCache() {
    _cache.clear();
    _cacheTimestamps.clear();
    _trafficCache.clear();
    _trafficCacheTime = null;
    _trafficFetchCompleters.clear();
  }

  void clearAllCache() {
    clearCache();
    _persistentCache.clear();
    _persistentCacheTimestamps.clear();
  }

  Future<Map<String, double>> getPortCurrentRate(String interfaceName) async {
    final existingCompleter = _trafficFetchCompleters[interfaceName];
    if (existingCompleter != null) {
      return existingCompleter.future;
    }

    final now = DateTime.now();
    if (_trafficCacheTime != null &&
        now.difference(_trafficCacheTime!) < _trafficCacheDuration &&
        _trafficCache.containsKey(interfaceName)) {
      return _trafficCache[interfaceName]!;
    }

    final completer = Completer<Map<String, double>>();
    _trafficFetchCompleters[interfaceName] = completer;

    try {
      final result = await _sendTrafficCommand(
        '/interface/monitor-traffic',
        {
          'interface': interfaceName,
          'once': '',
        },
      );

      final Map<String, double> trafficData;

      if (result.isNotEmpty) {
        final row = result.first;

        final rxBits =
            double.tryParse(row['rx-bits-per-second']?.toString() ?? '') ?? 0;
        final txBits =
            double.tryParse(row['tx-bits-per-second']?.toString() ?? '') ?? 0;
        final totalBits =
            double.tryParse(row['bits-per-second']?.toString() ?? '') ?? 0;

        if (rxBits > 0 || txBits > 0) {
          trafficData = {
            'rx-bits-per-second': rxBits,
            'tx-bits-per-second': txBits,
          };
        } else if (totalBits > 0) {
          trafficData = {
            'rx-bits-per-second': totalBits / 2,
            'tx-bits-per-second': totalBits / 2,
          };
        } else {
          trafficData = {
            'rx-bits-per-second': 0,
            'tx-bits-per-second': 0,
          };
        }
      } else {
        trafficData = {
          'rx-bits-per-second': 0,
          'tx-bits-per-second': 0,
        };
      }

      _trafficCache[interfaceName] = trafficData;
      _trafficCacheTime = now;

      if (!completer.isCompleted) completer.complete(trafficData);
      return trafficData;
    } catch (_) {
      const empty = {
        'rx-bits-per-second': 0.0,
        'tx-bits-per-second': 0.0,
      };
      if (!completer.isCompleted) completer.complete(empty);
      return empty;
    } finally {
      _trafficFetchCompleters.remove(interfaceName);
    }
  }

  Future<Map<String, Map<String, double>>> getBulkTraffic(
    List<String> interfaceNames,
  ) async {
    if (interfaceNames.isEmpty) return {};

    final now = DateTime.now();
    if (_trafficCacheTime != null &&
        now.difference(_trafficCacheTime!) < _trafficCacheDuration) {
      final cached = <String, Map<String, double>>{};
      bool allCached = true;
      for (final name in interfaceNames) {
        if (_trafficCache.containsKey(name)) {
          cached[name] = _trafficCache[name]!;
        } else {
          allCached = false;
          break;
        }
      }
      if (allCached) return cached;
    }

    final results = <String, Map<String, double>>{};
    const batchSize = _maxConcurrentTraffic;

    for (int i = 0; i < interfaceNames.length; i += batchSize) {
      final batch = interfaceNames.sublist(
        i,
        (i + batchSize).clamp(0, interfaceNames.length),
      );

      final batchResults = await Future.wait(
        batch.map((name) async {
          final data = await getPortCurrentRate(name);
          return MapEntry(name, data);
        }),
      );

      for (final entry in batchResults) {
        results[entry.key] = entry.value;
      }
    }

    return results;
  }

  Stream<double> monitorTrafficStream(String interface) async* {
    while (true) {
      if (!_connected || _client == null) {
        yield 0;
        await Future.delayed(const Duration(seconds: 2));
        continue;
      }

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

  Stream<Map<String, double>> monitorTrafficDetailsStream(
      String interface) async* {
    while (true) {
      if (!_connected || _client == null) {
        yield {'rx-bits-per-second': 0, 'tx-bits-per-second': 0};
        await Future.delayed(const Duration(seconds: 2));
        continue;
      }

      try {
        final data = await getPortCurrentRate(interface);
        yield data;
      } catch (_) {
        yield {'rx-bits-per-second': 0, 'tx-bits-per-second': 0};
      }
      await Future.delayed(const Duration(seconds: 1));
    }
  }

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

  void disconnect() {
    _safeCloseClient();
    _connected = false;

    for (final c in _commandQueue) {
      if (!c.isCompleted) c.completeError(Exception('Disconnected'));
    }
    _commandQueue.clear();
    _commandLocked = false;

    for (final c in _trafficWaitQueue) {
      if (!c.isCompleted) c.completeError(Exception('Disconnected'));
    }
    _trafficWaitQueue.clear();
    _activeTrafficRequests = 0;

    for (final c in _trafficFetchCompleters.values) {
      if (!c.isCompleted) {
        c.complete({'rx-bits-per-second': 0.0, 'tx-bits-per-second': 0.0});
      }
    }
    _trafficFetchCompleters.clear();

    clearAllCache();
  }

  bool get isConnected => _connected;
}
