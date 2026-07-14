import 'package:flutter/material.dart';
import 'package:st_manager/services/router_service.dart';
import 'package:st_manager/theme/app_theme.dart';

// نموذج بيانات التطبيق
class AppPriorityConfig {
  final String id;
  final String name;
  final IconData icon;
  final Color color;
  final List<String> hosts; // النطاقات الخاصة بالتطبيق لالتقاطها
  bool isEnabled;
  String currentLimit;

  AppPriorityConfig({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    required this.hosts,
    this.isEnabled = false,
    this.currentLimit = '',
  });
}

class AppPriorityScreen extends StatefulWidget {
  final RouterService? routerService;
  const AppPriorityScreen({super.key, required this.routerService});

  @override
  State<AppPriorityScreen> createState() => _AppPriorityScreenState();
}

class _AppPriorityScreenState extends State<AppPriorityScreen> {
  bool _loading = false;

  // قائمة التطبيقات المدعومة مع نطاقاتها (Hosts)
  final List<AppPriorityConfig> _apps = [
    AppPriorityConfig(
      id: 'whatsapp',
      name: 'واتساب (WhatsApp)',
      icon: Icons.chat,
      color: Colors.green,
      hosts: ['*whatsapp.net*', '*whatsapp.com*'],
    ),
    AppPriorityConfig(
      id: 'facebook',
      name: 'فيسبوك (Facebook)',
      icon: Icons.facebook,
      color: Colors.blue,
      hosts: ['*facebook.com*', '*fbcdn.net*'],
    ),
    AppPriorityConfig(
      id: 'instagram',
      name: 'انستغرام (Instagram)',
      icon: Icons.camera_alt,
      color: Colors.purpleAccent,
      hosts: ['*instagram.com*', '*cdninstagram.com*'],
    ),
    AppPriorityConfig(
      id: 'tiktok',
      name: 'تيك توك (TikTok)',
      icon: Icons.music_note,
      color: Colors.white,
      hosts: ['*tiktokcdn.com*', '*tiktokv.com*'],
    ),
    AppPriorityConfig(
      id: 'youtube',
      name: 'يوتيوب (YouTube)',
      icon: Icons.play_circle_fill,
      color: Colors.red,
      hosts: ['*youtube.com*', '*googlevideo.com*'],
    ),
    AppPriorityConfig(
      id: 'pubg',
      name: 'ببجي موبايل (PUBG)',
      icon: Icons.games,
      color: Colors.orange,
      hosts: ['*pubgmobile.com*', '*igamecj.com*'],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _checkActivePriorities();
  }

  // دالة لجلب حالة التطبيقات من الراوتر (هل هي مفعلة أم لا)
  Future<void> _checkActivePriorities() async {
    if (widget.routerService == null) return;
    setState(() => _loading = true);

    try {
      // نجلب الـ Queue Tree لنرى ما هو المفعل حالياً
      final response = await widget.routerService!.sendCommand('/queue/tree/print');
      if (response != null) {
        final List<dynamic> queues = response is List ? response : [];
        
        for (var app in _apps) {
          final queueName = 'Priority_${app.id}';
          // نبحث هل الـ Queue الخاص بالتطبيق موجود؟
          final q = queues.firstWhere(
            (element) => element['name'] == queueName,
            orElse: () => null,
          );

          if (q != null) {
            app.isEnabled = true;
            app.currentLimit = q['max-limit']?.toString() ?? 'غير محدد';
          } else {
            app.isEnabled = false;
            app.currentLimit = '';
          }
        }
      }
    } catch (_) {
      // تجاهل الأخطاء بصمت
    }

    setState(() => _loading = false);
  }

  // ==========================================
  // تفعيل أولوية التطبيق (إنشاء الرولات)
  // ==========================================
  Future<void> _enableAppPriority(AppPriorityConfig app, String maxLimit) async {
    setState(() => _loading = true);
    final comment = 'AppManager_${app.id}';
    final connMark = 'conn_${app.id}';
    final packMark = 'pack_${app.id}';
    final queueName = 'Priority_${app.id}';

    try {
      // 1. إنشاء Mangle Rules للاتصالات (Connection Mark) لكل نطاق
      for (String host in app.hosts) {
        await widget.routerService!.sendCommand('/ip/firewall/mangle/add', params: {
          'chain': 'forward',
          'tls-host': host,
          'action': 'mark-connection',
          'new-connection-mark': connMark,
          'passthrough': 'yes',
          'comment': comment,
        });
      }

      // 2. إنشاء Mangle Rule للحزم (Packet Mark)
      await widget.routerService!.sendCommand('/ip/firewall/mangle/add', params: {
        'chain': 'forward',
        'connection-mark': connMark,
        'action': 'mark-packet',
        'new-packet-mark': packMark,
        'passthrough': 'no', // No passthrough لتخفيف العبء على المعالج
        'comment': comment,
      });

      // 3. إنشاء Queue Tree لضبط السرعة والأولوية
      await widget.routerService!.sendCommand('/queue/tree/add', params: {
        'name': queueName,
        'parent': 'global',
        'packet-mark': packMark,
        'max-limit': maxLimit,
        'priority': '2', // أولوية عالية (1-8، الافتراضي 8)
        'comment': comment,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تم تفعيل وتسريع ${app.name} بنجاح'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ أثناء التفعيل: $e'), backgroundColor: Colors.red),
        );
      }
    }
    
    await _checkActivePriorities(); // تحديث الحالة
  }

  // ==========================================
  // تعطيل أولوية التطبيق (تنظيف وحذف الرولات)
  // ==========================================
  Future<void> _disableAppPriority(AppPriorityConfig app) async {
    setState(() => _loading = true);
    final comment = 'AppManager_${app.id}';
    final queueName = 'Priority_${app.id}';

    try {
      // 1. جلب وحذف رولات الـ Mangle الخاصة بالتطبيق
      final mangleResp = await widget.routerService!.sendCommand('/ip/firewall/mangle/print');
      if (mangleResp != null && mangleResp is List) {
        for (var rule in mangleResp) {
          if (rule['comment'] == comment) {
            await widget.routerService!.sendCommand(
              '/ip/firewall/mangle/remove', 
              params: {'numbers': rule['.id'].toString()}
            );
          }
        }
      }

      // 2. جلب وحذف الـ Queue Tree الخاص بالتطبيق
      final queueResp = await widget.routerService!.sendCommand('/queue/tree/print');
      if (queueResp != null && queueResp is List) {
        for (var q in queueResp) {
          if (q['name'] == queueName) {
            await widget.routerService!.sendCommand(
              '/queue/tree/remove', 
              params: {'numbers': q['.id'].toString()}
            );
          }
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تم إيقاف تسريع ${app.name} وإزالة الرولات'), backgroundColor: Colors.orange),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ أثناء الإيقاف: $e'), backgroundColor: Colors.red),
        );
      }
    }

    await _checkActivePriorities(); // تحديث الحالة
  }

  // نافذة إدخال السرعة عند التفعيل
  void _showSetupDialog(AppPriorityConfig app) {
    final limitCtrl = TextEditingController(text: '100M'); // قيمة افتراضية

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('تفعيل تسريع ${app.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('أدخل الحد الأقصى للسرعة (Max Limit):', style: TextStyle(fontSize: 14)),
            const SizedBox(height: 10),
            TextField(
              controller: limitCtrl,
              decoration: const InputDecoration(
                labelText: 'مثال: 50M أو 100M/20M',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'ملاحظة: سيتم إنشاء قواعد Mangle (Connection & Packet) وقاعدة Queue Tree بأولوية عالية تلقائياً.',
              style: TextStyle(fontSize: 12, color: Colors.white54),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.gold),
            onPressed: () {
              final limit = limitCtrl.text.trim();
              if (limit.isNotEmpty) {
                Navigator.pop(context);
                _enableAppPriority(app, limit);
              }
            },
            child: const Text('تفعيل الآن', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // نافذة تأكيد الإيقاف
  void _showDisableConfirmDialog(AppPriorityConfig app) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('تأكيد الإيقاف'),
        content: Text('هل أنت متأكد من إيقاف تسريع ${app.name}؟\nسيتم حذف جميع رولات الـ Mangle والـ Queue Tree المرتبطة به تلقائياً.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(context);
              _disableAppPriority(app);
            },
            child: const Text('إيقاف وحذف', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('أولوية وتسريع التطبيقات'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppTheme.gold),
            onPressed: _checkActivePriorities,
            tooltip: 'تحديث الحالة',
          )
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.gold))
          : ListView.builder(
              padding: const EdgeInsets.all(8.0),
              itemCount: _apps.length,
              itemBuilder: (_, i) {
                final app = _apps[i];
                return Card(
                  elevation: app.isEnabled ? 4 : 1,
                  shape: RoundedRectangleBorder(
                    side: BorderSide(
                      color: app.isEnabled ? app.color : Colors.transparent,
                      width: 1.5,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: app.color.withOpacity(0.2),
                        child: Icon(app.icon, color: app.color),
                      ),
                      title: Text(
                        app.name,
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text(
                            app.isEnabled ? 'الحالة: مفعل ونشط' : 'الحالة: معطل',
                            style: TextStyle(
                              color: app.isEnabled ? Colors.greenAccent : Colors.white54,
                            ),
                          ),
                          if (app.isEnabled)
                            Text(
                              'السرعة القصوى: ${app.currentLimit}',
                              style: const TextStyle(color: AppTheme.gold, fontSize: 12),
                            ),
                        ],
                      ),
                      trailing: Switch(
                        value: app.isEnabled,
                        activeColor: app.color,
                        onChanged: (bool val) {
                          if (val) {
                            _showSetupDialog(app);
                          } else {
                            _showDisableConfirmDialog(app);
                          }
                        },
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
