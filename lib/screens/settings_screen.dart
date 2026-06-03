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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الإعدادات')),
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text('الوضع الفاتح',
                style: TextStyle(color: Colors.white)),
            subtitle: const Text('تغيير مظهر التطبيق إلى الألوان الفاتحة'),
            value: currentMode == ThemeMode.light,
            onChanged: (value) {
              onThemeChanged(value ? ThemeMode.light : ThemeMode.dark);
            },
            activeColor: AppTheme.gold,
          ),
          // يمكن إضافة إعدادات أخرى هنا
        ],
      ),
    );
  }
}
