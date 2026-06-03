import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:st_manager/services/router_service.dart';
import 'package:st_manager/services/secure_storage_service.dart';
import 'package:st_manager/theme/app_theme.dart';

class DevicesScreen extends StatefulWidget {
  final RouterService? routerService;
  const DevicesScreen({super.key, required this.routerService});

  @override
  State<DevicesScreen> createState() => _DevicesScreenState();
}

class _DevicesScreenState extends State<DevicesScreen> {
  final SecureStorageService _storage = SecureStorageService();
  List<Map<String, dynamic>> _devices = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadDevices();
  }

  Future<void> _loadDevices() async {
    if (widget.routerService == null) return;
    setState(() => _loading = true);

    // تحميل البيانات المخزنة محلياً أولاً
    final localJson = await _storage.read('devices_list');
    if (localJson != null) {
      final List<dynamic> localList = jsonDecode(localJson);
      setState(() => _devices = localList.cast<Map<String, dynamic>>());
    }

    try {
      // جلب قائمة Netwatch من الراوتر
      final netwatchList =
          await widget.routerService!.sendCommand('/tool/netwatch/print');
      final List<Map<String, dynamic>> updatedDevices = [];

      for (var entry in netwatchList) {
        final host = entry['host']?.toString() ?? '';
        final comment = entry['comment']?.toString() ?? '';
        final status = entry['status']?.toString() ?? 'unknown';

        // البحث عن جهاز مطابق في القائمة المحلية
        final existingIndex =
            _devices.indexWhere((d) => d['ip'] == host || d['name'] == comment);

        Map<String, dynamic> deviceData;
        if (existingIndex >= 0) {
          // تحديث البيانات من Netwatch
          deviceData = Map<String, dynamic>.from(_devices[existingIndex]);
          deviceData['status'] = status;
          deviceData['ip'] = host;
          deviceData['name'] = comment.isNotEmpty ? comment : host;
        } else {
          // جهاز جديد من Netwatch (لم يكن مخزناً محلياً)
          deviceData = {
            'id': entry['.id']?.toString() ?? '',
            'name': comment.isNotEmpty ? comment : host,
            'ip': host,
            'status': status,
            'type': 'Access Point', // افتراضي
            'username': '',
            'password': '',
          };
        }
        updatedDevices.add(deviceData);
      }

      // دمج مع الأجهزة المحلية التي لم تظهر في Netwatch بعد
      for (var localDevice in _devices) {
        final exists = updatedDevices.any((d) => d['ip'] == localDevice['ip']);
        if (!exists) {
          updatedDevices.add(Map<String, dynamic>.from(localDevice));
        }
      }

      setState(() {
        _devices = updatedDevices;
        _loading = false;
      });

      // حفظ القائمة المحدثة محلياً
      await _storage.write('devices_list', jsonEncode(updatedDevices));
    } catch (e) {
      setState(() => _loading = false);
      // الاكتفاء بالبيانات المحلية في حالة فشل الاتصال
    }
  }

  void _addOrEditDevice({int? index}) {
    final nameCtrl = TextEditingController();
    final ipCtrl = TextEditingController();
    final userCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    String type = 'Access Point';

    if (index != null) {
      final d = _devices[index];
      nameCtrl.text = d['name'] ?? '';
      ipCtrl.text = d['ip'] ?? '';
      userCtrl.text = d['username'] ?? '';
      passCtrl.text = d['password'] ?? '';
      type = d['type'] ?? 'Access Point';
    }

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(index == null ? 'إضافة جهاز' : 'تعديل جهاز'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField(
                value: type,
                items: ['Access Point', 'قطع بث']
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (v) => type = v!,
                decoration: const InputDecoration(labelText: 'النوع'),
              ),
              TextField(
                  controller: nameCtrl,
                  decoration:
                      const InputDecoration(labelText: 'الاسم / التعليق')),
              TextField(
                  controller: ipCtrl,
                  decoration: const InputDecoration(labelText: 'IP')),
              TextField(
                  controller: userCtrl,
                  decoration: const InputDecoration(
                      labelText: 'اسم المستخدم (اختياري)')),
              TextField(
                  controller: passCtrl,
                  decoration:
                      const InputDecoration(labelText: 'كلمة المرور (اختياري)'),
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
              final ip = ipCtrl.text.trim();
              final name = nameCtrl.text.trim();
              if (ip.isEmpty) return;

              final deviceData = {
                'name': name,
                'ip': ip,
                'username': userCtrl.text.trim(),
                'password': passCtrl.text.trim(),
                'type': type,
                'status': 'unknown',
              };

              // تحديث أو إضافة في Netwatch على الراوتر
              if (index == null) {
                await widget.routerService
                    ?.sendCommand('/tool/netwatch/add', params: {
                  'host': ip,
                  'comment': name,
                  'up-script': ':log "Device $name is up"',
                  'down-script': ':log "Device $name is down"',
                });
              } else {
                final id = _devices[index]['id'];
                if (id != null && id.toString().isNotEmpty) {
                  await widget.routerService
                      ?.sendCommand('/tool/netwatch/set', params: {
                    'numbers': id,
                    'host': ip,
                    'comment': name,
                  });
                }
              }

              _loadDevices(); // إعادة تحميل القائمة من الراوتر والمحلي
              Navigator.pop(context);
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  void _deleteDevice(int index) async {
    final id = _devices[index]['id'];
    if (id != null && id.toString().isNotEmpty) {
      await widget.routerService
          ?.sendCommand('/tool/netwatch/remove', params: {'numbers': id});
    }
    _devices.removeAt(index);
    await _storage.write('devices_list', jsonEncode(_devices));
    setState(() {});
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'up':
        return AppTheme.greenOnline;
      case 'down':
        return AppTheme.redOffline;
      default:
        return Colors.orange;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'up':
        return Icons.check_circle;
      case 'down':
        return Icons.error;
      default:
        return Icons.help_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الأجهزة (Netwatch)')),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTheme.gold,
        onPressed: () => _addOrEditDevice(),
        child: const Icon(Icons.add),
      ),
      body: _loading && _devices.isEmpty
          ? const Center(child: CircularProgressIndicator(color: AppTheme.gold))
          : _devices.isEmpty
              ? const Center(
                  child: Text('لا توجد أجهزة مراقبة',
                      style: TextStyle(color: Colors.white54)))
              : RefreshIndicator(
                  onRefresh: _loadDevices,
                  child: ListView.builder(
                    itemCount: _devices.length,
                    itemBuilder: (_, i) {
                      final d = _devices[i];
                      final status = d['status'] ?? 'unknown';
                      final type = d['type'] ?? 'Access Point';
                      return Card(
                        child: ListTile(
                          leading: Icon(
                            _statusIcon(status),
                            color: _statusColor(status),
                          ),
                          title: Text(d['name'] ?? '',
                              style: const TextStyle(color: Colors.white)),
                          subtitle: Text('${d['ip']}  |  $type',
                              style: const TextStyle(color: Colors.white54)),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                  icon: const Icon(Icons.edit,
                                      color: Colors.white54),
                                  onPressed: () => _addOrEditDevice(index: i)),
                              IconButton(
                                  icon: const Icon(Icons.delete,
                                      color: Colors.red),
                                  onPressed: () => _deleteDevice(i)),
                            ],
                          ),
                          onLongPress: () => _deleteDevice(i),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
