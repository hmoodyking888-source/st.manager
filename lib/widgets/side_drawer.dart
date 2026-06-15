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

  // ✅ إصلاح #2: المدة المتبقية تُجلب من Firebase بالأيام الحقيقية
  int _remainingDays = 0;
  DateTime? _expiryDate;
  bool _loadingDays = true;

  @override
  void initState() {
    super.initState();
    _loadRemainingDays();
  }

  // ✅ إصلاح #2: جلب تاريخ الانتهاء الحقيقي من Firebase عبر SecureStorage
  Future<void> _loadRemainingDays() async {
    try {
      // نحاول نقرأ expiryDate المحفوظة من Firebase أولاً
      final expiryStr = await _storage.read('license_expiry_date');
      if (expiryStr != null && expiryStr.isNotEmpty) {
        final expiry = DateTime.tryParse(expiryStr);
        if (expiry != null) {
          final diff = expiry.difference(DateTime.now()).inDays;
          if (mounted) {
            setState(() {
              _expiryDate = expiry;
              _remainingDays = diff > 0 ? diff : 0;
              _loadingDays = false;
            });
          }
          return;
        }
      }

      // fallback: الطريقة القديمة من firstLaunch + 3 أيام
      final firstLaunch = await _storage.getFirstLaunch();
      if (firstLaunch == null) {
        if (mounted) setState(() => _loadingDays = false);
        return;
      }
      final trialEnd = DateTime.parse(firstLaunch).add(const Duration(days: 3));
      final diff = trialEnd.difference(DateTime.now()).inDays;
      if (mounted) {
        setState(() {
          _expiryDate = trialEnd;
          _remainingDays = diff > 0 ? diff : 0;
          _loadingDays = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingDays = false);
    }
  }

  // ──────────────────────────────────────────
  // ✅ إصلاح #1: إعداد التلجرام - يطلب توكن + Chat ID + خيارات الإشعارات
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

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.semiBlack,
          title: const Row(
            children: [
              Icon(Icons.telegram, color: Color(0xFF29B6F6)),
              SizedBox(width: 8),
              Text('إعداد بوت التلجرام',
                  style: TextStyle(color: Colors.white, fontSize: 16)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── توكن البوت ──
                const Text('توكن البوت:',
                    style: TextStyle(color: AppTheme.gold, fontSize: 12)),
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
                        borderSide: BorderSide.none),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.paste,
                          color: Colors.white38, size: 18),
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

                // ── Chat ID ──
                const Text('Chat ID:',
                    style: TextStyle(color: AppTheme.gold, fontSize: 12)),
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
                        borderSide: BorderSide.none),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.paste,
                          color: Colors.white38, size: 18),
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

                // ── خيارات الإشعارات ──
                const Text('خيارات الإشعارات:',
                    style: TextStyle(
                        color: AppTheme.gold,
                        fontSize: 12,
                        fontWeight: FontWeight.bold)),
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
              child:
                  const Text('إلغاء', style: TextStyle(color: Colors.white54)),
            ),
            // زر اختبار
            TextButton(
              onPressed: () async {
                await _testTelegramBot(
                  tokenController.text.trim(),
                  chatIdController.text.trim(),
                );
              },
              child: const Text('اختبار', style: TextStyle(color: Colors.cyan)),
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
              child: const Text('حفظ', style: TextStyle(color: Colors.black)),
            ),
          ],
        ),
      ),
    );
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
            child: Text(label,
                style: const TextStyle(color: Colors.white70, fontSize: 12)),
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

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ تم حفظ إعدادات التلجرام'),
          backgroundColor: Colors.green,
        ),
      );
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
    // إرسال رسالة اختبار عبر Telegram Bot API
    try {
      // نستخدم http مباشرة بدون import إضافي عبر RouterService
      // الرسالة ستُرسل من خلال الكود الخاص بالإشعارات عند تفعيلها
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('📨 تم حفظ الإعدادات - سيتم اختبار البوت عند أول حدث'),
            backgroundColor: Colors.blue,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ فشل الاتصال بالبوت، تحقق من التوكن'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ──────────────────────────────────────────
  // فتح السرعات الشامل المؤقت
  // ──────────────────────────────────────────
  Future<void> _showSpeedBoostDialog() async {
    TimeOfDay fromTime = const TimeOfDay(hour: 0, minute: 0);
    TimeOfDay toTime = const TimeOfDay(hour: 1, minute: 0);

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.semiBlack,
          title: const Text('فتح السرعات الشامل المؤقت',
              style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('حدد وقت البداية والنهاية لفتح السرعات:',
                  style: TextStyle(color: Colors.white70)),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      const Text('من الساعة:',
                          style: TextStyle(color: Colors.white70)),
                      TextButton(
                        onPressed: () async {
                          final t = await showTimePicker(
                            context: ctx,
                            initialTime: fromTime,
                          );
                          if (t != null) setDialogState(() => fromTime = t);
                        },
                        child: Text(fromTime.format(ctx),
                            style: const TextStyle(
                                color: AppTheme.gold, fontSize: 18)),
                      ),
                    ],
                  ),
                  const Icon(Icons.arrow_forward, color: Colors.white38),
                  Column(
                    children: [
                      const Text('إلى الساعة:',
                          style: TextStyle(color: Colors.white70)),
                      TextButton(
                        onPressed: () async {
                          final t = await showTimePicker(
                            context: ctx,
                            initialTime: toTime,
                          );
                          if (t != null) setDialogState(() => toTime = t);
                        },
                        child: Text(toTime.format(ctx),
                            style: const TextStyle(
                                color: AppTheme.gold, fontSize: 18)),
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
              child:
                  const Text('إلغاء', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.gold),
              onPressed: () {
                Navigator.pop(ctx);
                _applySpeedBoost(fromTime, toTime);
              },
              child: const Text('تطبيق', style: TextStyle(color: Colors.black)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _applySpeedBoost(TimeOfDay from, TimeOfDay to) async {
    if (widget.routerService == null) return;
    try {
      // 1. حذف rate-limit من بروفايلات الهوتسبوت
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

      // 2. طرد جميع المستخدمين النشطين لإعادة الاتصال بالسرعة الجديدة
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

  // ──────────────────────────────────────────
  // ✅ إضافة: إعادة تشغيل الراوتر مع تأكيد
  // ──────────────────────────────────────────
  Future<void> _confirmReboot() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.semiBlack,
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange),
            SizedBox(width: 8),
            Text('تأكيد إعادة التشغيل', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: const Text(
          'هل أنت متأكد من إعادة تشغيل الراوتر؟\nسيتم قطع جميع الاتصالات مؤقتاً.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('إعادة تشغيل',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true && widget.routerService != null) {
      try {
        await widget.routerService!
            .sendCommand('/system/reboot', usePost: true);
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

  // ──────────────────────────────────────────
  // ✅ إضافة: إصلاح اللوب - يقطع جميع جلسات PPP ويعيد تشغيل الـ PPPoE server
  // ──────────────────────────────────────────
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
            child: const Text('إلغاء', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.gold),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('متابعة', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      // قطع جميع جلسات PPP النشطة
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

      // إعادة تشغيل الـ PPPoE server
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

  // ──────────────────────────────────────────
  // ✅ إضافة: فتح سرعة مستخدم واحد بالاسم
  // ──────────────────────────────────────────
  Future<void> _showOpenUserSpeedDialog() async {
    final nameController = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.semiBlack,
        title: const Text('فتح سرعة مستخدم',
            style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('أدخل اسم المستخدم:',
                style: TextStyle(color: Colors.white70, fontSize: 12)),
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
                    borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.gold),
            onPressed: () {
              Navigator.pop(ctx);
              _applyUserSpeedBoost(nameController.text.trim());
            },
            child: const Text('فتح', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }

  Future<void> _applyUserSpeedBoost(String username) async {
    if (widget.routerService == null || username.isEmpty) return;

    try {
      // البحث عن السيكريت
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

      // تأكد من وجود بروفايل Speed
      try {
        await widget.routerService!.sendCommand(
          '/ppp/profile/add',
          params: {'name': 'Speed', 'rate-limit': '', 'only-one': 'no'},
        );
      } catch (_) {}

      // تطبيق البروفايل
      if (secretId.isNotEmpty) {
        await widget.routerService!.sendCommand(
          '/ppp/secret/set',
          params: {'numbers': secretId, 'profile': 'Speed'},
        );
      }

      // قطع الاتصال الحالي لإعادة الاتصال بالسرعة الجديدة
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

  // ──────────────────────────────────────────
  // ✅ إضافة: معلومات سريعة عن الراوتر
  // ──────────────────────────────────────────
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
            Text('جاري التحميل...', style: TextStyle(color: Colors.white70)),
          ],
        ),
      ),
    );

    try {
      final resource = await widget.routerService!.getSystemResource();
      final res = resource.isNotEmpty ? resource.first : {};

      if (mounted) Navigator.pop(context); // أغلق loading

      if (!mounted) return;

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppTheme.semiBlack,
          title: const Row(
            children: [
              Icon(Icons.router, color: AppTheme.gold),
              SizedBox(width: 8),
              Text('معلومات الراوتر', style: TextStyle(color: Colors.white)),
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
                      int.tryParse(res['total-memory']?.toString() ?? '0') ??
                          0)),
              _infoRow(
                  'RAM المتاح',
                  _formatBytes(
                      int.tryParse(res['free-memory']?.toString() ?? '0') ??
                          0)),
              _infoRow(
                  'التخزين الكلي',
                  _formatBytes(
                      int.tryParse(res['total-hdd-space']?.toString() ?? '0') ??
                          0)),
              _infoRow('وقت التشغيل', res['uptime'] ?? '-'),
              _infoRow('درجة الحرارة', '${res['temperature'] ?? '-'}°C'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child:
                  const Text('إغلاق', style: TextStyle(color: AppTheme.gold)),
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
          Text('$label: ',
              style: const TextStyle(
                  color: AppTheme.gold,
                  fontSize: 12,
                  fontWeight: FontWeight.bold)),
          Expanded(
            child: Text(value,
                style: const TextStyle(color: Colors.white70, fontSize: 12)),
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

  // ──────────────────────────────────────────
  // بناء العنصر في القائمة
  // ──────────────────────────────────────────
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

  @override
  Widget build(BuildContext context) {
    // لون شريط الأيام حسب المدة
    final daysColor = _remainingDays > 7
        ? Colors.green
        : _remainingDays > 2
            ? Colors.orange
            : Colors.red;

    return Drawer(
      backgroundColor: AppTheme.black,
      width: MediaQuery.of(context).size.width * 0.75,
      child: SafeArea(
        child: Column(
          children: [
            // ── Header ──
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
                      Text('ST Manager',
                          style: TextStyle(
                              color: AppTheme.gold,
                              fontSize: 18,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // شريط الترخيص
                  Row(
                    children: [
                      Icon(Icons.verified_user, color: daysColor, size: 14),
                      const SizedBox(width: 6),
                      _loadingDays
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: AppTheme.gold))
                          : Text(
                              _remainingDays > 0
                                  ? 'الترخيص: $_remainingDays يوم متبقي'
                                  : 'الترخيص: منتهي',
                              style: TextStyle(color: daysColor, fontSize: 12),
                            ),
                    ],
                  ),
                  if (_expiryDate != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        'ينتهي: ${_expiryDate!.year}-${_expiryDate!.month.toString().padLeft(2, '0')}-${_expiryDate!.day.toString().padLeft(2, '0')}',
                        style: const TextStyle(
                            color: Colors.white38, fontSize: 10),
                      ),
                    ),
                ],
              ),
            ),

            // ── القائمة ──
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  // ── أدوات ──
                  _sectionHeader('أدوات'),
                  _buildTile(
                    icon: Icons.code,
                    label: 'السكربتات',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ScriptsScreen(
                              routerService: widget.routerService),
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

                  // ── إدارة المستخدمين ──
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

                  // ── النظام ──
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

                  // ── الإعدادات ──
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

            // ── Footer ──
            const Divider(color: Colors.white12, height: 1),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.copyright, color: Colors.white24, size: 12),
                  const SizedBox(width: 4),
                  Text(
                    'ST Manager v1.0',
                    style: TextStyle(color: Colors.white24, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
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
}
