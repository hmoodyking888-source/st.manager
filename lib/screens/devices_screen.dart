import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:st_manager/services/router_service.dart';
import 'package:st_manager/theme/app_theme.dart';

class DevicesScreen extends StatefulWidget {
  final RouterService? routerService;
  const DevicesScreen({super.key, required this.routerService});

  @override
  State<DevicesScreen> createState() => _DevicesScreenState();
}

class _DevicesScreenState extends State<DevicesScreen> {
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
    try {
      final netwatch =
          await widget.routerService!.sendCommand('tool/netwatch/print');
      setState(() {
        _devices = netwatch
            .map((e) => {
                  'id': e['.id'],
                  'name': e['comment'] ?? e['host'],
                  'ip': e['host'],
                  'status': e['status'] ?? 'unknown',
                })
            .toList();
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
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
                  decoration: const InputDecoration(labelText: 'اسم المستخدم')),
              TextField(
                  controller: passCtrl,
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
              final ip = ipCtrl.text.trim();
              final name = nameCtrl.text.trim();
              if (ip.isEmpty) return;
              if (index == null) {
                await widget.routerService
                    ?.sendCommand('tool/netwatch/add', params: {
                  'host': ip,
                  'comment': name,
                  'up-script': ':log "Device $name is up"',
                  'down-script': ':log "Device $name is down"',
                });
              } else {
                final id = _devices[index]['id'];
                await widget.routerService
                    ?.sendCommand('tool/netwatch/set', params: {
                  'numbers': id,
                  'host': ip,
                  'comment': name,
                });
              }
              _loadDevices();
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
    await widget.routerService
        ?.sendCommand('tool/netwatch/remove', params: {'numbers': id});
    _loadDevices();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الأجهزة (Netwatch)')),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTheme.gold,
        onPressed: () => _addOrEditDevice(),
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.gold))
          : _devices.isEmpty
              ? const Center(
                  child: Text('لا توجد أجهزة',
                      style: TextStyle(color: Colors.white54)))
              : ListView.builder(
                  itemCount: _devices.length,
                  itemBuilder: (_, i) {
                    final d = _devices[i];
                    final status = d['status'] ?? 'unknown';
                    return Card(
                      child: ListTile(
                        leading: Icon(
                          status == 'up' ? Icons.check_circle : Icons.error,
                          color: _statusColor(status),
                        ),
                        title: Text(d['name'] ?? '',
                            style: const TextStyle(color: Colors.white)),
                        subtitle: Text(d['ip'] ?? '',
                            style: const TextStyle(color: Colors.white54)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                                icon: const Icon(Icons.edit,
                                    color: Colors.white54),
                                onPressed: () => _addOrEditDevice(index: i)),
                            IconButton(
                                icon:
                                    const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _deleteDevice(i)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
