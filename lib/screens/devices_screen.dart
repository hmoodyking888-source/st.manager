import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:st_manager/services/router_service.dart';
import 'package:st_manager/services/secure_storage_service.dart';
import 'package:st_manager/theme/app_theme.dart';

/// شاشة إدارة الأجهزة المتصلة بالشبكة
/// تعرض: APs، Stations (CPEs)، DHCP Clients، Netwatch Devices
/// مع تفاصيل: Uptime، Signal، RX/TX Rates، IP، MAC
/// تحديث كل 10 ثوانٍ فقط لتقليل الضغط على الميكروتك
class DevicesScreen extends StatefulWidget {
  final RouterService? routerService;
  const DevicesScreen({super.key, required this.routerService});

  @override
  State<DevicesScreen> createState() => _DevicesScreenState();
}

class _DevicesScreenState extends State<DevicesScreen> {
  final SecureStorageService _storage = SecureStorageService();
  List<Map<String, dynamic>> _devices = [];
  List<Map<String, dynamic>> _filteredDevices = [];
  bool _loading = true;
  String? _errorMessage;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  /// مؤقت التحديث الدوري (كل 10 ثوانٍ)
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadDevices();
    _startAutoRefresh();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  /// بدء التحديث التلقائي كل 10 ثوانٍ
  void _startAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _loadDevices(),
    );
  }

  /// تحديد نوع/موديل الجهاز من الاسم أو البيانات
  String _detectDeviceModel(String name, String board, String version) {
    final lower = '${name}_${board}_${version}'.toLowerCase();
    if (lower.contains('litebeam') || lower.contains('lite beam')) return 'LiteBeam';
    if (lower.contains('powerbeam') || lower.contains('power beam')) return 'PowerBeam';
    if (lower.contains('nanostation') || lower.contains('nano station')) return 'NanoStation';
    if (lower.contains('nanobeam') || lower.contains('nano beam')) return 'NanoBeam';
    if (lower.contains('rocket') || lower.contains('rocket prism')) return 'Rocket';
    if (lower.contains('bullet')) return 'Bullet';
    if (lower.contains('loco')) return 'Loco';
    if (lower.contains('iso')) return 'IsoStation';
    if (lower.contains('liteap')) return 'LiteAP';
    if (lower.contains('edgemax') || lower.contains('edge')) return 'EdgeRouter';
    if (lower.contains('hap') || lower.contains('home ap')) return 'hAP';
    if (lower.contains('crs') || lower.contains('cloud router switch')) return 'CRS';
    if (lower.contains('rb') || lower.contains('routerboard')) return 'RouterBoard';
    if (lower.contains('sxt')) return 'SXT';
    if (lower.contains('lhg')) return 'LHG';
    if (lower.contains('dynadish')) return 'Dynadish';
    if (lower.contains('isostation')) return 'IsoStation';
    return 'Unknown';
  }

  /// اختيار الأيقونة المناسبة حسب نوع الجهاز
  IconData _getDeviceIcon(String model, String deviceType) {
    if (model.contains('LiteBeam')) return Icons.wifi_tethering;
    if (model.contains('PowerBeam')) return Icons.cell_tower;
    if (model.contains('NanoStation') || model.contains('NanoBeam')) return Icons.router;
    if (model.contains('Rocket')) return Icons.rocket_launch;
    if (model.contains('Bullet')) return Icons.settings_ethernet;
    if (model.contains('Loco')) return Icons.wifi_tethering;
    if (model.contains('hAP') || model.contains('CRS') || model.contains('RouterBoard'))
      return Icons.router;
    if (model.contains('SXT') || model.contains('LHG') || model.contains('Dynadish'))
      return Icons.wifi_find;
    if (deviceType == 'AP') return Icons.wifi;
    if (deviceType == 'Station') return Icons.computer;
    if (deviceType == 'DHCP') return Icons.devices;
    return Icons.device_unknown;
  }

  /// لون الأيقونة حسب النوع
  Color _getDeviceColor(String model, String deviceType) {
    if (model.contains('LiteBeam')) return Colors.lightGreen;
    if (model.contains('PowerBeam')) return Colors.blue;
    if (model.contains('NanoStation') || model.contains('NanoBeam')) return Colors.orange;
    if (model.contains('Rocket')) return Colors.red;
    if (model.contains('Bullet')) return Colors.teal;
    if (model.contains('hAP') || model.contains('CRS')) return Colors.purple;
    if (deviceType == 'AP') return Colors.indigo;
    if (deviceType == 'Station') return Colors.cyan;
    if (deviceType == 'DHCP') return Colors.amber;
    return Colors.grey;
  }

  /// تنسيق الوقت (Uptime)
  String _formatUptime(String? uptime) {
    if (uptime == null || uptime.isEmpty) return 'غير معروف';
    return uptime;
  }

  /// تنسيق السرعة
  String _formatRate(String? rate) {
    if (rate == null || rate.isEmpty) return '-';
    return rate;
  }

  /// تحميل جميع الأجهزة من مصادر متعددة بشكل متوازي
  Future<void> _loadDevices() async {
    if (widget.routerService == null) {
      if (mounted) {
        setState(() {
          _loading = false;
          _errorMessage = 'خدمة الراوتر غير متوفرة';
        });
      }
      return;
    }

    if (mounted) setState(() => _loading = _devices.isEmpty);

    try {
      /// جلب البيانات من مصادر متعددة بالتوازي لتقليل الوقت
      final results = await Future.wait([
        widget.routerService!.sendCommand('/ip/neighbor/print'),
        widget.routerService!.sendCommand('/interface/wireless/registration-table/print'),
        widget.routerService!.sendCommand('/interface/wireless/print'),
        widget.routerService!.sendCommand('/ip/dhcp-server/lease/print'),
        widget.routerService!.sendCommand('/tool/netwatch/print'),
        widget.routerService!.sendCommand('/system/identity/print'),
      ]);

      final neighbors = results[0] as List<dynamic>;
      final registrations = results[1] as List<dynamic>;
      final wirelessInterfaces = results[2] as List<dynamic>;
      final dhcpLeases = results[3] as List<dynamic>;
      final netwatchList = results[4] as List<dynamic>;
      final identity = results[5] as List<dynamic>;
      final routerName = identity.isNotEmpty
          ? identity.first['name']?.toString() ?? 'Router'
          : 'Router';

      final List<Map<String, dynamic>> mergedDevices = [];
      final Set<String> processedIps = {};
      final Set<String> processedMacs = {};

      /// 1. معالجة الأجهزة اللاسلكية المتصلة (Stations/CPEs)
      for (final reg in registrations) {
        final mac = reg['mac-address']?.toString() ?? '';
        final ip = reg['last-ip']?.toString() ?? '';
        final name = reg['comment']?.toString() ??
            reg['radio-name']?.toString() ??
            reg['mac-address']?.toString() ??
            'Station';
        final signal = reg['signal-strength']?.toString() ?? '';
        final rxRate = reg['rx-rate']?.toString() ?? '';
        final txRate = reg['tx-rate']?.toString() ?? '';
        final uptime = reg['uptime']?.toString() ?? '';
        final interface = reg['interface']?.toString() ?? '';
        final lastActivity = reg['last-activity']?.toString() ?? '';

        /// البحث عن الجار المطابق
        Map<String, dynamic>? neighbor;
        for (final n in neighbors) {
          if (n['mac-address']?.toString() == mac) {
            neighbor = Map<String, dynamic>.from(n);
            break;
          }
        }

        final model = _detectDeviceModel(
          neighbor?['identity']?.toString() ?? name,
          neighbor?['board']?.toString() ?? '',
          neighbor?['version']?.toString() ?? '',
        );

        mergedDevices.add({
          'id': mac,
          'name': neighbor?['identity']?.toString() ?? name,
          'ip': ip,
          'mac': mac,
          'status': 'online',
          'type': 'Station',
          'deviceModel': model,
          'signal': signal,
          'uptime': _formatUptime(uptime),
          'rxRate': _formatRate(rxRate),
          'txRate': _formatRate(txRate),
          'interface': interface,
          'lastActivity': lastActivity,
          'ssid': '',
          'frequency': '',
          'routerName': routerName,
          'source': 'wireless',
        });

        if (ip.isNotEmpty) processedIps.add(ip);
        if (mac.isNotEmpty) processedMacs.add(mac);
      }

      /// 2. معالجة نقاط الوصول (APs)
      for (final wlan in wirelessInterfaces) {
        final name = wlan['name']?.toString() ?? '';
        final ssid = wlan['ssid']?.toString() ?? '';
        final frequency = wlan['frequency']?.toString() ?? '';
        final band = wlan['band']?.toString() ?? '';
        final mode = wlan['mode']?.toString() ?? '';
        final txPower = wlan['tx-power']?.toString() ?? '';
        final running = wlan['running']?.toString() == 'true';

        if (mode.contains('ap') || mode.contains('bridge')) {
          mergedDevices.add({
            'id': name,
            'name': name,
            'ip': '',
            'mac': wlan['mac-address']?.toString() ?? '',
            'status': running ? 'online' : 'offline',
            'type': 'AP',
            'deviceModel': 'Access Point',
            'signal': '',
            'uptime': '',
            'rxRate': '',
            'txRate': txPower.isNotEmpty ? '${txPower}dBm' : '',
            'interface': name,
            'lastActivity': '',
            'ssid': ssid,
            'frequency': frequency.isNotEmpty ? '$frequency MHz' : '',
            'band': band,
            'routerName': routerName,
            'source': 'wireless-interface',
          });
        }
      }

      /// 3. معالجة أجهزة DHCP
      for (final lease in dhcpLeases) {
        final ip = lease['address']?.toString() ?? '';
        final mac = lease['mac-address']?.toString() ?? '';
        final hostname = lease['host-name']?.toString() ?? '';
        final status = lease['status']?.toString() ?? '';
        final lastSeen = lease['last-seen']?.toString() ?? '';
        final comment = lease['comment']?.toString() ?? '';

        if (ip.isEmpty) continue;
        if (processedIps.contains(ip) || processedMacs.contains(mac)) continue;

        final name = comment.isNotEmpty
            ? comment
            : (hostname.isNotEmpty ? hostname : ip);

        mergedDevices.add({
          'id': lease['.id']?.toString() ?? mac,
          'name': name,
          'ip': ip,
          'mac': mac,
          'status': status == 'bound' ? 'online' : 'offline',
          'type': 'DHCP',
          'deviceModel': 'DHCP Client',
          'signal': '',
          'uptime': '',
          'rxRate': '',
          'txRate': '',
          'interface': lease['server']?.toString() ?? '',
          'lastActivity': lastSeen,
          'ssid': '',
          'frequency': '',
          'routerName': routerName,
          'source': 'dhcp',
        });

        processedIps.add(ip);
        if (mac.isNotEmpty) processedMacs.add(mac);
      }

      /// 4. معالجة Netwatch (الأجهزة المراقبة)
      for (final entry in netwatchList) {
        final host = entry['host']?.toString() ?? '';
        final comment = entry['comment']?.toString() ?? '';
        final status = entry['status']?.toString() ?? 'unknown';
        final id = entry['.id']?.toString() ?? '';

        if (host.isEmpty) continue;
        if (processedIps.contains(host)) {
          /// تحديث حالة الجهاز الموجود
          final idx = mergedDevices.indexWhere((d) => d['ip'] == host);
          if (idx >= 0) {
            mergedDevices[idx]['status'] = status;
            mergedDevices[idx]['netwatchId'] = id;
          }
          continue;
        }

        mergedDevices.add({
          'id': id,
          'name': comment.isNotEmpty ? comment : host,
          'ip': host,
          'mac': '',
          'status': status,
          'type': 'Netwatch',
          'deviceModel': 'Monitored Device',
          'signal': '',
          'uptime': '',
          'rxRate': '',
          'txRate': '',
          'interface': '',
          'lastActivity': '',
          'ssid': '',
          'frequency': '',
          'routerName': routerName,
          'source': 'netwatch',
        });

        processedIps.add(host);
      }

      /// 5. إضافة الأجهزة من Neighbor Discovery التي لم تُعالج
      for (final n in neighbors) {
        final ip = n['address']?.toString() ?? '';
        final mac = n['mac-address']?.toString() ?? '';
        if (ip.isEmpty && mac.isEmpty) continue;
        if (processedIps.contains(ip) || processedMacs.contains(mac)) continue;

        final identity = n['identity']?.toString() ?? '';
        final model = _detectDeviceModel(
          identity,
          n['board']?.toString() ?? '',
          n['version']?.toString() ?? '',
        );

        mergedDevices.add({
          'id': mac.isNotEmpty ? mac : ip,
          'name': identity.isNotEmpty ? identity : (ip.isNotEmpty ? ip : mac),
          'ip': ip,
          'mac': mac,
          'status': 'unknown',
          'type': 'Neighbor',
          'deviceModel': model,
          'signal': '',
          'uptime': n['uptime']?.toString() ?? '',
          'rxRate': '',
          'txRate': '',
          'interface': n['interface']?.toString() ?? '',
          'lastActivity': '',
          'ssid': '',
          'frequency': '',
          'routerName': routerName,
          'source': 'neighbor',
        });

        if (ip.isNotEmpty) processedIps.add(ip);
        if (mac.isNotEmpty) processedMacs.add(mac);
      }

      /// حفظ محلياً
      await _storage.write('devices_list', jsonEncode(mergedDevices));

      if (mounted) {
        setState(() {
          _devices = mergedDevices;
          _applySearch();
          _loading = false;
          _errorMessage = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'فشل تحميل الأجهزة: ${e.toString()}';
          _loading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_errorMessage!),
            backgroundColor: AppTheme.redOffline,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  /// تطبيق البحث
  void _applySearch() {
    if (_searchQuery.isEmpty) {
      _filteredDevices = List.from(_devices);
    } else {
      final query = _searchQuery.toLowerCase();
      _filteredDevices = _devices.where((d) {
        final name = d['name']?.toString().toLowerCase() ?? '';
        final ip = d['ip']?.toString().toLowerCase() ?? '';
        final mac = d['mac']?.toString().toLowerCase() ?? '';
        final model = d['deviceModel']?.toString().toLowerCase() ?? '';
        final type = d['type']?.toString().toLowerCase() ?? '';
        return name.contains(query) ||
            ip.contains(query) ||
            mac.contains(query) ||
            model.contains(query) ||
            type.contains(query);
      }).toList();
    }
  }

  void _onSearchChanged(String value) {
    setState(() {
      _searchQuery = value;
      _applySearch();
    });
  }

  void _clearSearch() {
    _searchController.clear();
    _onSearchChanged('');
  }

  /// ==================== Netwatch & Telegram ====================

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
    final identityResult = await widget.routerService
        ?.sendCommand('/system/identity/print');
    final hostname = identityResult != null && identityResult.isNotEmpty
        ? identityResult.first['name']?.toString() ?? ''
        : '';

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
        hostname: hostname,
      );
      params['down-script'] = _buildTelegramScript(
        isUp: false,
        botToken: botToken.trim(),
        chatId: chatId.trim(),
        deviceIp: ip,
        deviceName: name,
        deviceType: deviceType,
        iface: iface,
        hostname: hostname,
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

  /// ==================== UI Actions ====================

  void _addOrEditDevice({int? index}) {
    /// إيقاف التحديث التلقائي أثناء فتح الـ Dialog
    _refreshTimer?.cancel();

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
                DropdownButtonFormField<String>(
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
              onPressed: () {
                Navigator.pop(context);
                _startAutoRefresh();
              },
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

                  if (mounted) {
                    Navigator.pop(context);
                    _startAutoRefresh();
                    _loadDevices();
                  }
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

  Future<void> _deleteDevice(int index) async {
    final device = _filteredDevices[index];
    final name = device['name']?.toString() ?? 'هذا الجهاز';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: Text('هل أنت متأكد من حذف الجهاز "$name"؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final id = device['netwatchId'] ?? device['id'];
    if (id != null && id.toString().isNotEmpty) {
      try {
        await widget.routerService
            ?.sendCommand('/tool/netwatch/remove', params: {'numbers': id});
      } catch (_) {
        /// نتجاهل خطأ الحذف من الراوتر
      }
    }

    _devices.removeWhere((d) => d['id'] == device['id']);
    await _storage.write('devices_list', jsonEncode(_devices));

    if (mounted) {
      setState(() => _applySearch());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تم حذف الجهاز "$name"')),
      );
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'up':
      case 'online':
        return AppTheme.greenOnline;
      case 'down':
      case 'offline':
        return AppTheme.redOffline;
      default:
        return Colors.orange;
    }
  }

  String _statusText(String status) {
    switch (status) {
      case 'up':
      case 'online':
        return 'متصل';
      case 'down':
      case 'offline':
        return 'غير متصل';
      default:
        return 'غير معروف';
    }
  }

  /// ==================== Build ====================

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return Scaffold(
      appBar: AppBar(
        title: const Text('الأجهزة (Devices)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'تحديث الآن',
            onPressed: _loading ? null : _loadDevices,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTheme.gold,
        onPressed: () => _addOrEditDevice(),
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          /// شريط البحث
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              textDirection: TextDirection.rtl,
              decoration: InputDecoration(
                hintText: 'ابحث عن جهاز...',
                hintTextDirection: TextDirection.rtl,
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: _clearSearch,
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
            ),
          ),

          /// عداد الأجهزة
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                Icon(Icons.devices_other,
                    color: onSurface.withValues(alpha: 0.6)),
                const SizedBox(width: 8),
                Text(
                  'الأجهزة: ${_filteredDevices.length}',
                  style: TextStyle(
                    color: onSurface.withValues(alpha: 0.7),
                    fontSize: 14,
                  ),
                ),
                const Spacer(),
                if (_loading)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.gold,
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          /// المحتوى الرئيسي
          Expanded(
            child: _buildBody(onSurface),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(Color onSurface) {
    if (_loading && _devices.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.gold),
      );
    }

    if (_errorMessage != null && _devices.isEmpty) {
      return _buildErrorView(onSurface);
    }

    if (_filteredDevices.isEmpty) {
      return _buildEmptyView(onSurface);
    }

    return RefreshIndicator(
      onRefresh: _loadDevices,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _filteredDevices.length,
        itemBuilder: (_, i) {
          final d = _filteredDevices[i];
          return _DeviceCard(
            key: ValueKey(d['id']?.toString() ?? i),
            device: d,
            onSurface: onSurface,
            statusColor: _statusColor(d['status'] ?? 'unknown'),
            statusText: _statusText(d['status'] ?? 'unknown'),
            onEdit: () => _addOrEditDevice(index: _devices.indexOf(d)),
            onDelete: () => _deleteDevice(i),
          );
        },
      ),
    );
  }

  Widget _buildErrorView(Color onSurface) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline,
              size: 48,
              color: AppTheme.redOffline.withValues(alpha: 0.7)),
          const SizedBox(height: 16),
          Text(
            _errorMessage!,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: onSurface.withValues(alpha: 0.7),
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _loadDevices,
            icon: const Icon(Icons.refresh),
            label: const Text('إعادة المحاولة'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyView(Color onSurface) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.devices_other,
              size: 64, color: onSurface.withValues(alpha: 0.2)),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isEmpty
                ? 'لا توجد أجهزة متصلة'
                : 'لا توجد نتائج مطابقة',
            style: TextStyle(
              color: onSurface.withValues(alpha: 0.5),
              fontSize: 16,
            ),
          ),
          if (_searchQuery.isEmpty) ...[
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadDevices,
              icon: const Icon(Icons.refresh),
              label: const Text('إعادة المحاولة'),
            ),
          ],
        ],
      ),
    );
  }
}

/// ==================== بطاقة الجهاز ====================

class _DeviceCard extends StatelessWidget {
  final Map<String, dynamic> device;
  final Color onSurface;
  final Color statusColor;
  final String statusText;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _DeviceCard({
    super.key,
    required this.device,
    required this.onSurface,
    required this.statusColor,
    required this.statusText,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final name = device['name']?.toString() ?? '';
    final ip = device['ip']?.toString() ?? '';
    final mac = device['mac']?.toString() ?? '';
    final type = device['type']?.toString() ?? 'Unknown';
    final model = device['deviceModel']?.toString() ?? 'Unknown';
    final signal = device['signal']?.toString() ?? '';
    final uptime = device['uptime']?.toString() ?? '';
    final rxRate = device['rxRate']?.toString() ?? '';
    final txRate = device['txRate']?.toString() ?? '';
    final ssid = device['ssid']?.toString() ?? '';
    final frequency = device['frequency']?.toString() ?? '';
    final interface = device['interface']?.toString() ?? '';
    final lastActivity = device['lastActivity']?.toString() ?? '';
    final source = device['source']?.toString() ?? '';

    final iconColor = _getDeviceColor(model, type);
    final iconData = _getDeviceIcon(model, type);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      elevation: 2,
      child: ExpansionTile(
        leading: Stack(
          alignment: Alignment.bottomRight,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: iconColor.withValues(alpha: 0.3),
                  width: 1.5,
                ),
              ),
              child: Icon(iconData, color: iconColor, size: 28),
            ),
            /// مؤشر الحالة LED صغير
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: statusColor,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: statusColor.withValues(alpha: 0.5),
                    blurRadius: 4,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
          ],
        ),
        title: Text(
          name,
          style: TextStyle(
            color: onSurface,
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),
        subtitle: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                model,
                style: TextStyle(
                  color: iconColor.withValues(alpha: 0.9),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '• $statusText',
              style: TextStyle(
                color: statusColor,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (signal.isNotEmpty)
              Tooltip(
                message: 'إشارة: $signal',
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.signal_cellular_alt,
                        size: 16, color: statusColor),
                    const SizedBox(width: 2),
                    Text(
                      signal,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.white54, size: 20),
              onPressed: onEdit,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              padding: EdgeInsets.zero,
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red, size: 20),
              onPressed: onDelete,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              padding: EdgeInsets.zero,
            ),
          ],
        ),
        children: [
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _DetailRow(label: 'النوع', value: type),
                _DetailRow(label: 'الموديل', value: model),
                if (ip.isNotEmpty) _DetailRow(label: 'عنوان IP', value: ip),
                if (mac.isNotEmpty) _DetailRow(label: 'عنوان MAC', value: mac),
                if (uptime.isNotEmpty)
                  _DetailRow(label: 'مدة التشغيل', value: uptime),
                if (ssid.isNotEmpty) _DetailRow(label: 'SSID', value: ssid),
                if (frequency.isNotEmpty)
                  _DetailRow(label: 'التردد', value: frequency),
                if (interface.isNotEmpty)
                  _DetailRow(label: 'الواجهة', value: interface),
                if (rxRate.isNotEmpty)
                  _DetailRow(label: 'سرعة الاستقبال', value: rxRate),
                if (txRate.isNotEmpty)
                  _DetailRow(label: 'سرعة الإرسال', value: txRate),
                if (lastActivity.isNotEmpty)
                  _DetailRow(label: 'آخر نشاط', value: lastActivity),
                if (source.isNotEmpty)
                  _DetailRow(
                    label: 'المصدر',
                    value: _translateSource(source),
                    valueColor: Colors.blue,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getDeviceColor(String model, String type) {
    if (model.contains('LiteBeam')) return Colors.lightGreen;
    if (model.contains('PowerBeam')) return Colors.blue;
    if (model.contains('NanoStation') || model.contains('NanoBeam'))
      return Colors.orange;
    if (model.contains('Rocket')) return Colors.red;
    if (model.contains('Bullet')) return Colors.teal;
    if (model.contains('hAP') || model.contains('CRS')) return Colors.purple;
    if (type == 'AP') return Colors.indigo;
    if (type == 'Station') return Colors.cyan;
    if (type == 'DHCP') return Colors.amber;
    return Colors.grey;
  }

  IconData _getDeviceIcon(String model, String type) {
    if (model.contains('LiteBeam')) return Icons.wifi_tethering;
    if (model.contains('PowerBeam')) return Icons.cell_tower;
    if (model.contains('NanoStation') || model.contains('NanoBeam'))
      return Icons.router;
    if (model.contains('Rocket')) return Icons.rocket_launch;
    if (model.contains('Bullet')) return Icons.settings_ethernet;
    if (model.contains('hAP') || model.contains('CRS')) return Icons.router;
    if (type == 'AP') return Icons.wifi;
    if (type == 'Station') return Icons.computer;
    if (type == 'DHCP') return Icons.devices;
    return Icons.device_unknown;
  }

  String _translateSource(String source) {
    switch (source) {
      case 'wireless':
        return 'جدول التسجيل اللاسلكي';
      case 'wireless-interface':
        return 'واجهة لاسلكية';
      case 'dhcp':
        return 'خادم DHCP';
      case 'netwatch':
        return 'مراقبة Netwatch';
      case 'neighbor':
        return 'اكتشاف الجيران';
      default:
        return source;
    }
  }
}

/// ==================== مكونات مساعدة ====================

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _DetailRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              color: onSurface.withValues(alpha: 0.55),
              fontSize: 13,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: valueColor ?? onSurface.withValues(alpha: 0.9),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
