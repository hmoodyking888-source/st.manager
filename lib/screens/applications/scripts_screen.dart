import 'package:flutter/material.dart';
import 'package:st_manager/services/router_service.dart';
import 'package:st_manager/theme/app_theme.dart';

/// اسم قائمة الواجهات الخارجية في الراوتر.
/// إذا كان اسم WAN عندك مختلفًا غيّره من إعداد التطبيق.
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
    this.downloadParent = 'global',
    this.uploadParent = 'global',
  });
}

enum ExtraMenu {
  openSpeed,
  telegramBot,
  loopProtection,
}

class _LoopInterfaceInfo {
  final String name;
  final String status;
  final String bridge;
  final bool enabled;
  final bool loopDetected;
  final bool isWan;

  const _LoopInterfaceInfo({
    required this.name,
    required this.status,
    required this.bridge,
    required this.enabled,
    required this.loopDetected,
    required this.isWan,
  });
}

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

  bool _loopScanRunning = false;

  final List<AppPriorityConfig> _apps = [
    AppPriorityConfig(
      id: 'whatsapp',
      name: 'واتساب (WhatsApp)',
      icon: Icons.chat,
      color: Colors.green,
      hosts: [
        '*whatsapp.net*',
        '*whatsapp.com*',
      ],
    ),
    AppPriorityConfig(
      id: 'facebook',
      name: 'فيسبوك (Facebook)',
      icon: Icons.facebook,
      color: Colors.blue,
      hosts: [
        '*facebook.com*',
        '*messenger.com*',
        '*fbcdn.net*',
      ],
    ),
    AppPriorityConfig(
      id: 'instagram',
      name: 'انستغرام (Instagram)',
      icon: Icons.camera_alt,
      color: Colors.purpleAccent,
      hosts: [
        '*instagram.com*',
        '*cdninstagram.com*',
        '*instagram.*',
      ],
    ),
    AppPriorityConfig(
      id: 'tiktok',
      name: 'تيك توك (TikTok)',
      icon: Icons.music_note,
      color: Colors.white,
      hosts: [
        '*tiktokcdn.com*',
        '*tiktokv.com*',
        '*tiktok.com*',
      ],
    ),
    AppPriorityConfig(
      id: 'youtube',
      name: 'يوتيوب (YouTube)',
      icon: Icons.play_circle_fill,
      color: Colors.red,
      hosts: [
        '*youtube.com*',
        '*googlevideo.com*',
        '*ytimg.com*',
        '*youtubei.googleapis.com*',
      ],
    ),
    AppPriorityConfig(
      id: 'pubg',
      name: 'ببجي موبايل (PUBG)',
      icon: Icons.sports_esports,
      color: Colors.orange,
      hosts: [
        '*pubgmobile.com*',
        '*igamecj.com*',
      ],
    ),
    AppPriorityConfig(
      id: 'telegram',
      name: 'تيليجرام (Telegram)',
      icon: Icons.send,
      color: Colors.cyan,
      hosts: [
        '*telegram.org*',
        '*t.me*',
        '*telegram.me*',
      ],
    ),
    AppPriorityConfig(
      id: 'snapchat',
      name: 'سناب شات (Snapchat)',
      icon: Icons.camera_alt_outlined,
      color: Colors.amber,
      hosts: [
        '*snapchat.com*',
        '*sc-cdn.net*',
        '*snapkit.com*',
      ],
    ),
    AppPriorityConfig(
      id: 'x',
      name: 'إكس / تويتر (X)',
      icon: Icons.public,
      color: Colors.lightBlueAccent,
      hosts: [
        '*x.com*',
        '*twitter.com*',
        '*twimg.com*',
      ],
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
      hosts: [
        '*netflix.com*',
        '*nflxvideo.net*',
        '*nflximg.net*',
      ],
    ),
    AppPriorityConfig(
      id: 'twitch',
      name: 'تويتش (Twitch)',
      icon: Icons.videogame_asset,
      color: Colors.purple,
      hosts: [
        '*twitch.tv*',
        '*ttvnw.net*',
        '*jtvnw.net*',
      ],
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

  String _commentFor(AppPriorityConfig app) {
    return 'AppManager_${app.id}';
  }

  String _connMarkFor(AppPriorityConfig app) {
    return 'conn_${app.id}';
  }

  String _downPackMarkFor(AppPriorityConfig app) {
    return 'pack_${app.id}_down';
  }

  String _upPackMarkFor(AppPriorityConfig app) {
    return 'pack_${app.id}_up';
  }

  String _downQueueNameFor(AppPriorityConfig app) {
    return 'Priority_${app.id}_down';
  }

  String _upQueueNameFor(AppPriorityConfig app) {
    return 'Priority_${app.id}_up';
  }

  String _addressListFor(AppPriorityConfig app) {
    return 'AppManager_${app.id}_addr';
  }

  String _fastTrackExclusionCommentFor(AppPriorityConfig app) {
    return 'AppManager_FastTrack_Exclude_${app.id}';
  }

  void _showSnack(
    String message, {
    Color backgroundColor = Colors.black87,
  }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(
            fontFamily: 'Cairo',
          ),
        ),
        backgroundColor: backgroundColor,
      ),
    );
  }

  List<Map<String, dynamic>> _asMapList(dynamic response) {
    if (response is List) {
      return response.whereType<Map>().map((item) {
        return item.map(
          (key, value) => MapEntry(
            key.toString(),
            value,
          ),
        );
      }).toList();
    }

    if (response is Map && response['data'] is List) {
      final data = response['data'] as List;

      return data.whereType<Map>().map((item) {
        return item.map(
          (key, value) => MapEntry(
            key.toString(),
            value,
          ),
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

  bool _isDisabled(dynamic value) {
    final v = value?.toString().trim().toLowerCase();

    return v == 'true' ||
        v == 'yes' ||
        v == '1';
  }

  bool _isValidRateLimit(String value) {
    final cleaned = value
        .replaceAll(' ', '')
        .trim();

    return RegExp(
      r'^\d+(\.\d+)?[KkMmGg]?(?:/\d+(\.\d+)?[KkMmGg]?)?$',
    ).hasMatch(cleaned);
  }

  bool _isValidBurstTime(String value) {
    final cleaned = value
        .replaceAll(' ', '')
        .trim();

    return RegExp(
      r'^\d+(ms|s|m|h)$',
    ).hasMatch(cleaned);
  }

  String _normalizeRateLimit(String value) {
    return value
        .replaceAll(' ', '')
        .trim();
  }

  String _normalizeHostToDomain(String value) {
    return value
        .replaceAll('*', '')
        .replaceAll('?', '')
        .trim()
        .replaceAll(
          RegExp(r'^https?://'),
          '',
        )
        .split('/')
        .first
        .trim()
        .toLowerCase();
  }

  List<String> _normalizedAppDomains(
    AppPriorityConfig app,
  ) {
    final result = <String>{};

    for (final host in app.hosts) {
      final domain =
          _normalizeHostToDomain(host);

      if (domain.isEmpty) continue;

      if (!domain.contains('.')) {
        continue;
      }

      result.add(domain);
    }

    return result.toList();
  }

  String? _validateRateLimitField(
    String? value,
  ) {
    final v = (value ?? '').trim();

    if (v.isEmpty) {
      return 'هذا الحقل مطلوب';
    }

    if (!_isValidRateLimit(v)) {
      return 'صيغة غير صحيحة';
    }

    return null;
  }

  String? _validatePriorityField(
    String? value,
  ) {
    final v = int.tryParse(
      (value ?? '').trim(),
    );

    if (v == null) {
      return 'أدخل رقمًا من 1 إلى 8';
    }

    if (v < 1 || v > 8) {
      return 'الأولوية يجب أن تكون من 1 إلى 8';
    }

    return null;
  }

  String? _validateBurstTimeField(
    String? value,
  ) {
    final v = (value ?? '').trim();

    if (v.isEmpty) {
      return 'هذا الحقل مطلوب';
    }

    if (!_isValidBurstTime(v)) {
      return 'مثال: 20s أو 500ms';
    }

    return null;
  }

  String? _validateNonEmptyField(
    String? value,
  ) {
    if ((value ?? '').trim().isEmpty) {
      return 'هذا الحقل مطلوب';
    }

    return null;
  }

  Future<void> _refreshAll() async {
    if (mounted) {
      setState(() {
        _loading = true;
      });
    }

    await _checkActivePriorities(
      showLoader: false,
    );

    await _checkFastTrackWarning();

    if (mounted) {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _checkFastTrackWarning() async {
    final router = _router;

    if (router == null) return;

    try {
      final response = await router.sendCommand(
        '/ip/firewall/filter/print',
      );

      final rules = _asMapList(response);

      int count = 0;

      for (final rule in rules) {
        final action = rule['action']
            ?.toString()
            .trim()
            .toLowerCase();

        if (action ==
                'fasttrack-connection' &&
            !_isDisabled(
              rule['disabled'],
            )) {
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

  Future<void> _checkActivePriorities({
    bool showLoader = true,
  }) async {
    final router = _router;

    if (router == null) return;

    if (showLoader && mounted) {
      setState(() {
        _loading = true;
      });
    }

    try {
      final queueResponse =
          await router.sendCommand(
        '/queue/tree/print',
      );

      final mangleResponse =
          await router.sendCommand(
        '/ip/firewall/mangle/print',
      );

      final queues =
          _asMapList(queueResponse);

      final mangleRules =
          _asMapList(mangleResponse);

      if (!mounted) return;

      setState(() {
        for (final app in _apps) {
          final comment =
              _commentFor(app);

          final downQueue =
              _findByField(
            queues,
            'name',
            _downQueueNameFor(app),
          );

          final upQueue =
              _findByField(
            queues,
            'name',
            _upQueueNameFor(app),
          );

          final connExists =
              _findByField(
                    mangleRules,
                    'comment',
                    comment,
                  ) !=
                  null;

          final downPackExists =
              _findByField(
                    mangleRules,
                    'new-packet-mark',
                    _downPackMarkFor(app),
                  ) !=
                  null;

          final upPackExists =
              _findByField(
                    mangleRules,
                    'new-packet-mark',
                    _upPackMarkFor(app),
                  ) !=
                  null;

          app.isEnabled =
              connExists &&
              downPackExists &&
              upPackExists &&
              downQueue != null &&
              upQueue != null;

          app.currentDownloadLimit =
              downQueue?['max-limit']
                      ?.toString() ??
                  '';

          app.currentUploadLimit =
              upQueue?['max-limit']
                      ?.toString() ??
                  '';
        }
      });
    } catch (_) {
      // لا نوقف الشاشة بسبب خطأ في قراءة الحالة.
    } finally {
      if (mounted && showLoader) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<bool> _showFastTrackWarningDialog() async {
    if (!_fastTrackDetected) {
      return true;
    }

    final result =
        await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title:
              const Text('تحذير FastTrack'),
          content: Text(
            'تم اكتشاف $_fastTrackRulesCount قاعدة FastTrack مفعلة في الراوتر.\n\n'
            'سيتم إنشاء استثناء تلقائي للتطبيق حتى لا يتجاوز FastTrack قواعد Mangle و Queue Tree الخاصة به.\n\n'
            'لن يتم حذف أو تعطيل قواعد FastTrack العامة.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  false,
                );
              },
              child:
                  const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  true,
                );
              },
              child:
                  const Text('متابعة'),
            ),
          ],
        );
      },
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
    app.downloadMaxLimit =
        downloadMaxLimit;

    app.uploadMaxLimit =
        uploadMaxLimit;

    app.downloadLimitAt =
        downloadLimitAt;

    app.uploadLimitAt =
        uploadLimitAt;

    app.priority =
        priority;

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

    app.inInterfaceList =
        inInterfaceList;

    app.outInterfaceList =
        outInterfaceList;

    app.downloadParent =
        downloadParent;

    app.uploadParent =
        uploadParent;
  }

  Future<void> _removeExistingRulesForApp(
    RouterService router,
    AppPriorityConfig app,
  ) async {
    final comment =
        _commentFor(app);

    final connectionMark =
        _connMarkFor(app);

    final downMark =
        _downPackMarkFor(app);

    final upMark =
        _upPackMarkFor(app);

    final queueNames =
        <String>{
      _downQueueNameFor(app),
      _upQueueNameFor(app),
    };

    // ============================================================
    // MANGLE
    // ============================================================

    final mangleResp =
        await router.sendCommand(
      '/ip/firewall/mangle/print',
    );

    final mangleRules =
        _asMapList(mangleResp);

    for (final rule in mangleRules) {
      final ruleComment =
          rule['comment']?.toString();

      final newPacketMark =
          rule['new-packet-mark']
              ?.toString();

      final newConnectionMark =
          rule['new-connection-mark']
              ?.toString();

      final matches =
          ruleComment == comment ||
          newPacketMark == downMark ||
          newPacketMark == upMark ||
          newConnectionMark ==
              connectionMark;

      if (!matches) continue;

      final id =
          rule['.id']?.toString();

      if (id == null || id.isEmpty) {
        continue;
      }

      await router.sendCommand(
        '/ip/firewall/mangle/remove',
        params: {
          'numbers': id,
        },
      );
    }

    // ============================================================
    // QUEUE TREE
    // ============================================================

    final queueResp =
        await router.sendCommand(
      '/queue/tree/print',
    );

    final queueRules =
        _asMapList(queueResp);

    for (final q in queueRules) {
      final name =
          q['name']?.toString();

      final qComment =
          q['comment']?.toString();

      if (qComment != comment &&
          !queueNames.contains(name)) {
        continue;
      }

      final id =
          q['.id']?.toString();

      if (id == null || id.isEmpty) {
        continue;
      }

      await router.sendCommand(
        '/queue/tree/remove',
        params: {
          'numbers': id,
        },
      );
    }

    // ============================================================
    // FASTTRACK EXCLUSION
    // ============================================================

    final filterResp =
        await router.sendCommand(
      '/ip/firewall/filter/print',
    );

    final filterRules =
        _asMapList(filterResp);

    final exclusionComment =
        _fastTrackExclusionCommentFor(
      app,
    );

    for (final rule in filterRules) {
      if (rule['comment']?.toString() !=
          exclusionComment) {
        continue;
      }

      final id =
          rule['.id']?.toString();

      if (id == null || id.isEmpty) {
        continue;
      }

      await router.sendCommand(
        '/ip/firewall/filter/remove',
        params: {
          'numbers': id,
        },
      );
    }

    // ============================================================
    // ADDRESS LIST
    // ============================================================

    final listResp =
        await router.sendCommand(
      '/ip/firewall/address-list/print',
    );

    final listRules =
        _asMapList(listResp);

    final addressList =
        _addressListFor(app);

    for (final rule in listRules) {
      if (rule['list']?.toString() !=
          addressList) {
        continue;
      }

      final id =
          rule['.id']?.toString();

      if (id == null || id.isEmpty) {
        continue;
      }

      await router.sendCommand(
        '/ip/firewall/address-list/remove',
        params: {
          'numbers': id,
        },
      );
    }
  }

  Future<void> _createAppAddressList(
    RouterService router,
    AppPriorityConfig app,
  ) async {
    final listName =
        _addressListFor(app);

    final domains =
        _normalizedAppDomains(app);

    if (domains.isEmpty) return;

    for (final domain in domains) {
      await router.sendCommand(
        '/ip/firewall/address-list/add',
        params: {
          'list': listName,
          'address': domain,
          'comment': _commentFor(app),
        },
      );
    }
  }

  Future<void> _createFastTrackExclusion(
    RouterService router,
    AppPriorityConfig app,
  ) async {
    final response =
        await router.sendCommand(
      '/ip/firewall/filter/print',
    );

    final rules =
        _asMapList(response);

    final exclusionComment =
        _fastTrackExclusionCommentFor(
      app,
    );

    final existing =
        _findByField(
      rules,
      'comment',
      exclusionComment,
    );

    String? exclusionId;

    if (existing != null) {
      exclusionId =
          existing['.id']?.toString();

      if (existing['disabled'] != null &&
          _isDisabled(
            existing['disabled'],
          ) &&
          exclusionId != null &&
          exclusionId.isNotEmpty) {
        await router.sendCommand(
          '/ip/firewall/filter/set',
          params: {
            'numbers': exclusionId,
            'disabled': 'no',
          },
        );
      }
    } else {
      final addResult =
          await router.sendCommand(
        '/ip/firewall/filter/add',
        params: {
          'chain': 'forward',
          'connection-state':
              'established,related',
          'connection-mark':
              _connMarkFor(app),
          'action': 'accept',
          'comment':
              exclusionComment,
        },
      );

      if (addResult != null) {
        final resultText =
            addResult.toString();

        if (resultText.isNotEmpty &&
            resultText != 'null') {
          exclusionId =
              resultText;
        }
      }
    }

    // ------------------------------------------------------------
    // إعادة قراءة القواعد وتحديد FastTrack
    // ------------------------------------------------------------

    final latestResponse =
        await router.sendCommand(
      '/ip/firewall/filter/print',
    );

    final latestRules =
        _asMapList(latestResponse);

    final createdRule =
        _findByField(
      latestRules,
      'comment',
      exclusionComment,
    );

    exclusionId ??=
        createdRule?['.id']
            ?.toString();

    Map<String, dynamic>? fastTrackRule;

    for (final rule in latestRules) {
      final action = rule['action']
          ?.toString()
          .trim()
          .toLowerCase();

      if (action ==
              'fasttrack-connection' &&
          !_isDisabled(
            rule['disabled'],
          )) {
        fastTrackRule = rule;
        break;
      }
    }

    final fastTrackId =
        fastTrackRule?['.id']
            ?.toString();

    if (exclusionId != null &&
        exclusionId.isNotEmpty &&
        fastTrackId != null &&
        fastTrackId.isNotEmpty) {
      try {
        await router.sendCommand(
          '/ip/firewall/filter/move',
          params: {
            'numbers': exclusionId,
            'destination': fastTrackId,
          },
        );
      } catch (_) {
        // بعض RouterService قد لا تدعم move.
        // القاعدة تبقى موجودة دون فشل العملية كلها.
      }
    }
  }

  Future<void> _createApplicationMangleRules(
    RouterService router,
    AppPriorityConfig app,
  ) async {
    final comment =
        _commentFor(app);

    final connMark =
        _connMarkFor(app);

    final downPackMark =
        _downPackMarkFor(app);

    final upPackMark =
        _upPackMarkFor(app);

    final addressList =
        _addressListFor(app);

    // ============================================================
    // TLS HOST
    // ============================================================

    for (final host in app.hosts) {
      await router.sendCommand(
        '/ip/firewall/mangle/add',
        params: {
          'chain': 'prerouting',
          'protocol': 'tcp',
          'connection-state': 'new',
          'connection-mark': 'no-mark',
          'tls-host': host,
          'action': 'mark-connection',
          'new-connection-mark':
              connMark,
          'passthrough': 'yes',
          'comment': comment,
        },
      );
    }

    // ============================================================
    // ADDRESS LIST - TCP
    // ============================================================

    await router.sendCommand(
      '/ip/firewall/mangle/add',
      params: {
        'chain': 'prerouting',
        'protocol': 'tcp',
        'connection-state': 'new',
        'connection-mark': 'no-mark',
        'dst-address-list': addressList,
        'action': 'mark-connection',
        'new-connection-mark':
            connMark,
        'passthrough': 'yes',
        'comment': comment,
      },
    );

    // ============================================================
    // ADDRESS LIST - UDP / QUIC
    // ============================================================

    await router.sendCommand(
      '/ip/firewall/mangle/add',
      params: {
        'chain': 'prerouting',
        'protocol': 'udp',
        'connection-state': 'new',
        'connection-mark': 'no-mark',
        'dst-address-list': addressList,
        'action': 'mark-connection',
        'new-connection-mark':
            connMark,
        'passthrough': 'yes',
        'comment': comment,
      },
    );

    // ============================================================
    // DOWNLOAD
    // ============================================================

    await router.sendCommand(
      '/ip/firewall/mangle/add',
      params: {
        'chain': 'prerouting',
        'connection-mark': connMark,
        'in-interface-list':
            app.inInterfaceList,
        'action': 'mark-packet',
        'new-packet-mark':
            downPackMark,
        'passthrough': 'no',
        'comment': comment,
      },
    );

    // ============================================================
    // UPLOAD
    // ============================================================

    await router.sendCommand(
      '/ip/firewall/mangle/add',
      params: {
        'chain': 'postrouting',
        'connection-mark': connMark,
        'out-interface-list':
            app.outInterfaceList,
        'action': 'mark-packet',
        'new-packet-mark':
            upPackMark,
        'passthrough': 'no',
        'comment': comment,
      },
    );
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
    final params =
        <String, String>{
      'name': name,
      'parent': parent,
      'packet-mark': packetMark,
      'max-limit': maxLimit,
      'limit-at': limitAt,
      'priority':
          priority.toString(),
      'comment': comment,
    };

    if (burstEnabled) {
      if (burstLimit.trim().isNotEmpty) {
        params['burst-limit'] =
            burstLimit.trim();
      }

      if (burstThreshold
          .trim()
          .isNotEmpty) {
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

    final inList =
        app.inInterfaceList
                .trim()
                .isEmpty
            ? _defaultWanInterfaceList
            : app.inInterfaceList
                .trim();

    final outList =
        app.outInterfaceList
                .trim()
                .isEmpty
            ? _defaultWanInterfaceList
            : app.outInterfaceList
                .trim();

    if (downMax.isEmpty ||
        upMax.isEmpty ||
        downAt.isEmpty ||
        upAt.isEmpty ||
        app.priority < 1 ||
        app.priority > 8 ||
        inList.isEmpty ||
        outList.isEmpty) {
      _showSnack(
        'بعض الحقول المطلوبة فارغة',
        backgroundColor: Colors.red,
      );
      return;
    }

    if (!_isValidRateLimit(
          downMax,
        ) ||
        !_isValidRateLimit(
          upMax,
        ) ||
        !_isValidRateLimit(
          downAt,
        ) ||
        !_isValidRateLimit(
          upAt,
        )) {
      _showSnack(
        'صيغة السرعات غير صحيحة',
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

    final proceed =
        await _showFastTrackWarningDialog();

    if (!proceed) {
      return;
    }

    if (mounted) {
      setState(() {
        _loading = true;
      });
    }

    try {
      // ----------------------------------------------------------
      // حذف القديم بالكامل
      // ----------------------------------------------------------

      await _removeExistingRulesForApp(
        router,
        app,
      );

      // ----------------------------------------------------------
      // Address List
      // ----------------------------------------------------------

      await _createAppAddressList(
        router,
        app,
      );

      // ----------------------------------------------------------
      // Mangle
      // ----------------------------------------------------------

      await _createApplicationMangleRules(
        router,
        app,
      );

      // ----------------------------------------------------------
      // Queue Tree - Download
      // ----------------------------------------------------------

      final downQueueParams =
          _buildQueueParams(
        name:
            _downQueueNameFor(app),
        parent: app.downloadParent
                .trim()
                .isEmpty
            ? 'global'
            : app.downloadParent.trim(),
        packetMark:
            _downPackMarkFor(app),
        maxLimit: downMax,
        limitAt: downAt,
        priority: app.priority,
        comment:
            _commentFor(app),
        burstEnabled:
            app.burstEnabled,
        burstLimit:
            downBurstLimit,
        burstThreshold:
            downBurstThreshold,
        burstTime:
            burstTime,
      );

      // ----------------------------------------------------------
      // Queue Tree - Upload
      // ----------------------------------------------------------

      final upQueueParams =
          _buildQueueParams(
        name:
            _upQueueNameFor(app),
        parent: app.uploadParent
                .trim()
                .isEmpty
            ? 'global'
            : app.uploadParent.trim(),
        packetMark:
            _upPackMarkFor(app),
        maxLimit: upMax,
        limitAt: upAt,
        priority: app.priority,
        comment:
            _commentFor(app),
        burstEnabled:
            app.burstEnabled,
        burstLimit:
            upBurstLimit,
        burstThreshold:
            upBurstThreshold,
        burstTime:
            burstTime,
      );

      await router.sendCommand(
        '/queue/tree/add',
        params: downQueueParams,
      );

      await router.sendCommand(
        '/queue/tree/add',
        params: upQueueParams,
      );

      // ----------------------------------------------------------
      // FastTrack exclusion
      // ----------------------------------------------------------

      if (_fastTrackDetected) {
        await _createFastTrackExclusion(
          router,
          app,
        );
      }

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
        setState(() {
          _loading = false;
        });
      }
    }
  }

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
      setState(() {
        _loading = true;
      });
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
        setState(() {
          _loading = false;
        });
      }
    }
  }

  // ==============================================================
  // LOOP PROTECTION
  // ==============================================================

  bool _looksLikePhysicalEthernet(
    String name,
  ) {
    final n =
        name.toLowerCase();

    return n.startsWith('ether') ||
        n.startsWith('sfp') ||
        n.startsWith('qsfp') ||
        n.startsWith('combo');
  }

  Future<List<_LoopInterfaceInfo>>
      _scanLoopInterfaces() async {
    final router = _router;

    if (router == null) {
      return [];
    }

    final bridgeResponse =
        await router.sendCommand(
      '/interface/bridge/print',
    );

    final bridgePortsResponse =
        await router.sendCommand(
      '/interface/bridge/port/print',
    );

    final ethernetResponse =
        await router.sendCommand(
      '/interface/ethernet/print',
    );

    final wanMembersResponse =
        await router.sendCommand(
      '/interface/list/member/print',
    );

    final bridges =
        _asMapList(
      bridgeResponse,
    );

    final bridgePorts =
        _asMapList(
      bridgePortsResponse,
    );

    final ethernetInterfaces =
        _asMapList(
      ethernetResponse,
    );

    final wanMembers =
        _asMapList(
      wanMembersResponse,
    );

    final wanInterfaces =
        <String>{};

    for (final member in wanMembers) {
      if (member['list']?.toString() ==
          _defaultWanInterfaceList) {
        final iface =
            member['interface']?.toString();

        if (iface != null &&
            iface.isNotEmpty) {
          wanInterfaces.add(
            iface,
          );
        }
      }
    }

    final bridgeNames =
        bridges
            .map(
              (e) => e['name']
                  ?.toString(),
            )
            .whereType<String>()
            .toSet();

    final result =
        <_LoopInterfaceInfo>[];

    for (final port in bridgePorts) {
      final interfaceName =
          port['interface']
              ?.toString();

      final bridgeName =
          port['bridge']
              ?.toString() ??
          '';

      if (interfaceName == null ||
          interfaceName.isEmpty) {
        continue;
      }

      if (bridgeNames.isNotEmpty &&
          !bridgeNames.contains(
            bridgeName,
          )) {
        continue;
      }

      if (!_looksLikePhysicalEthernet(
        interfaceName,
      )) {
        continue;
      }

      final ethernet =
          _findByField(
        ethernetInterfaces,
        'name',
        interfaceName,
      );

      final loopStatus =
          ethernet?[
                    'loop-protect-status']
                ?.toString()
                .toLowerCase() ??
            'off';

      final enabled =
          !_isDisabled(
        ethernet?['disabled'],
      );

      final running =
          (ethernet?['running']
                  ?.toString()
                  .toLowerCase() ==
              'true') ||
          (ethernet?['running']
                  ?.toString()
                  .toLowerCase() ==
              'yes');

      result.add(
        _LoopInterfaceInfo(
          name: interfaceName,
          status:
              running
                  ? 'متصل'
                  : 'غير متصل',
          bridge: bridgeName,
          enabled: enabled,
          loopDetected:
              loopStatus ==
                  'disable',
          isWan:
              wanInterfaces.contains(
            interfaceName,
          ),
        ),
      );
    }

    return result;
  }

  Future<void> _showLoopProtectionDialog() async {
    final router = _router;

    if (router == null) {
      _showSnack(
        'لا يوجد اتصال بالراوتر',
        backgroundColor:
            Colors.red,
      );
      return;
    }

    if (_loopScanRunning) {
      return;
    }

    setState(() {
      _loopScanRunning = true;
    });

    try {
      final interfaces =
          await _scanLoopInterfaces();

      final bridgeResponse =
          await router.sendCommand(
        '/interface/bridge/print',
      );

      final bridges =
          _asMapList(
        bridgeResponse,
      );

      final detected =
          interfaces
              .where(
                (i) => i.loopDetected,
              )
              .toList();

      final enabledProtection =
          interfaces
              .where(
                (i) =>
                    i.enabled &&
                    !i.isWan,
              )
              .toList();

      final missingProtection =
          interfaces
              .where(
                (i) =>
                    !i.isWan &&
                    i.enabled &&
                    !i.loopDetected,
              )
              .toList();

      bool rstpExists =
          false;

      for (final bridge in bridges) {
        final mode =
            bridge[
                      'protocol-mode']
                  ?.toString()
                  .toLowerCase();

        if (mode == 'rstp' ||
            mode == 'mstp') {
          rstpExists = true;
          break;
        }
      }

      if (!mounted) return;

      final shouldProtect =
          missingProtection.isNotEmpty ||
          !rstpExists;

      final result =
          await showDialog<bool>(
        context: context,
        builder:
            (dialogContext) {
          return AlertDialog(
            title: Row(
              children: [
                Icon(
                  detected.isNotEmpty
                      ? Icons.warning_amber_rounded
                      : Icons.shield_outlined,
                  color:
                      detected.isNotEmpty
                          ? Colors.redAccent
                          : AppTheme.gold,
                ),
                const SizedBox(
                  width: 8,
                ),
                const Expanded(
                  child: Text(
                    'فحص Loop وحماية الشبكة',
                  ),
                ),
              ],
            ),
            content:
                SizedBox(
              width:
                  double.maxFinite,
              child:
                  SingleChildScrollView(
                child:
                    Column(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                  children: [
                    Text(
                      'عدد منافذ Bridge الفعلية: ${interfaces.length}',
                    ),
                    const SizedBox(
                      height: 8,
                    ),
                    Text(
                      rstpExists
                          ? 'RSTP/MSTP: مفعل'
                          : 'RSTP/MSTP: غير ظاهر كمفعل',
                      style:
                          TextStyle(
                        color:
                            rstpExists
                                ? Colors.green
                                : Colors.orange,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),
                    const SizedBox(
                      height: 12,
                    ),
                    if (detected.isNotEmpty) ...[
                      const Text(
                        'تم اكتشاف منفذ تم تعطيله بواسطة Loop Protect:',
                        style:
                            TextStyle(
                          color:
                              Colors.redAccent,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),
                      const SizedBox(
                        height: 6,
                      ),
                      ...detected.map(
                        (e) => Text(
                          '• ${e.name} / ${e.bridge}',
                          style:
                              const TextStyle(
                            color:
                                Colors.redAccent,
                          ),
                        ),
                      ),
                      const SizedBox(
                        height: 12,
                      ),
                    ],
                    Text(
                      'حماية Loop Protect مفعلة على ${enabledProtection.length} منافذ.',
                    ),
                    const SizedBox(
                      height: 6,
                    ),
                    Text(
                      'المنافذ التي تحتاج حماية: ${missingProtection.length}',
                    ),
                    const SizedBox(
                      height: 12,
                    ),
                    const Text(
                      'لن يتم تعطيل أي منفذ يدويًا. سيتم فقط تفعيل Loop Protect على منافذ Bridge غير الموجودة في قائمة WAN، ويمكن تفعيل RSTP للـBridge عند الحاجة.',
                      style:
                          TextStyle(
                        color:
                            Colors.white70,
                        fontSize:
                            12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(
                    dialogContext,
                    false,
                  );
                },
                child:
                    const Text('إغلاق'),
              ),
              if (shouldProtect)
                ElevatedButton(
                  style:
                      ElevatedButton.styleFrom(
                    backgroundColor:
                        AppTheme.gold,
                    foregroundColor:
                        Colors.black,
                  ),
                  onPressed: () {
                    Navigator.pop(
                      dialogContext,
                      true,
                    );
                  },
                  child:
                      const Text(
                    'تفعيل الحماية',
                    style:
                        TextStyle(
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                ),
            ],
          );
        },
      );

      if (result == true) {
        await _enableLoopProtection(
          interfaces,
          bridges,
          enableRstp:
              !rstpExists,
        );
      }
    } catch (e) {
      if (mounted) {
        _showSnack(
          'حدث خطأ أثناء فحص Loop: $e',
          backgroundColor:
              Colors.red,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _loopScanRunning = false;
        });
      }
    }
  }

  Future<void> _enableLoopProtection(
    List<_LoopInterfaceInfo>
        interfaces,
    List<Map<String, dynamic>>
        bridges, {
    required bool enableRstp,
  }) async {
    final router = _router;

    if (router == null) {
      return;
    }

    if (mounted) {
      setState(() {
        _loading = true;
      });
    }

    try {
      if (enableRstp) {
        for (final bridge in bridges) {
          final bridgeId =
              bridge['.id']?.toString();

          if (bridgeId == null ||
              bridgeId.isEmpty) {
            continue;
          }

          final mode =
              bridge[
                        'protocol-mode']
                    ?.toString()
                    .toLowerCase();

          if (mode == null ||
              mode == 'none' ||
              mode == 'stp') {
            try {
              await router.sendCommand(
                '/interface/bridge/set',
                params: {
                  'numbers': bridgeId,
                  'protocol-mode':
                      'rstp',
                },
              );
            } catch (_) {
              // نكمل بقية الحماية
              // حتى لو رفض الإصدار تغيير STP.
            }
          }
        }
      }

      int protectedCount = 0;

      for (final info in interfaces) {
        if (!info.enabled) {
          continue;
        }

        if (info.isWan) {
          continue;
        }

        if (!_looksLikePhysicalEthernet(
          info.name,
        )) {
          continue;
        }

        final ethernetResponse =
            await router.sendCommand(
          '/interface/ethernet/print',
        );

        final ethernetRules =
            _asMapList(
          ethernetResponse,
        );

        final ethernet =
            _findByField(
          ethernetRules,
          'name',
          info.name,
        );

        final id =
            ethernet?['.id']
                ?.toString();

        if (id == null ||
            id.isEmpty) {
          continue;
        }

        try {
          await router.sendCommand(
            '/interface/ethernet/set',
            params: {
              'numbers': id,
              'loop-protect':
                  'on',
              'loop-protect-send-interval':
                  '5s',
              'loop-protect-disable-time':
                  '5m',
            },
          );

          protectedCount++;
        } catch (_) {
          // بعض الواجهات/الأجهزة
          // قد لا تدعم الخاصية.
        }
      }

      if (mounted) {
        _showSnack(
          'تم تفعيل حماية Loop Protect على $protectedCount منافذ.',
          backgroundColor:
              Colors.green,
        );
      }
    } catch (e) {
      if (mounted) {
        _showSnack(
          'حدث خطأ أثناء تفعيل حماية Loop: $e',
          backgroundColor:
              Colors.red,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _confirmOpenSpeed() async {
    final confirm =
        await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title:
              const Text(
            'تأكيد فتح السرعات للجميع',
          ),
          content:
              const Text(
            'هل أنت متأكد من تحويل جميع الحسابات لبروفايل "speed" وطرد جميع المتصلين حالياً (الأكتف) لتطبيق السرعة الجديدة؟',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  ctx,
                  false,
                );
              },
              child:
                  const Text('إلغاء'),
            ),
            ElevatedButton(
              style:
                  ElevatedButton.styleFrom(
                backgroundColor:
                    AppTheme.gold,
              ),
              onPressed: () {
                Navigator.pop(
                  ctx,
                  true,
                );
              },
              child:
                  const Text(
                'تأكيد وتنفيذ',
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

    if (confirm == true) {
      await _openSpeedForAll();
    }
  }

  Future<void> _openSpeedForAll() async {
    final router = _router;

    if (router == null) {
      _showSnack(
        'لا يوجد اتصال بالراوتر',
        backgroundColor:
            Colors.red,
      );
      return;
    }

    if (mounted) {
      setState(() {
        _loading = true;
      });
    }

    try {
      await router.sendCommand(
        '/ppp/secret/set',
        params: {
          'numbers': '[find]',
          'profile': 'speed',
        },
      );

      await router.sendCommand(
        '/ip/hotspot/user/set',
        params: {
          'numbers': '[find]',
          'profile': 'speed',
        },
      );

      await router.sendCommand(
        '/ppp/active/remove',
        params: {
          'numbers': '[find]',
        },
      );

      await router.sendCommand(
        '/ip/hotspot/active/remove',
        params: {
          'numbers': '[find]',
        },
      );

      _showSnack(
        'تم فتح السرعات للجميع وطرد الأكتف بنجاح (بروفايل speed)',
        backgroundColor:
            Colors.green,
      );
    } catch (e) {
      _showSnack(
        'حدث خطأ أثناء فتح السرعات: $e',
        backgroundColor:
            Colors.red,
      );
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _showTelegramBotDialog() async {
    final nameCtrl =
        TextEditingController();

    final ipCtrl =
        TextEditingController();

    final tokenCtrl =
        TextEditingController();

    final chatCtrl =
        TextEditingController();

    try {
      await showDialog(
        context: context,
        builder: (ctx) {
          return AlertDialog(
            title:
                const Text(
              'إعداد إشعارات البوت للقطع (Netwatch)',
            ),
            content:
                SingleChildScrollView(
              child:
                  Column(
                mainAxisSize:
                    MainAxisSize.min,
                children: [
                  _buildField(
                    controller:
                        nameCtrl,
                    label:
                        'اسم القطعة (مثال: مطعم اليمني)',
                  ),
                  _buildField(
                    controller:
                        ipCtrl,
                    label:
                        'IP القطعة (مثال: 192.168.1.10)',
                  ),
                  _buildField(
                    controller:
                        tokenCtrl,
                    label:
                        'توكن البوت (Bot Token)',
                    obscureText:
                        true,
                  ),
                  _buildField(
                    controller:
                        chatCtrl,
                    label:
                        'معرف المحادثة (Chat ID)',
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(
                    ctx,
                  );
                },
                child:
                    const Text(
                  'إلغاء',
                ),
              ),
              ElevatedButton(
                style:
                    ElevatedButton.styleFrom(
                  backgroundColor:
                      AppTheme.gold,
                ),
                onPressed:
                    () async {
                  Navigator.pop(
                    ctx,
                  );

                  await _injectTelegramScript(
                    nameCtrl.text
                        .trim(),
                    ipCtrl.text
                        .trim(),
                    tokenCtrl.text
                        .trim(),
                    chatCtrl.text
                        .trim(),
                  );
                },
                child:
                    const Text(
                  'حفظ الإشعار',
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
    } finally {
      nameCtrl.dispose();
      ipCtrl.dispose();
      tokenCtrl.dispose();
      chatCtrl.dispose();
    }
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
        backgroundColor:
            Colors.red,
      );
      return;
    }

    if (name.isEmpty ||
        ip.isEmpty ||
        token.isEmpty ||
        chat.isEmpty) {
      _showSnack(
        'الرجاء تعبئة جميع الحقول',
        backgroundColor:
            Colors.red,
      );
      return;
    }

    if (mounted) {
      setState(() {
        _loading = true;
      });
    }

    try {
      final upMsg =
          Uri.encodeComponent(
        "✅ القطعة $name عادت إلى العمل.",
      );

      final downMsg =
          Uri.encodeComponent(
        "❌ القطعة $name توقفت عن العمل.",
      );

      final upScript =
          '/tool fetch url="https://api.telegram.org/bot$token/sendMessage?chat_id=$chat&text=$upMsg" keep-result=no';

      final downScript =
          '/tool fetch url="https://api.telegram.org/bot$token/sendMessage?chat_id=$chat&text=$downMsg" keep-result=no';

      final response =
          await router.sendCommand(
        '/tool/netwatch/print',
      );

      final rules =
          _asMapList(response);

      final netwatchComment =
          'TelegramBot_$name';

      Map<String, dynamic>?
          existing;

      for (final rule in rules) {
        if (rule['comment']?.toString() ==
            netwatchComment) {
          existing = rule;
          break;
        }
      }

      if (existing != null) {
        final id =
            existing['.id']
                ?.toString();

        if (id != null &&
            id.isNotEmpty) {
          await router.sendCommand(
            '/tool/netwatch/set',
            params: {
              'numbers': id,
              'host': ip,
              'comment':
                  netwatchComment,
              'up-script':
                  upScript,
              'down-script':
                  downScript,
            },
          );
        }
      } else {
        await router.sendCommand(
          '/tool/netwatch/add',
          params: {
            'host': ip,
            'comment':
                netwatchComment,
            'up-script':
                upScript,
            'down-script':
                downScript,
            'interval':
                '10s',
            'timeout':
                '3s',
          },
        );
      }

      _showSnack(
        existing == null
            ? 'تمت إضافة إشعار Telegram إلى Netwatch'
            : 'تم تحديث إشعار Telegram الموجود',
        backgroundColor:
            Colors.green,
      );
    } catch (e) {
      _showSnack(
        'حدث خطأ أثناء إعداد Telegram: $e',
        backgroundColor:
            Colors.red,
      );
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Widget _buildField({
    required TextEditingController
        controller,
    required String label,
    String? hint,
    String? Function(String?)?
        validator,
    TextInputType keyboardType =
        TextInputType.text,
    int maxLines = 1,
    bool obscureText = false,
  }) {
    return Padding(
      padding:
          const EdgeInsets.only(
        bottom: 10,
      ),
      child:
          TextFormField(
        controller:
            controller,
        keyboardType:
            keyboardType,
        maxLines:
            maxLines,
        obscureText:
            obscureText,
        validator:
            validator,
        decoration:
            InputDecoration(
          labelText:
              label,
          hintText:
              hint,
          border:
              const OutlineInputBorder(),
        ),
      ),
    );
  }

  Future<bool>
      _showAppSettingsDialog(
    AppPriorityConfig app,
  ) async {
    final formKey =
        GlobalKey<FormState>();

    final downloadMaxCtrl =
        TextEditingController(
      text:
          app.downloadMaxLimit,
    );

    final uploadMaxCtrl =
        TextEditingController(
      text:
          app.uploadMaxLimit,
    );

    final downloadLimitAtCtrl =
        TextEditingController(
      text:
          app.downloadLimitAt,
    );

    final uploadLimitAtCtrl =
        TextEditingController(
      text:
          app.uploadLimitAt,
    );

    final priorityCtrl =
        TextEditingController(
      text:
          app.priority.toString(),
    );

    final inInterfaceCtrl =
        TextEditingController(
      text:
          app.inInterfaceList,
    );

    final outInterfaceCtrl =
        TextEditingController(
      text:
          app.outInterfaceList,
    );

    final downloadParentCtrl =
        TextEditingController(
      text:
          app.downloadParent,
    );

    final uploadParentCtrl =
        TextEditingController(
      text:
          app.uploadParent,
    );

    final burstDownloadLimitCtrl =
        TextEditingController(
      text:
          app.burstDownloadLimit,
    );

    final burstUploadLimitCtrl =
        TextEditingController(
      text:
          app.burstUploadLimit,
    );

    final burstDownloadThresholdCtrl =
        TextEditingController(
      text:
          app.burstDownloadThreshold,
    );

    final burstUploadThresholdCtrl =
        TextEditingController(
      text:
          app.burstUploadThreshold,
    );

    final burstTimeCtrl =
        TextEditingController(
      text:
          app.burstTime,
    );

    bool burstEnabled =
        app.burstEnabled;

    bool applyNow =
        false;

    try {
      final result =
          await showDialog<bool>(
        context: context,
        barrierDismissible:
            false,
        builder:
            (dialogContext) {
          return StatefulBuilder(
            builder:
                (
              context,
              setDialogState,
            ) {
              void commitValues() {
                final priority =
                    int.tryParse(
                      priorityCtrl
                          .text
                          .trim(),
                    ) ??
                    1;

                _applySettingsToApp(
                  app,
                  downloadMaxLimit:
                      downloadMaxCtrl
                          .text
                          .trim(),
                  uploadMaxLimit:
                      uploadMaxCtrl
                          .text
                          .trim(),
                  downloadLimitAt:
                      downloadLimitAtCtrl
                          .text
                          .trim(),
                  uploadLimitAt:
                      uploadLimitAtCtrl
                          .text
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
                      burstTimeCtrl
                          .text
                          .trim(),
                  inInterfaceList:
                      inInterfaceCtrl
                          .text
                          .trim(),
                  outInterfaceList:
                      outInterfaceCtrl
                          .text
                          .trim(),
                  downloadParent:
                      downloadParentCtrl
                          .text
                          .trim(),
                  uploadParent:
                      uploadParentCtrl
                          .text
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
                content:
                    SizedBox(
                  width:
                      double.maxFinite,
                  child:
                      SingleChildScrollView(
                    child:
                        Form(
                      key:
                          formKey,
                      child:
                          Column(
                        mainAxisSize:
                            MainAxisSize.min,
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'السرعات الأساسية',
                            style:
                                TextStyle(
                              fontWeight:
                                  FontWeight.bold,
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
                                TextInputType.number,
                            validator:
                                _validatePriorityField,
                          ),
                          const SizedBox(
                            height: 8,
                          ),
                          const Text(
                            'الواجهات والمسارات',
                            style:
                                TextStyle(
                              fontWeight:
                                  FontWeight.bold,
                            ),
                          ),
                          const SizedBox(
                            height: 8,
                          ),
                          _buildField(
                            controller:
                                inInterfaceCtrl,
                            label:
                                'Input Interface List',
                            hint:
                                'مثال: WAN',
                            validator:
                                _validateNonEmptyField,
                          ),
                          _buildField(
                            controller:
                                outInterfaceCtrl,
                            label:
                                'Output Interface List',
                            hint:
                                'مثال: WAN',
                            validator:
                                _validateNonEmptyField,
                          ),
                          _buildField(
                            controller:
                                downloadParentCtrl,
                            label:
                                'Parent للتحميل (مثال: global)',
                            hint:
                                'مثال: global',
                            validator:
                                _validateNonEmptyField,
                          ),
                          _buildField(
                            controller:
                                uploadParentCtrl,
                            label:
                                'Parent للرفع (مثال: global)',
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
                                EdgeInsets.zero,
                            value:
                                burstEnabled,
                            onChanged:
                                (value) {
                              setDialogState(
                                () {
                                  burstEnabled =
                                      value ??
                                          false;
                                },
                              );
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
                                    FontWeight.bold,
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
                            'ملاحظة: التطبيقات تستخدم نطاقات وCDN متغيرة وقد تستخدم TCP أو UDP/QUIC، لذلك لا يمكن ضمان تصنيف 100% من الترافيك بواسطة أسماء النطاقات فقط.',
                            style:
                                TextStyle(
                              fontSize:
                                  12,
                              color:
                                  Colors.white54,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed:
                        () {
                      Navigator.pop(
                        dialogContext,
                        false,
                      );
                    },
                    child:
                        const Text(
                      'إلغاء',
                    ),
                  ),
                  OutlinedButton(
                    onPressed:
                        () {
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
                        ElevatedButton
                            .styleFrom(
                      backgroundColor:
                          AppTheme.gold,
                    ),
                    onPressed:
                        () {
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
                    child:
                        const Text(
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

      return applyNow ||
          result;
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

  Future<void> _openSettingsForApp(
    AppPriorityConfig app,
  ) async {
    final apply =
        await _showAppSettingsDialog(
      app,
    );

    if (!mounted) return;

    if (apply &&
        app.isEnabled) {
      await _enableAppPriority(
        app,
      );
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
      await _enableAppPriority(
        app,
      );
    }
  }

  Future<void>
      _showDisableConfirmDialog(
    AppPriorityConfig app,
  ) async {
    final result =
        await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) {
        return AlertDialog(
          title:
              const Text(
            'تأكيد الإيقاف',
          ),
          content:
              Text(
            'هل أنت متأكد من إيقاف تسريع ${app.name}؟\n'
            'سيتم حذف Mangle و Queue Tree وAddress List واستثناء FastTrack الخاص به.',
          ),
          actions: [
            TextButton(
              onPressed:
                  () {
                Navigator.pop(
                  dialogContext,
                  false,
                );
              },
              child:
                  const Text(
                'إلغاء',
              ),
            ),
            ElevatedButton(
              style:
                  ElevatedButton
                      .styleFrom(
                backgroundColor:
                    Colors.red,
              ),
              onPressed:
                  () {
                Navigator.pop(
                  dialogContext,
                  true,
                );
              },
              child:
                  const Text(
                'إيقاف وحذف',
                style:
                    TextStyle(
                  color:
                      Colors.white,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (result == true) {
      await _disableAppPriority(
        app,
      );
    }
  }

  Widget _buildInfoCard() {
    return Card(
      elevation: 1,
      margin:
          const EdgeInsets.only(
        bottom: 12,
      ),
      shape:
          RoundedRectangleBorder(
        borderRadius:
            BorderRadius.circular(12),
      ),
      child:
          const Padding(
        padding:
            EdgeInsets.all(12.0),
        child:
            Text(
          'هذه الصفحة تضبط أولوية المرور للتطبيقات عبر Mangle و Queue Tree.\n'
          'يتم وسم التحميل من PREROUTING والرفع من POSTROUTING لتناسب Queue Tree ذات parent=global.\n'
          'يتم إنشاء Address List للتطبيق مع دعم TCP وUDP/QUIC، ويتم استثناء التطبيق من FastTrack عند الحاجة.\n'
          'كما تحتوي الصفحة على فحص وحماية Loop للشبكة.',
          style:
              TextStyle(
            fontSize: 13,
            color:
                Colors.white70,
            height: 1.4,
          ),
        ),
      ),
    );
  }

  Widget _buildFastTrackCard() {
    return Card(
      elevation: 1,
      margin:
          const EdgeInsets.only(
        bottom: 12,
      ),
      shape:
          RoundedRectangleBorder(
        side:
            const BorderSide(
          color:
              Colors.orangeAccent,
          width: 1,
        ),
        borderRadius:
            BorderRadius.circular(12),
      ),
      child:
          Padding(
        padding:
            const EdgeInsets.all(
          12.0,
        ),
        child:
            Row(
          crossAxisAlignment:
              CrossAxisAlignment
                  .start,
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              color:
                  Colors.orangeAccent,
            ),
            const SizedBox(
              width: 10,
            ),
            Expanded(
              child:
                  Text(
                'تم اكتشاف FastTrack مفعلًا ($_fastTrackRulesCount).\n'
                'سيتم استثناء التطبيقات المفعلة منه تلقائيًا.',
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
                  const Text(
                'فحص',
              ),
            ),
          ],
        ),
      ),
    );
  }

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
          app.isEnabled
              ? 4
              : 1,
      shape:
          RoundedRectangleBorder(
        side:
            BorderSide(
          color:
              app.isEnabled
                  ? app.color
                  : Colors.transparent,
          width: 1.5,
        ),
        borderRadius:
            BorderRadius.circular(12),
      ),
      margin:
          const EdgeInsets.symmetric(
        vertical: 8,
      ),
      child:
          Padding(
        padding:
            const EdgeInsets.all(
          8.0,
        ),
        child:
            ListTile(
          leading:
              CircleAvatar(
            backgroundColor:
                app.color.withOpacity(
              0.2,
            ),
            child:
                Icon(
              app.icon,
              color:
                  app.color,
            ),
          ),
          title:
              Text(
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
                style:
                    TextStyle(
                  color:
                      app.isEnabled
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
            width:
                108,
            child:
                Row(
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
                          ? (bool val) {
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

  @override
  Widget build(
    BuildContext context,
  ) {
    final children =
        <Widget>[
      _buildInfoCard(),

      if (_fastTrackDetected)
        _buildFastTrackCard(),

      ..._apps.map(
        _buildAppCard,
      ),
    ];

    return Scaffold(
      appBar:
          AppBar(
        title:
            const Text(
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
                  ExtraMenu.openSpeed) {
                _confirmOpenSpeed();
              } else if (value ==
                  ExtraMenu.telegramBot) {
                _showTelegramBotDialog();
              } else if (value ==
                  ExtraMenu.loopProtection) {
                _showLoopProtectionDialog();
              }
            },
            itemBuilder:
                (context) =>
                    [
              const PopupMenuItem(
                value:
                    ExtraMenu.openSpeed,
                child:
                    Text(
                  'فتح السرعة للجميع',
                ),
              ),
              const PopupMenuItem(
                value:
                    ExtraMenu.telegramBot,
                child:
                    Text(
                  'إضافة/تعديل بوت تيليجرام',
                ),
              ),
              const PopupMenuItem(
                value:
                    ExtraMenu.loopProtection,
                child:
                    Row(
                  children: [
                    Icon(
                      Icons.shield_outlined,
                    ),
                    SizedBox(
                      width: 8,
                    ),
                    Text(
                      'فحص وحماية Loop',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body:
          _loading
              ? const Center(
                  child:
                      CircularProgressIndicator(
                    color:
                        AppTheme.gold,
                  ),
                )
              : ListView(
                  padding:
                      const EdgeInsets.all(
                    8.0,
                  ),
                  children:
                      children,
                ),
    );
  }
}
