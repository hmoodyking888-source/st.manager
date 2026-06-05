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

  Map<String, dynamic> _normalizeDevice(Map<String, dynamic> src) {
    return {
      'id': src['id']?.toString() ?? '',
      'name': src['name']?.toString() ?? '',
      'ip': src['ip']?.toString() ?? '',
      'status': src['status']?.toString() ?? 'unknown',
      'type': src['type']?.toString() ?? 'Access Point',
      'username': src['username']?.toString() ?? '',
      'password': src['password']?.toString() ?? '',
      'iface': src['iface']?.toString() ?? 'ether4,Bridge',
      'telegramEnabled': src['telegramEnabled'] == true ||
          src['telegramEnabled']?.toString() == 'true',
      'telegramBotToken': src['telegramBotToken']?.toString() ?? '',
      'telegramChatId': src['telegramChatId']?.toString() ?? '',
      'deviceType': src['deviceType']?.toString() ?? 'PowerBeam M5 400',
    };
  }

  Future<void> _loadDevices() async {
    if (widget.routerService == null) return;
    setState(() => _loading = true);

    final localJson = await _storage.read('devices_list');
    if (localJson != null) {
      final List<dynamic> localList = jsonDecode(localJson);
      if (mounted) {
        setState(() {
          _devices = localList
              .map((e) => _normalizeDevice(Map<String, dynamic>.from(e)))
              .toList();
        });
      }
    }

    try {
      final netwatchList =
          await widget.routerService!.sendCommand('/tool/netwatch/print');
      final List<Map<String, dynamic>> updatedDevices = [];

      for (var entry in netwatchList) {
        final host = entry['host']?.toString() ?? '';
        final comment = entry['comment']?.toString() ?? '';
        final status = entry['status']?.toString() ?? 'unknown';

        final existingIndex = _devices.indexWhere(
          (d) => d['ip'] == host || d['name'] == comment,
        );

        Map<String, dynamic> deviceData;
        if (existingIndex >= 0) {
          deviceData = Map<String, dynamic>.from(_devices[existingIndex]);
          deviceData['status'] = status;
          deviceData['ip'] = host;
          deviceData['name'] = comment.isNotEmpty ? comment : host;
          deviceData['id'] = entry['.id']?.toString() ?? deviceData['id'] ?? '';
        } else {
          deviceData = _normalizeDevice({
            'id': entry['.id']?.toString() ?? '',
            'name': comment.isNotEmpty ? comment : host,
            'ip': host,
            'status': status,
            'type': 'Access Point',
            'username': '',
            'password': '',
            'iface': 'ether4,Bridge',
            'telegramEnabled': false,
            'telegramBotToken': '',
            'telegramChatId': '',
            'deviceType': 'PowerBeam M5 400',
          });
        }
        updatedDevices.add(deviceData);
      }

      for (var localDevice in _devices) {
        final exists = updatedDevices.any((d) => d['ip'] == localDevice['ip']);
        if (!exists) {
          updatedDevices.add(Map<String, dynamic>.from(localDevice));
        }
      }

      if (mounted) {
        setState(() {
          _devices = updatedDevices;
          _loading = false;
        });
      }

      await _storage.write('devices_list', jsonEncode(updatedDevices));
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _escapeRosString(String input) {
    return input.replaceAll(r'\', r'\\').replaceAll('"', r'\"');
  }

  String _buildTelegramScript({
    required bool isUp,
    required String botToken,
    required String chatId,
    required String deviceIp,
    required String deviceName,
    required String deviceType,
    required String iface,
    required String hostname,
  }) {
    final statusEmoji = isUp ? '🟢' : '🔴';
    final statusText = isUp ? 'الجهاز متصل' : 'الجهاز داون';

    final safeToken = _escapeRosString(botToken);
    final safeChatId = _escapeRosString(chatId);
    final safeIp = _escapeRosString(deviceIp);
    final safeName = _escapeRosString(deviceName);
    final safeType = _escapeRosString(deviceType);
    final safeIface = _escapeRosString(iface);
    final safeHostname = _escapeRosString(hostname);

    return '''
:do {
  :local botToken "$safeToken";
  :local chatId "$safeChatId";
  :local deviceIp "$safeIp";
  :local deviceName "$safeName";
  :local deviceType "$safeType";
  :local iface "$safeIface";
  :local hostname "$safeHostname";
  :local d [/system clock get date];
  :local t [/system clock get time];
  :local msg "$statusEmoji <b>$statusText</b>%0A📛 <b>اسم الجهاز:</b> \$deviceName%0A📱 <b>نوع الجهاز:</b> \$deviceType%0A🌐 <b>IP:</b> \$deviceIp%0A🔌 <b>المنفذ:</b> \$iface%0A📍 <b>الراوتر:</b> \$hostname%0A🕒 <b>الوقت:</b> \$d \$t%0A💙 <i>ST_Manager</i>";
  /tool fetch keep-result=no check-certificate=no url=("https://api.telegram.org/bot" . \$botToken . "/sendMessage?chat_id=" . \$chatId . "&parse_mode=HTML&disable_web_page_preview=true&text=" . \$msg);
} on-error={}
'''
        .trim();
  }

  Future<void> _saveNetwatchDevice({
    required bool isNew,
    required Map<String, dynamic> deviceData,
    required String ip,
    required String name,
    required String iface,
    required String deviceType,
    required bool telegramEnabled,
    required String botToken,
    required String chatId,
  }) async {
    final hostname = await widget.routerService
        ?.sendCommand(
          '/system/identity/print',
        )
        .then((value) =>
            value.isNotEmpty ? value.first['name']?.toString() ?? '' : '');

    final params = <String, dynamic>{
      'host': ip,
      'comment': name,
    };

    if (telegramEnabled &&
        botToken.trim().isNotEmpty &&
        chatId.trim().isNotEmpty) {
      params['up-script'] = _buildTelegramScript(
        isUp: true,
        botToken: botToken.trim(),
        chatId: chatId.trim(),
        deviceIp: ip,
        deviceName: name,
        deviceType: deviceType,
        iface: iface,
        hostname: hostname ?? '',
      );
      params['down-script'] = _buildTelegramScript(
        isUp: false,
        botToken: botToken.trim(),
        chatId: chatId.trim(),
        deviceIp: ip,
        deviceName: name,
        deviceType: deviceType,
        iface: iface,
        hostname: hostname ?? '',
      );
    } else {
      params['up-script'] = '';
      params['down-script'] = '';
    }

    if (isNew) {
      await widget.routerService
          ?.sendCommand('/tool/netwatch/add', params: params);
    } else {
      final id = deviceData['id']?.toString() ?? '';
      if (id.isNotEmpty) {
        params['numbers'] = id;
        await widget.routerService
            ?.sendCommand('/tool/netwatch/set', params: params);
      }
    }
  }

  void _addOrEditDevice({int? index}) {
    final nameCtrl = TextEditingController();
    final ipCtrl = TextEditingController();
    final userCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    final ifaceCtrl = TextEditingController(text: 'ether4,Bridge');
    final botTokenCtrl = TextEditingController();
    final chatIdCtrl = TextEditingController();
    final deviceTypeCtrl = TextEditingController(text: 'PowerBeam M5 400');

    bool telegramEnabled = false;
    String type = 'Access Point';

    if (index != null) {
      final d = _devices[index];
      nameCtrl.text = d['name'] ?? '';
      ipCtrl.text = d['ip'] ?? '';
      userCtrl.text = d['username'] ?? '';
      passCtrl.text = d['password'] ?? '';
      ifaceCtrl.text = d['iface'] ?? 'ether4,Bridge';
      botTokenCtrl.text = d['telegramBotToken'] ?? '';
      chatIdCtrl.text = d['telegramChatId'] ?? '';
      deviceTypeCtrl.text = d['deviceType'] ?? 'PowerBeam M5 400';
      type = d['type'] ?? 'Access Point';
      telegramEnabled = d['telegramEnabled'] == true;
    }

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
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
                  onChanged: (v) => setDialogState(() => type = v!),
                  decoration: const InputDecoration(labelText: 'النوع'),
                ),
                TextField(
                  controller: nameCtrl,
                  decoration:
                      const InputDecoration(labelText: 'الاسم / التعليق'),
                ),
                TextField(
                  controller: ipCtrl,
                  decoration: const InputDecoration(labelText: 'IP'),
                ),
                TextField(
                  controller: ifaceCtrl,
                  decoration:
                      const InputDecoration(labelText: 'المنفذ / الواجهة'),
                ),
                TextField(
                  controller: deviceTypeCtrl,
                  decoration: const InputDecoration(labelText: 'نوع الجهاز'),
                ),
                TextField(
                  controller: userCtrl,
                  decoration: const InputDecoration(
                      labelText: 'اسم المستخدم (اختياري)'),
                ),
                TextField(
                  controller: passCtrl,
                  decoration:
                      const InputDecoration(labelText: 'كلمة المرور (اختياري)'),
                  obscureText: true,
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  title: const Text('تفعيل إشعارات تلجرام'),
                  value: telegramEnabled,
                  onChanged: (v) => setDialogState(() => telegramEnabled = v),
                ),
                if (telegramEnabled) ...[
                  TextField(
                    controller: botTokenCtrl,
                    decoration: const InputDecoration(labelText: 'Bot Token'),
                  ),
                  TextField(
                    controller: chatIdCtrl,
                    decoration: const InputDecoration(labelText: 'Chat ID'),
                    keyboardType: TextInputType.number,
                  ),
                ],
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
                  'iface': ifaceCtrl.text.trim(),
                  'telegramEnabled': telegramEnabled,
                  'telegramBotToken': botTokenCtrl.text.trim(),
                  'telegramChatId': chatIdCtrl.text.trim(),
                  'deviceType': deviceTypeCtrl.text.trim(),
                };

                try {
                  await _saveNetwatchDevice(
                    isNew: index == null,
                    deviceData: deviceData,
                    ip: ip,
                    name: name,
                    iface: ifaceCtrl.text.trim(),
                    deviceType: deviceTypeCtrl.text.trim(),
                    telegramEnabled: telegramEnabled,
                    botToken: botTokenCtrl.text.trim(),
                    chatId: chatIdCtrl.text.trim(),
                  );

                  if (index == null) {
                    await _storage.addRouter(deviceData
                        .map((key, value) => MapEntry(key, value.toString())));
                  } else {
                    final routers = await _storage.getRouters();
                    if (index < routers.length) {
                      routers[index] = deviceData
                          .map((key, value) => MapEntry(key, value.toString()));
                      await _storage.saveRouters(routers);
                    }
                  }

                  _loadDevices();
                  if (mounted) Navigator.pop(context);
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('فشل الحفظ: $e')),
                    );
                  }
                }
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
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
    final onSurface = Theme.of(context).colorScheme.onSurface;

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
              ? Center(
                  child: Text(
                    'لا توجد أجهزة مراقبة',
                    style: TextStyle(color: onSurface.withOpacity(0.6)),
                  ),
                )
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
                          title: Text(
                            d['name'] ?? '',
                            style: TextStyle(color: onSurface),
                          ),
                          subtitle: Text(
                            '${d['ip']}  |  $type',
                            style: TextStyle(color: onSurface.withOpacity(0.6)),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit,
                                    color: Colors.white54),
                                onPressed: () => _addOrEditDevice(index: i),
                              ),
                              IconButton(
                                icon:
                                    const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _deleteDevice(i),
                              ),
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
