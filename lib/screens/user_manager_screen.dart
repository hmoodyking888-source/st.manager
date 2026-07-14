import 'package:flutter/material.dart';
import 'package:st_manager/services/router_service.dart';
import 'package:st_manager/theme/app_theme.dart';

class UserManagerScreen extends StatefulWidget {
  final RouterService? routerService;
  const UserManagerScreen({super.key, required this.routerService});

  @override
  State<UserManagerScreen> createState() => _UserManagerScreenState();
}

class _UserManagerScreenState extends State<UserManagerScreen> {
  // 0: المستخدمون، 1: المتصلون (Active Sessions)، 2: البروفايلات
  int _currentIndex = 0; 
  
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _sessions = []; // الجلسات النشطة
  List<Map<String, dynamic>> _profiles = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadAllData(); // جلب كل البيانات لربطها ببعضها
  }

  // دالة لجلب كافة البيانات مرة واحدة للربط بين المستخدمين والجلسات
  Future<void> _loadAllData() async {
    if (widget.routerService == null) return;
    setState(() => _loading = true);
    
    try {
      // 1. جلب المستخدمين
      final users = await widget.routerService!.getUserManagerUsers();
      // 2. جلب الجلسات النشطة
      final sessions = await widget.routerService!.getUserManagerSessions();
      // 3. جلب البروفايلات
      final profilesResp = await widget.routerService!.sendCommand('/tool/user-manager/profile/print');
      
      setState(() {
        _users = users;
        _sessions = sessions;
        if (profilesResp != null) {
          _profiles = List<Map<String, dynamic>>.from(profilesResp);
        }
      });
    } catch (_) {
      // تجاهل الأخطاء بصمت أو يمكن إضافة رسالة للمستخدم
    }
    
    setState(() => _loading = false);
  }

  // فحص هل المستخدم متصل حالياً (Active)
  bool _isUserOnline(String? username) {
    if (username == null) return false;
    // في الميكروتيك، غالباً اسم المستخدم في الجلسة يكون تحت مفتاح 'user' أو 'name'
    return _sessions.any((s) => s['user'] == username || s['name'] == username);
  }

  // ==========================================
  // 1. عمليات إضافة وتعديل المستخدمين
  // ==========================================
  void _addOrEditUser({int? index}) {
    final nameCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    final groupCtrl = TextEditingController();

    if (index != null) {
      final u = _users[index];
      nameCtrl.text = u['name']?.toString() ?? '';
      passCtrl.text = u['password']?.toString() ?? '';
      groupCtrl.text = u['group']?.toString() ?? u['profile']?.toString() ?? '';
    }

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(index == null ? 'إضافة مستخدم جديد' : 'تعديل بيانات المستخدم'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'اسم المستخدم')),
              TextField(controller: passCtrl, decoration: const InputDecoration(labelText: 'كلمة المرور')),
              TextField(controller: groupCtrl, decoration: const InputDecoration(labelText: 'البروفايل / المجموعة')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              final params = {
                'name': nameCtrl.text.trim(),
                'password': passCtrl.text.trim(),
                // الميكروتيك إصدارات مختلفة تدعم group أو profile
                'group': groupCtrl.text.trim(), 
              };
              if (index == null) {
                await widget.routerService?.sendCommand('/tool/user-manager/user/add', params: params);
              } else {
                params['numbers'] = _users[index]['.id']?.toString() ?? '';
                await widget.routerService?.sendCommand('/tool/user-manager/user/set', params: params);
              }
              Navigator.pop(context);
              _loadAllData();
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 2. عمليات إضافة وتعديل البروفايلات
  // ==========================================
  void _addOrEditProfile({int? index}) {
    final nameCtrl = TextEditingController();
    final validityCtrl = TextEditingController();
    final priceCtrl = TextEditingController();

    if (index != null) {
      final p = _profiles[index];
      nameCtrl.text = p['name']?.toString() ?? '';
      validityCtrl.text = p['validity']?.toString() ?? '';
      priceCtrl.text = p['price']?.toString() ?? '';
    }

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(index == null ? 'إضافة بروفايل جديد' : 'تعديل البروفايل'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'اسم البروفايل')),
              TextField(controller: validityCtrl, decoration: const InputDecoration(labelText: 'الصلاحية (مثال: 30d)')),
              TextField(controller: priceCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'السعر')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              final params = {
                'name': nameCtrl.text.trim(),
                'validity': validityCtrl.text.trim(),
                'price': priceCtrl.text.trim(),
              };
              if (index == null) {
                await widget.routerService?.sendCommand('/tool/user-manager/profile/add', params: params);
              } else {
                params['numbers'] = _profiles[index]['.id']?.toString() ?? '';
                await widget.routerService?.sendCommand('/tool/user-manager/profile/set', params: params);
              }
              Navigator.pop(context);
              _loadAllData();
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 3. نافذة تأكيد الحذف (للمستخدمين، البروفايلات، والجلسات)
  // ==========================================
  void _confirmDelete(int index, String type) {
    String title = '';
    String content = '';
    String command = '';
    String id = '';

    if (type == 'user') {
      title = 'حذف المستخدم';
      content = 'هل أنت متأكد من حذف هذا المستخدم؟';
      command = '/tool/user-manager/user/remove';
      id = _users[index]['.id']?.toString() ?? '';
    } else if (type == 'profile') {
      title = 'حذف البروفايل';
      content = 'هل أنت متأكد من حذف هذا البروفايل؟';
      command = '/tool/user-manager/profile/remove';
      id = _profiles[index]['.id']?.toString() ?? '';
    } else if (type == 'session') {
      title = 'فصل المتصل';
      content = 'هل تريد فصل هذا المستخدم وإنهاء جلسته الآن؟';
      command = '/tool/user-manager/session/remove';
      id = _sessions[index]['.id']?.toString() ?? '';
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              await widget.routerService?.sendCommand(command, params: {'numbers': id});
              _loadAllData();
            },
            child: const Text('تأكيد', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // بناء الواجهات (UI Builders)
  // ==========================================

  // واجهة 1: كل المستخدمين
  Widget _buildUsersView() {
    if (_users.isEmpty) {
      return const Center(child: Text('لا يوجد مستخدمين مضافين', style: TextStyle(color: Colors.white54)));
    }
    return ListView.builder(
      itemCount: _users.length,
      itemBuilder: (_, i) {
        final u = _users[i];
        final bool isOnline = _isUserOnline(u['name']); // التحقق من حالة الاتصال
        
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: ListTile(
            leading: Stack(
              children: [
                const Icon(Icons.person, color: AppTheme.gold, size: 36),
                if (isOnline)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: Colors.greenAccent,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.black, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
            title: Text(
              u['name'] ?? 'بدون اسم',
              style: TextStyle(
                color: isOnline ? Colors.greenAccent : Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: Text(
              'البروفايل: ${u['group'] ?? u['profile'] ?? 'بدون'}',
              style: const TextStyle(color: Colors.white54),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(icon: const Icon(Icons.edit, color: Colors.white54), onPressed: () => _addOrEditUser(index: i)),
                IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _confirmDelete(i, 'user')),
              ],
            ),
          ),
        );
      },
    );
  }

  // واجهة 2: المتصلون الآن (Active Sessions)
  Widget _buildActiveSessionsView() {
    if (_sessions.isEmpty) {
      return const Center(child: Text('لا يوجد مستخدمين متصلين حالياً', style: TextStyle(color: Colors.white54)));
    }
    return ListView.builder(
      itemCount: _sessions.length,
      itemBuilder: (_, i) {
        final s = _sessions[i];
        // بعض الإصدارات تستخدم 'user' وبعضها 'name'
        final username = s['user'] ?? s['name'] ?? 'مجهول'; 
        final uptime = s['uptime'] ?? '00:00:00';
        final ipAddress = s['caller-id'] ?? s['ip'] ?? 'غير معروف';

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          shape: RoundedRectangleBorder(
            side: const BorderSide(color: Colors.greenAccent, width: 0.5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: ListTile(
            leading: const Icon(Icons.wifi_tethering, color: Colors.greenAccent),
            title: Text(username, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            subtitle: Text('الوقت: $uptime | IP: $ipAddress', style: const TextStyle(color: Colors.white70)),
            trailing: IconButton(
              icon: const Icon(Icons.power_settings_new, color: Colors.redAccent),
              tooltip: 'فصل الاتصال',
              onPressed: () => _confirmDelete(i, 'session'),
            ),
          ),
        );
      },
    );
  }

  // واجهة 3: البروفايلات
  Widget _buildProfilesView() {
    if (_profiles.isEmpty) {
      return const Center(child: Text('لا توجد بروفايلات مضافة', style: TextStyle(color: Colors.white54)));
    }
    return ListView.builder(
      itemCount: _profiles.length,
      itemBuilder: (_, i) {
        final p = _profiles[i];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: ListTile(
            leading: const Icon(Icons.card_membership, color: AppTheme.gold),
            title: Text(p['name'] ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            subtitle: Text('الصلاحية: ${p['validity'] ?? 'مفتوح'} | السعر: ${p['price'] ?? '0'}', style: const TextStyle(color: Colors.white54)),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(icon: const Icon(Icons.edit, color: Colors.white54), onPressed: () => _addOrEditProfile(index: i)),
                IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _confirmDelete(i, 'profile')),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // تحديد عنوان الـ AppBar بناءً على الشاشة
    final List<String> titles = ['إدارة المستخدمين', 'المتصلون الآن (${_sessions.length})', 'إدارة البروفايلات'];

    return Scaffold(
      appBar: AppBar(
        title: Text(titles[_currentIndex]),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppTheme.gold),
            onPressed: _loadAllData,
          )
        ],
      ),
      
      // إخفاء زر الإضافة في شاشة "المتصلون" لأنك لا تستطيع إضافة متصل يدوياً
      floatingActionButton: _currentIndex == 1 
          ? null 
          : FloatingActionButton(
              backgroundColor: AppTheme.gold,
              onPressed: () {
                if (_currentIndex == 0) _addOrEditUser();
                if (_currentIndex == 2) _addOrEditProfile();
              },
              child: const Icon(Icons.add),
            ),
            
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.gold))
          : IndexedStack(
              index: _currentIndex,
              children: [
                _buildUsersView(),
                _buildActiveSessionsView(),
                _buildProfilesView(),
              ],
            ),
      
      // شريط التنقل السفلي المطور بـ 3 تبويبات
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        selectedItemColor: AppTheme.gold,
        unselectedItemColor: Colors.white54,
        onTap: (index) {
          setState(() => _currentIndex = index);
          // لا حاجة لعمل load هنا لأننا نستخدم IndexedStack الذي يحفظ حالة الواجهات، 
          // ولكن يمكن للمستخدم الضغط على زر التحديث في الأعلى لجلب أحدث البيانات.
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.people), label: 'المستخدمون'),
          BottomNavigationBarItem(icon: Icon(Icons.wifi_tethering), label: 'المتصلون'),
          BottomNavigationBarItem(icon: Icon(Icons.assignment), label: 'البروفايلات'),
        ],
      ),
    );
  }
}
