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
    final isLight = currentMode == ThemeMode.light;
    final bg = isLight ? AppTheme.lightSurface : AppTheme.semiBlack;
    final border =
        isLight ? AppTheme.lightBorder : AppTheme.gold.withOpacity(0.25);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLight = currentMode == ThemeMode.light;
    final fg = isLight ? AppTheme.darkText : Colors.white;
    final fgSub = isLight ? AppTheme.mediumText : Colors.white54;

    return Scaffold(
      appBar: AppBar(title: const Text('الإعدادات')),
      body: ListView(
        children: [
          _buildSectionCard(
            context: context,
            child: SwitchListTile(
              title: Text(
                'الوضع الفاتح',
                style: TextStyle(color: fg),
              ),
              subtitle: Text(
                'تغيير مظهر التطبيق إلى الألوان الفاتحة',
                style: TextStyle(color: fgSub),
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
              title: Text(
                'حول التطبيق',
                style: TextStyle(color: fg),
              ),
              subtitle: Text(
                'ST_Manager - MikroTik Network Management',
                style: TextStyle(color: fgSub),
              ),
              trailing: Icon(
                Icons.chevron_right,
                color: isLight ? AppTheme.mediumText : Colors.white54,
              ),
              onTap: () {
                showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    backgroundColor:
                        isLight ? AppTheme.lightSurface : AppTheme.semiBlack,
                    title: Text(
                      'ST_Manager',
                      style: TextStyle(color: fg),
                    ),
                    content: Text(
                      'واجهة إدارة ميكروتك مع نظام راوترات، PPP، هوتسبوت، وواجهة تحكم سريعة.',
                      style: TextStyle(color: fgSub),
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
