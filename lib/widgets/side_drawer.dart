import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:st_manager/services/router_service.dart';
import 'package:st_manager/services/secure_storage_service.dart';
import 'package:st_manager/services/firebase_service.dart';
// تم تغيير الاستيراد هنا ليتعرف على شاشة الفايروول الجديدة
import 'package:st_manager/screens/firewall_screen.dart';
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
  static const String _telegramCommentPrefix = 'TelegramBot_';

  int? _subscriptionDaysRemaining;
  DateTime? _subscriptionExpiryDate;
  bool _loadingDays = true;

  Future<void> _loadSubscriptionCounter() async {
    try {
      final phone = await _storage.getPhone();
      DateTime? expiryDate;

      if (phone != null && phone.trim().isNotEmpty) {
        expiryDate = await FirebaseService.getLicenseExpiry(phone.trim());
        if (expiryDate != null) {
          await _storage.write(
              'license_expiry_date', expiryDate.toIso8601String());
        }
      }

      if (expiryDate == null) {
        final rawExpiry = await _storage.read('license_expiry_date');
        if (rawExpiry != null && rawExpiry.trim().isNotEmpty) {
          expiryDate = DateTime.tryParse(rawExpiry.trim());
        }
      }

      if (expiryDate == null) {
        if (mounted) {
          setState(() {
            _subscriptionExpiryDate = null;
            _subscriptionDaysRemaining = null;
            _loadingDays = false;
          });
        }
        return;
      }

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final expDate =
          DateTime(expiryDate.year, expiryDate.month, expiryDate.day);

      int daysRemaining = expDate.difference(today).inDays;
      if (daysRemaining < 0) daysRemaining = 0;

      if (mounted) {
        setState(() {
          _subscriptionExpiryDate = expDate;
          _subscriptionDaysRemaining = daysRemaining;
          _loadingDays = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _subscriptionExpiryDate = null;
          _subscriptionDaysRemaining = null;
          _loadingDays = false;
        });
      }
    }
  }

  String _subscriptionText() {
    final days = _subscriptionDaysRemaining;
    if (days == null) return 'الاشتراك: غير متوفر';
    if (days == 0) return 'الاشتراك منتهي';
    if (days == 1) return 'متبقي يوم واحد';
    if (days == 2) return 'متبقي يومان';
    return 'متبقي $days يوم';
  }

  Color _subscriptionColor() {
    final days = _subscriptionDaysRemaining;
    if (days == null) return Colors.white54;
    if (days <= 0) return Colors.redAccent;
    if (days <= 3) return Colors.orangeAccent;
    return Colors.greenAccent;
  }

  String _formatSubscriptionDate() {
    final date = _subscriptionExpiryDate;
    if (date == null) return 'تاريخ الانتهاء غير متوفر';
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();
    return '$day/$month/$year';
  }

  Future<void> _confirmFixLoop() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.semiBlack,
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange),
            SizedBox(width: 8),
            Text('حماية الشبكة من اللوب (Loop Protect)',
                style: TextStyle(color: Colors.white)),
          ],
        ),
        content: const Text(
          'هل أنت متأكد من تفعيل بروتوكول الحماية (RSTP) على جميع الجسور (Bridges) وتفعيل حماية المنافذ (Loop-Protect) لجميع كروت الشبكة؟\n'
          'هذا سيقوم بفصل أي راوتر يسبب لوب أوتوماتيكياً.',
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
            child: const Text('تأكيد وتنفيذ',
                style: TextStyle(
                    color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (confirm == true) await _fixLoop();
  }

  Future<void> _fixLoop() async {
    final router = widget.routerService;
    if (router == null) {
      _showSnack('لا يوجد اتصال بالراوتر', backgroundColor: Colors.red);
      return;
    }
    try {
      await router.sendCommand('/interface/bridge/set',
          params: {'numbers': '[find]', 'protocol-mode': 'rstp'});
      await router.sendCommand('/interface/ethernet/set',
          params: {'numbers': '[find]', 'loop-protect': 'on'});
      _showSnack('تم تفعيل حماية اللوب (RSTP & Loop-Protect) بنجاح',
          backgroundColor: Colors.green);
    } catch (e) {
      _showSnack('حدث خطأ أثناء تفعيل الحماية: $e',
          backgroundColor: Colors.red);
    }
  }

  String _cleanText(String value) => value.trim();

  bool _isValidIpv4(String ip) {
    final v = ip.trim();
    if (v.isEmpty || v == 'لا يوجد IP' || v == 'غير معروف') return false;
    final parts = v.split('.');
    if (parts.length != 4) return false;
    for (final part in parts) {
      final n = int.tryParse(part);
      if (n == null || n < 0 || n > 255) return false;
    }
    return true;
  }

  String _automaticDisplayName(Map<String, dynamic> device, int index) {
    final identity = _cleanText(device['identity']?.toString() ?? '');
    final board = _cleanText(device['board']?.toString() ?? '');
    if (identity.isNotEmpty && identity != 'unknown') return identity;
    if (board.isNotEmpty && board != 'unknown') return board;
    return 'قطعة ${index + 1}';
  }

  String _buildTelegramComment(String name, String mac) {
    final cleanName = name.trim().isEmpty ? 'قطعة' : name.trim();
    final cleanMac = mac.trim();
    if (cleanMac.isEmpty || cleanMac == 'غير معروف') {
      return '$_telegramCommentPrefix$cleanName';
    }
    return '$_telegramCommentPrefix$cleanName [MAC:$cleanMac]';
  }

  String _extractMacFromTelegramComment(String comment) {
    final match =
        RegExp(r'\[MAC:([^\]]+)\]', caseSensitive: false).firstMatch(comment);
    return match?.group(1)?.trim() ?? '';
  }

  String _telegramNameFromComment(String comment) {
    if (!comment.startsWith(_telegramCommentPrefix)) return comment;
    final value = comment.substring(_telegramCommentPrefix.length);
    return value
        .replaceFirst(
            RegExp(r'\s*\[MAC:[^\]]+\]\s*$', caseSensitive: false), '')
        .trim();
  }

  String _scriptForTelegram({
    required String token,
    required String chat,
    required String message,
  }) {
    final encoded = Uri.encodeComponent(message);
    return '/tool fetch url="https://api.telegram.org/bot$token/sendMessage?chat_id=$chat&text=$encoded" keep-result=no';
  }

  // الإصلاح الثاني: جلب القطع تلقائياً من Neighbors وإضافتها في Netwatch لمنع التكرار وحقنها بالسكربتات
  Future<void> _syncAutomaticNetwatchDevices({
    required String token,
    required String chat,
    required bool notifyUp,
    required bool notifyDown,
  }) async {
    final router = widget.routerService;
    if (router == null || token.trim().isEmpty || chat.trim().isEmpty) return;

    try {
      final neighborResponse = await router.sendCommand('/ip/neighbor/print');
      final neighbors =
          neighborResponse is List ? neighborResponse : <dynamic>[];
      final netwatchResponse = await router.sendCommand('/tool/netwatch/print');
      final entries = netwatchResponse is List ? netwatchResponse : <dynamic>[];

      // بناء خريطة لجميع عناصر Netwatch الموجودة بالراوتر لمنع التكرار
      final netwatchByHost = <String, Map<String, dynamic>>{};
      final netwatchByMac = <String, Map<String, dynamic>>{};

      for (final raw in entries) {
        if (raw is! Map) continue;
        final item = Map<String, dynamic>.from(raw);
        final host = item['host']?.toString().trim().toLowerCase() ?? '';
        final comment = item['comment']?.toString() ?? '';
        final mac = _extractMacFromTelegramComment(comment).toLowerCase();

        if (host.isNotEmpty) netwatchByHost[host] = item;
        if (mac.isNotEmpty) netwatchByMac[mac] = item;
      }

      int added = 0;
      int updated = 0;
      int index = 0;
      final Set<String> processedIps = {};

      for (final raw in neighbors) {
        if (raw is! Map) continue;
        final device = Map<String, dynamic>.from(raw);

        final ip = _cleanText(device['address']?.toString() ??
            device['ip-address']?.toString() ??
            '');
        if (!_isValidIpv4(ip) || ip == '127.0.0.1' || ip == '0.0.0.0') continue;

        final normalizedIp = ip.toLowerCase();
        if (processedIps.contains(normalizedIp)) continue;
        processedIps.add(normalizedIp);

        final mac = _cleanText(device['mac-address']?.toString() ??
            device['mac']?.toString() ??
            '');
        final name = _automaticDisplayName(device, index++);
        final normalizedMac = mac.toLowerCase();

        Map<String, dynamic>? existing = netwatchByHost[normalizedIp];
        if (existing == null && normalizedMac.isNotEmpty) {
          existing = netwatchByMac[normalizedMac];
        }

        final upMessage = '✅ القطعة $name ($ip) عادت إلى العمل.';
        final downMessage = '❌ القطعة $name ($ip) توقفت عن العمل.';
        final upScript = notifyUp
            ? _scriptForTelegram(token: token, chat: chat, message: upMessage)
            : '';
        final downScript = notifyDown
            ? _scriptForTelegram(token: token, chat: chat, message: downMessage)
            : '';

        if (existing != null) {
          final id = existing['.id']?.toString() ?? '';
          if (id.isNotEmpty) {
            final oldComment = existing['comment']?.toString() ?? '';
            final savedName = _telegramNameFromComment(oldComment);
            final displayName =
                (savedName.isNotEmpty && savedName != oldComment)
                    ? savedName
                    : name;
            final comment = _buildTelegramComment(displayName, mac);

            await router.sendCommand('/tool/netwatch/set', params: {
              'numbers': id,
              'host': ip,
              'comment': comment,
              'up-script': upScript,
              'down-script': downScript,
            });
            updated++;
          }
        } else {
          await router.sendCommand('/tool/netwatch/add', params: {
            'host': ip,
            'comment': _buildTelegramComment(name, mac),
            'up-script': upScript,
            'down-script': downScript,
          });
          added++;
        }
      }

      if (added > 0 || updated > 0) {
        _showSnack(
            '✅ تمت مزامنة قطع الشبكة من Neighbors تلقائياً: أضيف $added، حُدّث $updated',
            backgroundColor: Colors.green);
      }
    } catch (e) {
      _showSnack('⚠️ تعذر مزامنة قطع الشبكة مع Netwatch: $e',
          backgroundColor: Colors.orange);
    }
  }

  Future<void> _showTelegramBotDialog() async {
    final savedToken = await _storage.read('telegram_bot_token') ?? '';
    final savedChatId = await _storage.read('telegram_chat_id') ?? '';

    bool notifyUp = await _storage.read('tg_notify_up') == 'true';
    bool notifyDown = await _storage.read('tg_notify_down') == 'true';
    bool notifyExpiry = await _storage.read('tg_notify_expiry') == 'true';
    bool notifyHighUsage =
        await _storage.read('tg_notify_high_usage') == 'true';
    bool notifyRestart = await _storage.read('tg_notify_restart') == 'true';

    final ipsController = TextEditingController();
    final namesController = TextEditingController();
    final tokenCtrl = TextEditingController(text: savedToken);
    final chatCtrl = TextEditingController(text: savedChatId);

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
                _buildField(
                  controller: tokenCtrl,
                  label: 'توكن البوت (Bot Token)',
                  hint: 'سيتم حفظه تلقائياً',
                ),
                _buildField(
                  controller: chatCtrl,
                  label: 'معرف المحادثة (Chat ID)',
                  hint: 'سيتم حفظه تلقائياً',
                ),
                const SizedBox(height: 12),
                const Text('خيارات الإشعارات:',
                    style: TextStyle(
                        color: AppTheme.gold,
                        fontSize: 12,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                _buildNotifToggle(
                  ctx,
                  setDialogState,
                  icon: Icons.arrow_upward,
                  iconColor: Colors.green,
                  label: 'إشعار عند عودة القطعة (Up)',
                  value: notifyUp,
                  onChanged: (v) => setDialogState(() => notifyUp = v),
                ),
                _buildNotifToggle(
                  ctx,
                  setDialogState,
                  icon: Icons.arrow_downward,
                  iconColor: Colors.red,
                  label: 'إشعار عند انقطاع القطعة (Down)',
                  value: notifyDown,
                  onChanged: (v) => setDialogState(() => notifyDown = v),
                ),
                _buildNotifToggle(
                  ctx,
                  setDialogState,
                  icon: Icons.timer_off,
                  iconColor: Colors.orange,
                  label: 'إشعار انتهاء صلاحية (عام)',
                  value: notifyExpiry,
                  onChanged: (v) => setDialogState(() => notifyExpiry = v),
                ),
                _buildNotifToggle(
                  ctx,
                  setDialogState,
                  icon: Icons.speed,
                  iconColor: Colors.purple,
                  label: 'إشعار استهلاك عالي (عام)',
                  value: notifyHighUsage,
                  onChanged: (v) => setDialogState(() => notifyHighUsage = v),
                ),
                _buildNotifToggle(
                  ctx,
                  setDialogState,
                  icon: Icons.restart_alt,
                  iconColor: Colors.cyan,
                  label: 'إشعار إعادة تشغيل (عام)',
                  value: notifyRestart,
                  onChanged: (v) => setDialogState(() => notifyRestart = v),
                ),
                const Divider(color: Colors.white24, height: 20),
                const Text('إضافة قطع متعددة يدوياً إلى Netwatch:',
                    style: TextStyle(
                        color: AppTheme.gold,
                        fontSize: 12,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                _buildField(
                  controller: ipsController,
                  label: 'عناوين IP (مفصولة بفواصل)',
                  hint: 'مثال: 192.168.1.10, 192.168.1.20',
                ),
                _buildField(
                  controller: namesController,
                  label: 'أسماء القطع (مفصولة بفواصل بنفس الترتيب)',
                  hint: 'مثال: قطعة1, قطعة2',
                ),
                const SizedBox(height: 8),
                const Text(
                    'ملاحظة: سيتم استجلاب جميع قطع الأجهزة تلقائياً من Neighbors ومزامنتها مع Netwatch بدقة.',
                    style: TextStyle(color: Colors.white38, fontSize: 11)),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child:
                  const Text('إلغاء', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade700),
              onPressed: () async {
                await _testTelegramBot(
                  tokenCtrl.text.trim(),
                  chatCtrl.text.trim(),
                );
              },
              icon: const Icon(Icons.send, color: Colors.white),
              label:
                  const Text('اختبار', style: TextStyle(color: Colors.white)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.gold),
              onPressed: () async {
                final token = tokenCtrl.text.trim();
                final chat = chatCtrl.text.trim();

                await _storage.write('telegram_bot_token', token);
                await _storage.write('telegram_chat_id', chat);
                await _storage.write('tg_notify_up', notifyUp.toString());
                await _storage.write('tg_notify_down', notifyDown.toString());
                await _storage.write(
                    'tg_notify_expiry', notifyExpiry.toString());
                await _storage.write(
                    'tg_notify_high_usage', notifyHighUsage.toString());
                await _storage.write(
                    'tg_notify_restart', notifyRestart.toString());

                final ips = ipsController.text
                    .split(',')
                    .map((e) => e.trim())
                    .where((e) => e.isNotEmpty)
                    .toList();
                final names = namesController.text
                    .split(',')
                    .map((e) => e.trim())
                    .where((e) => e.isNotEmpty)
                    .toList();

                if (ips.isNotEmpty) {
                  final fullNames = List<String>.filled(ips.length, 'قطعة');
                  for (int i = 0; i < ips.length && i < names.length; i++) {
                    fullNames[i] = names[i];
                  }
                  for (int i = 0; i < ips.length; i++) {
                    await _addNetwatchEntry(
                      fullNames[i],
                      ips[i],
                      token,
                      chat,
                      notifyUp,
                      notifyDown,
                    );
                  }
                }

                await _updateAllNetwatchEntries(
                  token,
                  chat,
                  notifyUp,
                  notifyDown,
                );

                // استدعاء جلب وتحديث القطع من Neighbors تلقائياً
                await _syncAutomaticNetwatchDevices(
                  token: token,
                  chat: chat,
                  notifyUp: notifyUp,
                  notifyDown: notifyDown,
                );

                Navigator.pop(ctx);
                _showSnack(
                  '✅ تم حفظ الإعدادات ومزامنة جميع قطع الشبكة من Neighbors بنجاح',
                  backgroundColor: Colors.green,
                );
              },
              child: const Text('حفظ وتحديث الكل',
                  style: TextStyle(
                      color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
    tokenCtrl.dispose();
    chatCtrl.dispose();
    ipsController.dispose();
    namesController.dispose();
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

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    String? hint,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: AppTheme.gold, fontSize: 12),
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.white30),
          filled: true,
          fillColor: Colors.white10,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Future<void> _addNetwatchEntry(
    String name,
    String ip,
    String token,
    String chat,
    bool notifyUp,
    bool notifyDown,
  ) async {
    final router = widget.routerService;
    if (router == null || !_isValidIpv4(ip)) return;

    final upMsg = '✅ القطعة $name ($ip) عادت إلى العمل.';
    final downMsg = '❌ القطعة $name ($ip) توقفت عن العمل.';
    final upScript = notifyUp
        ? _scriptForTelegram(token: token, chat: chat, message: upMsg)
        : '';
    final downScript = notifyDown
        ? _scriptForTelegram(token: token, chat: chat, message: downMsg)
        : '';

    try {
      final response = await router.sendCommand('/tool/netwatch/print');
      final entries = response is List ? response : <dynamic>[];
      Map<String, dynamic>? existing;
      for (final raw in entries) {
        if (raw is! Map) continue;
        final item = Map<String, dynamic>.from(raw);
        final host = item['host']?.toString().trim() ?? '';
        if (host.toLowerCase() == ip.toLowerCase()) {
          existing = item;
          break;
        }
      }

      if (existing != null) {
        final id = existing['.id']?.toString() ?? '';
        if (id.isNotEmpty) {
          await router.sendCommand('/tool/netwatch/set', params: {
            'numbers': id,
            'comment': _buildTelegramComment(
                name,
                _extractMacFromTelegramComment(
                    existing['comment']?.toString() ?? '')),
            'up-script': upScript,
            'down-script': downScript,
          });
        }
      } else {
        await router.sendCommand('/tool/netwatch/add', params: {
          'host': ip,
          'comment': _buildTelegramComment(name, ''),
          'up-script': upScript,
          'down-script': downScript,
        });
      }
    } catch (_) {}
  }

  Future<void> _updateAllNetwatchEntries(
    String token,
    String chat,
    bool notifyUp,
    bool notifyDown,
  ) async {
    final router = widget.routerService;
    if (router == null) return;

    try {
      final response = await router.sendCommand('/tool/netwatch/print');
      final entries = response is List ? response : <dynamic>[];
      for (final raw in entries) {
        if (raw is! Map) continue;
        final entry = Map<String, dynamic>.from(raw);
        final comment = entry['comment']?.toString() ?? '';
        if (!comment.startsWith(_telegramCommentPrefix)) continue;

        final id = entry['.id']?.toString() ?? '';
        if (id.isEmpty) continue;

        final name = _telegramNameFromComment(comment);
        final ip = entry['host']?.toString() ?? '';
        final upMsg = '✅ القطعة $name ($ip) عادت إلى العمل.';
        final downMsg = '❌ القطعة $name ($ip) توقفت عن العمل.';
        final upScript = notifyUp
            ? _scriptForTelegram(token: token, chat: chat, message: upMsg)
            : '';
        final downScript = notifyDown
            ? _scriptForTelegram(token: token, chat: chat, message: downMsg)
            : '';

        await router.sendCommand('/tool/netwatch/set', params: {
          'numbers': id,
          'up-script': upScript,
          'down-script': downScript,
        });
      }
    } catch (_) {}
  }

  Future<void> _testTelegramBot(String token, String chat) async {
    final router = widget.routerService;
    if (router == null) {
      _showSnack('لا يوجد اتصال بالراوتر', backgroundColor: Colors.red);
      return;
    }
    if (token.isEmpty || chat.isEmpty) {
      _showSnack('⚠️️ أدخل التوكن والـ Chat ID أولاً',
          backgroundColor: Colors.orange);
      return;
    }

    try {
      final resource = await router.getSystemResource();
      final res = resource.isNotEmpty ? resource.first : {};
      final boardName = res['board-name'] ?? 'غير معروف';
      final version = res['version'] ?? '';
      final cpu = res['cpu'] ?? '';
      final temperature = res['temperature']?.toString() ?? 'غير متاح';

      String voltage = 'غير متاح';
      try {
        final healthResp = await router.sendCommand('/system/health/print');
        if (healthResp is List) {
          for (final item in healthResp) {
            if (item['name']?.toString().toLowerCase() == 'voltage') {
              voltage = item['value']?.toString() ?? 'غير متاح';
              break;
            }
          }
        }
      } catch (_) {}

      final message = '📊 *معلومات الراوتر*\n'
          '------------------------\n'
          '🖥️ الجهاز: $boardName\n'
          '📦 الإصدار: $version\n'
          '⚙️ المعالج: $cpu\n'
          '🌡️ الحرارة: $temperature°C\n'
          '⚡ الجهد: $voltage\n'
          '------------------------\n'
          '📱 *ST_Manager*';

      final encoded = Uri.encodeComponent(message);
      final url =
          'https://api.telegram.org/bot$token/sendMessage?chat_id=$chat&text=$encoded&parse_mode=Markdown';

      await router.sendCommand('/tool/fetch', params: {
        'url': url,
        'keep-result': 'no',
      });

      _showSnack('📨 تم إرسال رسالة الاختبار إلى التلجرام',
          backgroundColor: Colors.blue);
    } catch (e) {
      _showSnack('❌ فشل إرسال رسالة الاختبار: $e', backgroundColor: Colors.red);
    }
  }

  void _showSnack(String message, {Color backgroundColor = Colors.black87}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: backgroundColor),
    );
  }

  // الإصلاح الأول: فحص حالة قواعد Fasttrack
  Future<bool> _checkFasttrackStatus() async {
    final router = widget.routerService;
    if (router == null) return false;
    try {
      final filters = await router.sendCommand('/ip/firewall/filter/print');
      if (filters is List) {
        for (final rule in filters) {
          if (rule is Map) {
            final action = rule['action']?.toString() ?? '';
            final comment = rule['comment']?.toString() ?? '';
            final disabled = rule['disabled']?.toString() == 'true';
            if ((action == 'fasttrack-connection' ||
                    comment.contains('ST_Manager_Fasttrack')) &&
                !disabled) {
              return true;
            }
          }
        }
      }
    } catch (_) {}
    return false;
  }

  // الإصلاح الأول: تفعيل أو إيقاف قواعد Fasttrack وإعطائها الأولوية في الفايروول
  Future<void> _toggleFasttrack(bool enable) async {
    final router = widget.routerService;
    if (router == null) {
      _showSnack('لا يوجد اتصال بالراوتر', backgroundColor: Colors.red);
      return;
    }

    try {
      final filtersResp = await router.sendCommand('/ip/firewall/filter/print');
      final filters = filtersResp is List ? filtersResp : [];

      final List<Map<String, dynamic>> fasttrackRules = [];
      for (final rule in filters) {
        if (rule is Map) {
          final item = Map<String, dynamic>.from(rule);
          final action = item['action']?.toString() ?? '';
          final comment = item['comment']?.toString() ?? '';
          if (action == 'fasttrack-connection' ||
              comment.contains('ST_Manager_Fasttrack')) {
            fasttrackRules.add(item);
          }
        }
      }

      if (enable) {
        if (fasttrackRules.isNotEmpty) {
          // في حال وجود قواعد Fasttrack: تفعيلها ونقلها لأول الفايروول
          for (final rule in fasttrackRules) {
            final id = rule['.id']?.toString() ?? '';
            if (id.isNotEmpty) {
              await router.sendCommand('/ip/firewall/filter/set', params: {
                'numbers': id,
                'disabled': 'no',
              });
              try {
                await router.sendCommand('/ip/firewall/filter/move', params: {
                  'numbers': id,
                  'destination': '0',
                });
              } catch (_) {}
            }
          }
        } else {
          // في حال عدم وجودها: إنشاء قاعدة جديدة بأولوية قصوى
          await router.sendCommand('/ip/firewall/filter/add', params: {
            'chain': 'forward',
            'action': 'fasttrack-connection',
            'connection-state': 'established,related',
            'comment': 'ST_Manager_Fasttrack',
            'place-before': '0',
          });
        }
        _showSnack('✅ تم تفعيل فتح السرعة للجميع (Fasttrack) بنجاح',
            backgroundColor: Colors.green);
      } else {
        // عند إيقاف فتح السرعة: تعطيل قواعد Fasttrack
        if (fasttrackRules.isNotEmpty) {
          for (final rule in fasttrackRules) {
            final id = rule['.id']?.toString() ?? '';
            if (id.isNotEmpty) {
              await router.sendCommand('/ip/firewall/filter/set', params: {
                'numbers': id,
                'disabled': 'yes',
              });
            }
          }
        }
        _showSnack('🛑 تم إيقاف فتح السرعة (تعطيل قواعد Fasttrack)',
            backgroundColor: Colors.orange);
      }
    } catch (e) {
      _showSnack('❌ حدث خطأ أثناء تغيير حالة السرعة: $e',
          backgroundColor: Colors.red);
    }
  }

  // الإصلاح الأول: نافذة زر تشغيل وإيقاف السرعة للجميع بدل الساعة والمؤقت
  Future<void> _showSpeedBoostDialog() async {
    final router = widget.routerService;
    if (router == null) {
      _showSnack('لا يوجد اتصال بالراوتر', backgroundColor: Colors.red);
      return;
    }

    bool isEnabled = await _checkFasttrackStatus();
    bool isProcessing = false;

    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            backgroundColor: AppTheme.semiBlack,
            title: const Row(
              children: [
                Icon(Icons.rocket_launch, color: AppTheme.gold),
                SizedBox(width: 8),
                Text('فتح السرعة للجميع',
                    style: TextStyle(color: Colors.white, fontSize: 16)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'عند تشغيل فتح السرعة للجميع، سيتم التأكد من وجود قواعد Fasttrack وتفعيلها وإعطائها الأولوية في جدار الحماية. وعند الإيقاف يتم تعطيلها.',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 16),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            isEnabled ? Icons.flash_on : Icons.flash_off,
                            color:
                                isEnabled ? Colors.greenAccent : Colors.white38,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            isEnabled ? 'مفعل (سرعة مفتوحة)' : 'معطل',
                            style: TextStyle(
                              color: isEnabled
                                  ? Colors.greenAccent
                                  : Colors.white70,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      isProcessing
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppTheme.gold,
                              ),
                            )
                          : Switch(
                              value: isEnabled,
                              activeColor: AppTheme.gold,
                              onChanged: (val) async {
                                setDialogState(() => isProcessing = true);
                                await _toggleFasttrack(val);
                                final status = await _checkFasttrackStatus();
                                if (ctx.mounted) {
                                  setDialogState(() {
                                    isEnabled = status;
                                    isProcessing = false;
                                  });
                                }
                              },
                            ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('إغلاق',
                    style: TextStyle(color: Colors.white54)),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showOpenUserSpeedDialog() async {
    final nameController = TextEditingController();
    try {
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
              child:
                  const Text('إلغاء', style: TextStyle(color: Colors.white54)),
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
    } finally {
      nameController.dispose();
    }
  }

  Future<void> _applyUserSpeedBoost(String username) async {
    final router = widget.routerService;
    if (router == null || username.isEmpty) return;

    try {
      final secrets =
          await router.sendCommand('/ppp/secret/print', useCache: false);
      final secret = secrets.firstWhere(
        (s) => s['name']?.toString().toLowerCase() == username.toLowerCase(),
        orElse: () => {},
      );

      if (secret.isEmpty) {
        _showSnack('⚠️ المستخدم "$username" غير موجود',
            backgroundColor: Colors.orange);
        return;
      }

      final secretId = secret['.id']?.toString() ?? '';
      if (secretId.isNotEmpty) {
        try {
          await router.sendCommand('/ppp/profile/add',
              params: {'name': 'Speed', 'rate-limit': '', 'only-one': 'no'});
        } catch (_) {}
        await router.sendCommand('/ppp/secret/set',
            params: {'numbers': secretId, 'profile': 'Speed'});
      }

      final active =
          await router.sendCommand('/ppp/active/print', useCache: false);
      for (final session in active) {
        final sessionName = session['name']?.toString().toLowerCase() ?? '';
        if (sessionName == username.toLowerCase()) {
          final activeId = session['.id']?.toString() ?? '';
          if (activeId.isNotEmpty) {
            await router.sendCommand('/ppp/active/remove',
                params: {'numbers': activeId});
          }
        }
      }

      _showSnack('✅ تم فتح سرعة "$username" بنجاح',
          backgroundColor: Colors.green);
    } catch (e) {
      _showSnack('❌ فشل: $e', backgroundColor: Colors.red);
    }
  }

  Future<void> _showRouterInfo() async {
    final router = widget.routerService;
    if (router == null) return;

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
      final resource = await router.getSystemResource();
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
        _showSnack('❌ فشل جلب المعلومات: $e', backgroundColor: Colors.red);
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
                  style: const TextStyle(color: Colors.white70, fontSize: 12))),
        ],
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    if (bytes >= 1024 * 1024 * 1024)
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    if (bytes >= 1024 * 1024)
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    if (bytes >= 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
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
      title: Text(label,
          style: TextStyle(color: labelColor ?? Colors.white, fontSize: 13)),
      onTap: onTap,
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(title,
          style: const TextStyle(
              color: AppTheme.gold,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5)),
    );
  }

  Widget _buildFooter() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Colors.white12, width: 1)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('ST Manager',
              style: TextStyle(
                  color: AppTheme.gold.withOpacity(0.95),
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.6)),
          const SizedBox(height: 4),
          Text('الإصدار $_appVersion • برمجة م.احمد النعيمي',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white38, fontSize: 11)),
          const SizedBox(height: 2),
          const Text('+963995870655',
              style: TextStyle(color: Colors.white38, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildSubscriptionHeader() {
    final color = _subscriptionColor();
    final text =
        _loadingDays ? 'جارٍ التحقق من الترخيص...' : _subscriptionText();

    return Column(
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
        const SizedBox(height: 4),
        const Text('إدارة الشبكة والتحكم الذكي',
            style: TextStyle(color: Colors.white54, fontSize: 11)),
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(
              _subscriptionDaysRemaining != null &&
                      _subscriptionDaysRemaining! <= 0
                  ? Icons.error_outline
                  : Icons.verified_user,
              color: color,
              size: 14,
            ),
            const SizedBox(width: 6),
            _loadingDays
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppTheme.gold))
                : Text(text, style: TextStyle(color: color, fontSize: 12)),
          ],
        ),
        if (_subscriptionExpiryDate != null && !_loadingDays)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text('ينتهي: ${_formatSubscriptionDate()}',
                style: const TextStyle(color: Colors.white38, fontSize: 10)),
          ),
      ],
    );
  }

  @override
  void initState() {
    super.initState();
    _loadSubscriptionCounter();
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
              child: _buildSubscriptionHeader(),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  _sectionHeader('أدوات'),
                  _buildTile(
                    icon: Icons.info_outline,
                    label: 'معلومات الراوتر',
                    onTap: () {
                      Navigator.pop(context);
                      _showRouterInfo();
                    },
                  ),
                  _sectionHeader('إدارة الجدار الناري'),
                  _buildTile(
                    icon: Icons.security,
                    label: 'Firewall',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => FirewallScreen(
                                  routerService: widget.routerService)));
                    },
                  ),
                  _buildTile(
                    icon: Icons.build,
                    label: 'حماية اللوب (Loop Protect)',
                    onTap: () {
                      Navigator.pop(context);
                      _confirmFixLoop();
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
                    label: 'فتح السرعة للجميع',
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
                    label: 'إعداد بوت التلجرام (Netwatch)',
                    iconColor: const Color(0xFF29B6F6),
                    onTap: () {
                      Navigator.pop(context);
                      _showTelegramBotDialog();
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
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child:
                  const Text('إلغاء', style: TextStyle(color: Colors.white54))),
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
        _showSnack('🔄 جاري إعادة تشغيل الراوتر...',
            backgroundColor: Colors.orange);
      } catch (e) {
        _showSnack('❌ فشل: $e', backgroundColor: Colors.red);
      }
    }
  }
}
