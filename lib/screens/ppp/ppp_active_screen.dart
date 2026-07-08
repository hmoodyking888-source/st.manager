import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:st_manager/screens/ppp/ppp_user_screen.dart';
import 'package:st_manager/services/router_service.dart';
import 'package:st_manager/services/secure_storage_service.dart';
import 'package:st_manager/theme/app_theme.dart';
import 'package:url_launcher/url_launcher.dart';

// ---------- فئة مساعدة ----------
class _CommentData {
  final String phone;
  final String note;
  final DateTime? expiryDate;
  final bool isPaid;
  const _CommentData({
    required this.phone,
    required this.note,
    required this.expiryDate,
    this.isPaid = false,
  });
}

// ---------- الشاشة الرئيسية ----------
class PppActiveScreen extends StatefulWidget {
  final RouterService? routerService;
  const PppActiveScreen({super.key, required this.routerService});

  @override
  State<PppActiveScreen> createState() => _PppActiveScreenState();
}

class _PppActiveScreenState extends State<PppActiveScreen> {
  static const String _expiredProfileName = 'Xpirer';
  static const String _expiredRateLimit = '512K/512K';
  static const String _expirationCheckKey = 'ppp_last_expiration_check';

  // === مهل زمنية للشبكة (تم إضافتها) ===
  // بدون هذه المهل، أي عدم استجابة من الراوتر كانت تُبقي الشاشة عالقة على
  // "جاري التحميل..." إلى الأبد، لأن الكود كان ينتظر (await) بلا حد زمني،
  // ولأن _isLoading تبقى true فلا يستطيع زر التحديث ولا المؤقت الدوري
  // إعادة المحاولة. الآن أي طلب متعثر سينتهي بخطأ واضح خلال مهلة معقولة
  // بدل التعليق الأبدي.
  static const Duration _dataFetchTimeout = Duration(seconds: 20);
  static const Duration _actionTimeout = Duration(seconds: 12);
  static const Duration _trafficTimeout = Duration(seconds: 8);

  final SecureStorageService _storage = SecureStorageService();

  // البيانات الأساسية (تُعرض فوراً)
  List<Map<String, dynamic>> _accounts = [];
  bool _loading = false;
  bool _initialLoadDone = false;

  // متغيرات البحث والفرز والتصفية
  String _searchQuery = '';
  String _sortBy = 'status';
  String _filter = 'all';
  bool _showRxFirst = true;

  // التحكم بالتحديث والخلفية
  Timer? _refreshTimer;
  bool _isLoading = false;
  bool _isFetchingTraffic = false; // يمنع تراكم طلبات جلب السرعات فوق بعضها
  String? _lastExpirationCheckIso;
  Map<String, Map<String, double>> _trafficCache = {};

  // ==================== دورة الحياة ====================
  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    _lastExpirationCheckIso = await _storage.read(_expirationCheckKey);
    await _load(initial: true);
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 10), // تقليل التحديث لتقليل الضغط
      (_) => _load(background: true),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  // ==================== دوال مساعدة عامة ====================
  String _normalizeText(dynamic value) => value?.toString().trim() ?? '';
  double _toDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }

  bool _isDisabled(Map<String, dynamic> user) {
    final raw = user['disabled'];
    if (raw == null) return false;
    final v = raw.toString().toLowerCase().trim();
    return v == 'true' || v == 'yes' || v == '1' || v == 'on';
  }

  bool _isExpired(DateTime? expiryDate) {
    if (expiryDate == null) return false;
    final end = DateTime(expiryDate.year, expiryDate.month, expiryDate.day, 23, 59, 59);
    return DateTime.now().isAfter(end);
  }

  String _dateOnlyString(DateTime date) => DateFormat('yyyy-MM-dd').format(date);

  // ==================== معالجة التعليق ====================
  _CommentData _parseComment(String raw) {
    if (raw.trim().isEmpty) {
      return const _CommentData(phone: '', note: '', expiryDate: null, isPaid: false);
    }
    String phone = '';
    DateTime? expiryDate;
    bool isPaid = false;
    final notes = <String>[];
    for (final part in raw.split('|')) {
      final token = part.trim();
      if (token.isEmpty) continue;
      if (token.toLowerCase().startsWith('phone:')) {
        phone = token.substring(6).trim();
      } else if (token.toLowerCase().startsWith('exp:')) {
        final parsed = DateTime.tryParse(token.substring(4).trim());
        if (parsed != null) expiryDate = parsed;
      } else if (token.toLowerCase().startsWith('paid:')) {
        final val = token.substring(5).trim().toLowerCase();
        isPaid = val == 'true' || val == 'yes' || val == '1' || val == 'on';
      } else {
        notes.add(token);
      }
    }
    return _CommentData(
      phone: phone,
      note: notes.join(' | '),
      expiryDate: expiryDate,
      isPaid: isPaid,
    );
  }

  String _buildComment(_CommentData data, {bool? paidOverride}) {
    final parts = <String>[];
    if (data.phone.trim().isNotEmpty) parts.add('phone:${data.phone.trim()}');
    if (data.expiryDate != null) parts.add('exp:${_dateOnlyString(data.expiryDate!)}');
    parts.add('paid:${(paidOverride ?? data.isPaid) ? 'true' : 'false'}');
    if (data.note.trim().isNotEmpty) parts.add(data.note.trim());
    return parts.join(' | ');
  }

  // ==================== مفاتيح الجلسات ====================
  String _sessionKey(Map<String, dynamic> item) {
    for (final key in ['.id', 'name', 'user', 'username', 'caller-id', 'address']) {
      final v = _normalizeText(item[key]);
      if (v.isNotEmpty) return v;
    }
    return 'session-${item.hashCode}';
  }

  List<String> _candidateKeys(Map<String, dynamic> item) {
    return ['name', 'user', 'username', 'caller-id', 'address']
        .map((k) => _normalizeText(item[k]).toLowerCase())
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList();
  }

  Map<String, Map<String, dynamic>> _buildActiveBySession(List<Map<String, dynamic>> active) {
    final map = <String, Map<String, dynamic>>{};
    for (final a in active) {
      map[_sessionKey(a)] = a;
    }
    return map;
  }

  String? _matchActiveSessionKey(Map<String, dynamic> secret, Map<String, Map<String, dynamic>> activeBySession) {
    final secretKeys = _candidateKeys(secret);
    for (final entry in activeBySession.entries) {
      final activeKeys = _candidateKeys(entry.value);
      for (final key in secretKeys) {
        if (activeKeys.contains(key)) return entry.key;
      }
    }
    return null;
  }

  // ==================== قواعد الانتهاء ====================
  Future<bool> _shouldRunExpirationCheck() async {
    final now = DateTime.now();
    final todayNoon = DateTime(now.year, now.month, now.day, 12);
    if (now.isBefore(todayNoon)) return false;
    if (_lastExpirationCheckIso != null) {
      final last = DateTime.tryParse(_lastExpirationCheckIso!);
      if (last != null && last.year == now.year && last.month == now.month && last.day == now.day) {
        return false;
      }
    }
    // (تم إصلاح خطأ سابق هنا): لم نعد نُسجّل وقت الفحص فوراً هنا، بل بعد نجاح
    // تطبيق قواعد الانتهاء فعلياً عبر _markExpirationCheckDone بالأسفل.
    // سابقاً كان التسجيل يحدث هنا قبل التنفيذ الفعلي، فإذا فشلت العملية في
    // منتصف الطريق (انقطاع اتصال بالراوتر مثلاً) كان النظام يعتبر الفحص
    // "منتهياً" لهذا اليوم ويتجاهل بقية الحسابات المنتهية حتى اليوم التالي.
    return true;
  }

  Future<void> _markExpirationCheckDone() async {
    final now = DateTime.now();
    _lastExpirationCheckIso = now.toIso8601String();
    await _storage.write(_expirationCheckKey, _lastExpirationCheckIso!);
  }

  Future<void> _ensureExpiredProfile() async {
    if (widget.routerService == null) return;
    final profiles = await widget.routerService!
        .sendCommand('/ppp/profile/print', useCache: false)
        .timeout(_actionTimeout);
    final existing = profiles.where((p) => _normalizeText(p['name']).toLowerCase() == _expiredProfileName.toLowerCase());
    if (existing.isEmpty) {
      await widget.routerService!.sendCommand(
        '/ppp/profile/add',
        params: {'name': _expiredProfileName, 'rate-limit': _expiredRateLimit, 'only-one': 'no', 'change-tcp-mss': 'yes'},
      ).timeout(_actionTimeout);
    } else {
      final id = _normalizeText(existing.first['.id']);
      if (id.isNotEmpty) {
        await widget.routerService!.sendCommand(
          '/ppp/profile/set',
          params: {'numbers': id, 'rate-limit': _expiredRateLimit},
        ).timeout(_actionTimeout);
      }
    }
  }

  Future<bool> _applyExpirationRules(
    List<Map<String, dynamic>> secrets,
    Map<String, Map<String, dynamic>> activeBySession,
  ) async {
    if (widget.routerService == null) return true;

    try {
      await _ensureExpiredProfile();
    } catch (_) {
      return false; // لا فائدة من المتابعة إن تعذّر تجهيز بروفايل "Xpirer"
    }

    final expiredSecrets = secrets.where((secret) {
      final parsed = _parseComment(secret['comment']?.toString() ?? '');
      return parsed.expiryDate != null && _isExpired(parsed.expiryDate);
    }).toList();

    if (expiredSecrets.isEmpty) return true;

    bool allSucceeded = true;

    // (تم إصلاح خطأ سابق هنا): كانت هذه المعالجة تتم لكل حساب منتهٍ على حدة
    // بالتوالي (await داخل for)، فإذا كان هناك عشرات الحسابات المنتهية في
    // نفس اليوم كانت عملية التحميل بأكملها تتجمّد لثوانٍ أو حتى دقائق.
    // الآن تُعالَج كل الحسابات بالتوازي عبر Future.wait، وأي فشل في حساب
    // واحد لا يوقف معالجة البقية.
    await Future.wait(expiredSecrets.map((secret) async {
      try {
        final secretId = _normalizeText(secret['.id']);
        if (secretId.isNotEmpty && _normalizeText(secret['profile']).toLowerCase() != _expiredProfileName.toLowerCase()) {
          await widget.routerService!.sendCommand(
            '/ppp/secret/set',
            params: {'numbers': secretId, 'profile': _expiredProfileName},
          ).timeout(_actionTimeout);
          secret['profile'] = _expiredProfileName;
        }
        final sessionKey = _matchActiveSessionKey(secret, activeBySession);
        if (sessionKey != null) {
          final activeEntry = activeBySession[sessionKey];
          final activeId = _normalizeText(activeEntry?['.id']);
          if (activeId.isNotEmpty) {
            await widget.routerService!.sendCommand(
              '/ppp/active/remove',
              params: {'numbers': activeId},
            ).timeout(_actionTimeout);
            activeBySession.remove(sessionKey);
          }
        }
      } catch (_) {
        allSucceeded = false;
      }
    }));

    return allSucceeded;
  }

  // ==================== جلب السرعات (محسّن) ====================
  Future<Map<String, double>> _getSessionTraffic(String interface) async {
    if (widget.routerService == null) return {'rx': 0, 'tx': 0};
    try {
      final result = await widget.routerService!.sendCommand(
        '/interface/monitor-traffic',
        params: {'interface': interface, 'once': ''},
        useCache: false,
      ).timeout(_trafficTimeout);
      if (result.isNotEmpty) {
        final row = result.first;
        final rx = double.tryParse(row['rx-bits-per-second']?.toString() ?? '') ?? 0;
        final tx = double.tryParse(row['tx-bits-per-second']?.toString() ?? '') ?? 0;
        return {'rx': rx / 1000000, 'tx': tx / 1000000}; // بالميغابت
      }
    } catch (_) {}
    return {'rx': 0, 'tx': 0};
  }

  Future<void> _fetchTrafficInBackground(List<Map<String, dynamic>> activeList) async {
    if (activeList.isEmpty) return;
    // (تم إصلاح خطأ سابق هنا): كان جلب السرعات يتم بالتوالي (await داخل for)
    // لكل جلسة نشطة، فمع 20-30 مستخدماً متصلاً كانت السرعات تستغرق عشرات
    // الثواني لتظهر. كذلك كانت هذه الدالة تُستدعى فقط عندما background=false
    // بينما زر التحديث والمؤقت الدوري كلاهما يستدعيان _load(background: true)
    // — أي أن السرعات كانت تُجلب مرة واحدة فقط عند فتح الشاشة ثم تتجمّد ولا
    // تتحدث أبداً بعد ذلك. الآن تُجلب في كل دورة تحديث، وبالتوازي.
    if (_isFetchingTraffic) return; // نمنع تراكم الطلبات إن لم تنتهِ الدورة السابقة
    _isFetchingTraffic = true;
    try {
      await Future.wait(activeList.map((active) async {
        final interface = _buildTrafficInterfaceName(active);
        if (interface.isEmpty) return;
        final traffic = await _getSessionTraffic(interface);
        final key = _sessionKey(active);
        _trafficCache[key] = traffic;
        // تحديث القائمة المعروضة بشكل تدريجي
        if (mounted) {
          setState(() {
            // نبحث عن الحساب المطابق ونحدث سرعاته
            final index = _accounts.indexWhere((acc) => acc['session-key'] == key);
            if (index != -1) {
              _accounts[index] = {
                ..._accounts[index],
                'rx-speed': traffic['rx'] ?? 0,
                'tx-speed': traffic['tx'] ?? 0,
                'speed-mbps': (traffic['rx'] ?? 0) + (traffic['tx'] ?? 0),
              };
            }
          });
        }
      }));
    } finally {
      _isFetchingTraffic = false;
    }
  }

  String _buildTrafficInterfaceName(Map<String, dynamic> active) {
    final direct = _normalizeText(active['interface']);
    if (direct.isNotEmpty) return direct;
    final service = _normalizeText(active['service']).toLowerCase();
    final name = _normalizeText(active['name']);
    final user = _normalizeText(active['user']);
    final username = _normalizeText(active['username']);
    final base = name.isNotEmpty ? name : (user.isNotEmpty ? user : username);
    if (service.isNotEmpty && base.isNotEmpty) return '$service-$base';
    if (base.isNotEmpty) return 'pppoe-$base';
    return '';
  }

  // ==================== التحميل الأساسي (سريع) ====================
  Future<void> _load({bool initial = false, bool background = false}) async {
    if (_isLoading) return;
    if (widget.routerService == null) return;

    _isLoading = true;
    if (initial) setState(() => _loading = true);

    try {
      // جلب البيانات الأساسية (بدون سرعات)
      // (تم إصلاح خطأ سابق هنا): أضفنا timeout على كل طلب. بدونه، إن توقف
      // الراوتر عن الرد كانت الشاشة تبقى على "جاري التحميل" إلى الأبد بلا
      // أي فرصة لإعادة المحاولة (راجع شرح _isLoading أعلاه).
      final results = await Future.wait([
        widget.routerService!.sendCommand('/ppp/secret/print', useCache: false).timeout(_dataFetchTimeout),
        widget.routerService!.sendCommand('/ppp/active/print', useCache: false).timeout(_dataFetchTimeout),
      ]);

      final secrets = List<Map<String, dynamic>>.from(results[0]);
      var activeBySession = _buildActiveBySession(List<Map<String, dynamic>>.from(results[1]));

      // تطبيق قواعد الانتهاء (خلفية)
      if (await _shouldRunExpirationCheck()) {
        final expirationSucceeded = await _applyExpirationRules(secrets, activeBySession);
        // لا نُسجّل "تم الفحص اليوم" إلا عند النجاح الكامل، وإلا يُعاد
        // المحاولة في الدورة التالية (بعد 10 ثوانٍ) بدل تفويت اليوم كاملاً
        if (expirationSucceeded) {
          await _markExpirationCheckDone();
        }
      }

      // بناء قائمة الحسابات الأساسية (بدون سرعات)
      final accounts = _buildAccountList(secrets, activeBySession.values.toList());

      if (!mounted) return;
      setState(() {
        _accounts = accounts;
        _loading = false;
        _initialLoadDone = true;
      });

      // جلب السرعات في الخلفية (لا ننتظرها)
      // (تم إصلاح خطأ سابق هنا): كان الشرط "if (!background)" يمنع تحديث
      // السرعات في كل تحديث دوري وفي زر التحديث اليدوي أيضاً (لأن كليهما
      // يستدعيان _load مع background: true)، فتُجلب السرعات مرة واحدة فقط
      // عند فتح الشاشة ثم تتجمّد. الآن تُجلب في كل تحديث، وبالتوازي.
      _fetchTrafficInBackground(activeBySession.values.toList());
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل التحميل: $e'), backgroundColor: Colors.red),
        );
        setState(() => _loading = false);
      }
    } finally {
      _isLoading = false;
    }
  }

  // ==================== بناء القائمة ====================
  List<Map<String, dynamic>> _buildAccountList(
    List<Map<String, dynamic>> secrets,
    List<Map<String, dynamic>> activeList,
  ) {
    final activeBySession = _buildActiveBySession(activeList);

    return secrets.map((secret) {
      final sessionKey = _matchActiveSessionKey(secret, activeBySession);
      final activeEntry = sessionKey != null ? activeBySession[sessionKey] : null;
      final parsed = _parseComment(secret['comment']?.toString() ?? '');

      final isDisabled = _isDisabled(secret);
      final isExpired = _isExpired(parsed.expiryDate);
      final isActive = activeEntry != null;

      // سرعات افتراضية صفر (تُملأ لاحقاً)
      double rx = 0, tx = 0;
      if (activeEntry != null && _trafficCache.containsKey(sessionKey)) {
        final t = _trafficCache[sessionKey]!;
        rx = t['rx'] ?? 0;
        tx = t['tx'] ?? 0;
      }

      String status;
      if (isDisabled) status = 'disabled';
      else if (isExpired) status = 'expired';
      else if (isActive) status = 'active';
      else status = 'offline';

      final address = _normalizeText(activeEntry?['address']);
      final remote = _normalizeText(secret['remote-address']);
      final local = _normalizeText(secret['local-address']);
      final browserIp = address.isNotEmpty ? address : (remote.isNotEmpty ? remote : local);

      return {
        ...secret,
        'phone': parsed.phone,
        'note': parsed.note,
        'expiry-date': parsed.expiryDate,
        'expiry-label': parsed.expiryDate == null ? '' : _dateOnlyString(parsed.expiryDate!),
        'is-paid': parsed.isPaid,
        'active': isActive,
        'disabled': isDisabled,
        'expired': isExpired,
        'status': status,
        'active-id': _normalizeText(activeEntry?['.id']),
        'session-key': sessionKey ?? '',
        'rx-speed': rx,
        'tx-speed': tx,
        'speed-mbps': rx + tx,
        'uptime': _normalizeText(activeEntry?['uptime']),
        'uptime-seconds': _parseUptime(activeEntry?['uptime']),
        'browser-ip': browserIp,
      };
    }).toList();
  }

  int _parseUptime(dynamic uptime) {
    final str = _normalizeText(uptime);
    if (str.isEmpty) return 0;
    int total = 0;
    final reg = RegExp(r'(\d+)([wdhms])');
    for (final m in reg.allMatches(str.toLowerCase())) {
      final val = int.tryParse(m.group(1) ?? '0') ?? 0;
      final unit = m.group(2) ?? '';
      switch (unit) {
        case 'w': total += val * 7 * 24 * 3600; break;
        case 'd': total += val * 24 * 3600; break;
        case 'h': total += val * 3600; break;
        case 'm': total += val * 60; break;
        case 's': total += val; break;
      }
    }
    return total;
  }

  // ==================== الفرز والتصفية ====================
  List<Map<String, dynamic>> get filtered {
    var list = List<Map<String, dynamic>>.from(_accounts);
    // فرز
    switch (_sortBy) {
      case 'status':
        const order = {'active': 0, 'offline': 1, 'disabled': 2, 'expired': 3};
        list.sort((a, b) {
          final ao = order[a['status']] ?? 99;
          final bo = order[b['status']] ?? 99;
          if (ao != bo) return ao.compareTo(bo);
          return _normalizeText(a['name']).compareTo(_normalizeText(b['name']));
        });
        break;
      case 'name':
        list.sort((a, b) => _normalizeText(a['name']).compareTo(_normalizeText(b['name'])));
        break;
      case 'uptime':
        list.sort((a, b) {
          final aa = a['active'] == true;
          final ba = b['active'] == true;
          if (aa && !ba) return -1;
          if (!aa && ba) return 1;
          if (aa && ba) {
            final diff = (b['uptime-seconds'] ?? 0).compareTo(a['uptime-seconds'] ?? 0);
            if (diff != 0) return diff;
          }
          return _normalizeText(a['name']).compareTo(_normalizeText(b['name']));
        });
        break;
      case 'usage':
        list.sort((a, b) {
          final aa = a['active'] == true;
          final ba = b['active'] == true;
          if (aa && !ba) return -1;
          if (!aa && ba) return 1;
          if (aa && ba) {
            final at = _toDouble(a['rx-speed']) + _toDouble(a['tx-speed']);
            final bt = _toDouble(b['rx-speed']) + _toDouble(b['tx-speed']);
            if (bt != at) return bt.compareTo(at);
          }
          return _normalizeText(a['name']).compareTo(_normalizeText(b['name']));
        });
        break;
      case 'profile':
        list.sort((a, b) {
          final pc = _normalizeText(a['profile']).compareTo(_normalizeText(b['profile']));
          if (pc != 0) return pc;
          return _normalizeText(a['name']).compareTo(_normalizeText(b['name']));
        });
        break;
      default:
        list.sort((a, b) => _normalizeText(a['name']).compareTo(_normalizeText(b['name'])));
    }

    // تصفية
    switch (_filter) {
      case 'active':
        list = list.where((u) => u['status'] == 'active').toList();
        break;
      case 'offline':
        list = list.where((u) => u['status'] == 'offline').toList();
        break;
      case 'disabled':
        list = list.where((u) => u['status'] == 'disabled').toList();
        break;
      case 'expired':
        list = list.where((u) => u['status'] == 'expired').toList();
        break;
    }

    // بحث
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((u) {
        final s = [
          u['name'],
          u['phone'],
          u['note'],
          u['profile'],
          u['expiry-label'],
          u['status'],
          u['browser-ip']
        ].map((e) => e?.toString().toLowerCase() ?? '').join(' | ');
        return s.contains(q);
      }).toList();
    }

    return list;
  }

  int _countStatus(String filterType) {
    if (_accounts.isEmpty) return 0;
    if (filterType == 'all') return _accounts.length;
    return _accounts.where((u) => u['status'] == filterType).length;
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'active': return 'متصل';
      case 'offline': return 'غير متصل';
      case 'disabled': return 'معطل';
      case 'expired': return 'منتهي';
      default: return 'الكل';
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'active': return AppTheme.greenOnline;
      case 'expired': return Colors.orange;
      case 'disabled': return Colors.red;
      case 'offline': return Colors.blue;
      default: return AppTheme.gold;
    }
  }

  // ==================== إجراءات المستخدم ====================
  Future<void> _togglePaid(Map<String, dynamic> user) async {
    final id = _normalizeText(user['.id']);
    if (id.isEmpty) return;
    final parsed = _parseComment(user['comment']?.toString() ?? '');
    final newComment = _buildComment(parsed, paidOverride: !parsed.isPaid);
    try {
      await widget.routerService?.sendCommand(
        '/ppp/secret/set',
        params: {'numbers': id, 'comment': newComment},
      ).timeout(_actionTimeout);
      _load(background: true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر تحديث حالة الدفع: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _deleteAccount(Map<String, dynamic> user) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.semiBlack,
        title: const Text('تأكيد الحذف', style: TextStyle(color: Colors.white)),
        content: Text('هل أنت متأكد من حذف "${user['name']}"؟', style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء', style: TextStyle(color: Colors.white54))),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('حذف', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm != true) return;
    final id = _normalizeText(user['.id']);
    if (id.isNotEmpty) {
      try {
        await widget.routerService?.sendCommand('/ppp/secret/remove', params: {'numbers': id}).timeout(_actionTimeout);
        _load(background: true);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('تعذر حذف الحساب: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _openBrowser(Map<String, dynamic> user) async {
    String ip = _normalizeText(user['browser-ip']);
    if (ip.isEmpty) {
      final controller = TextEditingController();
      final result = await showDialog<String>(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: AppTheme.semiBlack,
          title: const Text('أدخل IP العميل', style: TextStyle(color: Colors.white)),
          content: TextField(
            controller: controller,
            style: const TextStyle(color: Colors.white),
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              hintText: 'مثال: 10.16.255.213',
              hintStyle: TextStyle(color: Colors.white38),
              filled: true,
              fillColor: Colors.white10,
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء', style: TextStyle(color: Colors.white54))),
            TextButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: Text('فتح', style: TextStyle(color: AppTheme.gold)),
            ),
          ],
        ),
      );
      if (result == null || result.isEmpty) return;
      ip = result;
    }
    ip = ip.replaceAll(RegExp(r'^https?://'), '').trim();
    final url = Uri.parse('http://$ip/login.html');
    try {
      final launched = await launchUrl(url, mode: LaunchMode.externalApplication);
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر فتح المتصفح: http://$ip/login.html'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في فتح المتصفح: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showActions(Map<String, dynamic> user) {
    final isDisabled = user['status'] == 'disabled';
    final isPaid = user['is-paid'] == true;
    final browserIp = _normalizeText(user['browser-ip']);

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.semiBlack,
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.open_in_browser, color: Colors.cyan),
              title: const Text('فتح في المتصفح', style: TextStyle(color: Colors.white)),
              subtitle: browserIp.isNotEmpty ? Text('http://$browserIp/login.html', style: const TextStyle(color: Colors.white38, fontSize: 11)) : null,
              onTap: () { Navigator.pop(context); _openBrowser(user); },
            ),
            ListTile(
              leading: Icon(isPaid ? Icons.money_off : Icons.attach_money, color: isPaid ? Colors.red : Colors.green),
              title: Text(isPaid ? 'تغيير إلى: لم يتم الدفع' : 'تغيير إلى: تم الدفع', style: const TextStyle(color: Colors.white)),
              onTap: () async { Navigator.pop(context); await _togglePaid(user); },
            ),
            if (user['active'] == true)
              ListTile(
                leading: const Icon(Icons.link_off, color: Colors.red),
                title: const Text('قطع الاتصال', style: TextStyle(color: Colors.white)),
                onTap: () async {
                  Navigator.pop(context);
                  final activeId = _normalizeText(user['active-id']);
                  if (activeId.isNotEmpty) {
                    try {
                      await widget.routerService?.sendCommand('/ppp/active/remove', params: {'numbers': activeId}).timeout(_actionTimeout);
                      _load(background: true);
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('تعذر قطع الاتصال: $e'), backgroundColor: Colors.red),
                        );
                      }
                    }
                  }
                },
              ),
            ListTile(
              leading: const Icon(Icons.edit, color: AppTheme.gold),
              title: const Text('تعديل', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PppUserScreen(
                      routerService: widget.routerService,
                      isEdit: true,
                      initialData: user,
                    ),
                  ),
                ).then((_) => _load(background: true));
              },
            ),
            ListTile(
              leading: Icon(Icons.block, color: isDisabled ? Colors.green : Colors.orange),
              title: Text(isDisabled ? 'تفعيل الحساب' : 'تعطيل الحساب', style: const TextStyle(color: Colors.white)),
              onTap: () async {
                Navigator.pop(context);
                final secretId = _normalizeText(user['.id']);
                if (secretId.isEmpty) return;
                try {
                  if (!isDisabled && user['active'] == true) {
                    final activeId = _normalizeText(user['active-id']);
                    if (activeId.isNotEmpty) {
                      await widget.routerService?.sendCommand('/ppp/active/remove', params: {'numbers': activeId}).timeout(_actionTimeout);
                    }
                  }
                  await widget.routerService?.sendCommand(
                    '/ppp/secret/set',
                    params: {'numbers': secretId, 'disabled': isDisabled ? 'no' : 'yes'},
                  ).timeout(_actionTimeout);
                  _load(background: true);
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('تعذر تغيير حالة الحساب: $e'), backgroundColor: Colors.red),
                    );
                  }
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.speed, color: AppTheme.gold),
              title: const Text('فتح السرعة', style: TextStyle(color: Colors.white)),
              onTap: () { Navigator.pop(context); _applySpeedProfile(user); },
            ),
            ListTile(
              leading: const Icon(Icons.delete_forever, color: Colors.red),
              title: const Text('حذف الحساب', style: TextStyle(color: Colors.white)),
              onTap: () async { Navigator.pop(context); await _deleteAccount(user); },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _applySpeedProfile(Map<String, dynamic> user) async {
    final secretId = _normalizeText(user['.id']);
    final activeId = _normalizeText(user['active-id']);
    if (secretId.isEmpty) return;
    try {
      await widget.routerService?.sendCommand(
        '/ppp/secret/set',
        params: {'numbers': secretId, 'profile': 'Speed'},
      ).timeout(_actionTimeout);
      if (user['active'] == true && activeId.isNotEmpty) {
        await widget.routerService?.sendCommand('/ppp/active/remove', params: {'numbers': activeId}).timeout(_actionTimeout);
      }
      _load(background: true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر تطبيق باقة السرعة: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _addNewAccount() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PppUserScreen(routerService: widget.routerService, isEdit: false),
      ),
    ).then((_) => _load(background: true));
  }

  // ==================== بناء الواجهة ====================
  Widget _buildStatusChip(Map<String, dynamic> user) {
    final status = user['status'] ?? 'offline';
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.45)),
      ),
      child: Text(_statusLabel(status), style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildInfoLine(String title, String value) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: RichText(
        text: TextSpan(
          style: TextStyle(color: onSurface.withOpacity(0.82), fontSize: 12, height: 1.25),
          children: [
            TextSpan(text: '$title: ', style: const TextStyle(fontWeight: FontWeight.bold)),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }

  Widget _buildSpeedBadge(double rx, double tx) {
    final primary = _showRxFirst ? 'RX' : 'TX';
    final primaryVal = _showRxFirst ? rx : tx;
    final secondary = _showRxFirst ? 'TX' : 'RX';
    final secondaryVal = _showRxFirst ? tx : rx;

    return Container(
      width: 122,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.greenOnline.withOpacity(0.14),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.greenOnline.withOpacity(0.85), width: 1),
      ),
      child: Stack(
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(primary, style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold)),
              Text(_formatSpeed(primaryVal), style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('$secondary: ${_formatSpeed(secondaryVal)}', style: const TextStyle(color: Colors.white70, fontSize: 9)),
            ],
          ),
          Positioned(
            top: -6,
            right: -6,
            child: InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: () => setState(() => _showRxFirst = !_showRxFirst),
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(color: Colors.black.withOpacity(0.2), shape: BoxShape.circle, border: Border.all(color: Colors.white24)),
                child: const Icon(Icons.swap_vert, size: 14, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatSpeed(double speedMbps) {
    if (speedMbps >= 1000) return '${(speedMbps / 1000).toStringAsFixed(1)} Gbps';
    if (speedMbps >= 1) return '${speedMbps.toStringAsFixed(1)} Mbps';
    if (speedMbps > 0) return '${(speedMbps * 1000).toStringAsFixed(0)} Kbps';
    return '0';
  }

  Widget _buildAccountCard(Map<String, dynamic> user) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final status = user['status'] ?? 'offline';
    final isActive = user['active'] == true;
    final rx = _toDouble(user['rx-speed']);
    final tx = _toDouble(user['tx-speed']);
    final note = _normalizeText(user['note']);
    final phone = _normalizeText(user['phone']);
    final expiry = _normalizeText(user['expiry-label']);
    final profile = _normalizeText(user['profile']);
    final isPaid = user['is-paid'] == true;
    final browserIp = _normalizeText(user['browser-ip']);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _statusColor(status).withOpacity(0.45)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () => _openBrowser(user),
        onLongPress: () => _showActions(user),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _statusColor(status).withOpacity(0.12),
                      border: Border.all(color: _statusColor(status).withOpacity(0.4)),
                    ),
                    child: Icon(isActive ? Icons.person : Icons.person_off, color: _statusColor(status)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                _normalizeText(user['name']),
                                style: TextStyle(color: onSurface, fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                            ),
                            if (browserIp.isNotEmpty)
                              InkWell(
                                borderRadius: BorderRadius.circular(8),
                                onTap: () => _openBrowser(user),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.cyan.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.cyan.withOpacity(0.35)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.open_in_browser, color: Colors.cyan, size: 14),
                                      const SizedBox(width: 4),
                                      Text(browserIp, style: const TextStyle(color: Colors.cyan, fontSize: 10, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _buildStatusChip(user),
                            if (profile.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: AppTheme.gold.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(color: AppTheme.gold.withOpacity(0.35)),
                                ),
                                child: Text('الباقة: $profile', style: const TextStyle(color: AppTheme.gold, fontSize: 11, fontWeight: FontWeight.bold)),
                              ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: (isPaid ? Colors.green : Colors.red).withOpacity(0.12),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(color: (isPaid ? Colors.green : Colors.red).withOpacity(0.35)),
                              ),
                              child: Text(isPaid ? 'مدفوع' : 'غير مدفوع', style: TextStyle(color: isPaid ? Colors.green : Colors.red, fontSize: 11, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (isActive) ...[
                    const SizedBox(width: 8),
                    _buildSpeedBadge(rx, tx),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              if (phone.isNotEmpty) _buildInfoLine('الهاتف', phone),
              if (expiry.isNotEmpty) _buildInfoLine('الصلاحية', expiry),
              if (note.isNotEmpty) _buildInfoLine('الكومنت', note),
              const SizedBox(height: 8),
              if (status == 'active')
                Text('متصل الآن', style: TextStyle(color: AppTheme.greenOnline, fontSize: 11, fontWeight: FontWeight.bold))
              else if (status == 'disabled')
                Text('معطل', style: TextStyle(color: Colors.red, fontSize: 11, fontWeight: FontWeight.bold))
              else if (status == 'expired')
                Text(
                  isActive ? 'منتهي - ما زال يعمل' : 'منتهي - سيُنقل إلى بروفايل Xpirer',
                  style: TextStyle(color: Colors.orange, fontSize: 11, fontWeight: FontWeight.bold),
                )
              else
                Text('غير متصل', style: TextStyle(color: Colors.blue, fontSize: 11, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilters() {
    final chips = [
      ('all', 'الكل', _countStatus('all')),
      ('active', 'متصل', _countStatus('active')),
      ('offline', 'غير متصل', _countStatus('offline')),
      ('disabled', 'معطل', _countStatus('disabled')),
      ('expired', 'منتهي', _countStatus('expired')),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: chips.map((item) {
          final selected = _filter == item.$1;
          return Padding(
            padding: const EdgeInsets.only(left: 8),
            child: ChoiceChip(
              label: Text('${item.$2} (${item.$3})'),
              selected: selected,
              selectedColor: AppTheme.gold,
              backgroundColor: Theme.of(context).cardColor,
              labelStyle: TextStyle(
                color: selected ? Colors.black : Theme.of(context).colorScheme.onSurface,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
              onSelected: (_) => setState(() => _filter = item.$1),
            ),
          );
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final filteredList = filtered;

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) {
          Navigator.of(context).popUntil((route) => route.settings.name == '/dashboard' || route.isFirst);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              Navigator.of(context).popUntil((route) => route.settings.name == '/dashboard' || route.isFirst);
            },
          ),
          title: const Text('البرودباند'),
          actions: [
            IconButton(onPressed: () => _load(background: true), icon: const Icon(Icons.refresh), tooltip: 'تحديث'),
            IconButton(onPressed: _addNewAccount, icon: const Icon(Icons.person_add), tooltip: 'إضافة مستخدم'),
          ],
        ),
        body: Column(
          children: [
            if (_loading) const LinearProgressIndicator(color: AppTheme.gold),
            const SizedBox(height: 12),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: _buildFilters()),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'بحث...',
                        prefixIcon: const Icon(Icons.search, color: AppTheme.gold),
                        filled: true,
                        fillColor: Theme.of(context).cardColor,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                        hintStyle: TextStyle(color: onSurface.withOpacity(0.4)),
                      ),
                      style: TextStyle(color: onSurface),
                      onChanged: (q) => setState(() => _searchQuery = q),
                    ),
                  ),
                  const SizedBox(width: 8),
                  DropdownButton<String>(
                    value: _sortBy,
                    dropdownColor: Theme.of(context).cardColor,
                    underline: const SizedBox(),
                    style: TextStyle(color: onSurface),
                    icon: Icon(Icons.sort, color: AppTheme.gold),
                    items: const [
                      DropdownMenuItem(value: 'status', child: Text('الحالة')),
                      DropdownMenuItem(value: 'name', child: Text('الاسم')),
                      DropdownMenuItem(value: 'uptime', child: Text('مدة الاتصال')),
                      DropdownMenuItem(value: 'usage', child: Text('الاستخدام')),
                      DropdownMenuItem(value: 'profile', child: Text('الباقة')),
                    ],
                    onChanged: (val) => setState(() => _sortBy = val!),
                  ),
                ],
              ),
            ),
            Expanded(
              child: filteredList.isEmpty
                  ? Center(
                      child: Text(
                        _accounts.isEmpty ? ( _loading ? 'جاري التحميل...' : 'لا توجد حسابات' ) : 'لا توجد نتائج',
                        style: TextStyle(color: onSurface.withOpacity(0.6)),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: filteredList.length,
                      itemBuilder: (_, i) => _buildAccountCard(filteredList[i]),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
