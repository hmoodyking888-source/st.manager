import 'package:flutter/material.dart';
import 'package:st_manager/services/router_service.dart';
import 'package:st_manager/screens/hotspot/hotspot_active_users_screen.dart';
import 'package:st_manager/screens/hotspot/hotspot_profile_screen.dart';
import 'package:st_manager/screens/hotspot/hotspot_user_screen.dart';
import 'package:st_manager/theme/app_theme.dart';

class HotspotMenuScreen extends StatelessWidget {
  final RouterService? routerService;
  const HotspotMenuScreen({super.key, required this.routerService});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الهوتسبوت')),
      body: Center(
        child: Wrap(
          spacing: 20,
          runSpacing: 20,
          children: [
            _buildOption(context, 'المتصلون الآن', Icons.people, () {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => HotspotActiveUsersScreen(
                          routerService: routerService)));
            }),
            _buildOption(context, 'إضافة بروفايل', Icons.add_box, () {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => HotspotProfileScreen(
                          routerService: routerService, isEdit: false)));
            }),
            _buildOption(context, 'تعديل بروفايل', Icons.edit, () {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => HotspotProfileScreen(
                          routerService: routerService, isEdit: true)));
            }),
            _buildOption(context, 'إضافة حساب', Icons.person_add, () {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => HotspotUserScreen(
                          routerService: routerService, isEdit: false)));
            }),
            _buildOption(context, 'تعديل حساب', Icons.edit, () {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => HotspotUserScreen(
                          routerService: routerService, isEdit: true)));
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildOption(
      BuildContext context, String label, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          border: Border.all(color: AppTheme.gold, width: 1.5),
          borderRadius: BorderRadius.circular(16),
          color: AppTheme.semiBlack,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppTheme.gold, size: 40),
            const SizedBox(height: 8),
            Text(label,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
