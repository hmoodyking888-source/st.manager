import 'dart:async';
import 'package:flutter/material.dart';
import 'package:st_manager/services/router_service.dart';
import 'package:st_manager/theme/app_theme.dart';
import 'package:st_manager/screens/hotspot/hotspot_active_users_screen.dart';
import 'package:st_manager/screens/ppp/ppp_active_screen.dart';
import 'package:st_manager/screens/cards/cards_screen.dart';
import 'package:st_manager/screens/devices_screen.dart';
import 'package:st_manager/screens/backup_restore_screen.dart';
import 'package:st_manager/screens/interface_screen.dart';
import 'package:st_manager/screens/simple_queue_screen.dart';
import 'package:st_manager/screens/applications/scripts_screen.dart';
import 'package:st_manager/widgets/side_drawer.dart';

class _RouterLogNotification {
  final String key;
  final String title;
  final String body;
  final String time;
  final String category;
  final String topics;
  final IconData icon;
  final Color color;

  const _RouterLogNotification({
    required this.key,
    required this.title,
    required this.body,
    required this.time,
    required this.category,
    required this.topics,
    required this.icon,
    required this.color,
  });
}

class DashboardScreen extends StatefulWidget {
  final Map<String, String> routerData;
  const DashboardScreen({super.key, required this.routerData});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // نحتفظ بأحدث 35 إشعاراً فقط لتقليل استهلاك الذاكرة.
  static const int _maxRouterNotifications = 35;
  static const Duration _logsRefreshInterval = Duration(seconds: 40);

  RouterService? _routerService;

  double _cpuLoad = 0;
  double _temperature = 0;
  double _voltage = 0;

  double _rxSpeed = 0;
  double _txSpeed = 0;
  bool _showRxMain = true;

  String _routerModel = '...';
  String _uptime = '...';

  int _activeUsers = 0;
  int _totalUsers = 0;
  int _pppActive = 0;
  int _pppTotal = 0;
  int _interfaceCount = 0;

  String? _selectedInterface = 'bridge1';
  List<String> _availableInterfaces = ['bridge1'];

  StreamSubscription<Map<String, double>>? _speedSubscription;
  Timer? _statsTimer;
  Timer? _logsTimer;
  Timer? _deviceStatsTimer;
  bool _isLoadingDeviceStats = false;
  int _deviceTotal = 0;
  int _deviceConnected = 0;
  int _currentIndex = 0;

  final List<_RouterLogNotification> _routerNotifications = [];
  final Set<String> _seenLogKeys = {};
  bool _isLoadingLogs = false;
  String? _logsError;
  DateTime? _lastLogsRefresh;
  String _notificationFilter = 'الكل';

  @override
  void initState() {
    super.initState();
    _connectToRouter();
  }

  Future<void> _connectToRouter() async {
    final data = widget.routerData;

    _routerService = RouterService(
      host: data['ip']!,
      port: int.tryParse(data['port'] ?? '8728') ?? 8728,
      username: data['username']!,
      password: data['password']!,
    );

    final ok = await _routerService!.connect();

    if (ok) {
      _startMonitoring();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('فشل الاتصال بالراوتر')),
        );
        Navigator.pop(context);
      }
    }
  }

  void _startMonitoring() {
    _fetchStats();
    _loadInterfaces();
    _fetchDeviceStats();
    _deviceStatsTimer?.cancel();
    _deviceStatsTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _fetchDeviceStats(),
    );

    _statsTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => _fetchStats(),
    );

    // قراءة سجل MikroTik بشكل مستقل حتى لا نثقل جلب إحصاءات الشاشة.
    _loadRouterLogs();
    _logsTimer?.cancel();
    _logsTimer = Timer.periodic(
      _logsRefreshInterval,
      (_) => _loadRouterLogs(),
    );

    if (_selectedInterface != null) {
      _speedSubscription?.cancel();
      _speedSubscription = _routerService!
          .monitorTrafficDetailsStream(_selectedInterface!)
          .listen((speed) {
        if (!mounted) return;
        setState(() {
          _rxSpeed = (speed['rx-bits-per-second'] ?? 0) / 1000000;
          _txSpeed = (speed['tx-bits-per-second'] ?? 0) / 1000000;
        });
      });
    }
  }

  bool _isPortOrBridge(Map<String, dynamic> iface) {
    final name = iface['name']?.toString().toLowerCase().trim() ?? '';
    final type = iface['type']?.toString().toLowerCase().trim() ?? '';
    final kind =
        iface['actual-interface-type']?.toString().toLowerCase().trim() ?? '';

    bool startsWithAny(List<String> prefixes) => prefixes.any(
        (p) => name.startsWith(p) || type.startsWith(p) || kind.startsWith(p));

    return startsWithAny(['ether', 'bridge', 'sfp', 'wlan', 'bond']);
  }

  Future<void> _loadInterfaces() async {
    if (_routerService == null || !_routerService!.isConnected) return;

    try {
      final interfaces = await _routerService!.getInterfaceList();
      final names = interfaces
          .where(_isPortOrBridge)
          .map((e) => e['name']?.toString())
          .whereType<String>()
          .where((name) => name.trim().isNotEmpty)
          .toList();

      if (names.isNotEmpty && mounted) {
        setState(() {
          _availableInterfaces = names;
          _interfaceCount = names.length;
          if (!_availableInterfaces.contains(_selectedInterface)) {
            _selectedInterface = _availableInterfaces.first;
          }
        });

        _speedSubscription?.cancel();
        _speedSubscription = _routerService!
            .monitorTrafficDetailsStream(_selectedInterface!)
            .listen((speed) {
          if (!mounted) return;
          setState(() {
            _rxSpeed = (speed['rx-bits-per-second'] ?? 0) / 1000000;
            _txSpeed = (speed['tx-bits-per-second'] ?? 0) / 1000000;
          });
        });
      }
    } catch (_) {}
  }

  Future<void> _fetchStats() async {
    if (_routerService == null || !_routerService!.isConnected) return;

    try {
      final resource = await _routerService!.getSystemResource();
      final health = await _routerService!.getSystemHealth();
      final active = await _routerService!.getHotspotActive();
      final allUsers = await _routerService!.getHotspotUsers();
      final pppActive = await _routerService!.getPppActive();
      final pppSecrets = await _routerService!.getPppSecrets();

      if (!mounted) return;

      setState(() {
        if (resource.isNotEmpty) {
          _cpuLoad =
              double.tryParse(resource.first['cpu-load']?.toString() ?? '0') ??
                  0;
          _routerModel = resource.first['board-name']?.toString() ?? 'MikroTik';
          _uptime = resource.first['uptime']?.toString() ?? '...';
        }

        if (health.isNotEmpty) {
          _temperature = _parseTemperature(health);
          _voltage = _parseVoltage(health);
        }

        _activeUsers = active.length;
        _totalUsers = allUsers.length;
        _pppActive = pppActive.length;
        _pppTotal = pppSecrets.length;
      });
    } catch (_) {}
  }

  /// أعداد أجهزة Netwatch المعروضة في شاشة الأجهزة: الإجمالي والمتصل حالياً.
  /// نستخدم قائمة Netwatch نفسها لأنها تتضمن حالة كل جهاز (up/down).
  Future<void> _fetchDeviceStats() async {
    final router = _routerService;
    if (router == null || !router.isConnected || _isLoadingDeviceStats) return;

    _isLoadingDeviceStats = true;
    try {
      final devices = await router.sendCommand('/tool/netwatch/print');
      var total = 0;
      var connected = 0;

      for (final device in devices) {
        final disabled =
            (device['disabled']?.toString().toLowerCase().trim() ?? 'no');
        if (disabled == 'yes' || disabled == 'true' || disabled == '1') {
          continue;
        }

        total++;
        final status = device['status']?.toString().toLowerCase().trim() ?? '';
        if (status == 'up') connected++;
      }

      if (!mounted) return;
      setState(() {
        _deviceTotal = total;
        _deviceConnected = connected;
      });
    } catch (_) {
      // لا نغيّر آخر أرقام سليمة عند تعذر قراءة Netwatch مؤقتاً.
    } finally {
      _isLoadingDeviceStats = false;
    }
  }

  double _parseTemperature(List<Map<String, dynamic>> health) {
    for (var item in health) {
      if (item.containsKey('name') &&
          item['name'].toString().toLowerCase().contains('temp')) {
        double? temp = double.tryParse(item['value']?.toString() ?? '');
        if (temp != null) {
          if (temp > 100) temp = temp / 10;
          return temp;
        }
      }
      if (item.containsKey('temperature')) {
        double? temp = double.tryParse(item['temperature'].toString());
        if (temp != null) {
          if (temp > 100) temp = temp / 10;
          return temp;
        }
      }
    }
    return 0;
  }

  double _parseVoltage(List<Map<String, dynamic>> health) {
    if (health.isEmpty) return 0;
    final direct = double.tryParse(health.first['voltage']?.toString() ?? '');
    if (direct != null && direct > 0) return direct;

    for (var item in health) {
      if (item.containsKey('name') &&
          item['name'].toString().toLowerCase().contains('volt')) {
        final v = double.tryParse(item['value']?.toString() ?? '');
        if (v != null && v > 0) return v;
      }
    }
    return 0;
  }

  String _formatRouterLogTime(Object? value) {
    final raw = value?.toString().trim() ?? '';
    if (raw.isEmpty) return 'وقت غير محدد';

    final monthNumbers = <String, String>{
      'jan': '01',
      'feb': '02',
      'mar': '03',
      'apr': '04',
      'may': '05',
      'jun': '06',
      'jul': '07',
      'aug': '08',
      'sep': '09',
      'oct': '10',
      'nov': '11',
      'dec': '12',
    };

    final match = RegExp(
      r'^([a-z]{3})/(\d{1,2})/(\d{4})\s+(\d{1,2}):(\d{2})(?::\d{2})?$',
      caseSensitive: false,
    ).firstMatch(raw);

    if (match != null) {
      final month = monthNumbers[match.group(1)!.toLowerCase()];
      if (month != null) {
        final day = match.group(2)!.padLeft(2, '0');
        final year = match.group(3)!;
        final hour = match.group(4)!.padLeft(2, '0');
        final minute = match.group(5)!;
        return '$day/$month/$year $hour:$minute';
      }
    }

    final parsed = DateTime.tryParse(raw);
    if (parsed != null) {
      final day = parsed.day.toString().padLeft(2, '0');
      final month = parsed.month.toString().padLeft(2, '0');
      final hour = parsed.hour.toString().padLeft(2, '0');
      final minute = parsed.minute.toString().padLeft(2, '0');
      return '$day/$month/${parsed.year} $hour:$minute';
    }

    return raw;
  }

  String? _extractLogIp(String message) {
    final match = RegExp(r'\b(?:\d{1,3}\.){3}\d{1,3}\b').firstMatch(message);
    if (match == null) return null;

    final ip = match.group(0)!;
    final parts = ip.split('.');
    if (parts.length != 4 ||
        parts.any((part) => (int.tryParse(part) ?? 999) > 255)) {
      return null;
    }
    return ip;
  }

  String? _extractLogUser(String message) {
    final patterns = <RegExp>[
      RegExp(r'<pppoe-([^>]+)>', caseSensitive: false),
      RegExp(r'\bpppoe-([^\s,:;]+)', caseSensitive: false),
      RegExp(r'''\buser(?:name)?\s*[:=]\s*["']?([^\s,"']+)''',
          caseSensitive: false),
      RegExp(r'\buser\s+([^\s,(;]+)', caseSensitive: false),
      RegExp(r'^\s*([^\s(:,;]+)\s*\(', caseSensitive: false),
      RegExp(r'^\s*([^\s:,;]+)\s+(?:logged in|logged out)',
          caseSensitive: false),
      RegExp(
          r'^\s*([^\s:,;]+)\s*:\s*(?:connected|disconnected|authenticated|logged)',
          caseSensitive: false),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(message);
      final value = match?.group(1)?.trim();
      if (value != null && value.isNotEmpty && value.toLowerCase() != 'user') {
        return value;
      }
    }
    return null;
  }

  String? _extractLogMac(String message) {
    final match = RegExp(
      r'\b(?:[0-9a-f]{2}:){5}[0-9a-f]{2}\b',
      caseSensitive: false,
    ).firstMatch(message);
    return match?.group(0);
  }

  String _translateCommonLogText(String message) {
    var result = message.trim();
    const replacements = <String, String>{
      'login failure': 'فشل تسجيل الدخول',
      'authentication failed': 'فشل التحقق من بيانات الدخول',
      'logged out': 'سجّل الخروج',
      'logged in': 'سجّل الدخول',
      'disconnected': 'انقطع الاتصال',
      'disconnecting': 'جارٍ قطع الاتصال',
      'connected': 'متصل',
      'authenticated': 'تم التحقق من الحساب',
      'deassigned': 'تم تحرير العنوان',
      'unbound': 'تم فك ربط العنوان',
      'released': 'تم تحرير العنوان',
      'assigned': 'تم تخصيص العنوان',
      'bound': 'تم ربط العنوان',
      'link down': 'انقطع رابط الواجهة',
      'link up': 'عاد رابط الواجهة للعمل',
      'rebooting': 'إعادة تشغيل الراوتر',
      'restarted': 'تمت إعادة التشغيل',
      'changed by': 'تم التعديل بواسطة',
      'removed': 'تم الحذف',
      'added': 'تمت الإضافة',
      'failed': 'فشل',
      'error': 'خطأ',
      'warning': 'تحذير',
      'rejected': 'مرفوض',
      'expired': 'انتهت صلاحيته',
      'timeout': 'انتهت مهلة الانتظار',
      'not responding': 'لا يستجيب',
      'disabled': 'معطّل',
      'enabled': 'مفعّل',
    };

    for (final entry in replacements.entries) {
      result = result.replaceAll(
        RegExp(RegExp.escape(entry.key), caseSensitive: false),
        entry.value,
      );
    }
    return result;
  }

  String _translateLogTopics(String topics) {
    final lower = topics.toLowerCase();
    final labels = <String>[];
    if (lower.contains('ppp')) labels.add('برودباند');
    if (lower.contains('hotspot')) labels.add('هوتسبوت');
    if (lower.contains('dhcp')) labels.add('DHCP');
    if (lower.contains('interface')) labels.add('الواجهات');
    if (lower.contains('wireless') || lower.contains('wlan')) {
      labels.add('لاسلكي');
    }
    if (lower.contains('firewall')) labels.add('الجدار الناري');
    if (lower.contains('system')) labels.add('النظام');
    if (lower.contains('account')) labels.add('الحسابات');
    if (lower.contains('error')) labels.add('خطأ');
    if (lower.contains('warning')) labels.add('تحذير');
    return labels.isEmpty ? topics : labels.toSet().join(' • ');
  }

  _RouterLogNotification? _translateRouterLog(Map<String, dynamic> row) {
    final message = (row['message'] ?? row['text'] ?? row['comment'] ?? '')
        .toString()
        .trim();
    if (message.isEmpty) return null;

    final topics = (row['topics'] ?? row['topic'] ?? '').toString().trim();
    final lower = message.toLowerCase();
    final topicLower = topics.toLowerCase();
    final combined = '$topicLower $lower';
    final user = _extractLogUser(message);
    final ip = _extractLogIp(message);
    final mac = _extractLogMac(message);

    final subjectParts = <String>[];
    if (user != null) subjectParts.add('الحساب $user');
    if (ip != null) subjectParts.add('IP: $ip');
    if (mac != null) subjectParts.add('MAC: $mac');
    final subject = subjectParts.join(' • ');

    final isDisconnect = RegExp(
      r'\b(disconnected|disconnecting|terminating|logged out|terminated|link down|unbound|deassigned|released)\b',
      caseSensitive: false,
    ).hasMatch(lower);
    final isConnect = RegExp(
      r'\b(connected|logged in|established|link up)\b',
      caseSensitive: false,
    ).hasMatch(lower);
    final isFailedLogin = RegExp(
      r'(login failure|failed login|login failed|authentication failed|invalid password|failure for user)',
      caseSensitive: false,
    ).hasMatch(lower);

    String title;
    String body;
    String category;
    IconData icon;
    Color color;

    if (RegExp(r'\b(rebooting|restarted|system reboot|shutting down)\b')
        .hasMatch(lower)) {
      title = 'إعادة تشغيل الراوتر';
      body = _translateCommonLogText(message);
      category = 'نظام';
      icon = Icons.restart_alt_rounded;
      color = Colors.orange;
    } else if (isFailedLogin) {
      title = 'محاولة دخول فاشلة';
      body = subject.isNotEmpty
          ? 'محاولة تسجيل دخول غير ناجحة — $subject'
          : _translateCommonLogText(message);
      category = 'أمان';
      icon = Icons.gpp_bad_rounded;
      color = Colors.redAccent;
    } else if (topicLower.contains('hotspot') || lower.contains('hotspot')) {
      category = 'اتصال';
      icon = Icons.wifi_rounded;
      if (isDisconnect) {
        title = 'انقطع حساب هوتسبوت';
        body = user != null
            ? 'تم تسجيل خروج الحساب $user${ip == null ? '' : ' — IP: $ip'}'
            : _translateCommonLogText(message);
        color = Colors.orange;
      } else if (isConnect) {
        title = 'اتصل حساب هوتسبوت';
        body = user != null
            ? 'الحساب $user متصل الآن${ip == null ? '' : ' — IP: $ip'}'
            : _translateCommonLogText(message);
        color = AppTheme.greenOnline;
      } else {
        title = 'حدث في الهوتسبوت';
        body = subject.isNotEmpty
            ? '$subject — ${_translateCommonLogText(message)}'
            : _translateCommonLogText(message);
        color = Colors.blue;
      }
    } else if (topicLower.contains('ppp') ||
        lower.contains('pppoe') ||
        RegExp(r'\bppp\b').hasMatch(lower)) {
      category = 'اتصال';
      icon = Icons.router_rounded;
      if (isDisconnect) {
        title = 'انقطع حساب برودباند';
        body = user != null
            ? 'انقطع الاتصال عن الحساب $user${ip == null ? '' : ' — IP: $ip'}'
            : _translateCommonLogText(message);
        color = Colors.orange;
      } else if ((lower.contains('assigned') || lower.contains('address')) &&
          ip != null) {
        title = 'تم تعيين عنوان IP لبرودباند';
        body = user != null
            ? 'تم ربط العنوان $ip بالحساب $user'
            : 'تم تسجيل عنوان IP $ip لاتصال برودباند';
        category = 'IP';
        icon = Icons.lan_rounded;
        color = Colors.blue;
      } else if (isConnect) {
        title = 'اتصل حساب برودباند';
        body = user != null
            ? 'الحساب $user اتصل بنجاح${ip == null ? '' : ' — IP: $ip'}'
            : _translateCommonLogText(message);
        color = AppTheme.greenOnline;
      } else if (lower.contains('authenticated')) {
        title = 'تم توثيق حساب برودباند';
        body = user != null
            ? 'تم التحقق من بيانات الحساب $user${ip == null ? '' : ' — IP: $ip'}'
            : _translateCommonLogText(message);
        color = Colors.blue;
      } else {
        title = 'تحديث اتصال برودباند';
        body = subject.isNotEmpty
            ? '$subject — ${_translateCommonLogText(message)}'
            : _translateCommonLogText(message);
        color = Colors.blue;
      }
    } else if (topicLower.contains('dhcp') ||
        lower.contains('dhcp') ||
        (lower.contains('lease') &&
            (lower.contains('bound') || lower.contains('assigned')))) {
      category = 'IP';
      icon = Icons.lan_rounded;
      final returnedIp = RegExp(
        r'\b(deassigned|unbound|released|expired|removed)\b',
        caseSensitive: false,
      ).hasMatch(lower);
      if (returnedIp) {
        title = 'تمت إعادة عنوان IP';
        body = ip != null
            ? 'تم تحرير العنوان $ip وإعادته إلى مجموعة عناوين DHCP${mac == null ? '' : ' — MAC: $mac'}'
            : _translateCommonLogText(message);
        color = Colors.orange;
      } else if (RegExp(r'\b(assigned|bound|offered)\b', caseSensitive: false)
          .hasMatch(lower)) {
        title = 'تم تخصيص عنوان IP';
        body = ip != null
            ? 'تم تخصيص العنوان $ip لجهاز الشبكة${mac == null ? '' : ' — MAC: $mac'}'
            : _translateCommonLogText(message);
        color = Colors.blue;
      } else {
        title = 'تحديث DHCP';
        body = _translateCommonLogText(message);
        color = Colors.blue;
      }
    } else if (topicLower.contains('interface') ||
        RegExp(r'\b(link up|link down)\b').hasMatch(lower)) {
      category = 'نظام';
      icon = Icons.settings_ethernet_rounded;
      final interfaceName = RegExp(
        r'\b(ether\d+|sfp\d+|wlan\d+|bridge\S*)\b',
        caseSensitive: false,
      ).firstMatch(message)?.group(1);
      if (isDisconnect) {
        title = 'انقطع رابط واجهة';
        body = interfaceName == null
            ? _translateCommonLogText(message)
            : 'واجهة $interfaceName انقطع رابطها';
        color = Colors.orange;
      } else {
        title = 'واجهة الشبكة تعمل';
        body = interfaceName == null
            ? _translateCommonLogText(message)
            : 'واجهة $interfaceName عادت للعمل';
        color = AppTheme.greenOnline;
      }
    } else if (combined.contains('logged in') ||
        combined.contains('logged out') ||
        combined.contains('login')) {
      title = 'نشاط تسجيل دخول';
      body = subject.isNotEmpty
          ? '$subject — ${_translateCommonLogText(message)}'
          : _translateCommonLogText(message);
      category = 'أمان';
      icon = Icons.security_rounded;
      color = Colors.deepPurpleAccent;
    } else if (lower.contains('changed by') ||
        lower.contains('configuration') ||
        lower.contains('added') ||
        lower.contains('removed')) {
      title = 'تغيير في إعدادات الراوتر';
      body = _translateCommonLogText(message);
      category = 'نظام';
      icon = Icons.settings_rounded;
      color = AppTheme.gold;
    } else if (topicLower.contains('error') ||
        topicLower.contains('warning') ||
        topicLower.contains('critical') ||
        lower.contains('error') ||
        lower.contains('warning') ||
        lower.contains('failed')) {
      title = 'تنبيه من الراوتر';
      body = _translateCommonLogText(message);
      category = 'نظام';
      icon = Icons.warning_amber_rounded;
      color = Colors.redAccent;
    } else {
      // إظهار بقية رسائل السجل المهمة مع تعريب المصطلحات الشائعة.
      title = 'حدث في سجل الراوتر';
      final translated = _translateCommonLogText(message);
      body = translated == message && subject.isNotEmpty
          ? '$subject — $translated'
          : translated;
      category = 'عام';
      icon = Icons.article_rounded;
      color = AppTheme.gold;
    }

    final time = _formatRouterLogTime(row['time'] ?? row['datetime']);
    final id = row['.id']?.toString().trim() ?? '';
    final key =
        id.isNotEmpty ? '$id|$topics|$message' : '$time|$topics|$message';

    return _RouterLogNotification(
      key: key,
      title: title,
      body: body,
      time: time,
      category: category,
      topics: topics,
      icon: icon,
      color: color,
    );
  }

  Future<void> _loadRouterLogs() async {
    final router = _routerService;
    if (router == null || !router.isConnected || _isLoadingLogs) return;

    if (mounted) {
      setState(() {
        _isLoadingLogs = true;
        _logsError = null;
      });
    }

    try {
      List<Map<String, dynamic>> rows;
      try {
        rows = await router.sendCommand(
          '/log/print',
          params: {'.proplist': '.id,time,topics,message'},
        );
      } catch (_) {
        // بعض إصدارات RouterOS أو مكتبات API قد لا تقبل .proplist.
        rows = await router.sendCommand('/log/print');
      }

      final freshEvents = <_RouterLogNotification>[];
      // /log/print يعيد السجلات من الأقدم إلى الأحدث؛ نعكس الترتيب
      // ونفحص أحدث 35 سجلاً فقط، حتى لا نعالج السجلات القديمة كل مرة.
      for (final row in rows.reversed.take(_maxRouterNotifications)) {
        final event = _translateRouterLog(row);
        if (event == null || _seenLogKeys.contains(event.key)) continue;
        _seenLogKeys.add(event.key);
        freshEvents.add(event);
      }

      if (!mounted) return;
      setState(() {
        if (freshEvents.isNotEmpty) {
          _routerNotifications.insertAll(0, freshEvents);
          if (_routerNotifications.length > _maxRouterNotifications) {
            _routerNotifications.removeRange(
              _maxRouterNotifications,
              _routerNotifications.length,
            );
          }
        }
        _lastLogsRefresh = DateTime.now();
        _logsError = null;
      });

      if (_seenLogKeys.length > 1200) {
        _seenLogKeys
          ..clear()
          ..addAll(_routerNotifications.map((event) => event.key));
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _logsError =
              'تعذرت قراءة سجل الراوتر. تحقق من صلاحية قراءة Log للمستخدم.';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingLogs = false);
      }
    }
  }

  List<_RouterLogNotification> get _filteredRouterNotifications {
    switch (_notificationFilter) {
      case 'الاتصال':
        return _routerNotifications
            .where((event) => event.category == 'اتصال')
            .toList();
      case 'عناوين IP':
        return _routerNotifications
            .where((event) => event.category == 'IP')
            .toList();
      case 'الأمان':
        return _routerNotifications
            .where((event) => event.category == 'أمان')
            .toList();
      case 'النظام':
        return _routerNotifications
            .where((event) => event.category == 'نظام')
            .toList();
      default:
        return List<_RouterLogNotification>.from(_routerNotifications);
    }
  }

  @override
  void dispose() {
    _speedSubscription?.cancel();
    _statsTimer?.cancel();
    _logsTimer?.cancel();
    _deviceStatsTimer?.cancel();
    _routerService?.disconnect();
    super.dispose();
  }

  void _showInterfacePicker() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.semiBlack,
        title:
            const Text('اختر الواجهة', style: TextStyle(color: Colors.white)),
        content: DropdownButtonFormField<String>(
          value: _selectedInterface,
          isExpanded: true,
          dropdownColor: AppTheme.semiBlack,
          style: const TextStyle(color: Colors.white),
          items: _availableInterfaces
              .map((e) => DropdownMenuItem<String>(
                    value: e,
                    child: Text(e),
                  ))
              .toList(),
          onChanged: (val) {
            if (val == null) return;
            setState(() => _selectedInterface = val);
            _speedSubscription?.cancel();
            _speedSubscription = _routerService!
                .monitorTrafficDetailsStream(val)
                .listen((speed) {
              if (!mounted) return;
              setState(() {
                _rxSpeed = (speed['rx-bits-per-second'] ?? 0) / 1000000;
                _txSpeed = (speed['tx-bits-per-second'] ?? 0) / 1000000;
              });
            });
            Navigator.pop(context);
          },
        ),
      ),
    );
  }

  void _toggleSpeedView() => setState(() => _showRxMain = !_showRxMain);

  String _formatSpeed(double speed) {
    if (speed >= 1000) return '${(speed / 1000).toStringAsFixed(1)} Gbps';
    if (speed >= 1) return '${speed.toStringAsFixed(1)} Mbps';
    return '${(speed * 1000).toStringAsFixed(0)} Kbps';
  }

  @override
  Widget build(BuildContext context) {
    // إمكانية العودة بالزر المادي أو الزر العلوي للرئيسية دون الخروج من الراوتر
    return PopScope(
      canPop: _currentIndex == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _currentIndex != 0) {
          setState(() {
            _currentIndex = 0;
          });
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: _currentIndex != 0
              ? IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => setState(() => _currentIndex = 0),
                  tooltip: 'العودة للرئيسية',
                )
              : null,
          title: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(widget.routerData['name'] ?? 'ST_Manager'),
              Text(
                'ربطك بالعالم بسرعة وثقة',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(fontSize: 10),
              ),
            ],
          ),
          actions: [
            Builder(
              builder: (context) => IconButton(
                icon: const Icon(Icons.menu),
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),
            ),
          ],
        ),
        drawer: SideDrawer(routerService: _routerService),
        body: _buildBody(),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _currentIndex,
          type: BottomNavigationBarType.fixed,
          backgroundColor: AppTheme.semiBlack,
          selectedItemColor: AppTheme.gold,
          unselectedItemColor: Colors.white38,
          selectedFontSize: 11,
          unselectedFontSize: 10,
          onTap: (index) {
            if (index == 4) {
              Navigator.pushNamed(context, '/settings').then((_) {
                if (mounted) setState(() => _currentIndex = 0);
              });
              return;
            }
            setState(() => _currentIndex = index);
            if (index == 3) _loadRouterLogs();
          },
          items: [
            const BottomNavigationBarItem(
              icon: Icon(Icons.home_rounded),
              label: 'الرئيسية',
            ),
            BottomNavigationBarItem(
              icon: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(Icons.router_rounded),
                  if (_pppActive > 0)
                    Positioned(
                      top: -4,
                      right: -6,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                          color: AppTheme.greenOnline,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '$_pppActive',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                ],
              ),
              label: 'برودباند',
            ),
            BottomNavigationBarItem(
              icon: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(Icons.wifi_rounded),
                  if (_activeUsers > 0)
                    Positioned(
                      top: -4,
                      right: -6,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                          color: Colors.blue,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '$_activeUsers',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                ],
              ),
              label: 'هوتسبوت',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.notifications_rounded),
              label: 'الإشعارات',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.settings_rounded),
              label: 'الإعدادات',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    switch (_currentIndex) {
      case 0:
        return _buildDashboardContent();
      case 1:
        return PppActiveScreen(
          routerService: _routerService,
          onBackToDashboard: () {
            if (mounted) {
              setState(() => _currentIndex = 0);
            }
          },
        );
      case 2:
        return HotspotActiveUsersScreen(routerService: _routerService);
      case 3:
        return _buildNotificationsTab();
      default:
        return _buildDashboardContent();
    }
  }

  Widget _buildNotificationsTab() {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final events = _filteredRouterNotifications;
    final lastRefresh = _lastLogsRefresh == null
        ? 'التحديث التلقائي كل 40 ثانية'
        : 'آخر تحديث ${_lastLogsRefresh!.hour.toString().padLeft(2, '0')}:${_lastLogsRefresh!.minute.toString().padLeft(2, '0')} • تلقائياً كل 40 ثانية';

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
          decoration: BoxDecoration(
            color: AppTheme.semiBlack,
            border: Border(
              bottom: BorderSide(color: AppTheme.gold.withOpacity(0.20)),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppTheme.gold.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.notifications_active_rounded,
                  color: AppTheme.gold,
                  size: 22,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'مركز إشعارات الشبكة',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      lastRefresh,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: AppTheme.gold.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.gold.withOpacity(0.35)),
                ),
                child: Text(
                  '${_routerNotifications.length}',
                  style: const TextStyle(
                    color: AppTheme.gold,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 5),
              IconButton(
                tooltip: 'تحديث سجل الراوتر',
                onPressed: _isLoadingLogs ? null : _loadRouterLogs,
                icon: _isLoadingLogs
                    ? const SizedBox(
                        width: 19,
                        height: 19,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppTheme.gold,
                        ),
                      )
                    : const Icon(Icons.refresh_rounded, color: AppTheme.gold),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          child: Row(
            children: [
              Expanded(
                child: _buildNetworkCountCard(
                  title: 'برودباند',
                  total: _pppTotal,
                  connected: _pppActive,
                  icon: Icons.router_rounded,
                  color: AppTheme.greenOnline,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: _buildNetworkCountCard(
                  title: 'هوتسبوت',
                  total: _totalUsers,
                  connected: _activeUsers,
                  icon: Icons.wifi_rounded,
                  color: Colors.lightBlueAccent,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 43,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            scrollDirection: Axis.horizontal,
            children: ['الكل', 'الاتصال', 'عناوين IP', 'الأمان', 'النظام']
                .map((filter) => Padding(
                      padding: const EdgeInsetsDirectional.only(end: 7),
                      child: ChoiceChip(
                        label: Text(filter),
                        selected: _notificationFilter == filter,
                        onSelected: (_) {
                          setState(() => _notificationFilter = filter);
                        },
                        selectedColor: AppTheme.gold,
                        backgroundColor: AppTheme.semiBlack,
                        labelStyle: TextStyle(
                          color: _notificationFilter == filter
                              ? Colors.black
                              : Colors.white70,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                        side: BorderSide(
                          color: _notificationFilter == filter
                              ? AppTheme.gold
                              : Colors.white12,
                        ),
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 5),
                      ),
                    ))
                .toList(),
          ),
        ),
        const SizedBox(height: 6),
        const Divider(height: 1, color: Colors.white12),
        Expanded(
          child: _logsError != null && _routerNotifications.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.cloud_off_rounded,
                            color: Colors.orangeAccent, size: 42),
                        const SizedBox(height: 10),
                        Text(
                          _logsError!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 12),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          onPressed: _loadRouterLogs,
                          icon: const Icon(Icons.refresh_rounded, size: 17),
                          label: const Text('إعادة المحاولة'),
                        ),
                      ],
                    ),
                  ),
                )
              : events.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _isLoadingLogs
                                ? Icons.sync_rounded
                                : Icons.notifications_none_rounded,
                            color: AppTheme.gold.withOpacity(0.8),
                            size: 45,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            _isLoadingLogs
                                ? 'جارٍ جلب سجل الراوتر...'
                                : _notificationFilter == 'الكل'
                                    ? 'لا توجد أحداث مسجلة حالياً'
                                    : 'لا توجد إشعارات ضمن هذا التصنيف',
                            style: TextStyle(
                              color: onSurface.withOpacity(0.65),
                              fontSize: 13,
                            ),
                          ),
                          if (_logsError != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              _logsError!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  color: Colors.orangeAccent, fontSize: 11),
                            ),
                          ],
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                      itemCount: events.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final event = events[index];
                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.semiBlack,
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(
                              color: event.color.withOpacity(0.28),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 39,
                                height: 39,
                                decoration: BoxDecoration(
                                  color: event.color.withOpacity(0.13),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  event.icon,
                                  color: event.color,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            event.title,
                                            style: TextStyle(
                                              color: onSurface,
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 5),
                                        Text(
                                          event.category,
                                          style: TextStyle(
                                            color: event.color,
                                            fontSize: 9,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 5),
                                    Text(
                                      event.body,
                                      style: TextStyle(
                                        color: onSurface.withOpacity(0.78),
                                        fontSize: 11,
                                        height: 1.35,
                                      ),
                                    ),
                                    if (event.topics.isNotEmpty) ...[
                                      const SizedBox(height: 6),
                                      Text(
                                        'المصدر: ${_translateLogTopics(event.topics)}',
                                        style: const TextStyle(
                                          color: Colors.white38,
                                          fontSize: 9,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(width: 7),
                              Text(
                                event.time,
                                textAlign: TextAlign.end,
                                style: const TextStyle(
                                  color: Colors.white38,
                                  fontSize: 9,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
        ),
        Container(
          margin: const EdgeInsets.fromLTRB(12, 5, 12, 10),
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
          decoration: BoxDecoration(
            color: const Color(0xFF29B6F6).withOpacity(0.07),
            borderRadius: BorderRadius.circular(13),
            border: Border.all(
              color: const Color(0xFF29B6F6).withOpacity(0.22),
            ),
          ),
          child: Row(
            children: [
              const Icon(Icons.telegram, color: Color(0xFF29B6F6), size: 19),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'تُجلب الأحداث من Log في MikroTik تلقائياً. فعّل بوت تيليجرام للتنبيهات الخارجية.',
                  style: TextStyle(color: Colors.white70, fontSize: 10),
                ),
              ),
              Builder(
                builder: (drawerContext) => TextButton(
                  onPressed: () => Scaffold.of(drawerContext).openDrawer(),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 7),
                    minimumSize: const Size(42, 32),
                  ),
                  child: const Text(
                    'إعداد',
                    style: TextStyle(
                      color: Color(0xFF29B6F6),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNetworkCountCard({
    required String title,
    required int total,
    required int connected,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 17),
              const SizedBox(width: 6),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('الإجمالي',
                        style: TextStyle(color: Colors.white54, fontSize: 9)),
                    Text(
                      '$total',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Container(width: 1, height: 29, color: Colors.white12),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('متصل الآن',
                        style: TextStyle(color: Colors.white54, fontSize: 9)),
                    Text(
                      '$connected',
                      style: TextStyle(
                        color: color,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardContent() {
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _buildSmallCard('المعالج', '${_cpuLoad.toStringAsFixed(1)}%'),
              _buildSmallCard(
                  'الحرارة', '${_temperature.toStringAsFixed(1)}°C'),
              _buildSmallCard('الفولت', '${_voltage.toStringAsFixed(1)}V'),
              _buildSmallCard('الواجهات', '$_interfaceCount'),
            ],
          ),
          const SizedBox(height: 14),
          _buildSpeedCard(onSurface),
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    _routerModel,
                    style: TextStyle(
                      color: onSurface,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Uptime: $_uptime',
                    style: TextStyle(
                      color: onSurface.withOpacity(0.7),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _buildMenuButtonWithCounter(
                'هوتسبوت',
                Icons.wifi_rounded,
                '$_totalUsers/$_activeUsers',
                () => setState(() => _currentIndex = 2),
              ),
              _buildMenuButtonWithCounter(
                'برودباند',
                Icons.router_rounded,
                '$_pppTotal/$_pppActive',
                () => setState(() => _currentIndex = 1),
              ),
              _buildMenuButton('بطاقات', Icons.credit_card, () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CardsScreen(routerService: _routerService),
                  ),
                );
              }),
              _buildMenuButton('نسخ/استعادة', Icons.backup, () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        BackupRestoreScreen(routerService: _routerService),
                  ),
                );
              }),
              _buildMenuButtonWithCounter(
                'الأجهزة',
                Icons.cell_tower,
                '$_deviceTotal/$_deviceConnected',
                () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          DevicesScreen(routerService: _routerService),
                    ),
                  );
                },
              ),
              _buildMenuButton('الواجهات', Icons.settings_ethernet, () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        InterfaceScreen(routerService: _routerService),
                  ),
                );
              }),
              _buildMenuButton(
                  'قياس السرعة', Icons.speed, _showInterfacePicker),
              _buildMenuButton('Simple Queue', Icons.queue, () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        SimpleQueueScreen(routerService: _routerService),
                  ),
                );
              }),
              _buildMenuButton('تسريع التطبيقات', Icons.flash_on, () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        AppPriorityScreen(routerService: _routerService),
                  ),
                );
              }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSpeedCard(Color onSurface) {
    final primary = _showRxMain ? _rxSpeed : _txSpeed;
    final secondary = _showRxMain ? _txSpeed : _rxSpeed;
    final primaryLabel = _showRxMain ? 'RX' : 'TX';
    final secondaryLabel = _showRxMain ? 'TX' : 'RX';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.black, AppTheme.darkGrey, AppTheme.semiBlack],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: AppTheme.gold.withOpacity(0.35),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.gold.withOpacity(0.08),
            blurRadius: 24,
            spreadRadius: 1,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'السرعة اللحظية',
                style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w500),
              ),
              GestureDetector(
                onTap: _showInterfacePicker,
                child: Row(
                  children: [
                    Text(
                      _selectedInterface ?? '---',
                      style: const TextStyle(
                          color: AppTheme.gold,
                          fontSize: 13,
                          fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.expand_more,
                        color: AppTheme.gold, size: 16),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 18, horizontal: 14),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        primaryLabel,
                        style: const TextStyle(
                            color: AppTheme.gold,
                            fontSize: 14,
                            fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          _formatSpeed(primary),
                          style: TextStyle(
                              color: onSurface,
                              fontSize: 34,
                              fontWeight: FontWeight.bold,
                              height: 1),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'الأولوية الآن: $primaryLabel',
                        style: TextStyle(
                            color: onSurface.withOpacity(0.72), fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 84,
                child: Column(
                  children: [
                    ElevatedButton(
                      onPressed: _toggleSpeedView,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 10),
                        minimumSize: const Size.fromHeight(40),
                      ),
                      child: const Icon(Icons.swap_vert, size: 18),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Column(
                        children: [
                          Text(
                            secondaryLabel,
                            style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
                                fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _formatSpeed(secondary),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                height: 1),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSmallCard(String title, String value) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(title,
                style: const TextStyle(color: AppTheme.gold, fontSize: 12)),
            const SizedBox(height: 4),
            Text(value,
                style: TextStyle(
                    color: onSurface,
                    fontSize: 16,
                    fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuButton(String label, IconData icon, VoidCallback onTap) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return InkWell(
      onTap: onTap,
      child: Card(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppTheme.gold, size: 28),
            const SizedBox(height: 6),
            Text(label,
                style: TextStyle(color: onSurface, fontSize: 12),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuButtonWithCounter(
    String label,
    IconData icon,
    String counter,
    VoidCallback onTap,
  ) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return InkWell(
      onTap: onTap,
      child: Card(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppTheme.gold, size: 28),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(color: onSurface, fontSize: 12),
                textAlign: TextAlign.center),
            const SizedBox(height: 2),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  counter,
                  maxLines: 1,
                  style: const TextStyle(
                    color: AppTheme.greenOnline,
                    fontSize: 10,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
