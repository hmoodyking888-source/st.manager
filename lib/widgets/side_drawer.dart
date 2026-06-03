import 'package:flutter/material.dart';
import 'package:st_manager/services/router_service.dart';
import 'package:st_manager/services/secure_storage_service.dart';
import 'package:st_manager/screens/applications/scripts_screen.dart';
import 'package:st_manager/theme/app_theme.dart';
import 'package:url_launcher/url_launcher.dart';

class SideDrawer extends StatefulWidget {
  final RouterService? routerService;
  const SideDrawer({super.key, required this.routerService});

  @override
  State<SideDrawer> createState() => _SideDrawerState();
}

class _SideDrawerState extends State<SideDrawer> {
  final SecureStorageService _storage = SecureStorageService();
  int _remainingDays = 0;

  @override
  void initState() {
    super.initState();
    _loadRemainingDays();
  }

  Future<void> _loadRemainingDays() async {
    final firstLaunch = await _storage.getFirstLaunch();
    if (firstLaunch == null) return;
    final trialEnd = DateTime.parse(firstLaunch).add(const Duration(days: 3));
    final diff = trialEnd.difference(DateTime.now()).inDays;
    if (mounted) setState(() => _remainingDays = diff > 0 ? diff : 0);
  }

  // ---------- فتح السرعات الشامل المؤقت ----------
  Future<void> _showSpeedBoostDialog() async {
    TimeOfDay fromTime = const TimeOfDay(hour: 0, minute: 0);
    TimeOfDay toTime = const TimeOfDay(hour: 1, minute: 0);

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('فتح السرعات الشامل المؤقت'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('حدد وقت البداية والنهاية لفتح السرعات:'),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      const Text('من الساعة:'),
                      TextButton(
                        onPressed: () async {
                          final t = await showTimePicker(
                            context: ctx,
                            initialTime: fromTime,
                          );
                          if (t != null) setDialogState(() => fromTime = t);
                        },
                        child: Text(fromTime.format(ctx)),
                      ),
                    ],
                  ),
                  Column(
                    children: [
                      const Text('إلى الساعة:'),
                      TextButton(
                        onPressed: () async {
                          final t = await showTimePicker(
                            context: ctx,
                            initialTime: toTime,
                          );
                          if (t != null) setDialogState(() => toTime = t);
                        },
                        child: Text(toTime.format(ctx)),
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
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                _applySpeedBoost(fromTime, toTime);
              },
              child: const Text('تطبيق'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _applySpeedBoost(TimeOfDay from, TimeOfDay to) async {
    if (widget.routerService == null) return;
    try {
      // 1. حذف جميع rate-limit من بروفايلات الهوتسبوت
      final profiles = await widget.routerService!.getHotspotProfiles();
      for (var profile in profiles) {
        final profileId = profile['.id']?.toString() ?? '';
        if (profileId.isNotEmpty) {
          await widget.routerService!.sendCommand(
            '/ip/hotspot/user/profile/set',
            params: {
              'numbers': profileId,
              'rate-limit': '',
            },
          );
        }
      }

      // 2. طرد جميع المستخدمين النشطين
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
              'تم فتح السرعات من ${from.format(context)} إلى ${to.format(context)}',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل فتح السرعات: $e')),
        );
      }
    }
  }

  // ---------- تغيير الثيم ----------
  void _openSettings() {
    Navigator.pushNamed(context, '/settings');
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: AppTheme.black,
      width: MediaQuery.of(context).size.width * 0.4,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          const DrawerHeader(
            decoration: BoxDecoration(color: AppTheme.semiBlack),
            child: Text('القائمة الجانبية',
                style: TextStyle(color: AppTheme.gold)),
          ),
          ListTile(
            leading: const Icon(Icons.code, color: AppTheme.gold),
            title:
                const Text('السكربتات', style: TextStyle(color: Colors.white)),
            onTap: () {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) =>
                          ScriptsScreen(routerService: widget.routerService)));
            },
          ),
          ListTile(
            leading: const Icon(Icons.build, color: AppTheme.gold),
            title: const Text('إصلاح اللوب',
                style: TextStyle(color: Colors.white)),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.speed, color: AppTheme.gold),
            title: const Text('فتح سرعة مستخدم',
                style: TextStyle(color: Colors.white)),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.rocket_launch, color: AppTheme.gold),
            title: const Text('فتح سرعات شامل مؤقت',
                style: TextStyle(color: Colors.white)),
            onTap: _showSpeedBoostDialog,
          ),
          ListTile(
            leading: const Icon(Icons.restart_alt, color: AppTheme.gold),
            title: const Text('إعادة تشغيل الراوتر',
                style: TextStyle(color: Colors.white)),
            onTap: () async {
              await widget.routerService
                  ?.sendCommand('/system/reboot', usePost: true);
            },
          ),
          ListTile(
            leading: const Icon(Icons.telegram, color: AppTheme.gold),
            title: const Text('تفعيل البوت',
                style: TextStyle(color: Colors.white)),
            onTap: () async {
              await launchUrl(Uri.parse('https://t.me/st_mekro_bot'));
            },
          ),
          ListTile(
            leading: const Icon(Icons.palette, color: AppTheme.gold),
            title: const Text('تغيير الثيم',
                style: TextStyle(color: Colors.white)),
            onTap: _openSettings,
          ),
          const Divider(color: AppTheme.gold),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'المدة المتبقية: $_remainingDays يوم',
              style: const TextStyle(color: AppTheme.gold, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}
