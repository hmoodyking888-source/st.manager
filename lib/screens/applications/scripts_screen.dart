import 'package:flutter/material.dart';
import 'package:st_manager/services/router_service.dart';
import 'package:st_manager/services/secure_storage_service.dart';
import 'package:st_manager/theme/app_theme.dart';

/// اسم قائمة WAN الافتراضية.
/// سيتم تحميل قوائم Interface Lists من الراوتر تلقائيًا.
/// إذا لم توجد قوائم، سيبقى هذا الاسم كقيمة افتراضية.
const String _defaultWanInterfaceList = 'WAN';
const String _defaultLanInterfaceList = 'LAN';

class AppPriorityConfig {
  final String id;
  final String name;
  final IconData icon;
  final Color color;
  final List<String> hosts;

  bool isEnabled;
  String currentDownloadLimit;
  String currentUploadLimit;

  String downloadMaxLimit;
  String uploadMaxLimit;
  String downloadLimitAt;
  String uploadLimitAt;
  int priority;

  bool burstEnabled;
  String burstDownloadLimit;
  String burstUploadLimit;
  String burstDownloadThreshold;
  String burstUploadThreshold;
  String burstTime;

  /// قائمة LAN التي يدخل منها ترافيك العملاء.
  String lanInterfaceList;

  /// قائمة WAN التي يصل إليها/يأتي منها ترافيك الإنترنت.
  String wanInterfaceList;

  String downloadParent;
  String uploadParent;

  AppPriorityConfig({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    required this.hosts,
    this.isEnabled = false,
    this.currentDownloadLimit = '',
    this.currentUploadLimit = '',
    this.downloadMaxLimit = '100M',
    this.uploadMaxLimit = '20M',
    this.downloadLimitAt = '10M',
    this.uploadLimitAt = '2M',
    this.priority = 1,
    this.burstEnabled = true,
    this.burstDownloadLimit = '120M',
    this.burstUploadLimit = '25M',
    this.burstDownloadThreshold = '70M',
    this.burstUploadThreshold = '15M',
    this.burstTime = '20s',

    /// الافتراضي الصحيح:
    /// Download = WAN -> LAN
    /// Upload   = LAN -> WAN
    this.lanInterfaceList = _defaultLanInterfaceList,
    this.wanInterfaceList = _defaultWanInterfaceList,

    this.downloadParent = 'global',
    this.uploadParent = 'global',
  });
}

// تم استبدال openSpeed بـ fixLoop بناء على طلبك
enum ExtraMenu { fixLoop, telegramBot }

class AppPriorityScreen extends StatefulWidget {
  final RouterService? routerService;

  const AppPriorityScreen({
    super.key,
    required this.routerService,
  });

  @override
  State<AppPriorityScreen> createState() => _AppPriorityScreenState();
}

class _AppPriorityScreenState extends State<AppPriorityScreen> {
  bool _loading = false;
  bool _fastTrackDetected = false;
  int _fastTrackRulesCount = 0;

  // ---------------------------------------------------------------------------
  // اشتراك التطبيق
  // ---------------------------------------------------------------------------

  int? _subscriptionDaysRemaining;
  DateTime? _subscriptionExpiryDate;

  final SecureStorageService _secureStorage = SecureStorageService();

  // ---------------------------------------------------------------------------
  // Interface Lists
  // ---------------------------------------------------------------------------

  List<String> _interfaceLists = [];

  List<String> get _lanInterfaceLists {
    final values = <String>{};

    if (_interfaceLists.isNotEmpty) {
      for (final value in _interfaceLists) {
        final normalized = value.trim();
        if (normalized.isEmpty) continue;

        final lower = normalized.toLowerCase();

        // نضع قوائم LAN في الأعلى، لكن نبقي كل القوائم متاحة للاختيار.
        if (lower == 'lan' ||
            lower.contains('lan') ||
            lower.contains('inside') ||
            lower.contains('local')) {
          values.add(normalized);
        }
      }
    }

    values.add(_defaultLanInterfaceList);

    return values.toList();
  }

  List<String> get _wanInterfaceLists {
    final values = <String>{};

    if (_interfaceLists.isNotEmpty) {
      for (final value in _interfaceLists) {
        final normalized = value.trim();
        if (normalized.isEmpty) continue;

        final lower = normalized.toLowerCase();

        if (lower == 'wan' ||
            lower.contains('wan') ||
            lower.contains('internet') ||
            lower.contains('public') ||
            lower.contains('outside')) {
          values.add(normalized);
        }
      }
    }

    values.add(_defaultWanInterfaceList);

    return values.toList();
  }

  final List<AppPriorityConfig> _apps = [
    AppPriorityConfig(
      id: 'whatsapp',
      name: 'واتساب (WhatsApp)',
      icon: Icons.chat,
      color: Colors.green,
      hosts: ['*whatsapp.net*', '*whatsapp.com*'],
    ),
    AppPriorityConfig(
      id: 'facebook',
      name: 'فيسبوك (Facebook)',
      icon: Icons.facebook,
      color: Colors.blue,
      hosts: ['*facebook.com*', '*fbcdn.net*', '*messenger.com*'],
    ),
    AppPriorityConfig(
      id: 'instagram',
      name: 'انستغرام (Instagram)',
      icon: Icons.camera_alt,
      color: Colors.purpleAccent,
      hosts: ['*instagram.com*', '*cdninstagram.com*', '*fbcdn.net*'],
    ),
    AppPriorityConfig(
      id: 'tiktok',
      name: 'تيك توك (TikTok)',
      icon: Icons.music_note,
      color: Colors.white,
      hosts: ['*tiktokcdn.com*', '*tiktokv.com*', '*tiktok.com*'],
    ),
    AppPriorityConfig(
      id: 'youtube',
      name: 'يوتيوب (YouTube)',
      icon: Icons.play_circle_fill,
      color: Colors.red,
      hosts: ['*youtube.com*', '*googlevideo.com*', '*ytimg.com*'],
    ),
    AppPriorityConfig(
      id: 'pubg',
      name: 'ببجي موبايل (PUBG)',
      icon: Icons.sports_esports,
      color: Colors.orange,
      hosts: ['*pubgmobile.com*', '*igamecj.com*'],
    ),
    AppPriorityConfig(
      id: 'telegram',
      name: 'تيليجرام (Telegram)',
      icon: Icons.send,
      color: Colors.cyan,
      hosts: ['*telegram.org*', '*t.me*', '*telegram.me*'],
    ),
    AppPriorityConfig(
      id: 'snapchat',
      name: 'سناب شات (Snapchat)',
      icon: Icons.camera_alt_outlined,
      color: Colors.amber,
      hosts: ['*snapchat.com*', '*sc-cdn.net*', '*snapkit.com*'],
    ),
    AppPriorityConfig(
      id: 'x',
      name: 'إكس / تويتر (X)',
      icon: Icons.public,
      color: Colors.lightBlueAccent,
      hosts: ['*x.com*', '*twitter.com*', '*twimg.com*'],
    ),
    AppPriorityConfig(
      id: 'discord',
      name: 'ديسكورد (Discord)',
      icon: Icons.forum,
      color: Colors.indigoAccent,
      hosts: [
        '*discord.com*',
        '*discord.gg*',
        '*discordapp.com*',
        '*discordapp.net*',
      ],
    ),
    AppPriorityConfig(
      id: 'netflix',
      name: 'نتفلكس (Netflix)',
      icon: Icons.movie,
      color: Colors.redAccent,
      hosts: ['*netflix.com*', '*nflxvideo.net*', '*nflximg.net*'],
    ),
    AppPriorityConfig(
      id: 'twitch',
      name: 'تويتش (Twitch)',
      icon: Icons.videogame_asset,
      color: Colors.purple,
      hosts: ['*twitch.tv*', '*ttvnw.net*', '*jtvnw.net*'],
    ),
  ];

  RouterService? get _router => widget.routerService;

  bool get _hasRouter => _router != null;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshAll();
    });
  }

  // ---------------------------------------------------------------------------
  // Keys / Names
  // ---------------------------------------------------------------------------

  String _commentFor(AppPriorityConfig app) => 'AppManager_${app.id}';

  String _connMarkFor(AppPriorityConfig app) => 'conn_${app.id}';

  String _downPackMarkFor(AppPriorityConfig app) =>
      'pack_${app.id}_down';

  String _upPackMarkFor(AppPriorityConfig app) =>
      'pack_${app.id}_up';

  String _downQueueNameFor(AppPriorityConfig app) =>
      'Priority_${app.id}_down';

  String _upQueueNameFor(AppPriorityConfig app) =>
      'Priority_${app.id}_up';

  // ---------------------------------------------------------------------------
  // Snackbar
  // ---------------------------------------------------------------------------

  void _showSnack(
    String message, {
    Color backgroundColor = Colors.black87,
  }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Generic Response Parsing
  // ---------------------------------------------------------------------------

  List<Map<String, dynamic>> _asMapList(dynamic response) {
    if (response is List) {
      return response.whereType<Map>().map((item) {
        return item.map(
          (key, value) => MapEntry(key.toString(), value),
        );
      }).toList();
    }

    if (response is Map && response['data'] is List) {
      final data = response['data'] as List;

      return data.whereType<Map>().map((item) {
        return item.map(
          (key, value) => MapEntry(key.toString(), value),
        );
      }).toList();
    }

    return [];
  }

  Map<String, dynamic>? _findByField(
    List<Map<String, dynamic>> items,
    String field,
    String value,
  ) {
    for (final item in items) {
      if (item[field]?.toString() == value) {
        return item;
      }
    }

    return null;
  }

  // ---------------------------------------------------------------------------
  // Validation
  // ---------------------------------------------------------------------------

  bool _isValidRateLimit(String value) {
    final cleaned = value.replaceAll(' ', '').trim();

    return RegExp(
      r'^\d+(\.\d+)?[KkMmGg]?(?:/\d+(\.\d+)?[KkMmGg]?)?$',
    ).hasMatch(cleaned);
  }

  bool _isValidBurstTime(String value) {
    final cleaned = value.replaceAll(' ', '').trim();

    return RegExp(
      r'^\d+(ms|s|m|h)$',
    ).hasMatch(cleaned);
  }

  String _normalizeRateLimit(String value) {
    return value.replaceAll(' ', '').trim();
  }

  String? _validateRateLimitField(String? value) {
    final v = (value ?? '').trim();

    if (v.isEmpty) {
      return 'هذا الحقل مطلوب';
    }

    if (!_isValidRateLimit(v)) {
      return 'صيغة غير صحيحة';
    }

    return null;
  }

  String? _validatePriorityField(String? value) {
    final v = int.tryParse((value ?? '').trim());

    if (v == null) {
      return 'أدخل رقمًا من 1 إلى 8';
    }

    if (v < 1 || v > 8) {
      return 'الأولوية يجب أن تكون من 1 إلى 8';
    }

    return null;
  }

  String? _validateBurstTimeField(String? value) {
    final v = (value ?? '').trim();

    if (v.isEmpty) {
      return 'هذا الحقل مطلوب';
    }

    if (!_isValidBurstTime(v)) {
      return 'مثال: 20s أو 500ms';
    }

    return null;
  }

  String? _validateNonEmptyField(String? value) {
    if ((value ?? '').trim().isEmpty) {
      return 'هذا الحقل مطلوب';
    }

    return null;
  }

  String? _validateInterfaceList(
    String? value,
    List<String> values,
  ) {
    final v = (value ?? '').trim();

    if (v.isEmpty) {
      return 'اختر قائمة';
    }

    if (!values.contains(v)) {
      return 'القائمة غير موجودة';
    }

    return null;
  }

  // ---------------------------------------------------------------------------
  // Refresh
  // ---------------------------------------------------------------------------

  Future<void> _refreshAll() async {
    if (mounted) {
      setState(() => _loading = true);
    }

    await Future.wait([
      _loadInterfaceLists(),
      _loadSubscriptionCounter(),
      _checkActivePriorities(showLoader: false),
      _checkFastTrackWarning(),
    ]);

    if (mounted) {
      setState(() => _loading = false);
    }
  }

  // ---------------------------------------------------------------------------
  // Interface Lists
  // ---------------------------------------------------------------------------

  Future<void> _loadInterfaceLists() async {
    final router = _router;

    if (router == null) {
      return;
    }

    try {
      final response = await router.sendCommand(
        '/interface/list/print',
      );

      final items = _asMapList(response);

      final names = <String>[];

      for (final item in items) {
        final name = item['name']?.toString().trim();

        if (name != null && name.isNotEmpty) {
          names.add(name);
        }
      }

      names.sort(
        (a, b) => a.toLowerCase().compareTo(
              b.toLowerCase(),
            ),
      );

      if (!mounted) return;

      setState(() {
        _interfaceLists = names;
      });

      // تحديث القيم القديمة إلى قيم صحيحة موجودة على الراوتر
      for (final app in _apps) {
        if (!_lanInterfaceLists.contains(app.lanInterfaceList)) {
          app.lanInterfaceList =
              _lanInterfaceLists.first;
        }

        if (!_wanInterfaceLists.contains(app.wanInterfaceList)) {
          app.wanInterfaceList =
              _wanInterfaceLists.first;
        }
      }
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _interfaceLists = [];
      });
    }
  }

  // ---------------------------------------------------------------------------
  // Subscription Counter
  // ---------------------------------------------------------------------------

  Future<void> _loadSubscriptionCounter() async {
    try {
      final rawExpiry =
          await _secureStorage.read('license_expiry_date');

      if (rawExpiry == null || rawExpiry.trim().isEmpty) {
        if (!mounted) return;

        setState(() {
          _subscriptionExpiryDate = null;
          _subscriptionDaysRemaining = null;
        });

        return;
      }

      final parsed = DateTime.tryParse(
        rawExpiry.trim(),
      );

      if (parsed == null) {
        if (!mounted) return;

        setState(() {
          _subscriptionExpiryDate = null;
          _subscriptionDaysRemaining = null;
        });

        return;
      }

      final now = DateTime.now();

      final today = DateTime(
        now.year,
        now.month,
        now.day,
      );

      final expiryDate = DateTime(
        parsed.year,
        parsed.month,
        parsed.day,
      );

      int daysRemaining =
          expiryDate.difference(today).inDays;

      if (daysRemaining < 0) {
        daysRemaining = 0;
      }

      if (!mounted) return;

      setState(() {
        _subscriptionExpiryDate = expiryDate;
        _subscriptionDaysRemaining = daysRemaining;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _subscriptionExpiryDate = null;
        _subscriptionDaysRemaining = null;
      });
    }
  }

  String _subscriptionText() {
    final days = _subscriptionDaysRemaining;

    if (days == null) {
      return 'اشتراك: غير متوفر';
    }

    if (days == 0) {
      return 'الاشتراك منتهي';
    }

    if (days == 1) {
      return 'متبقي يوم واحد';
    }

    if (days == 2) {
      return 'متبقي يومان';
    }

    return 'متبقي $days يوم';
  }

  Color _subscriptionColor() {
    final days = _subscriptionDaysRemaining;

    if (days == null) {
      return Colors.white54;
    }

    if (days <= 0) {
      return Colors.redAccent;
    }

    if (days <= 3) {
      return Colors.orangeAccent;
    }

    return Colors.greenAccent;
  }

  String _formatSubscriptionDate() {
    final date = _subscriptionExpiryDate;

    if (date == null) {
      return 'تاريخ الانتهاء غير متوفر';
    }

    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();

    return '$day/$month/$year';
  }

  // ---------------------------------------------------------------------------
  // FastTrack
  // ---------------------------------------------------------------------------

  Future<void> _checkFastTrackWarning() async {
    final router = _router;

    if (router == null) {
      return;
    }

    try {
      final response = await router.sendCommand(
        '/ip/firewall/filter/print',
      );

      final rules = _asMapList(response);

      int count = 0;

      for (final rule in rules) {
        final action = rule['action']?.toString().trim();
        final disabled =
            rule['disabled']?.toString().toLowerCase();

        final isDisabled =
            disabled == 'true' ||
            disabled == 'yes' ||
            disabled == '1';

        if (action == 'fasttrack-connection' &&
            !isDisabled) {
          count++;
        }
      }

      if (!mounted) return;

      setState(() {
        _fastTrackDetected = count > 0;
        _fastTrackRulesCount = count;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _fastTrackDetected = false;
        _fastTrackRulesCount = 0;
      });
    }
  }

  // ---------------------------------------------------------------------------
  // Check active configurations
  // ---------------------------------------------------------------------------

  Future<void> _checkActivePriorities({
    bool showLoader = true,
  }) async {
    final router = _router;

    if (router == null) {
      return;
    }

    if (showLoader && mounted) {
      setState(() => _loading = true);
    }

    try {
      final queueResponse =
          await router.sendCommand('/queue/tree/print');

      final mangleResponse =
          await router.sendCommand('/ip/firewall/mangle/print');

      final queues = _asMapList(queueResponse);
      final mangleRules = _asMapList(mangleResponse);

      if (!mounted) return;

      setState(() {
        for (final app in _apps) {
          final comment = _commentFor(app);

          final downQueue = _findByField(
            queues,
            'name',
            _downQueueNameFor(app),
          );

          final upQueue = _findByField(
            queues,
            'name',
            _upQueueNameFor(app),
          );

          final connExists =
              mangleRules.any(
            (rule) =>
                rule['comment']?.toString() == comment &&
                rule['action']?.toString() ==
                    'mark-connection',
          );

          final downPackExists =
              mangleRules.any(
            (rule) =>
                rule['comment']?.toString() == comment &&
                rule['action']?.toString() ==
                    'mark-packet' &&
                rule['new-packet-mark']?.toString() ==
                    _downPackMarkFor(app),
          );

          final upPackExists =
              mangleRules.any(
            (rule) =>
                rule['comment']?.toString() == comment &&
                rule['action']?.toString() ==
                    'mark-packet' &&
                rule['new-packet-mark']?.toString() ==
                    _upPackMarkFor(app),
          );

          app.isEnabled =
              connExists &&
              downPackExists &&
              upPackExists &&
              downQueue != null &&
              upQueue != null;

          app.currentDownloadLimit =
              downQueue?['max-limit']?.toString() ?? '';

          app.currentUploadLimit =
              upQueue?['max-limit']?.toString() ?? '';

          if (downQueue != null) {
            final parent =
                downQueue['parent']?.toString();

            if (parent != null &&
                parent.isNotEmpty) {
              app.downloadParent = parent;
            }
          }

          if (upQueue != null) {
            final parent =
                upQueue['parent']?.toString();

            if (parent != null &&
                parent.isNotEmpty) {
              app.uploadParent = parent;
            }
          }
        }
      });
    } catch (_) {
      // تجاهل الخطأ حتى لا تتأثر الشاشة
    } finally {
      if (mounted && showLoader) {
        setState(() => _loading = false);
      }
    }
  }

  // ---------------------------------------------------------------------------
  // FastTrack Confirmation
  // ---------------------------------------------------------------------------

  Future<bool> _showFastTrackWarningDialog() async {
    if (!_fastTrackDetected) {
      return true;
    }

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('تحذير FastTrack'),
        content: Text(
          'تم اكتشاف $_fastTrackRulesCount قاعدة FastTrack مفعلة في الراوتر.\n\n'
          'هذا قد يجعل قواعد Queue Tree لا تعمل كما يجب أو يقلل أثر الأولوية.\n\n'
          'الأفضل تعطيل FastTrack أو استثناء هذا الترافيك منه إذا كنت تريد نتيجة دقيقة.',
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () =>
                Navigator.pop(dialogContext, true),
            child: const Text('متابعة رغم التحذير'),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  // ---------------------------------------------------------------------------
  // Apply Settings
  // ---------------------------------------------------------------------------

  void _applySettingsToApp(
    AppPriorityConfig app, {
    required String downloadMaxLimit,
    required String uploadMaxLimit,
    required String downloadLimitAt,
    required String uploadLimitAt,
    required int priority,
    required bool burstEnabled,
    required String burstDownloadLimit,
    required String burstUploadLimit,
    required String burstDownloadThreshold,
    required String burstUploadThreshold,
    required String burstTime,
    required String lanInterfaceList,
    required String wanInterfaceList,
    required String downloadParent,
    required String uploadParent,
  }) {
    app.downloadMaxLimit =
        downloadMaxLimit;

    app.uploadMaxLimit =
        uploadMaxLimit;

    app.downloadLimitAt =
        downloadLimitAt;

    app.uploadLimitAt =
        uploadLimitAt;

    app.priority = priority;

    app.burstEnabled =
        burstEnabled;

    app.burstDownloadLimit =
        burstDownloadLimit;

    app.burstUploadLimit =
        burstUploadLimit;

    app.burstDownloadThreshold =
        burstDownloadThreshold;

    app.burstUploadThreshold =
        burstUploadThreshold;

    app.burstTime =
        burstTime;

    app.lanInterfaceList =
        lanInterfaceList;

    app.wanInterfaceList =
        wanInterfaceList;

    app.downloadParent =
        downloadParent;

    app.uploadParent =
        uploadParent;
  }

  // ---------------------------------------------------------------------------
  // Remove Existing Rules
  // ---------------------------------------------------------------------------

  Future<void> _removeExistingRulesForApp(
    RouterService router,
    AppPriorityConfig app,
  ) async {
    final comment = _commentFor(app);

    final queueNames = <String>{
      _downQueueNameFor(app),
      _upQueueNameFor(app),
    };

    // -----------------------------
    // Remove Mangle
    // -----------------------------

    final mangleResp = await router.sendCommand(
      '/ip/firewall/mangle/print',
    );

    final mangleRules = _asMapList(mangleResp);

    for (final rule in mangleRules) {
      final ruleComment =
          rule['comment']?.toString();

      if (ruleComment == comment) {
        final id = rule['.id']?.toString();

        if (id != null && id.isNotEmpty) {
          await router.sendCommand(
            '/ip/firewall/mangle/remove',
            params: {
              'numbers': id,
            },
          );
        }
      }
    }

    // -----------------------------
    // Remove Queue Tree
    // -----------------------------

    final queueResp = await router.sendCommand(
      '/queue/tree/print',
    );

    final queueRules = _asMapList(queueResp);

    for (final queue in queueRules) {
      final name =
          queue['name']?.toString();

      final queueComment =
          queue['comment']?.toString();

      if (queueComment == comment ||
          queueNames.contains(name)) {
        final id =
            queue['.id']?.toString();

        if (id != null &&
            id.isNotEmpty) {
          await router.sendCommand(
            '/queue/tree/remove',
            params: {
              'numbers': id,
            },
          );
        }
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Queue Builder
  // ---------------------------------------------------------------------------

  Map<String, String> _buildQueueParams({
    required String name,
    required String parent,
    required String packetMark,
    required String maxLimit,
    required String limitAt,
    required int priority,
    required String comment,
    required bool burstEnabled,
    required String burstLimit,
    required String burstThreshold,
    required String burstTime,
  }) {
    final params = <String, String>{
      'name': name,
      'parent': parent,
      'packet-mark': packetMark,
      'max-limit': maxLimit,
      'limit-at': limitAt,
      'priority': priority.toString(),
      'comment': comment,
    };

    if (burstEnabled) {
      if (burstLimit.trim().isNotEmpty) {
        params['burst-limit'] =
            burstLimit.trim();
      }

      if (burstThreshold.trim().isNotEmpty) {
        params['burst-threshold'] =
            burstThreshold.trim();
      }

      if (burstTime.trim().isNotEmpty) {
        params['burst-time'] =
            burstTime.trim();
      }
    }

    return params;
  }

  // ---------------------------------------------------------------------------
  // Enable App Priority
  // ---------------------------------------------------------------------------

  Future<void> _enableAppPriority(
    AppPriorityConfig app,
  ) async {
    final router = _router;

    if (router == null) {
      _showSnack(
        'لا يوجد اتصال بالراوتر',
        backgroundColor: Colors.red,
      );
      return;
    }

    final downMax =
        _normalizeRateLimit(
          app.downloadMaxLimit,
        );

    final upMax =
        _normalizeRateLimit(
          app.uploadMaxLimit,
        );

    final downAt =
        _normalizeRateLimit(
          app.downloadLimitAt,
        );

    final upAt =
        _normalizeRateLimit(
          app.uploadLimitAt,
        );

    final downBurstLimit =
        _normalizeRateLimit(
          app.burstDownloadLimit,
        );

    final upBurstLimit =
        _normalizeRateLimit(
          app.burstUploadLimit,
        );

    final downBurstThreshold =
        _normalizeRateLimit(
          app.burstDownloadThreshold,
        );

    final upBurstThreshold =
        _normalizeRateLimit(
          app.burstUploadThreshold,
        );

    final burstTime =
        app.burstTime.trim();

    final lanList = app.lanInterfaceList
            .trim()
            .isEmpty
        ? _defaultLanInterfaceList
        : app.lanInterfaceList.trim();

    final wanList = app.wanInterfaceList
            .trim()
            .isEmpty
        ? _defaultWanInterfaceList
        : app.wanInterfaceList.trim();

    final downloadParent =
        app.downloadParent.trim().isEmpty
            ? 'global'
            : app.downloadParent.trim();

    final uploadParent =
        app.uploadParent.trim().isEmpty
            ? 'global'
            : app.uploadParent.trim();

    if (downMax.isEmpty ||
        upMax.isEmpty ||
        downAt.isEmpty ||
        upAt.isEmpty ||
        app.priority < 1 ||
        app.priority > 8 ||
        lanList.isEmpty ||
        wanList.isEmpty) {
      _showSnack(
        'بعض الحقول المطلوبة فارغة',
        backgroundColor: Colors.red,
      );
      return;
    }

    if (!_isValidRateLimit(downMax) ||
        !_isValidRateLimit(upMax) ||
        !_isValidRateLimit(downAt) ||
        !_isValidRateLimit(upAt)) {
      _showSnack(
        'صيغة السرعات غير صحيحة. مثال: 50M أو 100M/20M',
        backgroundColor: Colors.red,
      );
      return;
    }

    if (app.burstEnabled) {
      if (!_isValidRateLimit(
            downBurstLimit,
          ) ||
          !_isValidRateLimit(
            upBurstLimit,
          ) ||
          !_isValidRateLimit(
            downBurstThreshold,
          ) ||
          !_isValidRateLimit(
            upBurstThreshold,
          ) ||
          !_isValidBurstTime(
            burstTime,
          )) {
        _showSnack(
          'إعدادات Burst غير صحيحة',
          backgroundColor: Colors.red,
        );
        return;
      }
    }

    // التأكد من وجود القوائم في الراوتر.
    if (_interfaceLists.isNotEmpty) {
      if (!_interfaceLists.contains(lanList)) {
        _showSnack(
          'قائمة LAN المحددة غير موجودة في الراوتر',
          backgroundColor: Colors.red,
        );
        return;
      }

      if (!_interfaceLists.contains(wanList)) {
        _showSnack(
          'قائمة WAN المحددة غير موجودة في الراوتر',
          backgroundColor: Colors.red,
        );
        return;
      }
    }

    final proceed =
        await _showFastTrackWarningDialog();

    if (!proceed) {
      return;
    }

    if (mounted) {
      setState(() => _loading = true);
    }

    try {
      // ---------------------------------------
      // 1. إزالة القواعد السابقة
      // ---------------------------------------

      await _removeExistingRulesForApp(
        router,
        app,
      );

      final comment =
          _commentFor(app);

      final connMark =
          _connMarkFor(app);

      final downPackMark =
          _downPackMarkFor(app);

      final upPackMark =
          _upPackMarkFor(app);

      // ---------------------------------------
      // 2. Mark Connection
      // ---------------------------------------
      //
      // يتم اكتشاف TLS SNI من أول اتصال TCP
      // ثم يتم تعليم الاتصال بالكامل.
      //
      // لا نستخدم connection-state=new هنا
      // حتى لا نفقد المطابقة عند تفاوت حالة
      // أول حزمة TLS.
      //
      // connection-mark=no-mark يقلل إعادة الفحص
      // للاتصالات التي تم تعليمها مسبقًا.
      //

      for (final host in app.hosts) {
        await router.sendCommand(
          '/ip/firewall/mangle/add',
          params: {
            'chain': 'prerouting',
            'protocol': 'tcp',
            'connection-mark': 'no-mark',
            'tls-host': host,
            'action': 'mark-connection',
            'new-connection-mark': connMark,
            'passthrough': 'yes',
            'comment': comment,
          },
        );
      }

      // ---------------------------------------
      // 3. Download Packet Mark
      // ---------------------------------------
      //
      // الإنترنت يدخل من WAN إلى الراوتر.
      // لذلك:
      //
      // in-interface-list = WAN
      //
      // وهذا هو اتجاه DOWNLOAD.
      //

      await router.sendCommand(
        '/ip/firewall/mangle/add',
        params: {
          'chain': 'prerouting',
          'connection-mark': connMark,
          'in-interface-list': wanList,
          'action': 'mark-packet',
          'new-packet-mark': downPackMark,
          'passthrough': 'no',
          'comment': comment,
        },
      );

      // ---------------------------------------
      // 4. Upload Packet Mark
      // ---------------------------------------
      //
      // العميل يرسل من LAN إلى الإنترنت.
      // لذلك:
      //
      // in-interface-list = LAN
      //
      // وهذا هو اتجاه UPLOAD.
      //

      await router.sendCommand(
        '/ip/firewall/mangle/add',
        params: {
          'chain': 'prerouting',
          'connection-mark': connMark,
          'in-interface-list': lanList,
          'action': 'mark-packet',
          'new-packet-mark': upPackMark,
          'passthrough': 'no',
          'comment': comment,
        },
      );

      // ---------------------------------------
      // 5. Download Queue Tree
      // ---------------------------------------

      final downQueueParams =
          _buildQueueParams(
        name:
            _downQueueNameFor(app),
        parent:
            downloadParent,
        packetMark:
            downPackMark,
        maxLimit:
            downMax,
        limitAt:
            downAt,
        priority:
            app.priority,
        comment:
            comment,
        burstEnabled:
            app.burstEnabled,
        burstLimit:
            downBurstLimit,
        burstThreshold:
            downBurstThreshold,
        burstTime:
            burstTime,
      );

      // ---------------------------------------
      // 6. Upload Queue Tree
      // ---------------------------------------

      final upQueueParams =
          _buildQueueParams(
        name:
            _upQueueNameFor(app),
        parent:
            uploadParent,
        packetMark:
            upPackMark,
        maxLimit:
            upMax,
        limitAt:
            upAt,
        priority:
            app.priority,
        comment:
            comment,
        burstEnabled:
            app.burstEnabled,
        burstLimit:
            upBurstLimit,
        burstThreshold:
            upBurstThreshold,
        burstTime:
            burstTime,
      );

      // ---------------------------------------
      // 7. إنشاء Queue Tree
      // ---------------------------------------

      await router.sendCommand(
        '/queue/tree/add',
        params: downQueueParams,
      );

      await router.sendCommand(
        '/queue/tree/add',
        params: upQueueParams,
      );

      if (mounted) {
        _showSnack(
          'تم تفعيل وتسريع ${app.name} بنجاح',
          backgroundColor: Colors.green,
        );
      }
    } catch (e) {
      if (mounted) {
        _showSnack(
          'حدث خطأ أثناء التفعيل: $e',
          backgroundColor: Colors.red,
        );
      }
    } finally {
      await _checkActivePriorities(
        showLoader: false,
      );

      await _checkFastTrackWarning();

      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Disable App Priority
  // ---------------------------------------------------------------------------

  Future<void> _disableAppPriority(
    AppPriorityConfig app,
  ) async {
    final router = _router;

    if (router == null) {
      _showSnack(
        'لا يوجد اتصال بالراوتر',
        backgroundColor: Colors.red,
      );
      return;
    }

    if (mounted) {
      setState(() => _loading = true);
    }

    try {
      await _removeExistingRulesForApp(
        router,
        app,
      );

      if (mounted) {
        _showSnack(
          'تم إيقاف تسريع ${app.name} وإزالة الرولات',
          backgroundColor: Colors.orange,
        );
      }
    } catch (e) {
      if (mounted) {
        _showSnack(
          'حدث خطأ أثناء الإيقاف: $e',
          backgroundColor: Colors.red,
        );
      }
    } finally {
      await _checkActivePriorities(
        showLoader: false,
      );

      await _checkFastTrackWarning();

      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Loop Protect
  // ---------------------------------------------------------------------------

  Future<void> _confirmFixLoop() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'حماية الشبكة من اللوب (Loop Protect)',
        ),
        content: const Text(
          'هل أنت متأكد من تفعيل بروتوكول الحماية (RSTP) على جميع الجسور (Bridges) وتفعيل حماية المنافذ (Loop-Protect) لجميع كروت الشبكة؟\n'
          'هذا سيقوم بفصل أي راوتر يسبب لوب أوتوماتيكياً.',
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.gold,
            ),
            onPressed: () =>
                Navigator.pop(ctx, true),
            child: const Text(
              'تأكيد وتنفيذ',
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _fixLoop();
    }
  }

  Future<void> _fixLoop() async {
    final router = _router;

    if (router == null) {
      _showSnack(
        'لا يوجد اتصال بالراوتر',
        backgroundColor: Colors.red,
      );
      return;
    }

    if (mounted) {
      setState(() => _loading = true);
    }

    try {
      await router.sendCommand(
        '/interface/bridge/set',
        params: {
          'numbers': '[find]',
          'protocol-mode': 'rstp',
        },
      );

      await router.sendCommand(
        '/interface/ethernet/set',
        params: {
          'numbers': '[find]',
          'loop-protect': 'on',
        },
      );

      _showSnack(
        'تم تفعيل حماية اللوب (RSTP & Loop-Protect) بنجاح',
        backgroundColor: Colors.green,
      );
    } catch (e) {
      _showSnack(
        'حدث خطأ أثناء تفعيل الحماية: $e',
        backgroundColor: Colors.red,
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Telegram
  // ---------------------------------------------------------------------------

  Future<void> _showTelegramBotDialog() async {
    final nameCtrl =
        TextEditingController();

    final ipCtrl =
        TextEditingController();

    final tokenCtrl =
        TextEditingController();

    final chatCtrl =
        TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'إعداد إشعارات البوت للقطع (Netwatch)',
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildField(
                controller: nameCtrl,
                label:
                    'اسم القطعة (مثال: مطعم اليمني)',
              ),
              _buildField(
                controller: ipCtrl,
                label:
                    'IP القطعة (مثال: 192.168.1.10)',
              ),
              _buildField(
                controller: tokenCtrl,
                label:
                    'توكن البوت (Bot Token)',
              ),
              _buildField(
                controller: chatCtrl,
                label:
                    'معرف المحادثة (Chat ID)',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  AppTheme.gold,
            ),
            onPressed: () async {
              Navigator.pop(ctx);

              await _injectTelegramScript(
                nameCtrl.text.trim(),
                ipCtrl.text.trim(),
                tokenCtrl.text.trim(),
                chatCtrl.text.trim(),
              );
            },
            child: const Text(
              'حقن السكربت',
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    nameCtrl.dispose();
    ipCtrl.dispose();
    tokenCtrl.dispose();
    chatCtrl.dispose();
  }

  Future<void> _injectTelegramScript(
    String name,
    String ip,
    String token,
    String chat,
  ) async {
    final router = _router;

    if (router == null) {
      _showSnack(
        'لا يوجد اتصال بالراوتر',
        backgroundColor: Colors.red,
      );
      return;
    }

    if (name.isEmpty ||
        ip.isEmpty ||
        token.isEmpty ||
        chat.isEmpty) {
      _showSnack(
        'الرجاء تعبئة جميع الحقول',
        backgroundColor: Colors.red,
      );
      return;
    }

    if (mounted) {
      setState(() => _loading = true);
    }

    try {
      final upMsg = Uri.encodeComponent(
        '✅ القطعة $name عادت إلى العمل.',
      );

      final downMsg = Uri.encodeComponent(
        '❌ القطعة $name توقفت عن العمل.',
      );

      final upScript =
          '/tool fetch url="https://api.telegram.org/bot$token/sendMessage?chat_id=$chat&text=$upMsg" keep-result=no';

      final downScript =
          '/tool fetch url="https://api.telegram.org/bot$token/sendMessage?chat_id=$chat&text=$downMsg" keep-result=no';

      await router.sendCommand(
        '/tool/netwatch/add',
        params: {
          'host': ip,
          'comment':
              'TelegramBot_$name',
          'up-script': upScript,
          'down-script': downScript,
        },
      );

      _showSnack(
        'تم إضافة السكربت إلى Netwatch بنجاح',
        backgroundColor: Colors.green,
      );
    } catch (e) {
      _showSnack(
        'حدث خطأ أثناء إضافة السكربت: $e',
        backgroundColor: Colors.red,
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  // ---------------------------------------------------------------------------
  // General Field
  // ---------------------------------------------------------------------------

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    String? hint,
    String? Function(String?)? validator,
    TextInputType keyboardType =
        TextInputType.text,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(
        bottom: 10,
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border:
              const OutlineInputBorder(),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Interface Dropdown
  // ---------------------------------------------------------------------------

  Widget _buildInterfaceDropdown({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    String? Function(String?)? validator,
  }) {
    final safeItems = <String>{
      ...items,
      if (value.trim().isNotEmpty) value,
    }.toList();

    final safeValue =
        safeItems.contains(value)
            ? value
            : (safeItems.isNotEmpty
                ? safeItems.first
                : null);

    return Padding(
      padding: const EdgeInsets.only(
        bottom: 10,
      ),
      child: DropdownButtonFormField<String>(
        value: safeValue,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: label,
          border:
              const OutlineInputBorder(),
          prefixIcon: const Icon(
            Icons.account_tree_outlined,
          ),
        ),
        items: safeItems.map((item) {
          return DropdownMenuItem<String>(
            value: item,
            child: Text(item),
          );
        }).toList(),
        validator: validator,
        onChanged: onChanged,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Settings Dialog
  // ---------------------------------------------------------------------------

  Future<bool> _showAppSettingsDialog(
    AppPriorityConfig app,
  ) async {
    final formKey =
        GlobalKey<FormState>();

    final downloadMaxCtrl =
        TextEditingController(
      text: app.downloadMaxLimit,
    );

    final uploadMaxCtrl =
        TextEditingController(
      text: app.uploadMaxLimit,
    );

    final downloadLimitAtCtrl =
        TextEditingController(
      text: app.downloadLimitAt,
    );

    final uploadLimitAtCtrl =
        TextEditingController(
      text: app.uploadLimitAt,
    );

    final priorityCtrl =
        TextEditingController(
      text: app.priority.toString(),
    );

    final downloadParentCtrl =
        TextEditingController(
      text: app.downloadParent,
    );

    final uploadParentCtrl =
        TextEditingController(
      text: app.uploadParent,
    );

    final burstDownloadLimitCtrl =
        TextEditingController(
      text: app.burstDownloadLimit,
    );

    final burstUploadLimitCtrl =
        TextEditingController(
      text: app.burstUploadLimit,
    );

    final burstDownloadThresholdCtrl =
        TextEditingController(
      text: app.burstDownloadThreshold,
    );

    final burstUploadThresholdCtrl =
        TextEditingController(
      text: app.burstUploadThreshold,
    );

    final burstTimeCtrl =
        TextEditingController(
      text: app.burstTime,
    );

    String selectedLan =
        _lanInterfaceLists.contains(
                app.lanInterfaceList)
            ? app.lanInterfaceList
            : _lanInterfaceLists.first;

    String selectedWan =
        _wanInterfaceLists.contains(
                app.wanInterfaceList)
            ? app.wanInterfaceList
            : _wanInterfaceLists.first;

    bool burstEnabled =
        app.burstEnabled;

    bool applyNow = false;

    try {
      final result =
          await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (
              context,
              setDialogState,
            ) {
              void commitValues() {
                final priority =
                    int.tryParse(
                          priorityCtrl.text
                              .trim(),
                        ) ??
                        1;

                _applySettingsToApp(
                  app,
                  downloadMaxLimit:
                      downloadMaxCtrl.text
                          .trim(),
                  uploadMaxLimit:
                      uploadMaxCtrl.text
                          .trim(),
                  downloadLimitAt:
                      downloadLimitAtCtrl
                          .text
                          .trim(),
                  uploadLimitAt:
                      uploadLimitAtCtrl.text
                          .trim(),
                  priority:
                      priority,
                  burstEnabled:
                      burstEnabled,
                  burstDownloadLimit:
                      burstDownloadLimitCtrl
                          .text
                          .trim(),
                  burstUploadLimit:
                      burstUploadLimitCtrl
                          .text
                          .trim(),
                  burstDownloadThreshold:
                      burstDownloadThresholdCtrl
                          .text
                          .trim(),
                  burstUploadThreshold:
                      burstUploadThresholdCtrl
                          .text
                          .trim(),
                  burstTime:
                      burstTimeCtrl.text
                          .trim(),
                  lanInterfaceList:
                      selectedLan,
                  wanInterfaceList:
                      selectedWan,
                  downloadParent:
                      downloadParentCtrl.text
                          .trim(),
                  uploadParent:
                      uploadParentCtrl.text
                          .trim(),
                );

                if (mounted) {
                  setState(() {});
                }
              }

              return AlertDialog(
                title: Text(
                  'إعدادات ${app.name}',
                ),
                content: SizedBox(
                  width: double.maxFinite,
                  child:
                      SingleChildScrollView(
                    child: Form(
                      key: formKey,
                      child: Column(
                        mainAxisSize:
                            MainAxisSize.min,
                        crossAxisAlignment:
                            CrossAxisAlignment
                                .start,
                        children: [
                          const Text(
                            'السرعات الأساسية',
                            style: TextStyle(
                              fontWeight:
                                  FontWeight
                                      .bold,
                            ),
                          ),
                          const SizedBox(
                            height: 8,
                          ),

                          _buildField(
                            controller:
                                downloadMaxCtrl,
                            label:
                                'تحميل Max Limit',
                            hint:
                                'مثال: 100M',
                            validator:
                                _validateRateLimitField,
                          ),

                          _buildField(
                            controller:
                                uploadMaxCtrl,
                            label:
                                'رفع Max Limit',
                            hint:
                                'مثال: 20M',
                            validator:
                                _validateRateLimitField,
                          ),

                          _buildField(
                            controller:
                                downloadLimitAtCtrl,
                            label:
                                'تحميل Limit At',
                            hint:
                                'مثال: 10M',
                            validator:
                                _validateRateLimitField,
                          ),

                          _buildField(
                            controller:
                                uploadLimitAtCtrl,
                            label:
                                'رفع Limit At',
                            hint:
                                'مثال: 2M',
                            validator:
                                _validateRateLimitField,
                          ),

                          _buildField(
                            controller:
                                priorityCtrl,
                            label:
                                'الأولوية',
                            hint:
                                '1 إلى 8',
                            keyboardType:
                                TextInputType
                                    .number,
                            validator:
                                _validatePriorityField,
                          ),

                          const SizedBox(
                            height: 8,
                          ),

                          const Text(
                            'اتجاهات الشبكة',
                            style: TextStyle(
                              fontWeight:
                                  FontWeight
                                      .bold,
                            ),
                          ),

                          const SizedBox(
                            height: 6,
                          ),

                          const Text(
                            'اختر قائمة LAN الخاصة بالعملاء وقائمة WAN الخاصة بالإنترنت. لا تكتب الاسم يدويًا.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors
                                  .white54,
                            ),
                          ),

                          const SizedBox(
                            height: 8,
                          ),

                          _buildInterfaceDropdown(
                            label:
                                'قائمة LAN',
                            value:
                                selectedLan,
                            items:
                                _lanInterfaceLists,
                            validator:
                                (value) =>
                                    _validateInterfaceList(
                              value,
                              _lanInterfaceLists,
                            ),
                            onChanged:
                                (value) {
                              if (value ==
                                  null) {
                                return;
                              }

                              setDialogState(() {
                                selectedLan =
                                    value;
                              });
                            },
                          ),

                          _buildInterfaceDropdown(
                            label:
                                'قائمة WAN',
                            value:
                                selectedWan,
                            items:
                                _wanInterfaceLists,
                            validator:
                                (value) =>
                                    _validateInterfaceList(
                              value,
                              _wanInterfaceLists,
                            ),
                            onChanged:
                                (value) {
                              if (value ==
                                  null) {
                                return;
                              }

                              setDialogState(() {
                                selectedWan =
                                    value;
                              });
                            },
                          ),

                          const SizedBox(
                            height: 8,
                          ),

                          const Text(
                            'الـQueue Tree',
                            style: TextStyle(
                              fontWeight:
                                  FontWeight
                                      .bold,
                            ),
                          ),

                          const SizedBox(
                            height: 8,
                          ),

                          _buildField(
                            controller:
                                downloadParentCtrl,
                            label:
                                'Parent للتحميل',
                            hint:
                                'مثال: global',
                            validator:
                                _validateNonEmptyField,
                          ),

                          _buildField(
                            controller:
                                uploadParentCtrl,
                            label:
                                'Parent للرفع',
                            hint:
                                'مثال: global',
                            validator:
                                _validateNonEmptyField,
                          ),

                          const SizedBox(
                            height: 8,
                          ),

                          CheckboxListTile(
                            contentPadding:
                                EdgeInsets
                                    .zero,
                            value:
                                burstEnabled,
                            onChanged:
                                (value) {
                              setDialogState(() {
                                burstEnabled =
                                    value ??
                                        false;
                              });
                            },
                            title:
                                const Text(
                              'تفعيل Burst',
                            ),
                            subtitle:
                                const Text(
                              'يعطي دفعة سرعة مؤقتة فوق الحد الأساسي إذا كان هناك هامش متاح',
                            ),
                            controlAffinity:
                                ListTileControlAffinity
                                    .leading,
                          ),

                          if (burstEnabled) ...[
                            const SizedBox(
                              height: 8,
                            ),
                            const Text(
                              'إعدادات Burst',
                              style:
                                  TextStyle(
                                fontWeight:
                                    FontWeight
                                        .bold,
                              ),
                            ),
                            const SizedBox(
                              height: 8,
                            ),

                            _buildField(
                              controller:
                                  burstDownloadLimitCtrl,
                              label:
                                  'Burst Limit للتحميل',
                              hint:
                                  'مثال: 120M',
                              validator:
                                  _validateRateLimitField,
                            ),

                            _buildField(
                              controller:
                                  burstUploadLimitCtrl,
                              label:
                                  'Burst Limit للرفع',
                              hint:
                                  'مثال: 25M',
                              validator:
                                  _validateRateLimitField,
                            ),

                            _buildField(
                              controller:
                                  burstDownloadThresholdCtrl,
                              label:
                                  'Burst Threshold للتحميل',
                              hint:
                                  'مثال: 70M',
                              validator:
                                  _validateRateLimitField,
                            ),

                            _buildField(
                              controller:
                                  burstUploadThresholdCtrl,
                              label:
                                  'Burst Threshold للرفع',
                              hint:
                                  'مثال: 15M',
                              validator:
                                  _validateRateLimitField,
                            ),

                            _buildField(
                              controller:
                                  burstTimeCtrl,
                              label:
                                  'Burst Time',
                              hint:
                                  'مثال: 20s أو 500ms',
                              validator:
                                  _validateBurstTimeField,
                            ),
                          ],

                          const SizedBox(
                            height: 8,
                          ),

                          const Text(
                            'ملاحظة: التسريع يعتمد على تطابق النطاقات مع الترافيك الفعلي. بعض التطبيقات تستخدم UDP/QUIC أو IPs متغيرة، لذلك قد لا تتأثر جميع الاتصالات عبر tls-host.',
                            style:
                                TextStyle(
                              fontSize:
                                  12,
                              color: Colors
                                  .white54,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () =>
                        Navigator.pop(
                      dialogContext,
                      false,
                    ),
                    child:
                        const Text(
                      'إلغاء',
                    ),
                  ),

                  OutlinedButton(
                    onPressed: () {
                      if (formKey
                              .currentState
                              ?.validate() ??
                          false) {
                        commitValues();

                        applyNow =
                            false;

                        Navigator.pop(
                          dialogContext,
                          false,
                        );
                      }
                    },
                    child:
                        const Text(
                      'حفظ فقط',
                    ),
                  ),

                  ElevatedButton(
                    style:
                        ElevatedButton.styleFrom(
                      backgroundColor:
                          AppTheme.gold,
                    ),
                    onPressed: () {
                      if (formKey
                              .currentState
                              ?.validate() ??
                          false) {
                        commitValues();

                        applyNow =
                            true;

                        Navigator.pop(
                          dialogContext,
                          true,
                        );
                      }
                    },
                    child: const Text(
                      'حفظ وتطبيق',
                      style:
                          TextStyle(
                        color:
                            Colors.black,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      );

      if (result == null) {
        return false;
      }

      return applyNow || result;
    } finally {
      downloadMaxCtrl.dispose();
      uploadMaxCtrl.dispose();
      downloadLimitAtCtrl.dispose();
      uploadLimitAtCtrl.dispose();
      priorityCtrl.dispose();
      downloadParentCtrl.dispose();
      uploadParentCtrl.dispose();
      burstDownloadLimitCtrl.dispose();
      burstUploadLimitCtrl.dispose();
      burstDownloadThresholdCtrl.dispose();
      burstUploadThresholdCtrl.dispose();
      burstTimeCtrl.dispose();
    }
  }

  // ---------------------------------------------------------------------------
  // Settings Open
  // ---------------------------------------------------------------------------

  Future<void> _openSettingsForApp(
    AppPriorityConfig app,
  ) async {
    final apply =
        await _showAppSettingsDialog(
      app,
    );

    if (!mounted) return;

    if (apply && app.isEnabled) {
      await _enableAppPriority(app);
    }
  }

  Future<void> _showEnableFlow(
    AppPriorityConfig app,
  ) async {
    final apply =
        await _showAppSettingsDialog(
      app,
    );

    if (!mounted) return;

    if (apply) {
      await _enableAppPriority(app);
    }
  }

  // ---------------------------------------------------------------------------
  // Disable Confirmation
  // ---------------------------------------------------------------------------

  Future<void>
      _showDisableConfirmDialog(
    AppPriorityConfig app,
  ) async {
    final result =
        await showDialog<bool>(
      context: context,
      builder: (dialogContext) =>
          AlertDialog(
        title: const Text(
          'تأكيد الإيقاف',
        ),
        content: Text(
          'هل أنت متأكد من إيقاف تسريع ${app.name}؟\n'
          'سيتم حذف جميع رولات الـ Mangle والـ Queue Tree المرتبطة به تلقائياً.',
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.pop(
              dialogContext,
              false,
            ),
            child:
                const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton
                .styleFrom(
              backgroundColor:
                  Colors.red,
            ),
            onPressed: () =>
                Navigator.pop(
              dialogContext,
              true,
            ),
            child: const Text(
              'إيقاف وحذف',
              style: TextStyle(
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );

    if (result == true) {
      await _disableAppPriority(
        app,
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Info Card
  // ---------------------------------------------------------------------------

  Widget _buildInfoCard() {
    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(
        bottom: 12,
      ),
      shape:
          RoundedRectangleBorder(
        borderRadius:
            BorderRadius.circular(
          12,
        ),
      ),
      child: const Padding(
        padding:
            EdgeInsets.all(12.0),
        child: Text(
          'هذه الصفحة تضبط أولوية المرور للتطبيقات عبر قواعد Mangle و Queue Tree.\n'
          'يتم تعليم الاتصال أولًا ثم تعليم الحزم حسب اتجاه LAN/WAN، وبعدها يتم تمرير packet-mark إلى Queue Tree.\n'
          'إذا كان الراوتر يستخدم FastTrack فراجع التحذير أعلى الصفحة.',
          style: TextStyle(
            fontSize: 13,
            color:
                Colors.white70,
            height: 1.4,
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Subscription Card
  // ---------------------------------------------------------------------------

  Widget _buildSubscriptionCard() {
    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(
        bottom: 12,
      ),
      shape:
          RoundedRectangleBorder(
        borderRadius:
            BorderRadius.circular(
          12,
        ),
        side: BorderSide(
          color: _subscriptionColor()
              .withOpacity(0.35),
        ),
      ),
      child: Padding(
        padding:
            const EdgeInsets.all(
          12,
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor:
                  _subscriptionColor()
                      .withOpacity(
                0.15,
              ),
              child: Icon(
                Icons
                    .calendar_month_rounded,
                color:
                    _subscriptionColor(),
              ),
            ),
            const SizedBox(
              width: 10,
            ),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment
                        .start,
                children: [
                  const Text(
                    'حالة الاشتراك',
                    style:
                        TextStyle(
                      fontWeight:
                          FontWeight
                              .bold,
                    ),
                  ),
                  const SizedBox(
                    height: 3,
                  ),
                  Text(
                    _subscriptionText(),
                    style:
                        TextStyle(
                      color:
                          _subscriptionColor(),
                      fontWeight:
                          FontWeight
                              .bold,
                    ),
                  ),
                  if (_subscriptionExpiryDate !=
                      null)
                    Padding(
                      padding:
                          const EdgeInsets.only(
                        top: 3,
                      ),
                      child: Text(
                        'ينتهي بتاريخ ${_formatSubscriptionDate()}',
                        style:
                            const TextStyle(
                          fontSize:
                              12,
                          color:
                              Colors.white54,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            IconButton(
              tooltip:
                  'تحديث الاشتراك',
              onPressed:
                  _loading
                      ? null
                      : _loadSubscriptionCounter,
              icon:
                  const Icon(
                Icons.refresh,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // FastTrack Card
  // ---------------------------------------------------------------------------

  Widget _buildFastTrackCard() {
    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(
        bottom: 12,
      ),
      shape:
          RoundedRectangleBorder(
        side: const BorderSide(
          color:
              Colors.orangeAccent,
          width: 1,
        ),
        borderRadius:
            BorderRadius.circular(
          12,
        ),
      ),
      child: Padding(
        padding:
            const EdgeInsets.all(
          12.0,
        ),
        child: Row(
          crossAxisAlignment:
              CrossAxisAlignment
                  .start,
          children: [
            const Icon(
              Icons
                  .warning_amber_rounded,
              color:
                  Colors.orangeAccent,
            ),
            const SizedBox(
              width: 10,
            ),
            Expanded(
              child: Text(
                'تم اكتشاف FastTrack مفعلًا ($_fastTrackRulesCount).\n'
                'قد يؤدي ذلك إلى تجاوز بعض قواعد Queue Tree أو تقليل أثر الأولوية.',
                style:
                    const TextStyle(
                  color:
                      Colors.orangeAccent,
                ),
              ),
            ),
            TextButton(
              onPressed:
                  _checkFastTrackWarning,
              child:
                  const Text('فحص'),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Application Card
  // ---------------------------------------------------------------------------

  Widget _buildAppCard(
    AppPriorityConfig app,
  ) {
    final routerAvailable =
        _hasRouter;

    final switchEnabled =
        routerAvailable &&
            !_loading;

    return Card(
      elevation:
          app.isEnabled ? 4 : 1,
      shape:
          RoundedRectangleBorder(
        side: BorderSide(
          color: app.isEnabled
              ? app.color
              : Colors.transparent,
          width: 1.5,
        ),
        borderRadius:
            BorderRadius.circular(
          12,
        ),
      ),
      margin:
          const EdgeInsets.symmetric(
        vertical: 8,
      ),
      child: Padding(
        padding:
            const EdgeInsets.all(
          8.0,
        ),
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor:
                app.color.withOpacity(
              0.2,
            ),
            child: Icon(
              app.icon,
              color: app.color,
            ),
          ),
          title: Text(
            app.name,
            style:
                const TextStyle(
              fontWeight:
                  FontWeight.bold,
              color:
                  Colors.white,
            ),
          ),
          subtitle:
              Column(
            crossAxisAlignment:
                CrossAxisAlignment
                    .start,
            children: [
              const SizedBox(
                height: 4,
              ),
              Text(
                app.isEnabled
                    ? 'الحالة: مفعل ونشط'
                    : 'الحالة: معطل',
                style: TextStyle(
                  color: app.isEnabled
                      ? Colors.greenAccent
                      : Colors.white54,
                ),
              ),
              const SizedBox(
                height: 4,
              ),
              Text(
                'الإعداد: DL ${app.downloadMaxLimit} | UL ${app.uploadMaxLimit} | LimitAt ${app.downloadLimitAt}/${app.uploadLimitAt} | Priority ${app.priority}',
                style:
                    const TextStyle(
                  color:
                      Colors.white54,
                  fontSize:
                      12,
                ),
              ),
              const SizedBox(
                height: 4,
              ),
              Text(
                'LAN: ${app.lanInterfaceList} | WAN: ${app.wanInterfaceList}',
                style:
                    const TextStyle(
                  color:
                      Colors.white54,
                  fontSize:
                      12,
                ),
              ),
              if (app.isEnabled) ...[
                const SizedBox(
                  height: 4,
                ),
                Text(
                  'السرعة الفعلية: DL ${app.currentDownloadLimit.isEmpty ? 'غير محدد' : app.currentDownloadLimit} | UL ${app.currentUploadLimit.isEmpty ? 'غير محدد' : app.currentUploadLimit}',
                  style:
                      const TextStyle(
                    color:
                        AppTheme.gold,
                    fontSize:
                        12,
                  ),
                ),
              ],
            ],
          ),
          trailing:
              SizedBox(
            width: 108,
            child: Row(
              mainAxisSize:
                  MainAxisSize.min,
              children: [
                IconButton(
                  visualDensity:
                      VisualDensity
                          .compact,
                  tooltip:
                      'الإعدادات',
                  onPressed:
                      _loading
                          ? null
                          : () =>
                              _openSettingsForApp(
                                app,
                              ),
                  icon:
                      const Icon(
                    Icons.tune,
                  ),
                ),
                Switch(
                  value:
                      app.isEnabled,
                  activeColor:
                      app.color,
                  onChanged:
                      switchEnabled
                          ? (bool
                              val) {
                              if (val) {
                                _showEnableFlow(
                                  app,
                                );
                              } else {
                                _showDisableConfirmDialog(
                                  app,
                                );
                              }
                            }
                          : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(
    BuildContext context,
  ) {
    final children =
        <Widget>[
      _buildSubscriptionCard(),
      _buildInfoCard(),
      if (_fastTrackDetected)
        _buildFastTrackCard(),
      ..._apps.map(
        _buildAppCard,
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'أولوية وتسريع التطبيقات',
        ),
        actions: [
          IconButton(
            icon:
                const Icon(
              Icons.refresh,
              color:
                  AppTheme.gold,
            ),
            onPressed:
                _loading
                    ? null
                    : _refreshAll,
            tooltip:
                'تحديث الحالة',
          ),

          PopupMenuButton<
              ExtraMenu>(
            icon:
                const Icon(
              Icons.more_vert,
            ),
            onSelected:
                (value) {
              if (value ==
                  ExtraMenu.fixLoop) {
                _confirmFixLoop();
              } else if (value ==
                  ExtraMenu
                      .telegramBot) {
                _showTelegramBotDialog();
              }
            },
            itemBuilder:
                (context) =>
                    [
              const PopupMenuItem(
                value:
                    ExtraMenu.fixLoop,
                child:
                    Text(
                  'حماية الشبكة من اللوب (Loop Protect)',
                ),
              ),
              const PopupMenuItem(
                value:
                    ExtraMenu
                        .telegramBot,
                child:
                    Text(
                  'إضافة بوت تيليجرام (إشعارات الأجهزة)',
                ),
              ),
            ],
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child:
                  CircularProgressIndicator(
                color:
                    AppTheme.gold,
              ),
            )
          : ListView(
              padding:
                  const EdgeInsets
                      .all(
                8.0,
              ),
              children:
                  children,
            ),
    );
  }
}
