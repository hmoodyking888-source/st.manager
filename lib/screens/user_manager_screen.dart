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
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _sessions = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (widget.routerService == null) return;
    setState(() => _loading = true);
    try {
      final users = await widget.routerService!.getUserManagerUsers();
      final sessions = await widget.routerService!.getUserManagerSessions();
      setState(() {
        _users = users;
        _sessions = sessions;
      });
    } catch (_) {}
    setState(() => _loading = false);
  }

  void _addOrEditUser({int? index}) {
    final nameCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    final groupCtrl = TextEditingController();

    if (index != null) {
      final u = _users[index];
      nameCtrl.text = u['name']?.toString() ?? '';
      passCtrl.text = u['password']?.toString() ?? '';
      groupCtrl.text = u['group']?.toString() ?? '';
    }

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(index == null ? 'إضافة مستخدم' : 'تعديل مستخدم'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'اسم المستخدم')),
              TextField(
                  controller: passCtrl,
                  decoration: const InputDecoration(labelText: 'كلمة المرور')),
              TextField(
                  controller: groupCtrl,
                  decoration: const InputDecoration(labelText: 'المجموعة')),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              final params = {
                'name': nameCtrl.text.trim(),
                'password': passCtrl.text.trim(),
                'group': groupCtrl.text.trim(),
              };
              if (index == null) {
                await widget.routerService?.sendCommand(
                    '/tool/user-manager/user/add',
                    params: params);
              } else {
                params['numbers'] = _users[index]['.id']?.toString() ?? '';
                await widget.routerService?.sendCommand(
                    '/tool/user-manager/user/set',
                    params: params);
              }
              _loadData();
              Navigator.pop(context);
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  void _deleteUser(int index) async {
    final id = _users[index]['.id']?.toString() ?? '';
    await widget.routerService?.sendCommand('/tool/user-manager/user/remove',
        params: {'numbers': id});
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('User Manager')),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTheme.gold,
        onPressed: () => _addOrEditUser(),
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.gold))
          : Column(
              children: [
                if (_sessions.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text('الجلسات النشطة: ${_sessions.length}',
                        style: const TextStyle(color: AppTheme.gold)),
                  ),
                Expanded(
                  child: _users.isEmpty
                      ? const Center(
                          child: Text('لا يوجد مستخدمين',
                              style: TextStyle(color: Colors.white54)))
                      : ListView.builder(
                          itemCount: _users.length,
                          itemBuilder: (_, i) {
                            final u = _users[i];
                            return Card(
                              child: ListTile(
                                leading: const Icon(Icons.person,
                                    color: AppTheme.gold),
                                title: Text(u['name'] ?? '',
                                    style:
                                        const TextStyle(color: Colors.white)),
                                subtitle: Text(u['group'] ?? '',
                                    style:
                                        const TextStyle(color: Colors.white54)),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                        icon: const Icon(Icons.edit,
                                            color: Colors.white54),
                                        onPressed: () =>
                                            _addOrEditUser(index: i)),
                                    IconButton(
                                        icon: const Icon(Icons.delete,
                                            color: Colors.red),
                                        onPressed: () => _deleteUser(i)),
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
