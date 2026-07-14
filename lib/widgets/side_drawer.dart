import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:st_manager/services/router_service.dart';
import 'package:st_manager/services/secure_storage_service.dart';
import 'package:st_manager/screens/applications/scripts_screen.dart';
import 'package:st_manager/theme/app_theme.dart';

class SideDrawer extends StatefulWidget {
  final RouterService? routerService;
  const SideDrawer({super.key, required this.routerService});

  @override
  State<SideDrawer> createState() => _SideDrawerState();
}

class _SideDrawerState extends State<SideDrawer> {
  final SecureStorageService _storage = SecureStorageService();

  static const String _appVersion = '2.6.0';

  int _remainingDays = 0;
  int _expiredDays = 0;
  DateTime? _expiryDate;
  bool _loadingDays = true;
  bool _licenseExpired = false;

  @override
  void initState() {
    super.initState();
    _loadRemainingDays();
  }

  int _positiveDaysFromDuration(Duration diff) {
    final minutes = diff.inMinutes.abs();
    final days = (minutes / (24 * 60)).ceil();
    return days <= 0 ? 1 : days;
  }

  void _setLicenseState(DateTime expiry) {
    final now = DateTime.now();
    final diff = expiry.difference(now);

    if (diff.isNegative) {
      _licenseExpired = true;
      _expiredDays = _positiveDaysFromDuration(diff);
      _remainingDays = 0;
    } else {
      _licenseExpired = false;
      _remainingDays = _positiveDaysFromDuration(diff);
      _expiredDays = 0;
    }

    _expiryDate = expiry;
    _loadingDays = false;
  }

  // جلب تاريخ الانتهاء الحقيقي من SecureStorage
  Future<void> _loadRemainingDays() async {
    try {
      final expiryStr = await _storage.read('license_expiry_date');
      if (expiryStr != null && expiryStr.isNotEmpty) {
        final expiry = DateTime.tryParse(expiryStr);
        if (expiry != null) {
          if (mounted) {
            setState(() {
              _setLicenseState(expiry);
            });
          }
          return;
        }
      }

      final firstLaunch = await _storage.getFirstLaunch();
      if (firstLaunch == null || firstLaunch.isEmpty) {
        if (mounted) {
          setState(() {
            _loadingDays = false;
          });
        }
        return;
      }

      final trialEnd = DateTime.parse(firstLaunch).add(const Duration(days: 3));
      if (mounted) {
        setState(() {
          _setLicenseState(trialEnd);
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loadingDays = false;
        });
      }
    }
  }

  // ──────────────────────────────────────────
  // إعداد التلجرام: يطلب توكن + Chat ID + خيارات الإشعارات
  // ──────────────────────────────────────────
  Future<void> _showTelegramSetupDialog() async {
    final tokenController = TextEditingController(
      text: await _storage.read('telegram_bot_token') ?? '',
    );
    final chatIdController = TextEditingController(
      text: await _storage.read('telegram_chat_id') ?? '',
    );

    bool notifyNewConnection =
        await _storage.read('tg_notify_connect') == 'true';
    bool notifyDisconnect =
        await _storage.read('tg_notify_disconnect') == 'true';
    bool notifyExpiry = await _storage.read('tg_notify_expiry') == 'true';
    bool notifyHighUsage =
        await _storage.read('tg_notify_high_usage') == 'true';
    bool notifyRouterRestart =
        await _storage.read('tg_notify_restart') == 'true';

    if (!mounted) return;

    try {
      await showDialog(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            backgroundColor: AppTheme.semiBlack,
            title: const Row(
              children: [
                Icon(Icons.telegram, color: Color(0xFF29B6F6)),
                SizedBox(width: 8),
                Text(
                  'إعداد بوت التلجرام',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'توكن البوت:',
                    style: TextStyle(color: AppTheme.gold, fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  TextField(
                    controller: tokenController,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: '123456789:AAF...',
                      hintStyle: const TextStyle(color: Colors.white30),
                      filled: true,
                      fillColor: Colors.white10,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      suffixIcon: IconButton(
                        icon: const Icon(
                          Icons.paste,
                          color: Colors.white38,
                          size: 18,
                        ),
                        onPressed: () async {
                          final data = await Clipboard.getData('text/plain');
                          if (data?.text != null) {
                            tokenController.text = data!.text!.trim();
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Chat ID:',
                    style: TextStyle(color: AppTheme.gold, fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  TextField(
                    controller: chatIdController,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      hintText: '-1001234567890',
                      hintStyle: const TextStyle(color: Colors.white30),
                      filled: true,
                      fillColor: Colors.white10,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      suffixIcon: IconButton(
                        icon: const Icon(
                          Icons.paste,
                          color: Colors.white38,
                          size: 18,
                        ),
                        onPressed: () async {
                          final data = await Clipboard.getData('text/plain');
                          if (data?.text != null) {
                            chatIdController.text = data!.text!.trim();
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'خيارات الإشعارات:',
                    style: TextStyle(
                      color: AppTheme.gold,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildNotifToggle(
                    ctx,
                    setDialogState,
                    icon: Icons.login,
                    iconColor: Colors.green,
                    label: 'اتصال مستخدم جديد',
                    value: notifyNewConnection,
                    onChanged: (v) =>
                        setDialogState(() => notifyNewConnection = v),
                  ),
                  _buildNotifToggle(
                    ctx,
                    setDialogState,
                    icon: Icons.logout,
                    iconColor: Colors.orange,
                    label: 'انقطاع اتصال مستخدم',
                    value: notifyDisconnect,
                    onChanged: (v) => setDialogState(() => notifyDisconnect = v),
                  ),
                  _buildNotifToggle(
                    ctx,
                    setDialogState,
                    icon: Icons.timer_off,
                    iconColor: Colors.red,
                    label: 'انتهاء صلاحية حساب',
                    value: notifyExpiry,
                    onChanged: (v) => setDialogState(() => notifyExpiry = v),
                  ),
                  _buildNotifToggle(
                    ctx,
                    setDialogState,
                    icon: Icons.speed,
                    iconColor: Colors.purple,
                    label: 'استهلاك عالي (> 50 Mbps)',
                    value: notifyHighUsage,
                    onChanged: (v) => setDialogState(() => notifyHighUsage = v),
                  ),
                  _buildNotifToggle(
                    ctx,
                    setDialogState,
                    icon: Icons.restart_alt,
                    iconColor: Colors.cyan,
                    label: 'إعادة تشغيل الراوتر',
                    value: notifyRouterRestart,
                    onChanged: (v) =>
                        setDialogState(() => notifyRouterRestart = v),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text(
                  'إلغاء',
                  style: TextStyle(color: Colors.white54),
                ),
              ),
              TextButton(
                onPressed: () async {
                  await _testTelegramBot(
                    tokenController.text.trim(),
                    chatIdController.text.trim(),
                  );
                },
                child: const Text(
                  'اختبار',
                  style: TextStyle(color: Colors.cyan),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.gold),
                onPressed: () async {
                  await _saveTelegramSettings(
                    token: tokenController.text.trim(),
                    chatId: chatIdController.text.trim(),
                    notifyConnect: notifyNewConnection,
                    notifyDisconnect: notifyDisconnect,
                    notifyExpiry: notifyExpiry,
                    notifyHighUsage: notifyHighUsage,
                    notifyRestart: notifyRouterRestart,
                  );
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: const Text(
                  'تفعيل البوت',
                  style: TextStyle(color: Colors.black),
                ),
              ),
            ],
          ),
        ),
      );
    } finally {
      tokenController.dispose();
      chatIdController.dispose();
    }
  }

  Widget _buildNotifToggle(
    BuildContext ctx,
    StateSetter setDialogState, {
    required IconData icon,
    required Color iconColor,
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppTheme.gold,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
    );
  }

  Future<void> _saveTelegramSettings({
    required String token,
    required String chatId,
    required bool notifyConnect,
    required bool notifyDisconnect,
    required bool notifyExpiry,
    required bool notifyHighUsage,
    required bool notifyRestart,
  }) async {
    await _storage.write('telegram_bot_token', token);
    await _storage.write('telegram_chat_id', chatId);
    await _storage.write('tg_notify_connect', notifyConnect.toString());
    await _storage.write('tg_notify_disconnect', notifyDisconnect.toString());
    await _storage.write('tg_notify_expiry', notifyExpiry.toString());
    await _storage.write('tg_notify_high_usage', notifyHighUsage.toString());
    await _storage.write('tg_notify_restart', notifyRestart.toString());

    if (widget.routerService != null && token.isNotEmpty && chatId.isNotEmpty) {
      await _installTelegramHelperScript(token: token, chatId: chatId);
      await _sendTelegramTestMessage(
        token: token,
        chatId: chatId,
        text: '✅ تم تفعيل ST Manager بنجاح',
      );
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ تم حفظ إعدادات التلجرام وتفعيلها'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  String _buildTelegramScriptSource({
    required String token,
    required String chatId,
  }) {
    final safeToken = token.replaceAll('"', r'\"');
    final safeChatId = chatId.replaceAll('"', r'\"');

    return ':global ST_TG_TOKEN "$safeToken";'
        ':global ST_TG_CHATID "$safeChatId";'
        ':global ST_TG_SEND do={'
        ':local msg \$1;'
        ':if ([:len \$msg] = 0) do={ :set msg "ST Manager"; }'
        ':local url ("https://api.telegram.org/bot" . \$ST_TG_TOKEN . "/sendMessage?chat_id=" . \$ST_TG_CHATID . "&text=" . \$msg);'
        '/tool fetch url=\$url keep-result=no;'
        '};';
  }

  Future<void> _installTelegramHelperScript({
    required String token,
    required String chatId,
  }) async {
    final router = widget.routerService;
    if (router == null) return;

    const scriptName = 'ST_Telegram_Bot';

    try {
      final scriptsResp = await router.sendCommand('/system/script/print');
      final scripts = scriptsResp is List ? scriptsResp : [];

      Map<String, dynamic>? existing;
      for (final item in scripts) {
        if (item is Map &&
            item['name']?.toString() == scriptName) {
          existing = item.map((k, v) => MapEntry(k.toString(), v));
          break;
        }
      }

      if (existing != null) {
        final id = existing['.id']?.toString() ?? '';
        if (id.isNotEmpty) {
          await router.sendCommand(
            '/system/script/remove',
            params: {'numbers': id},
          );
        }
      }

      await router.sendCommand('/system/script/add', params: {
        'name': scriptName,
        'policy': 'read,write,test,policy,password,sensitive,romon',
        'source': _buildTelegramScriptSource(token: token, chatId: chatId),
        'comment': 'ST Manager Telegram helper',
      });
    } catch (_) {
      // لا نكسر الواجهة إذا فشل حقن السكربت
    }
  }

  Future<void> _sendTelegramTestMessage({
    required String token,
    required String chatId,
    required String text,
  }) async {
    final router = widget.routerService;
    if (router == null) return;

    try {
      final encodedText = Uri.encodeComponent(text);
      final url =
          'https://api.telegram.org/bot$token/sendMessage?chat_id=$chatId&text=$encodedText';

      await router.sendCommand('/tool/fetch', params: {
        'url': url,
        'keep-result': 'no',
      });
    } catch (_) {
      // تجاهل الفشل حتى لا يمنع حفظ الإعدادات
    }
  }

  Future<void> _testTelegramBot(String token, String chatId) async {
    if (token.isEmpty || chatId.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ أدخل التوكن والـ Chat ID أولاً'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    await _sendTelegramTestMessage(
      token: token,
      chatId: chatId,
      text: '📨 اختبار من ST Manager',
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('📨 تم إرسال رسالة اختبار للبوت'),
          backgroundColor: Colors.blue,
        ),
      );
    }
  }

  Future<void> _showSpeedBoostDialog() async {
    TimeOfDay fromTime = const TimeOfDay(hour: 0, minute: 0);
    TimeOfDay toTime = const TimeOfDay(hour: 1, minute: 0);

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.semiBlack,
          title: const Text(
            'فتح السرعات الشامل المؤقت',
            style: TextStyle(color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'حدد وقت البداية والنهاية لفتح السرعات:',
                style: TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      const Text(
                        'من الساعة:',
                        style: TextStyle(color: Colors.white70),
                      ),
                      TextButton(
                        onPressed: () async {
                          final t = await showTimePicker(
                            context: ctx,
                            initialTime: fromTime,
                          );
                          if (t != null) setDialogState(() => fromTime = t);
                        },
                        child: Text(
                          fromTime.format(ctx),
                          style: const TextStyle(
                            color: AppTheme.gold,
                            fontSize: 18,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Icon(Icons.arrow_forward, color: Colors.white38),
                  Column(
                    children: [
                      const Text(
                        'إلى الساعة:',
                        style: TextStyle(color: Colors.white70),
                      ),
                      TextButton(
                        onPressed: () async {
                          final t = await showTimePicker(
                            context: ctx,
                            initialTime: toTime,
                          );
                          if (t != null) setDialogState(() => toTime = t);
                        },
                        child: Text(
                          toTime.format(ctx),
                          style: const TextStyle(
                            color: AppTheme.gold,
                            fontSize: 18,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text(
                'إلغاء',
                style: TextStyle(color: Colors.white54),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.gold),
              onPressed: () {
                Navigator.pop(ctx);
                _applySpeedBoost(fromTime, toTime);
              },
              child: const Text(
                'تطبيق',
                style: TextStyle(color: Colors.black),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _applySpeedBoost(TimeOfDay from, TimeOfDay to) async {
    if (widget.routerService == null) return;

    try {
      final profiles = await widget.routerService!.getHotspotProfiles();
      for (var profile in profiles) {
        final profileId = profile['.id']?.toString() ?? '';
        if (profileId.isNotEmpty) {
          await widget.routerService!.sendCommand(
            '/ip/hotspot/user/profile/set',
            params: {'numbers': profileId, 'rate-limit': ''},
          );
        }
      }

      final activeUsers = await widget.routerService!.getHotspotActive();
      for (var user in activeUsers) {
        final userId = user['.id']?.toString() ?? '';
        if (userId.isNotEmpty) {
          await widget.routerService!.sendCommand(
            '/ip/hotspot/active/remove',
            params: {'numbers': userId},
          );
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '🚀 تم فتح السرعات من ${from.format(context)} إلى ${to.format(context)}',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ فشل فتح السرعات: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _confirmReboot() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.semiBlack,
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange),
            SizedBox(width: 8),
            Text('تأكيد إعادة التشغيل',
                style: TextStyle(color: Colors.white)),
          ],
        ),
        content: const Text(
          'هل أنت متأكد من إعادة تشغيل الراوتر؟\nسيتم قطع جميع الاتصالات مؤقتاً.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'إلغاء',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'إعادة تشغيل',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && widget.routerService != null) {
      try {
        await widget.routerService!.sendCommand('/system/reboot', usePost: true);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('🔄 جاري إعادة تشغيل الراوتر...'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ فشل: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _fixLoop() async {
    if (widget.routerService == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.semiBlack,
        title: const Row(
          children: [
            Icon(Icons.build, color: AppTheme.gold),
            SizedBox(width: 8),
            Text('إصلاح اللوب', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: const Text(
          'سيتم قطع جميع جلسات PPP النشطة وإعادة تشغيل الـ PPPoE server.\nهل تريد المتابعة؟',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'إلغاء',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.gold),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'متابعة',
              style: TextStyle(color: Colors.black),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final activeSessions = await widget.routerService!.sendCommand(
        '/ppp/active/print',
        useCache: false,
      );
      for (final session in activeSessions) {
        final id = session['.id']?.toString() ?? '';
        if (id.isNotEmpty) {
          await widget.routerService!.sendCommand(
            '/ppp/active/remove',
            params: {'numbers': id},
          );
        }
      }

      final servers = await widget.routerService!.sendCommand(
        '/interface/pppoe-server/server/print',
        useCache: false,
      );
      for (final server in servers) {
        final id = server['.id']?.toString() ?? '';
        if (id.isNotEmpty) {
          await widget.routerService!.sendCommand(
            '/interface/pppoe-server/server/set',
            params: {'numbers': id, 'disabled': 'yes'},
          );
          await Future.delayed(const Duration(seconds: 1));
          await widget.routerService!.sendCommand(
            '/interface/pppoe-server/server/set',
            params: {'numbers': id, 'disabled': 'no'},
          );
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('✅ تم إصلاح اللوب - قُطعت ${activeSessions.length} جلسة'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ فشل إصلاح اللوب: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showOpenUserSpeedDialog() async {
    final nameController = TextEditingController();

    try {
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppTheme.semiBlack,
          title: const Text(
            'فتح سرعة مستخدم',
            style: TextStyle(color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'أدخل اسم المستخدم:',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: nameController,
                style: const TextStyle(color: Colors.white),
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'مثال: 1101',
                  hintStyle: const TextStyle(color: Colors.white30),
                  filled: true,
                  fillColor: Colors.white10,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text(
                'إلغاء',
                style: TextStyle(color: Colors.white54),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.gold),
              onPressed: () {
                Navigator.pop(ctx);
                _applyUserSpeedBoost(nameController.text.trim());
              },
              child: const Text(
                'فتح',
                style: TextStyle(color: Colors.black),
              ),
            ),
          ],
        ),
      );
    } finally {
      nameController.dispose();
    }
  }

  Future<void> _applyUserSpeedBoost(String username) async {
    if (widget.routerService == null || username.isEmpty) return;

    try {
      final secrets = await widget.routerService!.sendCommand(
        '/ppp/secret/print',
        useCache: false,
      );
      final secret = secrets.firstWhere(
        (s) => s['name']?.toString().toLowerCase() == username.toLowerCase(),
        orElse: () => {},
      );

      if (secret.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('⚠️ المستخدم "$username" غير موجود'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      final secretId = secret['.id']?.toString() ?? '';

      try {
        await widget.routerService!.sendCommand(
          '/ppp/profile/add',
          params: {'name': 'Speed', 'rate-limit': '', 'only-one': 'no'},
        );
      } catch (_) {}

      if (secretId.isNotEmpty) {
        await widget.routerService!.sendCommand(
          '/ppp/secret/set',
          params: {'numbers': secretId, 'profile': 'Speed'},
        );
      }

      final active = await widget.routerService!.sendCommand(
        '/ppp/active/print',
        useCache: false,
      );
      for (final session in active) {
        final sessionName = session['name']?.toString().toLowerCase() ?? '';
        if (sessionName == username.toLowerCase()) {
          final activeId = session['.id']?.toString() ?? '';
          if (activeId.isNotEmpty) {
            await widget.routerService!.sendCommand(
              '/ppp/active/remove',
              params: {'numbers': activeId},
            );
          }
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ تم فتح سرعة "$username" بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ فشل: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showRouterInfo() async {
    if (widget.routerService == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        backgroundColor: AppTheme.semiBlack,
        content: Row(
          children: [
            CircularProgressIndicator(color: AppTheme.gold),
            SizedBox(width: 16),
            Text(
              'جاري التحميل...',
              style: TextStyle(color: Colors.white70),
            ),
          ],
        ),
      ),
    );

    try {
      final resource = await widget.routerService!.getSystemResource();
      final res = resource.isNotEmpty ? resource.first : {};

      if (mounted) Navigator.pop(context);

      if (!mounted) return;

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppTheme.semiBlack,
          title: const Row(
            children: [
              Icon(Icons.router, color: AppTheme.gold),
              SizedBox(width: 8),
              Text(
                'معلومات الراوتر',
                style: TextStyle(color: Colors.white),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _infoRow('الجهاز', res['board-name'] ?? '-'),
              _infoRow('الإصدار', res['version'] ?? '-'),
              _infoRow('المعالج', res['cpu'] ?? '-'),
              _infoRow(
                'RAM الكلي',
                _formatBytes(
                  int.tryParse(res['total-memory']?.toString() ?? '0') ?? 0,
                ),
              ),
              _infoRow(
                'RAM المتاح',
                _formatBytes(
                  int.tryParse(res['free-memory']?.toString() ?? '0') ?? 0,
                ),
              ),
              _infoRow(
                'التخزين الكلي',
                _formatBytes(
                  int.tryParse(res['total-hdd-space']?.toString() ?? '0') ?? 0,
                ),
              ),
              _infoRow('وقت التشغيل', res['uptime'] ?? '-'),
              _infoRow('درجة الحرارة', '${res['temperature'] ?? '-'}°C'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text(
                'إغلاق',
                style: TextStyle(color: AppTheme.gold),
              ),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ فشل جلب المعلومات: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: const TextStyle(
              color: AppTheme.gold,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    if (bytes >= 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    if (bytes >= 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '$bytes B';
  }

  void _openSettings() {
    Navigator.pushNamed(context, '/settings');
  }

  Widget _buildTile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color iconColor = AppTheme.gold,
    Color? labelColor,
  }) {
    return ListTile(
      dense: true,
      leading: Icon(icon, color: iconColor, size: 20),
      title: Text(
        label,
        style: TextStyle(color: labelColor ?? Colors.white, fontSize: 13),
      ),
      onTap: onTap,
    );
  }

  Widget _buildLicenseBadge() {
    final Color daysColor = _licenseExpired
        ? Colors.red
        : _remainingDays > 7
            ? Colors.green
            : _remainingDays > 2
                ? Colors.orange
                : Colors.red;

    final String text = _loadingDays
        ? 'جارٍ التحقق من الترخيص...'
        : _licenseExpired
            ? 'الترخيص منتهي منذ $_expiredDays يوم'
            : 'الترخيص: $_remainingDays يوم متبقي';

    return Row(
      children: [
        Icon(
          _licenseExpired ? Icons.error_outline : Icons.verified_user,
          color: daysColor,
          size: 14,
        ),
        const SizedBox(width: 6),
        _loadingDays
            ? const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppTheme.gold,
                ),
              )
            : Text(
                text,
                style: TextStyle(color: daysColor, fontSize: 12),
              ),
      ],
    );
  }

  Widget _buildFooter() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: Colors.white12, width: 1),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'ST Manager',
            style: TextStyle(
              color: AppTheme.gold.withOpacity(0.95),
              fontSize: 14,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'الإصدار $_appVersion • برمجة م.احمد النعيمي',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white38,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            '+963995870655',
            style: TextStyle(
              color: Colors.white38,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(
        title,
        style: const TextStyle(
          color: AppTheme.gold,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: AppTheme.black,
      width: MediaQuery.of(context).size.width * 0.75,
      child: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              color: AppTheme.semiBlack,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.router, color: AppTheme.gold, size: 28),
                      SizedBox(width: 10),
                      Text(
                        'ST Manager',
                        style: TextStyle(
                          color: AppTheme.gold,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'إدارة الشبكة والتحكم الذكي',
                    style: TextStyle(color: Colors.white54, fontSize: 11),
                  ),
                  const SizedBox(height: 8),
                  _buildLicenseBadge(),
                  if (_expiryDate != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        _licenseExpired
                            ? 'انتهى في: ${_expiryDate!.year}-${_expiryDate!.month.toString().padLeft(2, '0')}-${_expiryDate!.day.toString().padLeft(2, '0')}'
                            : 'ينتهي: ${_expiryDate!.year}-${_expiryDate!.month.toString().padLeft(2, '0')}-${_expiryDate!.day.toString().padLeft(2, '0')}',
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 10,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  _sectionHeader('أدوات'),
                  _buildTile(
                    icon: Icons.speed,
                    label: 'تسريع البرامج',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AppPriorityScreen(
                            routerService: widget.routerService,
                          ),
                        ),
                      );
                    },
                  ),
                  _buildTile(
                    icon: Icons.info_outline,
                    label: 'معلومات الراوتر',
                    onTap: () {
                      Navigator.pop(context);
                      _showRouterInfo();
                    },
                  ),
                  _sectionHeader('إدارة المستخدمين'),
                  _buildTile(
                    icon: Icons.build,
                    label: 'إصلاح اللوب',
                    onTap: () {
                      Navigator.pop(context);
                      _fixLoop();
                    },
                  ),
                  _buildTile(
                    icon: Icons.speed,
                    label: 'فتح سرعة مستخدم',
                    onTap: () {
                      Navigator.pop(context);
                      _showOpenUserSpeedDialog();
                    },
                  ),
                  _buildTile(
                    icon: Icons.rocket_launch,
                    label: 'فتح سرعات شامل مؤقت',
                    onTap: () {
                      Navigator.pop(context);
                      _showSpeedBoostDialog();
                    },
                  ),
                  _sectionHeader('النظام'),
                  _buildTile(
                    icon: Icons.restart_alt,
                    label: 'إعادة تشغيل الراوتر',
                    iconColor: Colors.orange,
                    onTap: () {
                      Navigator.pop(context);
                      _confirmReboot();
                    },
                  ),
                  _sectionHeader('الإعدادات'),
                  _buildTile(
                    icon: Icons.telegram,
                    label: 'إعداد بوت التلجرام',
                    iconColor: const Color(0xFF29B6F6),
                    onTap: () {
                      Navigator.pop(context);
                      _showTelegramSetupDialog();
                    },
                  ),
                  _buildTile(
                    icon: Icons.palette,
                    label: 'تغيير الثيم',
                    onTap: () {
                      Navigator.pop(context);
                      _openSettings();
                    },
                  ),
                ],
              ),
            ),
            _buildFooter(),
          ],
        ),
      ),
    );
  }
}
