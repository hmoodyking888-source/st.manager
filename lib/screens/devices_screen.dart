// سأرسل الكود كاملاً في الرسالة التالية، لكن هذه هي الخلاصة
import 'package:flutter/material.dart';
import 'package:st_manager/theme/app_theme.dart';

class DevicesScreen extends StatefulWidget {
  const DevicesScreen({super.key});

  @override
  State<DevicesScreen> createState() => _DevicesScreenState();
}

class _DevicesScreenState extends State<DevicesScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _ipController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  String _deviceType = 'UBNT';
  List<Map<String, dynamic>> _devices = [];

  void _addDevice() {
    setState(() {
      _devices.add({
        'name': _nameController.text,
        'ip': _ipController.text,
        'type': _deviceType,
        'status': 'Offline',
      });
      _nameController.clear();
      _ipController.clear();
      _usernameController.clear();
      _passwordController.clear();
    });
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الأجهزة الخارجية')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddDialog(),
        backgroundColor: AppTheme.gold,
        child: const Icon(Icons.add),
      ),
      body: ListView.builder(
        itemCount: _devices.length,
        itemBuilder: (_, index) {
          final d = _devices[index];
          return ListTile(
            leading: Icon(
              d['type'] == 'UBNT' ? Icons.cell_tower : Icons.router,
              color: AppTheme.gold,
            ),
            title: Text(d['name']),
            subtitle: Text(d['ip']),
            trailing: IconButton(
              icon: const Icon(Icons.power_settings_new),
              onPressed: () {
                // فحص الحالة
              },
            ),
          );
        },
      ),
    );
  }

  void _showAddDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('إضافة جهاز'),
        content: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'الاسم'),
              ),
              TextFormField(
                controller: _ipController,
                decoration: const InputDecoration(labelText: 'IP'),
              ),
              DropdownButtonFormField(
                value: _deviceType,
                items: ['UBNT', 'MikroTik', 'Other']
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (val) => _deviceType = val.toString(),
              ),
              TextFormField(
                controller: _usernameController,
                decoration: const InputDecoration(labelText: 'اسم المستخدم'),
              ),
              TextFormField(
                controller: _passwordController,
                decoration: const InputDecoration(labelText: 'كلمة المرور'),
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(onPressed: _addDevice, child: const Text('حفظ')),
        ],
      ),
    );
  }
}
