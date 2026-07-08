import 'dart:async';
import 'package:routeros_api/routeros_api.dart';

/// خدمة للتواصل مع جهاز RouterOS عبر واجهة API.
/// تدعم إعادة المحاولة، التخزين المؤقت، والمراقبة الفورية للحركة.
///
/// الإصلاحات المطبقة:
/// [FIX-1] تراكم الطلبات: كل طلب اتصال يُضاف إلى قائمة انتظار واحدة
/// [FIX-2] تسلسل الأوامر العادية فقط: Semaphore يمنع تراكم إعادة الاتصال
///         لكن traffic requests تبقى متوازية عبر قناة منفصلة
/// [FIX-3] إعادة الاتصال السريعة: backoff تدريجي 500ms→1s→2s
/// [FIX-4] Completer آمن: لا يمكن تسريب حالة خاطئة بعد الخطأ
/// [FIX-5] Cache مستقل: كاش دائم لا يُمسح مع clearCache()
/// [FIX-6] Streams تتوقف بشكل صحيح عند الانقطاع
/// [FIX-7] traffic مجمّع حقيقي: Completer مشترك يمنع الطلبات المتكررة
/// [FIX-A] _trafficFetchCompleter يعمل فعلاً (كان معرَّفاً لكن غير مُستخدَم)
/// [FIX-B] traffic لا يمر عبر Semaphore العادي لتبقى متوازية
/// [FIX-C] إعادة الاتصال تحرر القفل أولاً لتجنب الـ Deadlock

class RouterService {
  final String host;
  final int port;
  final String username;
  final String password;

  bool _connected = false;
  RouterOSClient? _client;

  // [FIX-1] قائمة انتظار الاتصال: جميع الطلبات المتزامنة تنتظر completer واحد
  Completer<bool>? _connectCompleter;

  // [FIX-2] Semaphore للأوامر العادية فقط (ليس traffic)
  bool _commandLocked = false;
  final List<Completer<void>> _commandQueue = [];

  final Map<String, dynamic> _cache = {};
  final Map<String, DateTime> _cacheTimestamps = {};

  // [FIX-5] كاش منفصل لا يُمسح مع clearCache()
  final Map<String, dynamic> _persistentCache = {};
  final Map<String, DateTime> _persistentCacheTimestamps = {};

  static const Duration _cacheDuration = Duration(seconds: 120);

  // [FIX-3] timeouts محسّنة
  static const Duration _connectTimeout = Duration(seconds: 5);
  static const Duration _commandTimeout = Duration(seconds: 12);
  static const Duration _trafficTimeout = Duration(seconds: 4);

  // [FIX-7 + FIX-A] كاش traffic مع Completer حقيقي يمنع الطلبات المتكررة
  final Map<String, Map<String, double>> _trafficCache = {};
  DateTime? _trafficCacheTime;
  static const Duration _trafficCacheDuration = Duration(milliseconds: 900);

  // [FIX-A] الـ Completer الآن يُستخدَم فعلاً لمنع طلبات traffic المتزامنة
  // على نفس الواجهة من التكرار
  final Map<String, Completer<Map<String, double>>> _trafficFetchCompleters =
      {};

  RouterService({
    required this.host,
    this.port = 8728,
    required this.username,
    required this.password,
  });

  // ==================== الاتصال ====================

  /// [FIX-1 + FIX-3 + FIX-4]
  /// - جميع الطلبات المتزامنة تنتظر نفس الـ completer
  /// - backoff تدريجي: 500ms → 1s → 2s
  /// - الـ completer يُصفَّر بأمان عبر مرجع محلي
  Future<bool> connect({bool forceReconnect = false}) async {
    if (!forceReconnect && _connected && _client != null) {
      return true;
    }

    // [FIX-1] إذا يوجد اتصال جارٍ، انتظره
    if (_connectCompleter != null) {
      return _connectCompleter!.future;
    }

    _connectCompleter = Completer<bool>();
    // [FIX-4] مرجع محلي لتجنب null race في finally
    final localCompleter = _connectCompleter!;

    try {
      if (forceReconnect) {
        _safeCloseClient();
      }

      // [FIX-3] backoff تدريجي
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
      // [FIX-4] complete(false) بدلاً من completeError لتجنب unhandled exceptions
      if (!localCompleter.isCompleted) {
        localCompleter.complete(false);
      }
      return false;
    } finally {
      // [FIX-4] نصفّر فقط إذا كان المرجع لا يزال نفس الـ completer
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

  // ==================== Semaphore للأوامر العادية ====================

  /// [FIX-2] يمنع تراكم الأوامر العادية التي قد تُسبب تنافساً على إعادة الاتصال
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

  // [FIX-B] Semaphore منفصل للـ traffic بحد أقصى 5 طلبات متزامنة
  // بدلاً من تسلسل كامل أو فوضى كاملة
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

  // ==================== إرسال الأوامر الأساسي ====================

  /// إرسال أمر عادي إلى RouterOS مع Semaphore وإعادة المحاولة والكاش.
  /// - [usePost] محجوز للتوافق مع الإصدارات السابقة (لا يُستخدم حالياً).
  /// - [persistent] إذا كان true، يستخدم كاش لا يُمسح بـ clearCache()
  Future<List<Map<String, dynamic>>> sendCommand(
    String command, {
    Map<String, dynamic>? params,
    bool usePost = false, // محجوز للتوافق مع side_drawer وغيره
    bool useCache = false,
    bool persistent = false, // [FIX-5]
  }) async {
    final cacheKey = '$command${params?.toString() ?? ''}';

    // [FIX-5] اختيار الكاش المناسب
    final activeCache = persistent ? _persistentCache : _cache;
    final activeCacheTimestamps =
        persistent ? _persistentCacheTimestamps : _cacheTimestamps;

    // تحقق من الكاش قبل الحصول على القفل
    if (useCache &&
        activeCache.containsKey(cacheKey) &&
        activeCacheTimestamps.containsKey(cacheKey)) {
      final age = DateTime.now().difference(activeCacheTimestamps[cacheKey]!);
      if (age < _cacheDuration) {
        return activeCache[cacheKey] as List<Map<String, dynamic>>;
      }
    }

    // [FIX-2] انتظر دورك
    await _acquireLock();

    try {
      await _ensureConnected();

      for (int i = 0; i < 3; i++) {
        try {
          dynamic response;

          if (params == null || params.isEmpty) {
            response =
                await _client!.execute(command).timeout(_commandTimeout);
          } else {
            final sentence = <String>[
              command,
              ...params.entries.map((e) => '=${e.key}=${e.value}'),
            ];
            response =
                await _client!.talk(sentence).timeout(_commandTimeout);
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
            // [FIX-C] نحرر القفل أثناء إعادة الاتصال لتجنب الـ Deadlock
            _releaseLock();
            await connect(forceReconnect: true);
            await Future.delayed(Duration(milliseconds: 300 * (i + 1)));
            // نستعيد القفل بعد إعادة الاتصال
            await _acquireLock();
          }
        }
      }

      throw Exception('Failed after retries: $command');
    } finally {
      // [FIX-2] تحرير القفل دائماً
      _releaseLock();
    }
  }

  /// [FIX-B] إرسال أمر traffic مباشرةً بدون Semaphore عام
  /// يستخدم Semaphore منفصل بحد أقصى 5 طلبات متزامنة
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

      final response =
          await _client!.talk(sentence).timeout(_trafficTimeout);

      return _normalizeResponse(response);
    } catch (_) {
      return [];
    } finally {
      _releaseTrafficSlot();
    }
  }

  /// مسح الكاش العادي فقط (لا يمس الكاش الدائم).
  void clearCache() {
    _cache.clear();
    _cacheTimestamps.clear();
    _trafficCache.clear();
    _trafficCacheTime = null;
    // مسح أي traffic completers معلقة
    _trafficFetchCompleters.clear();
  }

  /// مسح الكاش الدائم أيضاً (عند تسجيل الخروج أو تغيير الراوتر).
  void clearAllCache() {
    clearCache();
    _persistentCache.clear();
    _persistentCacheTimestamps.clear();
  }

  // ==================== دوال مساعدة ====================

  /// [FIX-7 + FIX-A] جلب بيانات traffic لواجهة واحدة
  /// - كاش مشترك صالح 900ms
  /// - [FIX-A] Completer حقيقي يمنع الطلبات المتزامنة على نفس الواجهة
  /// - [FIX-B] لا يمر عبر Semaphore العام لتبقى التجميعات متوازية
  Future<Map<String, double>> getPortCurrentRate(String interfaceName) async {
    // [FIX-A] إذا يوجد طلب جارٍ لنفس الواجهة، انتظر نتيجته
    final existingCompleter = _trafficFetchCompleters[interfaceName];
    if (existingCompleter != null) {
      return existingCompleter.future;
    }

    // تحقق من الكاش أولاً
    final now = DateTime.now();
    if (_trafficCacheTime != null &&
        now.difference(_trafficCacheTime!) < _trafficCacheDuration &&
        _trafficCache.containsKey(interfaceName)) {
      return _trafficCache[interfaceName]!;
    }

    // [FIX-A] أنشئ completer حقيقي يمنع الطلبات المتزامنة على نفس الواجهة
    final completer = Completer<Map<String, double>>();
    _trafficFetchCompleters[interfaceName] = completer;

    try {
      // [FIX-B] استخدم _sendTrafficCommand بدلاً من sendCommand
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

      // حفظ في الكاش
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
      // [FIX-A] أزل الـ completer بعد الانتهاء
      _trafficFetchCompleters.remove(interfaceName);
    }
  }

  /// [FIX-7] جلب traffic لقائمة واجهات دفعةً
  /// دفعات من 5 طلبات متوازية بدلاً من 100 معاً أو 100 متسلسلة
  Future<Map<String, Map<String, double>>> getBulkTraffic(
    List<String> interfaceNames,
  ) async {
    if (interfaceNames.isEmpty) return {};

    // تحقق من الكاش أولاً
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

    // [FIX-B] دفعات بحجم _maxConcurrentTraffic للتوازي المحكوم
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

  // ==================== ستريمات المراقبة ====================

  /// [FIX-6] ستريم يبث إجمالي الاستخدام (Mbps) كل ثانية.
  /// يتحقق من الاتصال في كل دورة وليس مرة واحدة فقط.
  Stream<double> monitorTrafficStream(String interface) async* {
    while (true) {
      // [FIX-6] التحقق في كل دورة
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

  /// [FIX-6] ستريم يبث تفاصيل RX/TX كل ثانية.
  /// يتحقق من الاتصال في كل دورة.
  Stream<Map<String, double>> monitorTrafficDetailsStream(
      String interface) async* {
    while (true) {
      // [FIX-6] التحقق في كل دورة
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

  // ==================== إنهاء الخدمة ====================

  void disconnect() {
    _safeCloseClient();
    _connected = false;
    // تنظيف قوائم الانتظار
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
