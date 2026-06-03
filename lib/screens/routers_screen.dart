import 'package:flutter/material.dart';
import 'package:st_manager/services/firebase_service.dart';
import 'package:st_manager/services/secure_storage_service.dart';
import 'package:st_manager/theme/app_theme.dart';

class RoutersScreen extends StatefulWidget {
  const RoutersScreen({super.key});

  @override
  State<RoutersScreen> createState() => _RoutersScreenState();
}

class _RoutersScreenState extends State<RoutersScreen> {
  final SecureStorageService _storage = SecureStorageService();
  List<Map<String, String>> _routers = [];
  int _remainingDays = 0;

  @override
  void initState() {
    super.initState();
    _loadRouters();
    _checkRemainingDays();
  }

  Future<void> _loadRouters() async {
    final routers = await _storage.getRouters();
    setState(() => _routers = routers);
  }

  Future<void> _checkRemainingDays() async {
    final phone = await _storage.getPhone();
    if (phone == null) return;
    final licensed = await FirebaseService.checkLicense(phone);
    if (licensed) {
      setState(() => _remainingDays = 30);
    } else {
      final firstLaunch = await _storage.getFirstLaunch();
      if (firstLaunch != null) {
        final trialEnd =
            DateTime.parse(firstLaunch).add(const Duration(days: 3));
        final diff = trialEnd.difference(DateTime.now()).inDays;
        setState(() => _remainingDays = diff > 0 ? diff : 0);
      }
    }
  }

  void _addOrEditRouter({int? index}) async {
    final nameController = TextEditingController();
    final ipController = TextEditingController();
    final userController = TextEditingController();
    final passController = TextEditingController();
    String connectionType = 'api'; // api or rest
    final portController = TextEditingController(text: '8728');

    if (index != null) {
      final r = _routers[index];
      nameController.text = r['name'] ?? '';
      ipController.text = r['ip'] ?? '';
      userController.text = r['username'] ?? '';
      passController.text = r['password'] ?? '';
      connectionType = r['connectionType'] ?? 'api';
      portController.text = r['port'] ?? '8728';
    }

    await showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(index == null ? 'إضافة راوتر' : 'تعديل راوتر'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                    controller: nameController,
                    decoration:
                        const InputDecoration(labelText: 'اسم الراوتر')),
                TextField(
                    controller: ipController,
                    decoration: const InputDecoration(labelText: 'IP')),
                // اختيار نوع الاتصال
                Row(
                  children: [
                    Expanded(
                      child: RadioListTile<String>(
                        title: const Text('API (8728)',
                            style: TextStyle(fontSize: 13)),
                        value: 'api',
                        groupValue: connectionType,
                        onChanged: (v) {
                          setDialogState(() {
                            connectionType = v!;
                            portController.text = '8728';
                          });
                        },
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    Expanded(
                      child: RadioListTile<String>(
                        title: const Text('REST (80/443)',
                            style: TextStyle(fontSize: 13)),
                        value: 'rest',
                        groupValue: connectionType,
                        onChanged: (v) {
                          setDialogState(() {
                            connectionType = v!;
                            portController.text = '80';
                          });
                        },
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
                // حقل المنفذ
                TextField(
                  controller: portController,
                  decoration: const InputDecoration(labelText: 'المنفذ'),
                  keyboardType: TextInputType.number,
                ),
                TextField(
                    controller: userController,
                    decoration:
                        const InputDecoration(labelText: 'اسم المستخدم')),
                TextField(
                    controller: passController,
                    decoration: const InputDecoration(labelText: 'كلمة المرور'),
                    obscureText: true),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () async {
                final router = {
                  'name': nameController.text.trim(),
                  'ip': ipController.text.trim(),
                  'username': userController.text.trim(),
                  'password': passController.text.trim(),
                  'connectionType': connectionType,
                  'port': portController.text.trim(),
                };
                if (index == null) {
                  await _storage.addRouter(router);
                } else {
                  await _storage.updateRouter(index, router);
                }
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
      appBar: AppBar(
        title: const Text('إدارة الراوترات'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(30),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'المدة المتبقية: $_remainingDays يوم',
              style: const TextStyle(color: AppTheme.gold, fontSize: 14),
            ),
          ),
        ),
      ),
      body: _routers.isEmpty
          ? const Center(
              child: Text('لا يوجد راوترات مضافة',
                  style: TextStyle(color: Colors.white54)))
          : ListView.builder(
              itemCount: _routers.length,
              itemBuilder: (_, i) {
                final r = _routers[i];
                final type = r['connectionType'] ?? 'api';
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.router, color: AppTheme.gold),
                    title: Text(r['name'] ?? '',
                        style: const TextStyle(color: Colors.white)),
                    subtitle: Text(
                      '${r['ip']} (${type == 'api' ? 'API' : 'REST'}:${r['port'] ?? (type == 'api' ? '8728' : '80')})',
                      style: const TextStyle(color: Colors.white54),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                            icon: const Icon(Icons.edit, color: Colors.white54),
                            onPressed: () => _addOrEditRouter(index: i)),
                        IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _deleteRouter(i)),
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
