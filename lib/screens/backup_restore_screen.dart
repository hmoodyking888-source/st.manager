import 'package:flutter/material.dart';
import 'package:st_manager/services/router_service.dart';
import 'package:st_manager/theme/app_theme.dart';

class BackupRestoreScreen extends StatefulWidget {
  final RouterService? routerService;
  const BackupRestoreScreen({super.key, required this.routerService});

  @override
  State<BackupRestoreScreen> createState() => _BackupRestoreScreenState();
}

class _BackupRestoreScreenState extends State<BackupRestoreScreen> {
  bool _loading = false;

  Future<void> _backup() async {
    if (widget.routerService == null) return;
    setState(() => _loading = true);
    try {
      await widget.routerService!
          .sendCommand('/system/backup/save', params: {'name': 'st_backup'});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم إنشاء النسخة الاحتياطية')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('فشل إنشاء النسخة الاحتياطية')));
      }
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _restore() async {
    if (widget.routerService == null) return;
    setState(() => _loading = true);
    try {
      await widget.routerService!
          .sendCommand('/system/backup/load', params: {'name': 'st_backup'});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تمت الاستعادة، سيتم إعادة التشغيل')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('فشل الاستعادة')));
      }
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('النسخ الاحتياطي والاستعادة')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton.icon(
              onPressed: _loading ? null : _backup,
              icon: const Icon(Icons.save),
              label: const Text('إنشاء نسخة احتياطية'),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loading ? null : _restore,
              icon: const Icon(Icons.restore),
              label: const Text('استعادة آخر نسخة'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.redOffline),
            ),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(8.0),
                child: CircularProgressIndicator(color: AppTheme.gold),
              ),
          ],
        ),
      ),
    );
  }
}
