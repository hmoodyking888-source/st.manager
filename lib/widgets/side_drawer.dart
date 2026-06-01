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

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: AppTheme.black,
      width: MediaQuery.of(context).size.width * 0.4, // العرض هنا صحيح
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
            title:
                const Text('فتح السرعة', style: TextStyle(color: Colors.white)),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.restart_alt, color: AppTheme.gold),
            title: const Text('إعادة تشغيل الراوتر',
                style: TextStyle(color: Colors.white)),
            onTap: () async {
              await widget.routerService
                  ?.sendCommand('system/reboot', usePost: true);
            },
          ),
          ListTile(
            leading: const Icon(Icons.telegram, color: AppTheme.gold),
            title: const Text('تفعيل البوت',
                style: TextStyle(color: Colors.white)),
            onTap: () async {
              await launchUrl(Uri.parse('https://t.me/ST_ManagerBot'));
            },
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
