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
  List<File> _localBackups = [];

  @override
  void initState() {
    super.initState();
    _loadLocalBackups();
  }

  // الحصول على مسار المجلد باسم التطبيق على الهاتف
  Future<String> _getAppDirectory() async {
    Directory? directory;
    if (Platform.isAndroid) {
      // المحاولة لإنشاء المجلد في الذاكرة الخارجية الرئيسية لتسهيل الوصول إليه
      directory = Directory('/storage/emulated/0/st_manager');
      try {
        if (!await directory.exists()) {
          await directory.create(recursive: true);
        }
        return directory.path;
      } catch (e) {
        // في حال عدم وجود صلاحيات، سيتم استخدام المسار الافتراضي أدناه
      }
    }
    
    // المسار الافتراضي والآمن في النظام
    directory = await getApplicationDocumentsDirectory();
    final folder = Directory('${directory.path}/st_manager');
    if (!await folder.exists()) {
      await folder.create(recursive: true);
    }
    return folder.path;
  }

  // تحميل قائمة النسخ من الهاتف
  Future<void> _loadLocalBackups() async {
    try {
      final path = await _getAppDirectory();
      final folder = Directory(path);
      final files = folder.listSync().whereType<File>().where((file) => file.path.endsWith('.backup')).toList();
      
      // ترتيب النسخ من الأحدث إلى الأقدم
      files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
      
      setState(() {
        _localBackups = files;
      });
    } catch (e) {
      debugPrint("Error loading backups: $e");
    }
  }

  // دالة لتنسيق التاريخ بشكل مقروء
  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _backup() async {
    if (widget.routerService == null) return;
    setState(() => _loading = true);
    try {
      // إنشاء اسم فريد للنسخة بناءً على التاريخ والوقت
      final now = DateTime.now();
      final dateStr = "${now.year}${now.month.toString().padLeft(2,'0')}${now.day.toString().padLeft(2,'0')}_${now.hour}${now.minute}${now.second}";
      final backupName = 'st_backup_$dateStr';

      // أمر إنشاء النسخة على السيرفر
      await widget.routerService!.sendCommand('system/backup/save', params: {'name': backupName});
      
      // حفظ ملف النسخة (أو مرجعها) على الهاتف في مجلد التطبيق
      final path = await _getAppDirectory();
      final file = File('$path/$backupName.backup');
      await file.writeAsString('Backup Date: $now\nThis file represents the backup stored on the server.');

      await _loadLocalBackups(); // تحديث القائمة

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم إنشاء النسخة الاحتياطية وحفظها بنجاح')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('فشل إنشاء النسخة الاحتياطية')));
      }
    } finally {
      setState(() => _loading = false);
    }
  }

  // استرجاع النسخة
  Future<void> _restore(File file) async {
    if (widget.routerService == null) return;
    setState(() => _loading = true);
    try {
      final fileName = file.uri.pathSegments.last;
      await widget.routerService!.sendCommand('system/backup/load', params: {'name': fileName});
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تمت الاستعادة بنجاح (سيتم إعادة تشغيل السيرفر)')));
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

  // حذف النسخة
  Future<void> _delete(File file) async {
    final fileName = file.uri.pathSegments.last;
    
    // نافذة تأكيد الحذف
    bool? confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: Text('هل أنت متأكد من حذف النسخة $fileName؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
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
        // حذف من السيرفر (تجاهل الخطأ إن لم تكن موجودة هناك)
        await widget.routerService!.sendCommand('file/remove', params: {'numbers': fileName});
      } catch (_) {}

      try {
        // حذف من الهاتف
        if (await file.exists()) {
          await file.delete();
        }
        await _loadLocalBackups(); // تحديث القائمة
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('تم حذف النسخة بنجاح')));
        }
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('فشل الحذف')));
        }
      } finally {
        setState(() => _loading = false);
      }
    }
  }

  // نافذة تأكيد الاسترجاع
  Future<void> _confirmRestore(File file) async {
    bool? confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد الاسترجاع'),
        content: const Text('هل أنت متأكد من استرجاع هذه النسخة؟ سيتم استبدال الإعدادات الحالية وسيعاد تشغيل السيرفر.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('استرجاع', style: TextStyle(color: Colors.green)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _restore(file);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('النسخ الاحتياطي والاستعادة')),
      body: Column(
        children: [
          // قسم إنشاء النسخة العُلوي
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton.icon(
              onPressed: _loading ? null : _backup,
              icon: const Icon(Icons.save),
              label: const Text('إنشاء نسخة احتياطية جديدة'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
            ),
          ),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: CircularProgressIndicator(color: AppTheme.gold),
            ),
          const Divider(),
          
          // قسم عرض النسخ المحفوظة
          Expanded(
            child: _localBackups.isEmpty
                ? const Center(child: Text('لا توجد نسخ احتياطية محفوظة'))
                : ListView.builder(
                    itemCount: _localBackups.length,
                    itemBuilder: (context, index) {
                      final file = _localBackups[index];
                      final fileName = file.uri.pathSegments.last;
                      final fileDate = file.lastModifiedSync();

                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: ListTile(
                          leading: const Icon(Icons.backup, color: AppTheme.gold),
                          title: Text(fileName, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(_formatDate(fileDate)),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.restore, color: Colors.green),
                                onPressed: _loading ? null : () => _confirmRestore(file),
                                tooltip: 'استعادة هذه النسخة',
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: _loading ? null : () => _delete(file),
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
