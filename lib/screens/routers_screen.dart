import 'package:flutter/material.dart';
import 'package:st_manager/services/secure_storage_service.dart';
import 'package:st_manager/services/firebase_service.dart';
import 'package:st_manager/theme/app_theme.dart';

class RoutersScreen extends StatefulWidget {
  const RoutersScreen({super.key});

  @override
  State<RoutersScreen> createState() => _RoutersScreenState();
}

class _RoutersScreenState extends State<RoutersScreen> {
  final SecureStorageService _storage = SecureStorageService();
  List<Map<String, String>> _routers = [];

  @override
  void initState() {
    super.initState();
    _loadRouters();
  }

  Future<void> _loadRouters() async {
    final routers = await _storage.getRouters();
    setState(() => _routers = routers);
  }

  void _addOrEditRouter({int? index}) async {
    final nameController = TextEditingController();
    final ipController = TextEditingController();
    final userController = TextEditingController();
    final passController = TextEditingController();

    if (index != null) {
      final r = _routers[index];
      nameController.text = r['name'] ?? '';
      ipController.text = r['ip'] ?? '';
      userController.text = r['username'] ?? '';
      passController.text = r['password'] ?? '';
    }

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(index == null ? 'إضافة راوتر' : 'تعديل راوتر'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'اسم الراوتر'),
              ),
              TextField(
                controller: ipController,
                decoration: const InputDecoration(labelText: 'IP'),
              ),
              TextField(
                controller: userController,
                decoration: const InputDecoration(labelText: 'اسم المستخدم'),
              ),
              TextField(
                controller: passController,
                decoration: const InputDecoration(labelText: 'كلمة المرور'),
                obscureText: true,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              final router = {
                'name': nameController.text.trim(),
                'ip': ipController.text.trim(),
                'username': userController.text.trim(),
                'password': passController.text.trim(),
              };
              if (index == null) {
                await _storage.addRouter(router);
              } else {
                await _storage.updateRouter(index, router);
              }

              // حفظ في Firestore أيضًا
              final phone = await _storage.getPhone();
              if (phone != null) {
                await FirebaseService.saveUserPhone(phone, router);
              }

              _loadRouters();
              Navigator.pop(context);
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  void _deleteRouter(int index) async {
    await _storage.deleteRouter(index);
    _loadRouters();
  }

  void _selectRouter(Map<String, String> router) {
    Navigator.pushNamed(context, '/dashboard', arguments: router);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('إدارة الراوترات')),
      body: _routers.isEmpty
          ? const Center(
              child: Text(
                'لا يوجد راوترات مضافة',
                style: TextStyle(color: Colors.white54),
              ),
            )
          : ListView.builder(
              itemCount: _routers.length,
              itemBuilder: (_, i) {
                final r = _routers[i];
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.router, color: AppTheme.gold),
                    title: Text(r['name'] ?? '',
                        style: const TextStyle(color: Colors.white)),
                    subtitle: Text(r['ip'] ?? '',
                        style: const TextStyle(color: Colors.white54)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.white54),
                          onPressed: () => _addOrEditRouter(index: i),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _deleteRouter(i),
                        ),
                      ],
                    ),
                    onTap: () => _selectRouter(r),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTheme.gold,
        onPressed: () => _addOrEditRouter(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
