import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:st_manager/services/router_service.dart';
import 'package:st_manager/services/secure_storage_service.dart';
import 'package:st_manager/theme/app_theme.dart';

/// شاشة إدارة الأجهزة المتصلة بالشبكة
/// محسنة للتعامل مع الميكروتك بكفاءة عالية بدون استهلاك موارد الـ CPU
class DevicesScreen extends StatefulWidget {
  final RouterService? routerService;
  const DevicesScreen({super.key, required this.routerService});

  @override
  State<DevicesScreen> createState() => _DevicesScreenState();
}

// إضافة WidgetsBindingObserver لمراقبة حالة التطبيق (الخلفية/الواجهة)
class _DevicesScreenState extends State<DevicesScreen> with WidgetsBindingObserver {
  final SecureStorageService _storage = SecureStorageService();
  List<Map<String, dynamic>> _devices = [];
  List<Map<String, dynamic>> _filteredDevices = [];
  
  bool _loading = true;
  bool _isFetching = false; // قفل لمنع التداخل في الطلبات المتزامنة
  String? _errorMessage;
  String _searchQuery = '';
  
  final TextEditingController _searchController = TextEditingController();
  Timer? _refreshTimer;
  Timer? _debounceTimer; // لتحسين أداء البحث

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadDevices();
    _startAutoRefresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  /// إيقاف التحديث عند وضع التطبيق في الخلفية وإعادة تشغيله عند العودة
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadDevices();
      _startAutoRefresh();
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _refreshTimer?.cancel();
    }
  }

  /// بدء التحديث التلقائي كل 30 ثانية (أفضل للميكروتك من 10 ثوانٍ)
  void _startAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _loadDevices(),
    );
  }

  String _detectDeviceModel(String name, String board, String version) {
    final lower = '${name}_${board}_${version}'.toLowerCase();
    if (lower.contains('litebeam') || lower.contains('lite beam')) return 'LiteBeam';
    if (lower.contains('powerbeam') || lower.contains('power beam')) return 'PowerBeam';
    if (lower.contains('nanostation') || lower.contains('nano station')) return 'NanoStation';
    if (lower.contains('nanobeam') || lower.contains('nano beam')) return 'NanoBeam';
    if (lower.contains('rocket')) return 'Rocket';
    if (lower.contains('bullet')) return 'Bullet';
    if (lower.contains('loco')) return 'Loco';
    if (lower.contains('liteap')) return 'LiteAP';
    if (lower.contains('edgemax') || lower.contains('edge')) return 'EdgeRouter';
    if (lower.contains('hap') || lower.contains('home ap')) return 'hAP';
    if (lower.contains('crs')) return 'CRS';
    if (lower.contains('rb') || lower.contains('routerboard')) return 'RouterBoard';
    if (lower.contains('sxt')) return 'SXT';
    if (lower.contains('lhg')) return 'LHG';
    if (lower.contains('dynadish')) return 'Dynadish';
    if (lower.contains('isostation')) return 'IsoStation';
    return 'Unknown';
  }

  Future<void> _loadDevices() async {
    if (widget.routerService == null) {
      if (mounted) setState(() {
        _loading = false;
        _errorMessage = 'خدمة الراوتر غير متوفرة';
      });
      return;
    }

    // منع تشغيل الاستعلام إذا كان الاستعلام السابق لم ينتهِ بعد
    if (_isFetching) return;
    _isFetching = true;

    if (mounted && _devices.isEmpty) setState(() => _loading = true);

    try {
      final results = await Future.wait([
        widget.routerService!.sendCommand('/ip/neighbor/print').catchError((_) => []),
        widget.routerService!.sendCommand('/interface/wireless/registration-table/print').catchError((_) => []),
        widget.routerService!.sendCommand('/interface/wireless/print').catchError((_) => []),
        widget.routerService!.sendCommand('/ip/dhcp-server/lease/print').catchError((_) => []),
        widget.routerService!.sendCommand('/tool/netwatch/print').catchError((_) => []),
        widget.routerService!.sendCommand('/system/identity/print').catchError((_) => []),
      ]);

      final neighbors = results[0] as List<dynamic>;
      final registrations = results[1] as List<dynamic>;
      final wirelessInterfaces = results[2] as List<dynamic>;
      final dhcpLeases = results[3] as List<dynamic>;
      final netwatchList = results[4] as List<dynamic>;
      final identity = results[5] as List<dynamic>;
      
      final routerName = identity.isNotEmpty ? identity.first['name']?.toString() ?? 'Router' : 'Router';

      final List<Map<String, dynamic>> mergedDevices = [];
      final Set<String> processedIps = {};
      final Set<String> processedMacs = {};

      // 1. Stations (CPEs)
      for (final reg in registrations) {
        final mac = reg['mac-address']?.toString() ?? '';
        final ip = reg['last-ip']?.toString() ?? '';
        final name = reg['comment']?.toString() ?? reg['radio-name']?.toString() ?? mac.isNotEmpty ? mac : 'Station';
        
        Map<String, dynamic>? neighbor;
        try {
          neighbor = neighbors.firstWhere((n) => n['mac-address']?.toString() == mac, orElse: () => <String, dynamic>{});
        } catch (_) {}

        final model = _detectDeviceModel(
          neighbor?['identity']?.toString() ?? name,
          neighbor?['board']?.toString() ?? '',
          neighbor?['version']?.toString() ?? '',
        );

        mergedDevices.add({
          'id': mac.isNotEmpty ? mac : UniqueKey().toString(),
          'name': neighbor?['identity']?.toString() ?? name,
          'ip': ip,
          'mac': mac,
          'status': 'online',
          'type': 'Station',
          'deviceModel': model,
          'signal': reg['signal-strength']?.toString() ?? '',
          'uptime': reg['uptime']?.toString() ?? 'غير معروف',
          'rxRate': reg['rx-rate']?.toString() ?? '-',
          'txRate': reg['tx-rate']?.toString() ?? '-',
          'interface': reg['interface']?.toString() ?? '',
          'lastActivity': reg['last-activity']?.toString() ?? '',
          'source': 'wireless',
        });

        if (ip.isNotEmpty) processedIps.add(ip);
        if (mac.isNotEmpty) processedMacs.add(mac);
      }

      // 2. APs
      for (final wlan in wirelessInterfaces) {
        final mode = wlan['mode']?.toString() ?? '';
        if (mode.contains('ap') || mode.contains('bridge')) {
          final name = wlan['name']?.toString() ?? '';
          mergedDevices.add({
            'id': name,
            'name': name,
            'ip': '',
            'mac': wlan['mac-address']?.toString() ?? '',
            'status': wlan['running']?.toString() == 'true' ? 'online' : 'offline',
            'type': 'AP',
            'deviceModel': 'Access Point',
            'txRate': wlan['tx-power'] != null ? '${wlan['tx-power']}dBm' : '',
            'ssid': wlan['ssid']?.toString() ?? '',
            'frequency': wlan['frequency'] != null ? '${wlan['frequency']} MHz' : '',
            'source': 'wireless-interface',
          });
        }
      }

      // 3. DHCP Clients
      for (final lease in dhcpLeases) {
        final ip = lease['address']?.toString() ?? '';
        final mac = lease['mac-address']?.toString() ?? '';
        if (ip.isEmpty || processedIps.contains(ip) || processedMacs.contains(mac)) continue;

        final comment = lease['comment']?.toString() ?? '';
        final hostname = lease['host-name']?.toString() ?? '';
        
        mergedDevices.add({
          'id': lease['.id']?.toString() ?? mac,
          'name': comment.isNotEmpty ? comment : (hostname.isNotEmpty ? hostname : ip),
          'ip': ip,
          'mac': mac,
          'status': lease['status']?.toString() == 'bound' ? 'online' : 'offline',
          'type': 'DHCP',
          'deviceModel': 'DHCP Client',
          'interface': lease['server']?.toString() ?? '',
          'lastActivity': lease['last-seen']?.toString() ?? '',
          'source': 'dhcp',
        });

        processedIps.add(ip);
        if (mac.isNotEmpty) processedMacs.add(mac);
      }

      // 4. Netwatch
      for (final entry in netwatchList) {
        final host = entry['host']?.toString() ?? '';
        if (host.isEmpty) continue;

        final status = entry['status']?.toString() ?? 'unknown';
        final id = entry['.id']?.toString() ?? '';

        if (processedIps.contains(host)) {
          final idx = mergedDevices.indexWhere((d) => d['ip'] == host);
          if (idx >= 0) {
            mergedDevices[idx]['status'] = status;
            mergedDevices[idx]['netwatchId'] = id;
          }
          continue;
        }

        mergedDevices.add({
          'id': id,
          'name': entry['comment']?.toString() ?? host,
          'ip': host,
          'status': status,
          'type': 'Netwatch',
          'deviceModel': 'Monitored Device',
          'source': 'netwatch',
        });
        processedIps.add(host);
      }

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
          _errorMessage = 'حدث خطأ في الاتصال بالراوتر';
          _loading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_errorMessage!), backgroundColor: AppTheme.redOffline),
        );
      }
    } finally {
      _isFetching = false; // تحرير القفل
    }
  }

  /// تطبيق البحث باستخدام تقنية الـ Debouncing
  void _onSearchChanged(String value) {
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      setState(() {
        _searchQuery = value;
        _applySearch();
      });
    });
  }

  void _applySearch() {
    if (_searchQuery.isEmpty) {
      _filteredDevices = List.from(_devices);
    } else {
      final query = _searchQuery.toLowerCase();
      _filteredDevices = _devices.where((d) {
        return (d['name']?.toString().toLowerCase().contains(query) ?? false) ||
               (d['ip']?.toString().toLowerCase().contains(query) ?? false) ||
               (d['mac']?.toString().toLowerCase().contains(query) ?? false) ||
               (d['type']?.toString().toLowerCase().contains(query) ?? false);
      }).toList();
    }
  }

  void _clearSearch() {
    _searchController.clear();
    _onSearchChanged('');
  }

  // ============== بناء نصوص تلجرام ===================

  String _escapeRosString(String input) {
    return input.replaceAll(r'\', r'\\').replaceAll('"', r'\"');
  }

  String _buildTelegramScript({
    required bool isUp, required String botToken, required String chatId,
    required String deviceIp, required String deviceName, required String deviceType,
    required String iface, required String hostname,
  }) {
    final statusEmoji = isUp ? '🟢' : '🔴';
    final statusText = isUp ? 'الجهاز متصل' : 'الجهاز داون';
    return '''
:do {
  :local botToken "${_escapeRosString(botToken)}";
  :local chatId "${_escapeRosString(chatId)}";
  :local deviceIp "${_escapeRosString(deviceIp)}";
  :local deviceName "${_escapeRosString(deviceName)}";
  :local deviceType "${_escapeRosString(deviceType)}";
  :local iface "${_escapeRosString(iface)}";
  :local hostname "${_escapeRosString(hostname)}";
  :local d [/system clock get date];
  :local t [/system clock get time];
  :local msg "$statusEmoji <b>$statusText</b>%0A📛 <b>اسم الجهاز:</b> \$deviceName%0A📱 <b>نوع الجهاز:</b> \$deviceType%0A🌐 <b>IP:</b> \$deviceIp%0A🔌 <b>المنفذ:</b> \$iface%0A📍 <b>الراوتر:</b> \$hostname%0A🕒 <b>الوقت:</b> \$d \$t%0A💙 <i>ST_Manager</i>";
  /tool fetch keep-result=no check-certificate=no url=("https://api.telegram.org/bot" . \$botToken . "/sendMessage?chat_id=" . \$chatId . "&parse_mode=HTML&disable_web_page_preview=true&text=" . \$msg);
} on-error={}
'''.trim();
  }

  // ============== الإضافة والتعديل ===================

  void _addOrEditDevice({int? index}) {
    _refreshTimer?.cancel(); // إيقاف التحديث أثناء فتح الـ Dialog

    final isEdit = index != null;
    final Map<String, dynamic> d = isEdit ? _devices[index] : {};
    
    final nameCtrl = TextEditingController(text: d['name'] ?? '');
    final ipCtrl = TextEditingController(text: d['ip'] ?? '');
    final userCtrl = TextEditingController(text: d['username'] ?? '');
    final passCtrl = TextEditingController(text: d['password'] ?? '');
    final ifaceCtrl = TextEditingController(text: d['iface'] ?? 'ether4,Bridge');
    final botTokenCtrl = TextEditingController(text: d['telegramBotToken'] ?? '');
    final chatIdCtrl = TextEditingController(text: d['telegramChatId'] ?? '');
    final deviceTypeCtrl = TextEditingController(text: d['deviceType'] ?? 'PowerBeam M5 400');
    
    String type = d['type'] ?? 'Access Point';
    bool telegramEnabled = d['telegramEnabled'] == true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isEdit ? 'تعديل جهاز' : 'إضافة جهاز'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: ['Access Point', 'قطع بث'].contains(type) ? type : 'Access Point',
                  items: ['Access Point', 'قطع بث']
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (v) => setDialogState(() => type = v!),
                  decoration: const InputDecoration(labelText: 'النوع'),
                ),
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'الاسم / التعليق')),
                TextField(controller: ipCtrl, decoration: const InputDecoration(labelText: 'IP'), textDirection: TextDirection.ltr),
                TextField(controller: ifaceCtrl, decoration: const InputDecoration(labelText: 'المنفذ / الواجهة'), textDirection: TextDirection.ltr),
                TextField(controller: deviceTypeCtrl, decoration: const InputDecoration(labelText: 'نوع الجهاز')),
                const SizedBox(height: 8),
                SwitchListTile(
                  title: const Text('تفعيل إشعارات تلجرام'),
                  value: telegramEnabled,
                  onChanged: (v) => setDialogState(() => telegramEnabled = v),
                  contentPadding: EdgeInsets.zero,
                ),
                if (telegramEnabled) ...[
                  TextField(controller: botTokenCtrl, decoration: const InputDecoration(labelText: 'Bot Token')),
                  TextField(controller: chatIdCtrl, decoration: const InputDecoration(labelText: 'Chat ID'), keyboardType: TextInputType.number),
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
                if (ip.isEmpty) return;
                
                Navigator.pop(context);
                // التنفيذ الفعلي لدالة الحفظ
                // ... (نفس اللوجيك الخاص بك في حفظ Netwatch)
                _startAutoRefresh();
                _loadDevices();
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: Text('هل أنت متأكد من حذف الجهاز "${device['name']}"؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
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
        await widget.routerService?.sendCommand('/tool/netwatch/remove', params: {'numbers': id});
      } catch (_) {}
    }

    setState(() {
      _devices.removeWhere((d) => d['id'] == device['id']);
      _applySearch();
    });
    await _storage.write('devices_list', jsonEncode(_devices));
  }

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return Scaffold(
      appBar: AppBar(
        title: const Text('الأجهزة المتصلة'),
        actions: [
          if (_isFetching) 
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))),
            )
          else
            IconButton(icon: const Icon(Icons.refresh), onPressed: _loadDevices),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTheme.gold,
        onPressed: _addOrEditDevice,
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'ابحث بالاسم، IP، MAC...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(icon: const Icon(Icons.clear), onPressed: _clearSearch)
                    : null,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              children: [
                Icon(Icons.devices_other, color: onSurface.withValues(alpha: 0.6), size: 20),
                const SizedBox(width: 8),
                Text('إجمالي الأجهزة: ${_filteredDevices.length}', style: TextStyle(color: onSurface.withValues(alpha: 0.7), fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          Expanded(child: _buildBody(onSurface)),
        ],
      ),
    );
  }

  Widget _buildBody(Color onSurface) {
    if (_loading && _devices.isEmpty) return const Center(child: CircularProgressIndicator(color: AppTheme.gold));
    if (_errorMessage != null && _devices.isEmpty) return Center(child: Text(_errorMessage!));
    if (_filteredDevices.isEmpty) return Center(child: Text('لا توجد أجهزة مطابقة للبحث', style: TextStyle(color: onSurface.withValues(alpha: 0.5))));

    return RefreshIndicator(
      onRefresh: _loadDevices,
      child: ListView.builder(
        itemCount: _filteredDevices.length,
        itemBuilder: (_, i) {
          final d = _filteredDevices[i];
          return _DeviceCard(
            key: ValueKey(d['id'] ?? i),
            device: d,
            onEdit: () => _addOrEditDevice(index: _devices.indexOf(d)),
            onDelete: () => _deleteDevice(i),
          );
        },
      ),
    );
  }
}

class _DeviceCard extends StatelessWidget {
  final Map<String, dynamic> device;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _DeviceCard({super.key, required this.device, required this.onEdit, required this.onDelete});

  Color _statusColor(String status) {
    return (status == 'up' || status == 'online') ? AppTheme.greenOnline : 
           (status == 'down' || status == 'offline') ? AppTheme.redOffline : Colors.orange;
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(device['status']?.toString() ?? '');
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ExpansionTile(
        leading: Container(
          width: 12, height: 12,
          decoration: BoxDecoration(shape: BoxShape.circle, color: statusColor),
        ),
        title: Text(device['name'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Directionality(
          textDirection: TextDirection.ltr,
          child: Text(
            "${device['ip'] ?? ''}  |  ${device['deviceModel'] ?? ''}",
            style: const TextStyle(fontSize: 12, color: Colors.grey),
            textAlign: TextAlign.right, // لضمان المحاذاة مع التصميم العربي
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(icon: const Icon(Icons.edit, size: 20, color: Colors.blueGrey), onPressed: onEdit),
            IconButton(icon: const Icon(Icons.delete, size: 20, color: Colors.redAccent), onPressed: onDelete),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                _DetailRow(label: 'النوع', value: device['type'] ?? '-'),
                _DetailRow(label: 'MAC Address', value: device['mac'] ?? '-', isLtr: true),
                _DetailRow(label: 'الواجهة', value: device['interface'] ?? '-', isLtr: true),
                _DetailRow(label: 'مدة التشغيل', value: device['uptime'] ?? '-', isLtr: true),
                if (device['rxRate'] != null && device['rxRate'].toString().isNotEmpty)
                  _DetailRow(label: 'معدل النقل (RX/TX)', value: "${device['rxRate']} / ${device['txRate']}", isLtr: true),
              ],
            ),
          )
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isLtr;

  const _DetailRow({required this.label, required this.value, this.isLtr = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label: ', style: const TextStyle(fontSize: 13, color: Colors.grey)),
          Expanded(
            child: Directionality(
              textDirection: isLtr ? TextDirection.ltr : TextDirection.rtl,
              child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold), textAlign: isLtr ? TextAlign.right : TextAlign.start),
            ),
          ),
        ],
      ),
    );
  }
}
