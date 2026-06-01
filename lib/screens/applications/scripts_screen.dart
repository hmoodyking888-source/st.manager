import 'package:flutter/material.dart';
import 'package:st_manager/services/router_service.dart';
import 'package:st_manager/theme/app_theme.dart';

class ScriptsScreen extends StatefulWidget {
  final RouterService? routerService;
  const ScriptsScreen({super.key, required this.routerService});

  @override
  State<ScriptsScreen> createState() => _ScriptsScreenState();
}

class _ScriptsScreenState extends State<ScriptsScreen> {
  final List<Map<String, String>> _scripts = [
    {
      'name': 'تسريع واتساب',
      'command': 'ip dns static add name=whatsapp.com address=157.240.1.35'
    },
    {
      'name': 'تسريع فيسبوك',
      'command': 'ip dns static add name=facebook.com address=157.240.1.35'
    },
    {'name': 'استعادة نسخة', 'command': 'system backup load name=st_backup'},
  ];

  Future<void> _execute(String command) async {
    if (widget.routerService == null) return;
    try {
      final parts = command.split(' ');
      final cmd = parts.first;
      final params = <String, String>{};
      for (var p in parts.skip(1)) {
        final eq = p.split('=');
        if (eq.length == 2) params[eq[0]] = eq[1];
      }
      await widget.routerService!.sendCommand(cmd, params: params);
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('تم التنفيذ')));
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('فشل: $e')));
    }
  }

  void _addScript() {
    final nameCtrl = TextEditingController();
    final cmdCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('إضافة سكربت'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'الاسم')),
            TextField(
                controller: cmdCtrl,
                decoration: const InputDecoration(labelText: 'الأمر')),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () {
              setState(() => _scripts
                  .add({'name': nameCtrl.text, 'command': cmdCtrl.text}));
              Navigator.pop(context);
            },
            child: const Text('إضافة'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('السكربتات')),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTheme.gold,
        onPressed: _addScript,
        child: const Icon(Icons.add),
      ),
      body: ListView.builder(
        itemCount: _scripts.length,
        itemBuilder: (_, i) {
          final s = _scripts[i];
          return ListTile(
            leading: const Icon(Icons.terminal, color: AppTheme.gold),
            title:
                Text(s['name']!, style: const TextStyle(color: Colors.white)),
            trailing: IconButton(
              icon: const Icon(Icons.play_arrow, color: AppTheme.greenOnline),
              onPressed: () => _execute(s['command']!),
            ),
            onLongPress: () => setState(() => _scripts.removeAt(i)),
          );
        },
      ),
    );
  }
}
