import 'package:flutter/material.dart';
import 'package:st_manager/theme/app_theme.dart';

class GamingControlsScreen extends StatefulWidget {
  const GamingControlsScreen({super.key});

  @override
  State<GamingControlsScreen> createState() => _GamingControlsScreenState();
}

class _GamingControlsScreenState extends State<GamingControlsScreen> {
  TimeOfDay _from = const TimeOfDay(hour: 0, minute: 0);
  TimeOfDay _to = const TimeOfDay(hour: 0, minute: 0);

  void _applySpeedBoost() {
    // سكربت لمسح الـ TX/RX مؤقتاً
  }

  void _reducePing() {
    // سكربت تحسين البينغ
  }

  void _blockGames() {
    // حظر الألعاب
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تحكم الألعاب')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Card(
              child: ListTile(
                leading: const Icon(Icons.speed, color: AppTheme.gold),
                title: const Text('فتح السرعة المؤقت'),
                subtitle: Text(
                  'من ${_from.format(context)} إلى ${_to.format(context)}',
                ),
                onTap: () async {
                  final from = await showTimePicker(
                    context: context,
                    initialTime: _from,
                  );
                  final to = await showTimePicker(
                    context: context,
                    initialTime: _to,
                  );
                  if (from != null && to != null) {
                    setState(() {
                      _from = from;
                      _to = to;
                    });
                  }
                },
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              icon: const Icon(Icons.bolt),
              label: const Text('تطبيق فتح السرعة'),
              onPressed: _applySpeedBoost,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              icon: const Icon(Icons.sports_esports),
              label: const Text('تخفيض البينغ'),
              onPressed: _reducePing,
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              icon: const Icon(Icons.block),
              label: const Text('إيقاف الألعاب'),
              onPressed: _blockGames,
            ),
          ],
        ),
      ),
    );
  }
}
