import 'dart:async';
import 'package:flutter/material.dart';
import 'package:st_manager/services/router_service.dart';

/// نموذج البيانات الشامل والنقي لقطع الشبكة والمضيفين
class NetworkDevice {
  final String id;
  final String name;       // اسم العميل أو اسم القطعة (مثل: رعد عبدالله)
  final String ip;         // عنوان IP
  final String mac;        // عنوان MAC
  final String interface;  // المنفذ الفيزيائي (مثل: مدخل ايثرنت 3)
  final String model;      // موديل اللوحة (مثل: LiteBeam M5)
  final String type;       // الفرز التلقائي: 'مستقبل', 'مرسل', 'هوتسبوت', 'بنية تحتية'
  final String status;     // حالة المضيف داخل الهوتسبوت
  final String uptime;     // وقت الاتصال الحالي بالجلسة

  NetworkDevice({
    required this.id,
    required this.name,
    required this.ip,
    required this.mac,
    required this.interface,
    required this.model,
    required this.type,
    required this.status,
    required this.uptime,
  });
}

class DevicesScreen extends StatefulWidget {
  final RouterService? routerService;
  const DevicesScreen({super.key, required this.routerService});

  @override
  State<DevicesScreen> createState() => _DevicesScreenState();
}

class _DevicesScreenState extends State<DevicesScreen> {
  List<NetworkDevice> _devices = [];
  List<NetworkDevice> _filteredDevices = [];
  
  bool _isLoading = true;
  String? _errorMessage;
  String _searchQuery = '';
  String _selectedFilter = 'الكل'; 

  // ألوان النمط الفاخر والنقي (Black & Gold Aesthetic)
  final Color _bgColor = const Color(0xFF0A0A0A);
  final Color _cardColor = const Color(0xFF141414);
  final Color _goldColor = const Color(0xFFFFD700);
  final Color _textColor = const Color(0xFFE0E0E0);
  final Color _subTextColor = const Color(0xFF888888);

  @override
  void initState() {
    super.initState();
    _fetchNetworkData();
  }

  /// فرز ذكي لنوع القطعة بناءً على الموديل البرمجي للوحة
  String _determineDeviceType(String board) {
    final b = board.toLowerCase();
    if (b.contains('litebeam') || b.contains('powerbeam') || b.contains('nanobeam') || b.contains('loco') || b.contains('sxt') || b.contains('lhg') || b.contains('cpe')) {
      return 'مستقبل';
    } else if (b.contains('rocket') || b.contains('base') || b.contains('mant') || b.contains('netmetal') || b.contains('omnitik')) {
      return 'مرسل';
    } else if (b.contains('rb') || b.contains('crs') || b.contains('ccr') || b.contains('hap') || b.contains('hex')) {
      return 'راوتر/سويتش';
    }
    return 'هوتسبوت';
  }

  /// تنسيق المداخل والواجهات لتظهر بعبارات عربية واضحة ومباشرة
  String _formatInterface(String iface) {
    String clean = iface.toLowerCase();
    if (clean.startsWith('ether')) {
      return clean.replaceFirst('ether', 'مدخل ايثرنت ');
    } else if (clean.startsWith('wlan')) {
      return clean.replaceFirst('wlan', 'وايرلس ');
    } else if (clean.startsWith('bridge')) {
      return clean.replaceFirst('bridge', 'جسر بريدج ');
    }
    return iface;
  }

  /// حل مشكلة الانهيار الجذري عن طريق عزل الاستعلامات بالكامل داخل بلوكات Try-Catch مستقلة
  Future<void> _fetchNetworkData() async {
    if (widget.routerService == null) {
      setState(() {
        _errorMessage = 'خدمة الاتصال بالراوتر غير متوفرة';
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    List<dynamic> neighbors = [];
    List<dynamic> hotspotHosts = [];

    // جلب بيانات الجيران بأمان تام
    try {
      final res = await widget.routerService!.sendCommand('/ip/neighbor/print');
      if (res is List) neighbors = res;
    } catch (_) {
      neighbors = []; // في حال الفشل نضمن البقاء على مصفوفة فارغة دون انهيار
    }

    // جلب بيانات مضيفي الهوتسبوت بأمان تام
    try {
      final res = await widget.routerService!.sendCommand('/ip/hotspot/host/print');
      if (res is List) hotspotHosts = res;
    } catch (_) {
      hotspotHosts = [];
    }

    try {
      final Map<String, Map<String, dynamic>> mergedMap = {};

      // 1. معالجة بيانات الـ Neighbors
      for (var n in neighbors) {
        if (n is! Map) continue;
        final mac = n['mac-address']?.toString() ?? '';
        if (mac.isEmpty) continue;

        final identity = n['identity']?.toString() ?? '';
        final board = n['board']?.toString() ?? 'جهاز شبكة';
        final ip = n['address']?.toString() ?? '';
        final iface = n['interface']?.toString() ?? '';

        mergedMap[mac] = {
          'name': identity.isNotEmpty ? identity : board,
          'ip': ip,
          'mac': mac,
          'interface': _formatInterface(iface),
          'model': board,
          'type': _determineDeviceType(board),
          'status': 'online',
          'uptime': '-',
        };
      }

      // 2. دمج وحقن بيانات الـ Hotspot Host للحصول على اسم المشترك الفعلي ووقت الاتصال
      for (var h in hotspotHosts) {
        if (h is! Map) continue;
        final mac = h['mac-address']?.toString() ?? '';
        if (mac.isEmpty) continue;

        final ip = h['address']?.toString() ?? '';
        final server = h['server']?.toString() ?? 'hotspot';
        final comment = h['comment']?.toString() ?? '';
        final user = h['user']?.toString() ?? '';
        final uptime = h['uptime']?.toString() ?? 'نشط حديثاً';

        String hostName = mac;
        if (comment.isNotEmpty) {
          hostName = comment;
        } else if (user.isNotEmpty) {
          hostName = user;
        }

        if (mergedMap.containsKey(mac)) {
          if (comment.isNotEmpty || user.isNotEmpty) {
            mergedMap[mac]!['name'] = hostName;
          }
          if (mergedMap[mac]!['ip'].toString().isEmpty) {
            mergedMap[mac]!['ip'] = ip;
          }
          mergedMap[mac]!['uptime'] = uptime;
        } else {
          mergedMap[mac] = {
            'name': hostName,
            'ip': ip,
            'mac': mac,
            'interface': server,
            'model': h['bypassed']?.toString() == 'true' ? 'بث مباشر (Bypass)' : 'جهاز عميل',
            'type': 'هوتسبوت',
            'status': h['authorized']?.toString() == 'true' ? 'online' : 'pending',
            'uptime': uptime,
          };
        }
      }

      List<NetworkDevice> loadedDevices = [];
      mergedMap.forEach((mac, data) {
        loadedDevices.add(NetworkDevice(
          id: mac,
          name: data['name'],
          ip: data['ip'],
          mac: data['mac'],
          interface: data['interface'],
          model: data['model'],
          type: data['type'],
          status: data['status'],
          uptime: data['uptime'],
        ));
      });

      loadedDevices.sort((a, b) => a.type.compareTo(b.type));

      if (mounted) {
        setState(() {
          _devices = loadedDevices;
          _applyFilters();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'حدث خطأ غير متوقع أثناء الفرز: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _applyFilters() {
    setState(() {
      _filteredDevices = _devices.where((d) {
        final matchesType = _selectedFilter == 'الكل' || d.type == _selectedFilter;
        final query = _searchQuery.toLowerCase();
        final matchesSearch = d.name.toLowerCase().contains(query) || 
                              d.ip.toLowerCase().contains(query) || 
                              d.mac.toLowerCase().contains(query) || 
                              d.model.toLowerCase().contains(query);
        return matchesType && matchesSearch;
      }).toList();
    });
  }

  /// هروب النصوص البرمجية لضمان حقن السكربت داخل الميكروتك بدون مشاكل في الرموز
  String _escapeRosString(String input) {
    return input.replaceAll(r'\', r'\\').replaceAll('"', r'\"');
  }

  /// بناء سكربت تلجرام احترافي متوافق بالكامل مع ميكروتك وسيرفر Netwatch
  String _buildTelegramScript({
    required bool isUp,
    required String botToken,
    required String chatId,
    required NetworkDevice device,
    required String identity,
  }) {
    final statusEmoji = isUp ? '🟢' : '🔴';
    final statusText = isUp ? 'متصل الآن' : 'انقطع الاتصال (داون)';
    
    final safeToken = _escapeRosString(botToken);
    final safeChatId = _escapeRosString(chatId);
    final safeName = _escapeRosString(device.name);
    final safeModel = _escapeRosString(device.model);
    final safeIp = _escapeRosString(device.ip);
    final safeInterface = _escapeRosString(device.interface);
    final safeIdentity = _escapeRosString(identity);

    return '''
:do {
  :local botToken "$safeToken";
  :local chatId "$safeChatId";
  :local d [/system clock get date];
  :local t [/system clock get time];
  :local msg "$statusEmoji <b>$statusText</b>%0A👤 <b>الاسم:</b> $safeName%0A📦 <b>النوع:</b> $safeModel%0A🌐 <b>IP:</b> $safeIp%0A🔌 <b>المنفذ:</b> $safeInterface%0A📍 <b>السيرفر:</b> \$d \$t%0A⚡ <i>S-Manager Bot</i>";
  /tool fetch keep-result=no check-certificate=no url=("https://api.telegram.org/bot" . \$botToken . "/sendMessage?chat_id=" . \$chatId . "&parse_mode=HTML&text=" . \$msg);
} on-error={}
'''.trim();
  }

  /// فتح نافذة التفعيل وحقن السكربت داخل الميكروتك مباشرة
  void _openTelegramConfigDialog(NetworkDevice device) {
    if (device.ip.isEmpty || device.ip.contains('لا يوجد')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا يمكن مراقبة قطعة لا تمتلك عنوان IP صالح'), backgroundColor: Colors.redAccent),
      );
      return;
    }

    final botTokenController = TextEditingController();
    final chatIdController = TextEditingController();
    bool isSubmitting = false;

    showDialog(
      context: context,
      barrierDismissible: !isSubmitting,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: _cardColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: _goldColor.withValues(alpha: 0.3))),
          title: Text('تفعيل مراقبة وتنبيهات القطعة', style: TextStyle(color: _goldColor, fontSize: 16, fontWeight: FontWeight.bold), textAlign: TextAlign.right),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('القطعة: ${device.name}', style: TextStyle(color: _textColor, fontSize: 13)),
              const SizedBox(height: 16),
              TextField(
                controller: botTokenController,
                style: TextStyle(color: _textColor, fontSize: 13),
                decoration: InputDecoration(
                  labelText: 'توكن بوت التلجرام (Bot Token)',
                  labelStyle: TextStyle(color: _subTextColor),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: _subTextColor)),
                  focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: _goldColor)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: chatIdController,
                style: TextStyle(color: _textColor, fontSize: 13),
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'معرف الشات (Chat ID)',
                  labelStyle: TextStyle(color: _subTextColor),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: _subTextColor)),
                  focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: _goldColor)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting ? null : () => Navigator.pop(context),
              child: Text('إلغاء', style: TextStyle(color: _subTextColor)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: _goldColor, foregroundColor: _bgColor),
              onPressed: isSubmitting ? null : () async {
                final token = botTokenController.text.trim();
                final chat = chatIdController.text.trim();
                if (token.isEmpty || chat.isEmpty) return;

                setDialogState(() => isSubmitting = true);

                try {
                  // جلب اسم الهوية الحالي للميكروتك
                  final identityRes = await widget.routerService?.sendCommand('/system/identity/print');
                  String routerIdentity = 'MikroTik';
                  if (identityRes is List && identityRes.isNotEmpty) {
                    routerIdentity = identityRes.first['name']?.toString() ?? 'MikroTik';
                  }

                  // بناء السكربت للاتصال والانفصال
                  final upScript = _buildTelegramScript(isUp: true, botToken: token, chatId: chat, device: device, identity: routerIdentity);
                  final downScript = _buildTelegramScript(isUp: false, botToken: token, chatId: chat, device: device, identity: routerIdentity);

                  // التحقق أولاً إذا كانت القطعة موجودة مسبقاً في الـ Netwatch لحذفها وتحديثها
                  final existing = await widget.routerService?.sendCommand('/tool/netwatch/print', params: {'?host': device.ip});
                  if (existing is List && existing.isNotEmpty) {
                    final rosId = existing.first['.id']?.toString();
                    if (rosId != null) {
                      await widget.routerService?.sendCommand('/tool/netwatch/remove', params: {'numbers': rosId});
                    }
                  }

                  // حقن وإضافة القطعة لجدول المراقبة الذكي بمعدل فحص مستقر كل دقيقة
                  await widget.routerService?.sendCommand('/tool/netwatch/add', params: {
                    'host': device.ip,
                    'interval': '00:01:00',
                    'comment': 'S-Manager: ${device.name}',
                    'up-script': upScript,
                    'down-script': downScript,
                  });

                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('تم تفعيل وحقن سكربت التنبيهات للقطعة ${device.name} بنجاح!'), backgroundColor: Colors.green),
                    );
                  }
                } catch (err) {
                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('فشل الحقن البرمجي: $err'), backgroundColor: Colors.redAccent),
                    );
                  }
                }
              },
              child: isSubmitting 
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                : const Text('تفعيل وحقن', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'مستقبل': return Icons.wifi_tethering;
      case 'مرسل': return Icons.cell_tower;
      case 'هوتسبوت': return Icons.phone_android;
      default: return Icons.dns;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: _cardColor,
        elevation: 0,
        centerTitle: true,
        title: Text('استكشاف الأجهزة والمضيفين', style: TextStyle(color: _goldColor, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(icon: Icon(Icons.sync, color: _goldColor), onPressed: _isLoading ? null : _fetchNetworkData)
        ],
      ),
      body: Column(
        children: [
          _buildSearchAndFilterPanel(),
          Expanded(child: _buildDeviceList()),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilterPanel() {
    return Container(
      color: _cardColor,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: _bgColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _goldColor.withValues(alpha: 0.25)),
            ),
            child: TextField(
              style: TextStyle(color: _textColor),
              textDirection: TextDirection.rtl,
              decoration: InputDecoration(
                hintText: 'ابحث باسم المشترك، الموديل أو الـ IP...',
                hintStyle: TextStyle(color: _subTextColor, fontSize: 13),
                prefixIcon: Icon(Icons.search, color: _goldColor, size: 22),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
              onChanged: (value) {
                _searchQuery = value;
                _applyFilters();
              },
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            reverse: true,
            child: Row(
              children: ['الكل', 'مستقبل', 'مرسل', 'هوتسبوت', 'راوتر/سويتش'].map((filter) {
                final isSelected = _selectedFilter == filter;
                return Padding(
                  padding: const EdgeInsets.only(left: 6.0),
                  child: ChoiceChip(
                    label: Text(filter, style: const TextStyle(fontSize: 12)),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          _selectedFilter = filter;
                          _applyFilters();
                        });
                      }
                    },
                    selectedColor: _goldColor.withValues(alpha: 0.2),
                    backgroundColor: _bgColor,
                    labelStyle: TextStyle(color: isSelected ? _goldColor : _subTextColor),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(color: isSelected ? _goldColor : Colors.transparent),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceList() {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: _goldColor));
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.warning_amber_rounded, size: 48, color: _goldColor),
            const SizedBox(height: 12),
            Text(_errorMessage!, style: TextStyle(color: _textColor), textAlign: TextAlign.center),
            const SizedBox(height: 12),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: _goldColor, foregroundColor: _bgColor),
              onPressed: _fetchNetworkData,
              child: const Text('تحديث'),
            )
          ],
        ),
      );
    }

    if (_filteredDevices.isEmpty) {
      return Center(child: Text('لا توجد قطع أو مضيفين مطابقين حالياً', style: TextStyle(color: _subTextColor)));
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: _filteredDevices.length,
      itemBuilder: (context, index) {
        final device = _filteredDevices[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: _cardColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF222222)),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _bgColor,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _goldColor.withValues(alpha: 0.3)),
              ),
              child: Icon(_getTypeIcon(device.type), color: _goldColor, size: 24),
            ),
            title: Text(device.name, style: TextStyle(color: _textColor, fontWeight: FontWeight.bold, fontSize: 15)),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 6.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(device.model, style: TextStyle(color: _goldColor, fontSize: 11, fontWeight: FontWeight.w500)),
                      const SizedBox(width: 8),
                      Text('•', style: TextStyle(color: _subTextColor)),
                      const SizedBox(width: 8),
                      Icon(Icons.lan_outlined, size: 12, color: _subTextColor),
                      const SizedBox(width: 4),
                      Text(device.interface, style: TextStyle(color: _subTextColor, fontSize: 11)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.access_time_rounded, size: 12, color: _goldColor.withValues(alpha: 0.7)),
                      const SizedBox(width: 4),
                      Text('وقت الاتصال: ${device.uptime}', style: TextStyle(color: _textColor.withValues(alpha: 0.7), fontSize: 11)),
                    ],
                  ),
                ],
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(device.ip, style: TextStyle(color: _textColor, fontSize: 12, fontFamily: 'monospace', fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(device.mac, style: TextStyle(color: _subTextColor, fontSize: 9, fontFamily: 'monospace')),
                  ],
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(Icons.notifications_active_outlined, color: _goldColor, size: 20),
                  tooltip: 'تفعيل إشعارات القطعة',
                  onPressed: () => _openTelegramConfigDialog(device),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
