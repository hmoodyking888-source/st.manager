import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
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
  List<Map<String, dynamic>> _backups = [];

  @override
  void initState() {
    super.initState();
    _loadBackups();
  }

  Future<String> _getAppDirectory() async {
    Directory? directory;
    if (Platform.isAndroid) {
      directory = Directory('/storage/emulated/0/ST_Backup');
      try {
        if (!await directory.exists()) {
          await directory.create(recursive: true);
        }
        return directory.path;
      } catch (e) {
        try {
          directory = Directory('/storage/emulated/0/Download/ST_Backup');
          if (!await directory.exists()) {
            await directory.create(recursive: true);
          }
          return directory.path;
        } catch (_) {}
      }
    }

    directory = await getApplicationDocumentsDirectory();
    final folder = Directory('${directory.path}/ST_Backup');
    if (!await folder.exists()) {
      await folder.create(recursive: true);
    }
    return folder.path;
  }

  /// تحميل ملفات النسخ الاحتياطي من الراوتر ومن جميع المسارات المحلية المتاحة لتفادي فقدانها بعد إعادة التثبيت
  Future<void> _loadBackups() async {
    final router = widget.routerService;
    final backupsList = <Map<String, dynamic>>[];

    // 1. جلب الملفات من الراوتر
    if (router != null && router.isConnected) {
      try {
        final files = await router.sendCommand('/file/print');
        for (var f in files) {
          final name = f['name']?.toString() ?? '';
          if (name.toLowerCase().endsWith('.backup')) {
            backupsList.add({
              'name': name,
              'size': f['size']?.toString() ?? 'غير معروف',
              'date': f['creation-time']?.toString() ?? 'سيرفر',
              'id': f['.id']?.toString() ?? '',
              'isServer': true,
            });
          }
        }
      } catch (e) {
        debugPrint("خطأ أثناء جلب ملفات الراوتر: $e");
      }
    }

    // 2. البحث عن الملفات في جميع المسارات المحلية المحتملة
    try {
      final List<String> possiblePaths = [];

      // إضافة المسارات العامة في الأندرويد التي قد تحتوي على نسخ قديمة
      if (Platform.isAndroid) {
        possiblePaths.add('/storage/emulated/0/ST_Backup');
        possiblePaths.add('/storage/emulated/0/Download/ST_Backup');
      }

      // إضافة المسار الخاص بالتطبيق (المسار الافتراضي الاحتياطي)
      final appDocDir = await getApplicationDocumentsDirectory();
      possiblePaths.add('${appDocDir.path}/ST_Backup');

      // ضمان إضافة المسار الأساسي الذي يتم الحفظ فيه حالياً
      final currentWritePath = await _getAppDirectory();
      if (!possiblePaths.contains(currentWritePath)) {
        possiblePaths.add(currentWritePath);
      }

      for (var path in possiblePaths) {
        try {
          final folder = Directory(path);
          if (folder.existsSync()) {
            final localFiles = folder
                .listSync()
                .whereType<File>()
                .where((file) => file.path.toLowerCase().endsWith('.backup'))
                .toList();

            for (var file in localFiles) {
              final fileName = file.uri.pathSegments.last;
              // التحقق من عدم التكرار (لتفادي عرض نفس النسخة مرتين إذا تطابقت المسارات)
              if (!backupsList.any((b) => b['name'] == fileName)) {
                backupsList.add({
                  'name': fileName,
                  'size': '${(file.lengthSync() / 1024).toStringAsFixed(1)} KB',
                  'date': _formatDate(file.lastModifiedSync()),
                  'file': file,
                  'isServer': false,
                });
              }
            }
          }
        } catch (e) {
          // يتم تجاهل الخطأ في مسار معين واستكمال البحث في المسارات الأخرى
          debugPrint("تعذر قراءة المسار: $path - $e");
        }
      }
    } catch (e) {
      debugPrint("خطأ أثناء جلب الملفات المحلية: $e");
    }

    if (mounted) {
      setState(() {
        _backups = backupsList;
      });
    }
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _showBackupTypeDialog() async {
    if (widget.routerService == null) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.semiBlack,
        title: const Text('اختر نوع النسخة الاحتياطية',
            textAlign: TextAlign.center, style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.dns, color: AppTheme.gold),
              title: const Text('نسخ احتياطي عام للسيرفر',
                  style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(ctx);
                _executeBackup('Server', 'نسخة عامة للسيرفر');
              },
            ),
            const Divider(color: Colors.white12),
            ListTile(
              leading: const Icon(Icons.router, color: Colors.blue),
              title: const Text('نسخة برودباند (حسابات وبروفايلات)',
                  style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(ctx);
                _executeBackup('Broadband', 'برودباند');
              },
            ),
            const Divider(color: Colors.white12),
            ListTile(
              leading: const Icon(Icons.wifi, color: Colors.orange),
              title: const Text('نسخة هوتسبوت (حسابات وبروفايلات)',
                  style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(ctx);
                _executeBackup('Hotspot', 'هوتسبوت');
              },
            ),
          ],
        ),
      ),
    );
  }

  /// تنفيذ إنشاء النسخة الاحتياطية بما يتوافق مع MikroTik RouterOS بدون أخطاء
  Future<void> _executeBackup(String prefix, String label) async {
    if (widget.routerService == null) return;
    setState(() => _loading = true);

    try {
      final now = DateTime.now();
      final dateFormatted =
          "${now.day.toString().padLeft(2, '0')}-${now.month.toString().padLeft(2, '0')}-${now.year}";
      final timeFormatted =
          "${now.hour.toString().padLeft(2, '0')}-${now.minute.toString().padLeft(2, '0')}";
      final backupName = '${prefix}_${dateFormatted}_$timeFormatted';

      // أمر إنشاء النسخة المتوافق مع ميكروتك (إزالة معيار type الغير مدعوم)
      await widget.routerService!.sendCommand(
        '/system/backup/save',
        params: {'name': backupName},
      );

      final path = await _getAppDirectory();
      final file = File('$path/$backupName.backup');
      await file.writeAsString(
          'Backup Type: $label\nDate: ${_formatDate(now)}\nStored on MikroTik Server.');

      await _loadBackups();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تم إنشاء نسخة ($label) وحفظها بنجاح')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل إنشاء النسخة الاحتياطية: $e')),
        );
      }
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _restore(Map<String, dynamic> backupItem) async {
    if (widget.routerService == null) return;
    setState(() => _loading = true);
    try {
      final fileName = backupItem['name']?.toString() ?? '';
      await widget.routerService!
          .sendCommand('/system/backup/load', params: {'name': fileName});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('تمت الاستعادة بنجاح (سيتم إعادة تشغيل السيرفر)')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل الاستعادة: $e')),
        );
      }
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _delete(Map<String, dynamic> backupItem) async {
    final fileName = backupItem['name']?.toString() ?? '';

    bool? confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.semiBlack,
        title: const Text('تأكيد الحذف', style: TextStyle(color: Colors.white)),
        content: Text('هل أنت متأكد من حذف النسخة $fileName؟',
            style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حذف', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _loading = true);

      try {
        if (backupItem['isServer'] == true) {
          final id = backupItem['id']?.toString() ?? '';
          if (id.isNotEmpty) {
            await widget.routerService!
                .sendCommand('/file/remove', params: {'numbers': id});
          } else {
            await widget.routerService!
                .sendCommand('/file/remove', params: {'numbers': fileName});
          }
        }
      } catch (_) {}

      try {
        if (backupItem['file'] != null && backupItem['file'] is File) {
          final File f = backupItem['file'];
          if (await f.exists()) {
            await f.delete();
          }
        }
        await _loadBackups();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم حذف النسخة بنجاح')),
          );
        }
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('فشل الحذف')),
          );
        }
      } finally {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _confirmRestore(Map<String, dynamic> backupItem) async {
    bool? confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.semiBlack,
        title: const Text('تأكيد الاسترجاع',
            style: TextStyle(color: Colors.white)),
        content: const Text(
          'هل أنت متأكد من استرجاع هذه النسخة؟ سيتم استبدال الإعدادات الحالية وسيعاد تشغيل السيرفر.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('استرجاع', style: TextStyle(color: Colors.green)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _restore(backupItem);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.black,
      appBar: AppBar(
        title: const Text('النسخ الاحتياطي والاستعادة'),
        backgroundColor: AppTheme.semiBlack,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton.icon(
              onPressed: _loading ? null : _showBackupTypeDialog,
              icon: const Icon(Icons.save),
              label: const Text('إنشاء نسخة احتياطية جديدة'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                backgroundColor: AppTheme.gold,
                foregroundColor: Colors.black,
              ),
            ),
          ),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: CircularProgressIndicator(color: AppTheme.gold),
            ),
          const Divider(color: Colors.white12),
          Expanded(
            child: _backups.isEmpty
                ? const Center(
                    child: Text('لا توجد نسخ احتياطية محفوظة',
                        style: TextStyle(color: Colors.white54)))
                : ListView.builder(
                    itemCount: _backups.length,
                    itemBuilder: (context, index) {
                      final item = _backups[index];
                      final fileName = item['name'] ?? '';
                      final fileDate = item['date'] ?? '';

                      return Card(
                        color: AppTheme.semiBlack,
                        margin: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 6),
                        child: ListTile(
                          leading:
                              const Icon(Icons.backup, color: AppTheme.gold),
                          title: Text(
                            fileName,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                fontSize: 13),
                          ),
                          subtitle: Text(fileDate,
                              style: const TextStyle(
                                  color: Colors.white38, fontSize: 11)),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.restore,
                                    color: Colors.green),
                                onPressed: _loading
                                    ? null
                                    : () => _confirmRestore(item),
                                tooltip: 'استعادة هذه النسخة',
                              ),
                              IconButton(
                                icon:
                                    const Icon(Icons.delete, color: Colors.red),
                                onPressed:
                                    _loading ? null : () => _delete(item),
                                tooltip: 'حذف هذه النسخة',
                              ),
                            ],
                          ),
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
