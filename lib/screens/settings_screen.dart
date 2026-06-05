import 'package:flutter/material.dart';
import 'package:st_manager/theme/app_theme.dart';

class SettingsScreen extends StatelessWidget {
  final ValueChanged<ThemeMode> onThemeChanged;
  final ThemeMode currentMode;

  const SettingsScreen({
    super.key,
    required this.onThemeChanged,
    required this.currentMode,
  });

  Widget _buildSectionCard({
    required BuildContext context,
    required Widget child,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.semiBlack,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppTheme.gold.withOpacity(0.25),
        ),
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLight = currentMode == ThemeMode.light;

    return Scaffold(
      appBar: AppBar(title: const Text('الإعدادات')),
      body: ListView(
        children: [
          _buildSectionCard(
            context: context,
            child: SwitchListTile(
              title: const Text(
                'الوضع الفاتح',
                style: TextStyle(color: Colors.white),
              ),
              subtitle: const Text(
                'تغيير مظهر التطبيق إلى الألوان الفاتحة',
                style: TextStyle(color: Colors.white54),
              ),
              value: isLight,
              onChanged: (value) {
                onThemeChanged(value ? ThemeMode.light : ThemeMode.dark);
              },
              activeColor: AppTheme.gold,
            ),
          ),
          _buildSectionCard(
            context: context,
            child: ListTile(
              leading: const Icon(Icons.info_outline, color: AppTheme.gold),
              title: const Text(
                'حول التطبيق',
                style: TextStyle(color: Colors.white),
              ),
              subtitle: const Text(
                'ST_Manager - MikroTik Network Management',
                style: TextStyle(color: Colors.white54),
              ),
              trailing: const Icon(Icons.chevron_right, color: Colors.white54),
              onTap: () {
                showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    backgroundColor: AppTheme.semiBlack,
                    title: const Text(
                      'ST_Manager',
                      style: TextStyle(color: Colors.white),
                    ),
                    content: const Text(
                      'واجهة إدارة ميكروتك مع نظام راوترات، PPP، هوتسبوت، وواجهة تحكم سريعة.',
                      style: TextStyle(color: Colors.white70),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('إغلاق'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
