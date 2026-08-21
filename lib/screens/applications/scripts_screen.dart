import 'package:flutter/material.dart';
import 'package:st_manager/services/router_service.dart';
import 'package:st_manager/theme/app_theme.dart';

/// اسم قائمة الواجهات الخارجية في الراوتر.
/// إذا كان اسم WAN عندك مختلفًا غيّره هنا فقط من واجهة الإعداد لكل تطبيق.
const String _defaultWanInterfaceList = 'WAN';

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

  String inInterfaceList;
  String outInterfaceList;
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
    this.inInterfaceList = _defaultWanInterfaceList,
    this.outInterfaceList = _defaultWanInterfaceList,
    // تم الإصلاح ليتناسب مع ميكروتك بإصداراته 6 و 7 حيث تم دمجها في global
    this.downloadParent = 'global',
    this.uploadParent = 'global',
  });
}

enum ExtraMenu { openSpeed, telegramBot }

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
      hosts: ['*discord.com*', '*discord.gg*', '*discordapp.com*', '*discordapp.net*'],
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

  String _commentFor(AppPriorityConfig app) => 'AppManager_${app.id}';
  String _connMarkFor(AppPriorityConfig app) => 'conn_${app.id}';
  String _downPackMarkFor(AppPriorityConfig app) => 'pack_${app.id}_down';
  String _upPackMarkFor(AppPriorityConfig app) => 'pack_${app.id}_up';
  String _downQueueNameFor(AppPriorityConfig app) => 'Priority_${app.id}_down';
  String _upQueueNameFor(AppPriorityConfig app) => 'Priority_${app.id}_up';

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

  List<Map<String, dynamic>> _asMapList(dynamic response) {
    if (response is List) {
      return response.whereType<Map>().map((item) {
        return item.map((key, value) => MapEntry(key.toString(), value));
      }).toList();
    }

    if (response is Map && response['data'] is List) {
      final data = response['data'] as List;
      return data.whereType<Map>().map((item) {
        return item.map((key, value) => MapEntry(key.toString(), value));
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

  bool _isValidRateLimit(String value) {
    final cleaned = value.replaceAll(' ', '').trim();
    return RegExp(
      r'^\d+(\.\d+)?[KkMmGg]?(?:/\d+(\.\d+)?[KkMmGg]?)?$',
    ).hasMatch(cleaned);
  }

  bool _isValidBurstTime(String value) {
    final cleaned = value.replaceAll(' ', '').trim();
    return RegExp(r'^\d+(ms|s|m|h)$').hasMatch(cleaned);
  }

  String _normalizeRateLimit(String value) {
    return value.replaceAll(' ', '').trim();
  }

  String? _validateRateLimitField(String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return 'هذا الحقل مطلوب';
    if (!_isValidRateLimit(v)) return 'صيغة غير صحيحة';
    return null;
  }

  String? _validatePriorityField(String? value) {
    final v = int.tryParse((value ?? '').trim());
    if (v == null) return 'أدخل رقمًا من 1 إلى 8';
    if (v < 1 || v > 8) return 'الأولوية يجب أن تكون من 1 إلى 8';
    return null;
  }

  String? _validateBurstTimeField(String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return 'هذا الحقل مطلوب';
    if (!_isValidBurstTime(v)) return 'مثال: 20s أو 500ms';
    return null;
  }

  String? _validateNonEmptyField(String? value) {
    if ((value ?? '').trim().isEmpty) return 'هذا الحقل مطلوب';
    return null;
  }

  Future<void> _refreshAll() async {
    if (mounted) {
      setState(() => _loading = true);
    }

    await _checkActivePriorities(showLoader: false);
    await _checkFastTrackWarning();

    if (mounted) {
      setState(() => _loading = false);
    }
  }

  Future<void> _checkFastTrackWarning() async {
    final router = _router;
    if (router == null) return;

    try {
      final response = await router.sendCommand('/ip/firewall/filter/print');
      final rules = _asMapList(response);

      int count = 0;
      for (final rule in rules) {
        final action = rule['action']?.toString().trim();
        final disabled = rule['disabled']?.toString().toLowerCase();
        final isDisabled = disabled == 'true' || disabled == 'yes' || disabled == '1';

        if (action == 'fasttrack-connection' && !isDisabled) {
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

  Future<void> _checkActivePriorities({bool showLoader = true}) async {
    final router = _router;
    if (router == null) return;

    if (showLoader && mounted) {
      setState(() => _loading = true);
    }

    try {
      final queueResponse = await router.sendCommand('/queue/tree/print');
      final mangleResponse = await router.sendCommand('/ip/firewall/mangle/print');

      final queues = _asMapList(queueResponse);
      final mangleRules = _asMapList(mangleResponse);

      if (!mounted) return;

      setState(() {
        for (final app in _apps) {
          final comment = _commentFor(app);

          final downQueue = _findByField(queues, 'name', _downQueueNameFor(app));
          final upQueue = _findByField(queues, 'name', _upQueueNameFor(app));

          final connExists = _findByField(mangleRules, 'comment', comment) != null;
          final downPackExists = _findByField(
                mangleRules,
                'new-packet-mark',
                _downPackMarkFor(app),
              ) !=
              null;
          final upPackExists = _findByField(
                mangleRules,
                'new-packet-mark',
                _upPackMarkFor(app),
              ) !=
              null;

          app.isEnabled =
              connExists && downPackExists && upPackExists && downQueue != null && upQueue != null;

          app.currentDownloadLimit = downQueue?['max-limit']?.toString() ?? '';
          app.currentUploadLimit = upQueue?['max-limit']?.toString() ?? '';
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

  Future<bool> _showFastTrackWarningDialog() async {
    if (!_fastTrackDetected) return true;

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
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('متابعة رغم التحذير'),
          ),
        ],
      ),
    );

    return result ?? false;
  }

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
    required String inInterfaceList,
    required String outInterfaceList,
    required String downloadParent,
    required String uploadParent,
  }) {
    app.downloadMaxLimit = downloadMaxLimit;
    app.uploadMaxLimit = uploadMaxLimit;
    app.downloadLimitAt = downloadLimitAt;
    app.uploadLimitAt = uploadLimitAt;
    app.priority = priority;
    app.burstEnabled = burstEnabled;
    app.burstDownloadLimit = burstDownloadLimit;
    app.burstUploadLimit = burstUploadLimit;
    app.burstDownloadThreshold = burstDownloadThreshold;
    app.burstUploadThreshold = burstUploadThreshold;
    app.burstTime = burstTime;
    app.inInterfaceList = inInterfaceList;
    app.outInterfaceList = outInterfaceList;
    app.downloadParent = downloadParent;
    app.uploadParent = uploadParent;
  }

  Future<void> _removeExistingRulesForApp(
    RouterService router,
    AppPriorityConfig app,
  ) async {
    final comment = _commentFor(app);
    final queueNames = <String>{
      _downQueueNameFor(app),
      _upQueueNameFor(app),
    };

    final mangleResp = await router.sendCommand('/ip/firewall/mangle/print');
    final mangleRules = _asMapList(mangleResp);

    for (final rule in mangleRules) {
      final ruleComment = rule['comment']?.toString();
      if (ruleComment == comment) {
        final id = rule['.id']?.toString();
        if (id != null && id.isNotEmpty) {
          await router.sendCommand(
            '/ip/firewall/mangle/remove',
            params: {'numbers': id},
          );
        }
      }
    }

    final queueResp = await router.sendCommand('/queue/tree/print');
    final queueRules = _asMapList(queueResp);

    for (final q in queueRules) {
      final name = q['name']?.toString();
      final matchesComment = q['comment']?.toString() == comment;
      if (matchesComment || queueNames.contains(name)) {
        final id = q['.id']?.toString();
        if (id != null && id.isNotEmpty) {
          await router.sendCommand(
            '/queue/tree/remove',
            params: {'numbers': id},
          );
        }
      }
    }
  }

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
        params['burst-limit'] = burstLimit.trim();
      }
      if (burstThreshold.trim().isNotEmpty) {
        params['burst-threshold'] = burstThreshold.trim();
      }
      if (burstTime.trim().isNotEmpty) {
        params['burst-time'] = burstTime.trim();
      }
    }

    return params;
  }

  Future<void> _enableAppPriority(AppPriorityConfig app) async {
    final router = _router;
    if (router == null) {
      _showSnack('لا يوجد اتصال بالراوتر', backgroundColor: Colors.red);
      return;
    }

    final downMax = _normalizeRateLimit(app.downloadMaxLimit);
    final upMax = _normalizeRateLimit(app.uploadMaxLimit);
    final downAt = _normalizeRateLimit(app.downloadLimitAt);
    final upAt = _normalizeRateLimit(app.uploadLimitAt);
    final downBurstLimit = _normalizeRateLimit(app.burstDownloadLimit);
    final upBurstLimit = _normalizeRateLimit(app.burstUploadLimit);
    final downBurstThreshold = _normalizeRateLimit(app.burstDownloadThreshold);
    final upBurstThreshold = _normalizeRateLimit(app.burstUploadThreshold);
    final burstTime = app.burstTime.trim();
    final inList = app.inInterfaceList.trim().isEmpty ? _defaultWanInterfaceList : app.inInterfaceList.trim();
    final outList = app.outInterfaceList.trim().isEmpty ? _defaultWanInterfaceList : app.outInterfaceList.trim();

    if (downMax.isEmpty ||
        upMax.isEmpty ||
        downAt.isEmpty ||
        upAt.isEmpty ||
        app.priority < 1 ||
        app.priority > 8 ||
        inList.isEmpty ||
        outList.isEmpty) {
      _showSnack('بعض الحقول المطلوبة فارغة', backgroundColor: Colors.red);
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
      if (!_isValidRateLimit(downBurstLimit) ||
          !_isValidRateLimit(upBurstLimit) ||
          !_isValidRateLimit(downBurstThreshold) ||
          !_isValidRateLimit(upBurstThreshold) ||
          !_isValidBurstTime(burstTime)) {
        _showSnack(
          'إعدادات Burst غير صحيحة',
          backgroundColor: Colors.red,
        );
        return;
      }
    }

    final proceed = await _showFastTrackWarningDialog();
    if (!proceed) return;

    setState(() => _loading = true);

    try {
      await _removeExistingRulesForApp(router, app);

      final comment = _commentFor(app);
      final connMark = _connMarkFor(app);
      final downPackMark = _downPackMarkFor(app);
      final upPackMark = _upPackMarkFor(app);

      for (final host in app.hosts) {
        await router.sendCommand('/ip/firewall/mangle/add', params: {
          'chain': 'forward',
          'protocol': 'tcp',
          'connection-state': 'new',
          'tls-host': host,
          'action': 'mark-connection',
          'new-connection-mark': connMark,
          'passthrough': 'yes',
          'comment': comment,
        });
      }

      await router.sendCommand('/ip/firewall/mangle/add', params: {
        'chain': 'forward',
        'connection-mark': connMark,
        'in-interface-list': inList,
        'action': 'mark-packet',
        'new-packet-mark': downPackMark,
        'passthrough': 'no',
        'comment': comment,
      });

      await router.sendCommand('/ip/firewall/mangle/add', params: {
        'chain': 'forward',
        'connection-mark': connMark,
        'out-interface-list': outList,
        'action': 'mark-packet',
        'new-packet-mark': upPackMark,
        'passthrough': 'no',
        'comment': comment,
      });

      final downQueueParams = _buildQueueParams(
        name: _downQueueNameFor(app),
        parent: app.downloadParent.trim().isEmpty ? 'global' : app.downloadParent.trim(),
        packetMark: downPackMark,
        maxLimit: downMax,
        limitAt: downAt,
        priority: app.priority,
        comment: comment,
        burstEnabled: app.burstEnabled,
        burstLimit: downBurstLimit,
        burstThreshold: downBurstThreshold,
        burstTime: burstTime,
      );

      final upQueueParams = _buildQueueParams(
        name: _upQueueNameFor(app),
        parent: app.uploadParent.trim().isEmpty ? 'global' : app.uploadParent.trim(),
        packetMark: upPackMark,
        maxLimit: upMax,
        limitAt: upAt,
        priority: app.priority,
        comment: comment,
        burstEnabled: app.burstEnabled,
        burstLimit: upBurstLimit,
        burstThreshold: upBurstThreshold,
        burstTime: burstTime,
      );

      await router.sendCommand('/queue/tree/add', params: downQueueParams);
      await router.sendCommand('/queue/tree/add', params: upQueueParams);

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
      await _checkActivePriorities(showLoader: false);
      await _checkFastTrackWarning();
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _disableAppPriority(AppPriorityConfig app) async {
    final router = _router;
    if (router == null) {
      _showSnack('لا يوجد اتصال بالراوتر', backgroundColor: Colors.red);
      return;
    }

    setState(() => _loading = true);

    try {
      await _removeExistingRulesForApp(router, app);

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
      await _checkActivePriorities(showLoader: false);
      await _checkFastTrackWarning();
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  // الدوال المضافة لتلبية المطالب الجديدة الخاصة بفتح السرعة وإشعارات البوت
  Future<void> _confirmOpenSpeed() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد فتح السرعات للجميع'),
        content: const Text(
            'هل أنت متأكد من تحويل جميع الحسابات لبروفايل "speed" وطرد جميع المتصلين حالياً (الأكتف) لتطبيق السرعة الجديدة؟'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.gold),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('تأكيد وتنفيذ',
                style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _openSpeedForAll();
    }
  }

  Future<void> _openSpeedForAll() async {
    final router = _router;
    if (router == null) {
      _showSnack('لا يوجد اتصال بالراوتر', backgroundColor: Colors.red);
      return;
    }

    setState(() => _loading = true);
    try {
      // تعديل بروفايلات PPPoE إلى speed
      await router.sendCommand('/ppp/secret/set',
          params: {'numbers': '[find]', 'profile': 'speed'});
      
      // تعديل بروفايلات Hotspot إلى speed
      await router.sendCommand('/ip/hotspot/user/set',
          params: {'numbers': '[find]', 'profile': 'speed'});
      
      // طرد المتصلين حالياً ليتمكنوا من الاتصال بالبروفايل الجديد
      await router.sendCommand('/ppp/active/remove',
          params: {'numbers': '[find]'});
      await router.sendCommand('/ip/hotspot/active/remove',
          params: {'numbers': '[find]'});

      _showSnack('تم فتح السرعات للجميع وطرد الأكتف بنجاح (بروفايل speed)',
          backgroundColor: Colors.green);
    } catch (e) {
      _showSnack('حدث خطأ أثناء فتح السرعات: $e', backgroundColor: Colors.red);
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _showTelegramBotDialog() async {
    final nameCtrl = TextEditingController();
    final ipCtrl = TextEditingController();
    final tokenCtrl = TextEditingController();
    final chatCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إعداد إشعارات البوت للقطع (Netwatch)'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildField(
                  controller: nameCtrl,
                  label: 'اسم القطعة (مثال: مطعم اليمني)'),
              _buildField(
                  controller: ipCtrl,
                  label: 'IP القطعة (مثال: 192.168.1.10)'),
              _buildField(
                  controller: tokenCtrl, label: 'توكن البوت (Bot Token)'),
              _buildField(
                  controller: chatCtrl, label: 'معرف المحادثة (Chat ID)'),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.gold),
            onPressed: () async {
              Navigator.pop(ctx);
              await _injectTelegramScript(
                nameCtrl.text.trim(),
                ipCtrl.text.trim(),
                tokenCtrl.text.trim(),
                chatCtrl.text.trim(),
              );
            },
            child: const Text('حقن السكربت',
                style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _injectTelegramScript(
      String name, String ip, String token, String chat) async {
    final router = _router;
    if (router == null) {
      _showSnack('لا يوجد اتصال بالراوتر', backgroundColor: Colors.red);
      return;
    }

    if (name.isEmpty || ip.isEmpty || token.isEmpty || chat.isEmpty) {
      _showSnack('الرجاء تعبئة جميع الحقول', backgroundColor: Colors.red);
      return;
    }

    setState(() => _loading = true);
    try {
      // تجهيز النصوص وتشفيرها لـ URL لتصل بشكل صحيح للتليجرام
      String upMsg = Uri.encodeComponent("✅ القطعة $name عادت إلى العمل.");
      String downMsg = Uri.encodeComponent("❌ القطعة $name توقفت عن العمل.");

      // بناء أوامر الـ Script الخاصة بالـ Fetch 
      String upScript =
          '/tool fetch url="https://api.telegram.org/bot$token/sendMessage?chat_id=$chat&text=$upMsg" keep-result=no';
      String downScript =
          '/tool fetch url="https://api.telegram.org/bot$token/sendMessage?chat_id=$chat&text=$downMsg" keep-result=no';

      // إضافة الـ Netwatch للراوتر
      await router.sendCommand('/tool/netwatch/add', params: {
        'host': ip,
        'comment': 'TelegramBot_$name',
        'up-script': upScript,
        'down-script': downScript,
      });

      _showSnack('تم إضافة السكربت إلى Netwatch بنجاح',
          backgroundColor: Colors.green);
    } catch (e) {
      _showSnack('حدث خطأ أثناء إضافة السكربت: $e',
          backgroundColor: Colors.red);
    } finally {
      setState(() => _loading = false);
    }
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    String? hint,
    String? Function(String?)? validator,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  Future<bool> _showAppSettingsDialog(AppPriorityConfig app) async {
    final formKey = GlobalKey<FormState>();

    final downloadMaxCtrl = TextEditingController(text: app.downloadMaxLimit);
    final uploadMaxCtrl = TextEditingController(text: app.uploadMaxLimit);
    final downloadLimitAtCtrl = TextEditingController(text: app.downloadLimitAt);
    final uploadLimitAtCtrl = TextEditingController(text: app.uploadLimitAt);
    final priorityCtrl = TextEditingController(text: app.priority.toString());

    final inInterfaceCtrl = TextEditingController(text: app.inInterfaceList);
    final outInterfaceCtrl = TextEditingController(text: app.outInterfaceList);
    final downloadParentCtrl = TextEditingController(text: app.downloadParent);
    final uploadParentCtrl = TextEditingController(text: app.uploadParent);

    final burstDownloadLimitCtrl = TextEditingController(text: app.burstDownloadLimit);
    final burstUploadLimitCtrl = TextEditingController(text: app.burstUploadLimit);
    final burstDownloadThresholdCtrl = TextEditingController(text: app.burstDownloadThreshold);
    final burstUploadThresholdCtrl = TextEditingController(text: app.burstUploadThreshold);
    final burstTimeCtrl = TextEditingController(text: app.burstTime);

    bool burstEnabled = app.burstEnabled;
    bool applyNow = false;

    try {
      final result = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              void commitValues() {
                final priority = int.tryParse(priorityCtrl.text.trim()) ?? 1;

                _applySettingsToApp(
                  app,
                  downloadMaxLimit: downloadMaxCtrl.text.trim(),
                  uploadMaxLimit: uploadMaxCtrl.text.trim(),
                  downloadLimitAt: downloadLimitAtCtrl.text.trim(),
                  uploadLimitAt: uploadLimitAtCtrl.text.trim(),
                  priority: priority,
                  burstEnabled: burstEnabled,
                  burstDownloadLimit: burstDownloadLimitCtrl.text.trim(),
                  burstUploadLimit: burstUploadLimitCtrl.text.trim(),
                  burstDownloadThreshold: burstDownloadThresholdCtrl.text.trim(),
                  burstUploadThreshold: burstUploadThresholdCtrl.text.trim(),
                  burstTime: burstTimeCtrl.text.trim(),
                  inInterfaceList: inInterfaceCtrl.text.trim(),
                  outInterfaceList: outInterfaceCtrl.text.trim(),
                  downloadParent: downloadParentCtrl.text.trim(),
                  uploadParent: uploadParentCtrl.text.trim(),
                );

                if (mounted) {
                  setState(() {});
                }
              }

              return AlertDialog(
                title: Text('إعدادات ${app.name}'),
                content: SizedBox(
                  width: double.maxFinite,
                  child: SingleChildScrollView(
                    child: Form(
                      key: formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'السرعات الأساسية',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          _buildField(
                            controller: downloadMaxCtrl,
                            label: 'تحميل Max Limit',
                            hint: 'مثال: 100M',
                            validator: _validateRateLimitField,
                          ),
                          _buildField(
                            controller: uploadMaxCtrl,
                            label: 'رفع Max Limit',
                            hint: 'مثال: 20M',
                            validator: _validateRateLimitField,
                          ),
                          _buildField(
                            controller: downloadLimitAtCtrl,
                            label: 'تحميل Limit At',
                            hint: 'مثال: 10M',
                            validator: _validateRateLimitField,
                          ),
                          _buildField(
                            controller: uploadLimitAtCtrl,
                            label: 'رفع Limit At',
                            hint: 'مثال: 2M',
                            validator: _validateRateLimitField,
                          ),
                          _buildField(
                            controller: priorityCtrl,
                            label: 'الأولوية',
                            hint: '1 إلى 8',
                            keyboardType: TextInputType.number,
                            validator: _validatePriorityField,
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'الواجهات والمسارات',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          _buildField(
                            controller: inInterfaceCtrl,
                            label: 'Input Interface List',
                            hint: 'مثال: WAN',
                            validator: _validateNonEmptyField,
                          ),
                          _buildField(
                            controller: outInterfaceCtrl,
                            label: 'Output Interface List',
                            hint: 'مثال: WAN',
                            validator: _validateNonEmptyField,
                          ),
                          _buildField(
                            controller: downloadParentCtrl,
                            label: 'Parent للتحميل (مثال: global)',
                            hint: 'مثال: global',
                            validator: _validateNonEmptyField,
                          ),
                          _buildField(
                            controller: uploadParentCtrl,
                            label: 'Parent للرفع (مثال: global)',
                            hint: 'مثال: global',
                            validator: _validateNonEmptyField,
                          ),
                          const SizedBox(height: 8),
                          CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            value: burstEnabled,
                            onChanged: (value) {
                              setDialogState(() {
                                burstEnabled = value ?? false;
                              });
                            },
                            title: const Text('تفعيل Burst'),
                            subtitle: const Text(
                              'يعطي دفعة سرعة مؤقتة فوق الحد الأساسي إذا كان هناك هامش متاح',
                            ),
                            controlAffinity: ListTileControlAffinity.leading,
                          ),
                          if (burstEnabled) ...[
                            const SizedBox(height: 8),
                            const Text(
                              'إعدادات Burst',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            _buildField(
                              controller: burstDownloadLimitCtrl,
                              label: 'Burst Limit للتحميل',
                              hint: 'مثال: 120M',
                              validator: _validateRateLimitField,
                            ),
                            _buildField(
                              controller: burstUploadLimitCtrl,
                              label: 'Burst Limit للرفع',
                              hint: 'مثال: 25M',
                              validator: _validateRateLimitField,
                            ),
                            _buildField(
                              controller: burstDownloadThresholdCtrl,
                              label: 'Burst Threshold للتحميل',
                              hint: 'مثال: 70M',
                              validator: _validateRateLimitField,
                            ),
                            _buildField(
                              controller: burstUploadThresholdCtrl,
                              label: 'Burst Threshold للرفع',
                              hint: 'مثال: 15M',
                              validator: _validateRateLimitField,
                            ),
                            _buildField(
                              controller: burstTimeCtrl,
                              label: 'Burst Time',
                              hint: 'مثال: 20s أو 500ms',
                              validator: _validateBurstTimeField,
                            ),
                          ],
                          const SizedBox(height: 8),
                          const Text(
                            'ملاحظة: التسريع يعتمد على تطابق النطاقات مع الترافيك الفعلي، وبعض التطبيقات قد لا تتأثر بالكامل إذا كانت تستخدم IPs متغيرة أو UDP أو QUIC.',
                            style: TextStyle(fontSize: 12, color: Colors.white54),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext, false),
                    child: const Text('إلغاء'),
                  ),
                  OutlinedButton(
                    onPressed: () {
                      if (formKey.currentState?.validate() ?? false) {
                        commitValues();
                        applyNow = false;
                        Navigator.pop(dialogContext, false);
                      }
                    },
                    child: const Text('حفظ فقط'),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.gold),
                    onPressed: () {
                      if (formKey.currentState?.validate() ?? false) {
                        commitValues();
                        applyNow = true;
                        Navigator.pop(dialogContext, true);
                      }
                    },
                    child: const Text(
                      'حفظ وتطبيق',
                      style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              );
            },
          );
        },
      );

      if (result == null) return false;
      return applyNow || result;
    } finally {
      downloadMaxCtrl.dispose();
      uploadMaxCtrl.dispose();
      downloadLimitAtCtrl.dispose();
      uploadLimitAtCtrl.dispose();
      priorityCtrl.dispose();
      inInterfaceCtrl.dispose();
      outInterfaceCtrl.dispose();
      downloadParentCtrl.dispose();
      uploadParentCtrl.dispose();
      burstDownloadLimitCtrl.dispose();
      burstUploadLimitCtrl.dispose();
      burstDownloadThresholdCtrl.dispose();
      burstUploadThresholdCtrl.dispose();
      burstTimeCtrl.dispose();
    }
  }

  Future<void> _openSettingsForApp(AppPriorityConfig app) async {
    final apply = await _showAppSettingsDialog(app);

    if (!mounted) return;

    if (apply && app.isEnabled) {
      await _enableAppPriority(app);
    }
  }

  Future<void> _showEnableFlow(AppPriorityConfig app) async {
    final apply = await _showAppSettingsDialog(app);

    if (!mounted) return;

    if (apply) {
      await _enableAppPriority(app);
    }
  }

  Future<void> _showDisableConfirmDialog(AppPriorityConfig app) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('تأكيد الإيقاف'),
        content: Text(
          'هل أنت متأكد من إيقاف تسريع ${app.name}؟\n'
          'سيتم حذف جميع رولات الـ Mangle والـ Queue Tree المرتبطة به تلقائياً.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('إيقاف وحذف', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (result == true) {
      await _disableAppPriority(app);
    }
  }

  Widget _buildInfoCard() {
    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Padding(
        padding: EdgeInsets.all(12.0),
        child: Text(
          'هذه الصفحة تضبط أولوية المرور للتطبيقات عبر قواعد Mangle و Queue Tree.\n'
          'تم تحديث المسارات الافتراضية (Parent) إلى global لتعمل مع أنظمة ميكروتك الحديثة بسلاسة.\n'
          'إذا كان اسم قائمة WAN مختلفًا أو كان الراوتر يستخدم FastTrack فراجع التحذير أعلى الصفحة.',
          style: TextStyle(
            fontSize: 13,
            color: Colors.white70,
            height: 1.4,
          ),
        ),
      ),
    );
  }

  Widget _buildFastTrackCard() {
    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: Colors.orangeAccent, width: 1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'تم اكتشاف FastTrack مفعلًا ($_fastTrackRulesCount).\n'
                'قد يؤدي ذلك إلى تجاوز بعض قواعد Queue Tree أو تقليل أثر الأولوية.',
                style: const TextStyle(color: Colors.orangeAccent),
              ),
            ),
            TextButton(
              onPressed: _checkFastTrackWarning,
              child: const Text('فحص'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppCard(AppPriorityConfig app) {
    final routerAvailable = _hasRouter;
    final switchEnabled = routerAvailable && !_loading;

    return Card(
      elevation: app.isEnabled ? 4 : 1,
      shape: RoundedRectangleBorder(
        side: BorderSide(
          color: app.isEnabled ? app.color : Colors.transparent,
          width: 1.5,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: app.color.withOpacity(0.2),
            child: Icon(app.icon, color: app.color),
          ),
          title: Text(
            app.name,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Text(
                app.isEnabled ? 'الحالة: مفعل ونشط' : 'الحالة: معطل',
                style: TextStyle(
                  color: app.isEnabled ? Colors.greenAccent : Colors.white54,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'الإعداد: DL ${app.downloadMaxLimit} | UL ${app.uploadMaxLimit} | LimitAt ${app.downloadLimitAt}/${app.uploadLimitAt} | Priority ${app.priority}',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
              if (app.isEnabled) ...[
                const SizedBox(height: 4),
                Text(
                  'السرعة الفعلية: DL ${app.currentDownloadLimit.isEmpty ? 'غير محدد' : app.currentDownloadLimit} | UL ${app.currentUploadLimit.isEmpty ? 'غير محدد' : app.currentUploadLimit}',
                  style: const TextStyle(
                    color: AppTheme.gold,
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
          trailing: SizedBox(
            width: 108,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: 'الإعدادات',
                  onPressed: _loading ? null : () => _openSettingsForApp(app),
                  icon: const Icon(Icons.tune),
                ),
                Switch(
                  value: app.isEnabled,
                  activeColor: app.color,
                  onChanged: switchEnabled
                      ? (bool val) {
                          if (val) {
                            _showEnableFlow(app);
                          } else {
                            _showDisableConfirmDialog(app);
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

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[
      _buildInfoCard(),
      if (_fastTrackDetected) _buildFastTrackCard(),
      ..._apps.map(_buildAppCard),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('أولوية وتسريع التطبيقات'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppTheme.gold),
            onPressed: _loading ? null : _refreshAll,
            tooltip: 'تحديث الحالة',
          ),
          // القائمة الجانبية التي تحتوي على الخصائص الجديدة المضافة
          PopupMenuButton<ExtraMenu>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == ExtraMenu.openSpeed) {
                _confirmOpenSpeed();
              } else if (value == ExtraMenu.telegramBot) {
                _showTelegramBotDialog();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: ExtraMenu.openSpeed,
                child: Text('فتح السرعة للجميع'),
              ),
              const PopupMenuItem(
                value: ExtraMenu.telegramBot,
                child: Text('إضافة بوت تيليجرام (إشعارات الأجهزة)'),
              ),
            ],
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.gold))
          : ListView(
              padding: const EdgeInsets.all(8.0),
              children: children,
            ),
    );
  }
}
