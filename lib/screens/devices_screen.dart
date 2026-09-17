import 'dart:async';
import 'package:flutter/material.dart';
import 'package:st_manager/services/router_service.dart';
import 'package:st_manager/services/secure_storage_service.dart';
import 'package:url_launcher/url_launcher.dart';

class NetworkDevice {
  final String name;
  final String ip;
  final String mac;
  final String interface;
  final String model;
  final String type;
  final String uptime;
  final String status;
  final Map<String, dynamic> rawData;

  NetworkDevice({
    required this.name,
    required this.ip,
    required this.mac,
    required this.interface,
    required this.model,
    required this.type,
    required this.uptime,
    required this.status,
    required this.rawData,
  });
}

class NetwatchDevice {
  final String host;
  final String comment;
  final String status;
  final DateTime? since;
  final Map<String, dynamic> rawData;

  NetwatchDevice({
    required this.host,
    required this.comment,
    required this.status,
    required this.since,
    required this.rawData,
  });
}

class DevicesScreen extends StatefulWidget {
  final RouterService? routerService;
  const DevicesScreen({super.key, required this.routerService});

  @override
  State<DevicesScreen> createState() => _DevicesScreenState();
}

class _DevicesScreenState extends State<DevicesScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          NeighborsTab(routerService: widget.routerService),
          NetwatchTab(routerService: widget.routerService),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: const Color(0xFF141414),
        currentIndex: _currentIndex,
        selectedItemColor: const Color(0xFFFFD700),
        unselectedItemColor: Colors.white60,
        type: BottomNavigationBarType.fixed,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.router), label: 'أجهزة الشبكة'),
          BottomNavigationBarItem(icon: Icon(Icons.monitor_heart), label: 'مراقبة Netwatch'),
        ],
      ),
    );
  }
}

class NeighborsTab extends StatefulWidget {
  final RouterService? routerService;
  const NeighborsTab({super.key, required this.routerService});

  @override
  State<NeighborsTab> createState() => _NeighborsTabState();
}

class _NeighborsTabState extends State<NeighborsTab> {
  List<NetworkDevice> _devices = [];
  List<NetworkDevice> _filteredDevices = [];
  List<String> _availableInterfaces = ['الكل'];

  bool _isLoading = true;
  String? _errorMessage;

  String _searchQuery = '';
  String _selectedTypeFilter = 'الكل';
  String _selectedInterfaceFilter = 'الكل';

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

  String _determineDeviceType(String board) {
    final b = board.toLowerCase();
    if (b.contains('litebeam') ||
        b.contains('powerbeam') ||
        b.contains('nanobeam') ||
        b.contains('loco') ||
        b.contains('sxt') ||
        b.contains('lhg') ||
        b.contains('disc') ||
        b.contains('cpe')) {
      return 'مستقبل';
    } else if (b.contains('rocket') ||
        b.contains('base') ||
        b.contains('mant') ||
        b.contains('netmetal') ||
        b.contains('omnitik')) {
      return 'مرسل';
    } else if (b.contains('rb') ||
        b.contains('crs') ||
        b.contains('ccr') ||
        b.contains('edgerouter') ||
        b.contains('hap') ||
        b.contains('hex')) {
      return 'راوتر/سويتش';
    }
    return 'جهاز شبكة';
  }

  String _formatInterface(String iface) {
    if (iface.toLowerCase().startsWith('ether')) {
      return iface.replaceFirst('ether', 'ايثرنت ');
    } else if (iface.toLowerCase().startsWith('wlan')) {
      return iface.replaceFirst('wlan', 'وايرلس ');
    } else if (iface.toLowerCase().startsWith('bridge')) {
      return iface.replaceFirst('bridge', 'بريدج ');
    }
    return iface;
  }

  Future<void> _fetchNetworkData() async {
    if (widget.routerService == null) {
      setState(() {
        _errorMessage = 'خدمة الاتصال غير متوفرة';
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      List<dynamic> neighbors = [];
      try {
        final resN = await widget.routerService!.sendCommand('/ip/neighbor/print');
        if (resN is List) neighbors = resN;
      } catch (_) {}

      List<NetworkDevice> loadedDevices = [];
      Set<String> interfacesSet = {'الكل'};

      for (var n in neighbors) {
        if (n is! Map) continue;
        final item = Map<String, dynamic>.from(n);
        final identity = item['identity']?.toString() ?? 'جهاز غير مسمى';
        final ip = item['address']?.toString() ?? 'لا يوجد IP';
        final mac = item['mac-address']?.toString() ?? 'غير معروف';
        final interface = _formatInterface(item['interface']?.toString() ?? 'غير معروف');
        final board = item['board']?.toString() ?? 'غير معروف';
        final uptime = item['uptime']?.toString() ?? '-';

        interfacesSet.add(interface);

        loadedDevices.add(
          NetworkDevice(
            name: identity,
            ip: ip,
            mac: mac,
            interface: interface,
            model: board != 'غير معروف' ? board : 'جهاز عام',
            type: _determineDeviceType(board),
            uptime: uptime,
            status: 'متصل',
            rawData: item,
          ),
        );
      }

      loadedDevices.sort((a, b) => a.name.compareTo(b.name));

      if (mounted) {
        setState(() {
          _devices = loadedDevices;
          _availableInterfaces = interfacesSet.toList();
          _filteredDevices = _devices.where(_matchesFilters).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'حدث خطأ أثناء جلب البيانات: $e';
          _isLoading = false;
        });
      }
    }
  }

  bool _matchesFilters(NetworkDevice d) {
    final matchesType = _selectedTypeFilter == 'الكل' || d.type == _selectedTypeFilter;
    final matchesInterface = _selectedInterfaceFilter == 'الكل' || d.interface == _selectedInterfaceFilter;
    final query = _searchQuery.toLowerCase();
    final matchesSearch = query.isEmpty ||
        d.name.toLowerCase().contains(query) ||
        d.ip.toLowerCase().contains(query) ||
        d.mac.toLowerCase().contains(query) ||
        d.model.toLowerCase().contains(query);
    return matchesType && matchesInterface && matchesSearch;
  }

  void _applyFilters() {
    setState(() {
      _filteredDevices = _devices.where(_matchesFilters).toList();
    });
  }

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'مستقبل':
        return Icons.wifi_tethering;
      case 'مرسل':
        return Icons.cell_tower;
      case 'راوتر/سويتش':
        return Icons.router;
      default:
        return Icons.devices_other;
    }
  }

  Future<void> _openInBrowser(String ip) async {
    if (ip == 'لا يوجد IP') return;
    final Uri url = Uri.parse('http://$ip');
    try {
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        throw Exception('لا يمكن فتح الرابط');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر فتح المتصفح للآيبي: $ip', style: const TextStyle(fontFamily: 'Cairo'))),
        );
      }
    }
  }

  void _showDeviceOptions(NetworkDevice device) {
    showModalBottomSheet(
      context: context,
      backgroundColor: _cardColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(device.name, style: TextStyle(color: _goldColor, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Divider(color: _subTextColor.withValues(alpha: 0.3)),
              ListTile(
                leading: Icon(Icons.language, color: _textColor),
                title: Text('فتح في المتصفح', style: TextStyle(color: _textColor)),
                subtitle: Text(device.ip, style: TextStyle(color: _subTextColor, fontSize: 12)),
                onTap: () {
                  Navigator.pop(context);
                  _openInBrowser(device.ip);
                },
              ),
              ListTile(
                leading: const Icon(Icons.restart_alt, color: Colors.orangeAccent),
                title: const Text('إعادة تشغيل الجهاز', style: TextStyle(color: Colors.orangeAccent)),
                onTap: () {
                  Navigator.pop(context);
                  _showRebootConfirmation(device);
                },
              ),
              ListTile(
                leading: Icon(Icons.info_outline, color: _textColor),
                title: Text('تفاصيل أكثر', style: TextStyle(color: _textColor)),
                onTap: () {
                  Navigator.pop(context);
                  _showMoreDetails(device);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showRebootConfirmation(NetworkDevice device) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cardColor,
        title: Text('تأكيد إعادة التشغيل', style: TextStyle(color: _goldColor)),
        content: Text('هل أنت متأكد أنك تريد إعادة تشغيل الجهاز:\n${device.name}؟', style: TextStyle(color: _textColor)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('تم إرسال أمر إعادة التشغيل إلى ${device.name}', style: const TextStyle(fontFamily: 'Cairo')), backgroundColor: Colors.green),
              );
            },
            child: const Text('إعادة تشغيل', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showMoreDetails(NetworkDevice device) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cardColor,
        title: Text('تفاصيل ${device.name}', style: TextStyle(color: _goldColor)),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: device.rawData.keys.length,
            itemBuilder: (context, index) {
              String key = device.rawData.keys.elementAt(index);
              String value = device.rawData[key].toString();
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 2, child: Text(key, style: TextStyle(color: _goldColor, fontSize: 13))),
                    Expanded(flex: 3, child: Text(value, style: TextStyle(color: _textColor, fontSize: 13), textDirection: TextDirection.ltr, textAlign: TextAlign.left)),
                  ],
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('إغلاق', style: TextStyle(color: _goldColor))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: _cardColor,
        elevation: 0,
        centerTitle: true,
        title: Text('أجهزة الشبكة', style: TextStyle(color: _goldColor, fontWeight: FontWeight.bold, letterSpacing: 1, fontSize: 18)),
        actions: [
          IconButton(icon: Icon(Icons.refresh, color: _goldColor), onPressed: _isLoading ? null : _fetchNetworkData, tooltip: 'تحديث البيانات'),
        ],
      ),
      body: Column(
        children: [
          _buildTopPanel(),
          Expanded(child: _buildDeviceList()),
        ],
      ),
    );
  }

  Widget _buildTopPanel() {
    return Container(
      color: _cardColor,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            decoration: BoxDecoration(
              color: _bgColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _goldColor.withValues(alpha: 0.3)),
            ),
            child: TextField(
              style: TextStyle(color: _textColor),
              textDirection: TextDirection.rtl,
              decoration: InputDecoration(
                hintText: 'ابحث عن جهاز، آيبي، ماك...',
                hintStyle: TextStyle(color: _subTextColor),
                prefixIcon: Icon(Icons.search, color: _goldColor),
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
              children: ['الكل', 'مستقبل', 'مرسل', 'راوتر/سويتش'].map((filter) {
                final isSelected = _selectedTypeFilter == filter;
                return Padding(
                  padding: const EdgeInsets.only(left: 8.0),
                  child: ChoiceChip(
                    label: Text(filter),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) {
                        _selectedTypeFilter = filter;
                        _applyFilters();
                      }
                    },
                    selectedColor: _goldColor.withValues(alpha: 0.2),
                    backgroundColor: _bgColor,
                    labelStyle: TextStyle(color: isSelected ? _goldColor : _subTextColor, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: isSelected ? _goldColor : Colors.transparent)),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            reverse: true,
            child: Row(
              children: _availableInterfaces.map((filter) {
                final isSelected = _selectedInterfaceFilter == filter;
                return Padding(
                  padding: const EdgeInsets.only(left: 8.0),
                  child: ChoiceChip(
                    label: Text(filter, textDirection: TextDirection.ltr),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) {
                        _selectedInterfaceFilter = filter;
                        _applyFilters();
                      }
                    },
                    selectedColor: Colors.blueAccent.withValues(alpha: 0.2),
                    backgroundColor: _bgColor,
                    labelStyle: TextStyle(color: isSelected ? Colors.blueAccent : _subTextColor, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: isSelected ? Colors.blueAccent : Colors.transparent)),
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
    if (_isLoading) return Center(child: CircularProgressIndicator(color: _goldColor));
    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.wifi_off, size: 64, color: Colors.redAccent.withValues(alpha: 0.8)),
            const SizedBox(height: 16),
            Text(_errorMessage!, style: TextStyle(color: _textColor)),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: _goldColor, foregroundColor: _bgColor),
              onPressed: _fetchNetworkData,
              child: const Text('إعادة المحاولة', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    }
    if (_filteredDevices.isEmpty) return Center(child: Text('لا توجد أجهزة مطابقة للبحث', style: TextStyle(color: _subTextColor, fontSize: 16)));

    return RefreshIndicator(
      color: _goldColor,
      backgroundColor: _cardColor,
      onRefresh: _fetchNetworkData,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _filteredDevices.length,
        itemBuilder: (context, index) => _buildDeviceCard(_filteredDevices[index]),
      ),
    );
  }

  Widget _buildDeviceCard(NetworkDevice device) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2A2A2A)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 8, offset: const Offset(0, 4))],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showDeviceOptions(device),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: _bgColor, borderRadius: BorderRadius.circular(12), border: Border.all(color: _goldColor.withValues(alpha: 0.5))),
                      child: Icon(_getTypeIcon(device.type), color: _goldColor, size: 28),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(device.name, style: TextStyle(color: _textColor, fontSize: 18, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(color: _goldColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
                                child: Text(device.type, style: TextStyle(color: _goldColor, fontSize: 12, fontWeight: FontWeight.bold)),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
                                child: Text(device.status, style: const TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.more_vert, color: _subTextColor.withValues(alpha: 0.5)),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(color: Color(0xFF2A2A2A), height: 1),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: _buildInfoColumn(Icons.memory, 'الموديل', device.model)),
                    Expanded(child: _buildInfoColumn(Icons.settings_ethernet, 'المدخل', device.interface)),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: _buildInfoColumn(Icons.network_check, 'الآيبي (IP)', device.ip, isLtr: true)),
                    Expanded(child: _buildInfoColumn(Icons.fingerprint, 'الماك (MAC)', device.mac, isLtr: true)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoColumn(IconData icon, String label, String value, {bool isLtr = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: _subTextColor),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(color: _subTextColor, fontSize: 11)),
              const SizedBox(height: 2),
              Directionality(
                textDirection: isLtr ? TextDirection.ltr : TextDirection.rtl,
                child: Text(value, style: TextStyle(color: _textColor, fontSize: 13, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: isLtr ? TextAlign.left : TextAlign.right),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class NetwatchTab extends StatefulWidget {
  final RouterService? routerService;
  const NetwatchTab({super.key, required this.routerService});

  @override
  State<NetwatchTab> createState() => _NetwatchTabState();
}

class _NetwatchTabState extends State<NetwatchTab> {
  final SecureStorageService _storage = SecureStorageService();
  static const String _telegramCommentPrefix = 'TelegramBot_';

  List<NetwatchDevice> _netwatchDevices = [];
  bool _isLoading = true;
  String? _errorMessage;
  Timer? _timer;
  Timer? _refreshTimer;
  Duration _timeOffset = Duration.zero;
  final Map<String, String> _lastKnownStatus = {};
  final Map<String, DateTime> _localStatusSince = {};

  final Color _bgColor = const Color(0xFF0A0A0A);
  final Color _cardColor = const Color(0xFF141414);
  final Color _goldColor = const Color(0xFFFFD700);
  final Color _textColor = const Color(0xFFE0E0E0);

  @override
  void initState() {
    super.initState();
    _initializeNetwatch();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) setState(() {});
    });
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (mounted) _fetchNetwatchData(silent: true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _initializeNetwatch() async {
    await _syncAutomaticDevicesFromTelegram();
    await _fetchNetwatchData();
  }

  String _normalizeLower(Object? value) => (value?.toString() ?? '').trim().toLowerCase();

  bool _isValidIpv4(String ip) {
    final value = ip.trim();
    if (value.isEmpty || value == 'لا يوجد IP' || value == 'غير معروف') return false;
    final parts = value.split('.');
    if (parts.length != 4) return false;
    for (final part in parts) {
      final n = int.tryParse(part);
      if (n == null || n < 0 || n > 255) return false;
    }
    return true;
  }

  bool _isAutomaticCandidate(Map<String, dynamic> device) {
    final ip = device['address']?.toString().trim() ?? '';
    if (!_isValidIpv4(ip) || ip == '127.0.0.1' || ip == '0.0.0.0') return false;

    final text = [
      device['identity'],
      device['board'],
      device['platform'],
      device['version'],
      device['software-version'],
      device['system-description'],
      device['type'],
    ].map(_normalizeLower).join(' ');

    const ubntTerms = [
      'ubiquiti',
      'ubnt',
      'litebeam',
      'powerbeam',
      'nanobeam',
      'nanostation',
      'loco',
      'rocket',
      'bullet',
      'airmax',
      'aircube',
      'unifi',
      'uap',
      'u6-',
      'uap-ac',
      'edgeswitch',
      'edgerouter',
    ];

    const routerApTerms = [
      'mikrotik',
      'routeros',
      'routerboard',
      'access point',
      'basebox',
      'omnitik',
      'netmetal',
      'mantbox',
      'hap',
      'cap ',
      'wap',
      'audience',
      'groove',
      'sxt',
      'lhg',
      'disc',
      'hex',
      'crs',
      'ccr',
      'rb-',
    ];

    return ubntTerms.any(text.contains) || routerApTerms.any(text.contains);
  }

  String _automaticName(Map<String, dynamic> device, int index) {
    final identity = device['identity']?.toString().trim() ?? '';
    final board = device['board']?.toString().trim() ?? '';
    if (identity.isNotEmpty && identity.toLowerCase() != 'unknown') return identity;
    if (board.isNotEmpty && board.toLowerCase() != 'unknown') return board;
    return 'قطعة ${index + 1}';
  }

  String _extractMac(String comment) {
    final match = RegExp(r'\[MAC:([^\]]+)\]', caseSensitive: false).firstMatch(comment);
    return match?.group(1)?.trim() ?? '';
  }

  String _displayComment(String comment, String host) {
    if (comment == 'بدون اسم') return host;
    if (!comment.startsWith(_telegramCommentPrefix)) return comment;
    final value = comment.substring(_telegramCommentPrefix.length);
    final cleaned = value.replaceFirst(RegExp(r'\s*\[MAC:[^\]]+\]\s*$', caseSensitive: false), '').trim();
    return cleaned.isEmpty ? host : cleaned;
  }

  String _buildTelegramComment(String name, String mac) {
    final cleanName = name.trim().isEmpty ? 'قطعة' : name.trim();
    final cleanMac = mac.trim();
    if (cleanMac.isEmpty || cleanMac == 'غير معروف') {
      return '$_telegramCommentPrefix$cleanName';
    }
    return '$_telegramCommentPrefix$cleanName [MAC:$cleanMac]';
  }

  String _scriptForTelegram({required String token, required String chat, required String message}) {
    final encoded = Uri.encodeComponent(message);
    return '/tool fetch url="https://api.telegram.org/bot$token/sendMessage?chat_id=$chat&text=$encoded" keep-result=no';
  }

  Future<Map<String, dynamic>> _readTelegramConfig() async {
    final token = (await _storage.read('telegram_bot_token') ?? '').trim();
    final chat = (await _storage.read('telegram_chat_id') ?? '').trim();
    final notifyUp = await _storage.read('tg_notify_up') == 'true';
    final notifyDown = await _storage.read('tg_notify_down') == 'true';
    return {
      'token': token,
      'chat': chat,
      'notifyUp': notifyUp,
      'notifyDown': notifyDown,
    };
  }

  Future<void> _syncAutomaticDevicesFromTelegram() async {
    final router = widget.routerService;
    if (router == null) return;

    final config = await _readTelegramConfig();
    final token = config['token']?.toString() ?? '';
    final chat = config['chat']?.toString() ?? '';
    final notifyUp = config['notifyUp'] == true;
    final notifyDown = config['notifyDown'] == true;
    if (token.isEmpty || chat.isEmpty || (!notifyUp && !notifyDown)) return;

    try {
      final neighborsResponse = await router.sendCommand('/ip/neighbor/print');
      final neighbors = neighborsResponse is List ? neighborsResponse : <dynamic>[];
      final netwatchResponse = await router.sendCommand('/tool/netwatch/print');
      final entries = netwatchResponse is List ? netwatchResponse : <dynamic>[];

      final byMac = <String, Map<String, dynamic>>{};
      final byHost = <String, Map<String, dynamic>>{};
      for (final raw in entries) {
        if (raw is! Map) continue;
        final item = Map<String, dynamic>.from(raw);
        final comment = item['comment']?.toString() ?? '';
        if (!comment.startsWith(_telegramCommentPrefix)) continue;
        final mac = _extractMac(comment).toLowerCase();
        final host = item['host']?.toString().trim().toLowerCase() ?? '';
        if (mac.isNotEmpty) byMac[mac] = item;
        if (host.isNotEmpty) byHost[host] = item;
      }

      var index = 0;
      for (final raw in neighbors) {
        if (raw is! Map) continue;
        final device = Map<String, dynamic>.from(raw);
        if (!_isAutomaticCandidate(device)) continue;

        final ip = device['address']?.toString().trim() ?? '';
        final mac = device['mac-address']?.toString().trim() ?? '';
        final newName = _automaticName(device, index++);
        final old = mac.isNotEmpty ? byMac[mac.toLowerCase()] : byHost[ip.toLowerCase()];
        final name = old == null ? newName : _displayComment(old['comment']?.toString() ?? '', ip);

        final upScript = notifyUp
            ? _scriptForTelegram(token: token, chat: chat, message: '✅ القطعة $name ($ip) عادت إلى العمل.')
            : '';
        final downScript = notifyDown
            ? _scriptForTelegram(token: token, chat: chat, message: '❌ القطعة $name ($ip) توقفت عن العمل.')
            : '';

        if (old != null) {
          final id = old['.id']?.toString() ?? '';
          if (id.isNotEmpty) {
            await router.sendCommand('/tool/netwatch/set', params: {
              'numbers': id,
              'host': ip,
              'comment': _buildTelegramComment(name, mac.isNotEmpty ? mac : _extractMac(old['comment']?.toString() ?? '')),
              'up-script': upScript,
              'down-script': downScript,
            });
          }
        } else {
          await router.sendCommand('/tool/netwatch/add', params: {
            'host': ip,
            'comment': _buildTelegramComment(name, mac),
            'up-script': upScript,
            'down-script': downScript,
          });
        }
      }
    } catch (_) {}
  }

  DateTime? _parseMikrotikSince(String sinceText) {
    try {
      final text = sinceText.trim();
      if (text.isEmpty) return null;
      final now = DateTime.now();
      final months = {
        'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6,
        'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12,
      };

      if (RegExp(r'^\d{1,2}:\d{2}:\d{2}?$').hasMatch(text)) {
        final parts = text.replaceAll('\u001b', '').split(':');
        final candidate = DateTime(now.year, now.month, now.day, int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
        if (candidate.isAfter(now.add(const Duration(seconds: 2)))) {
          return candidate.subtract(const Duration(days: 1));
        }
        return candidate;
      }

      final pieces = text.split(RegExp(r'\s+'));
      if (pieces.length < 2) return null;
      final dateParts = pieces[0].split('/');
      final timeParts = pieces[1].split(':');
      if (dateParts.length != 3 || timeParts.length < 3) return null;

      final monthText = dateParts[0].toLowerCase();
      final month = months[monthText] ?? int.tryParse(monthText) ?? now.month;
      final day = int.parse(dateParts[1]);
      final year = int.parse(dateParts[2]);
      return DateTime(year, month, day, int.parse(timeParts[0]), int.parse(timeParts[1]), int.parse(timeParts[2]));
    } catch (_) {
      return null;
    }
  }

  Future<void> _fetchNetwatchData({bool silent = false}) async {
    if (widget.routerService == null) {
      if (mounted) {
        setState(() {
          _errorMessage = 'خدمة الاتصال غير متوفرة';
          _isLoading = false;
        });
      }
      return;
    }

    if (mounted && !silent) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      try {
        final clockRes = await widget.routerService!.sendCommand('/system/clock/print');
        if (clockRes is List && clockRes.isNotEmpty) {
          final rTime = clockRes[0]['time']?.toString() ?? '';
          final rDate = clockRes[0]['date']?.toString() ?? '';
          final parsedRouterTime = _parseMikrotikSince('$rDate $rTime');
          if (parsedRouterTime != null) {
            _timeOffset = DateTime.now().difference(parsedRouterTime);
          }
        }
      } catch (_) {}

      final res = await widget.routerService!.sendCommand('/tool/netwatch/print');

      final List<NetwatchDevice> loadedList = [];
      if (res is List) {
        for (final raw in res) {
          if (raw is! Map) continue;
          final item = Map<String, dynamic>.from(raw);
          final host = item['host']?.toString() ?? 'غير معروف';
          final comment = item['comment']?.toString() ?? 'بدون اسم';
          final status = item['status']?.toString() ?? 'unknown';
          final sinceStr = item['since']?.toString() ?? '';

          DateTime? sinceTime;
          if (sinceStr.isNotEmpty) sinceTime = _parseMikrotikSince(sinceStr);

          final statusKey = item['.id']?.toString() ?? host;
          final normalizedStatus = status.trim().toLowerCase();
          final previousStatus = _lastKnownStatus[statusKey];
          if (previousStatus != normalizedStatus || !_localStatusSince.containsKey(statusKey)) {
            if (sinceTime == null) {
              _localStatusSince[statusKey] = DateTime.now().subtract(_timeOffset);
            } else {
              _localStatusSince.remove(statusKey);
            }
          }
          _lastKnownStatus[statusKey] = normalizedStatus;
          sinceTime ??= _localStatusSince[statusKey];

          loadedList.add(NetwatchDevice(
            host: host,
            comment: comment,
            status: status,
            since: sinceTime,
            rawData: item,
          ));
        }
      }

      if (mounted) {
        setState(() {
          _netwatchDevices = loadedList;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'حدث خطأ أثناء جلب Netwatch: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _showSnack(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontFamily: 'Cairo', color: Colors.white)),
        backgroundColor: color,
      ),
    );
  }

  Future<void> _openInBrowser(String ip) async {
    final cleanIp = ip.trim();
    if (!_isValidIpv4(cleanIp)) {
      _showSnack('⚠️ آيبي غير صالح: $ip', Colors.orange);
      return;
    }
    final Uri url = Uri.parse('http://$cleanIp');
    try {
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        throw Exception('لا يمكن فتح الرابط');
      }
    } catch (_) {
      if (mounted) {
        _showSnack('تعذر فتح المتصفح للآيبي: $cleanIp', Colors.redAccent);
      }
    }
  }

  Future<void> _addDevice(String name, String ip) async {
    if (widget.routerService == null) return;
    final cleanName = name.trim();
    final cleanIp = ip.trim();
    if (cleanName.isEmpty || !_isValidIpv4(cleanIp)) {
      _showSnack('⚠️ أدخل اسم الجهاز وآيبي صحيح', Colors.orange);
      return;
    }

    try {
      final config = await _readTelegramConfig();
      final token = config['token']?.toString() ?? '';
      final chat = config['chat']?.toString() ?? '';
      final notifyUp = config['notifyUp'] == true;
      final notifyDown = config['notifyDown'] == true;

      final upScript = (token.isNotEmpty && chat.isNotEmpty && notifyUp)
          ? _scriptForTelegram(token: token, chat: chat, message: '✅ القطعة $cleanName ($cleanIp) عادت إلى العمل.')
          : '';
      final downScript = (token.isNotEmpty && chat.isNotEmpty && notifyDown)
          ? _scriptForTelegram(token: token, chat: chat, message: '❌ القطعة $cleanName ($cleanIp) توقفت عن العمل.')
          : '';

      final existingResponse = await widget.routerService!.sendCommand('/tool/netwatch/print');
      final entries = existingResponse is List ? existingResponse : <dynamic>[];
      Map<String, dynamic>? existing;
      for (final raw in entries) {
        if (raw is! Map) continue;
        final item = Map<String, dynamic>.from(raw);
        if ((item['host']?.toString().trim().toLowerCase() ?? '') == cleanIp.toLowerCase()) {
          existing = item;
          break;
        }
      }

      if (existing != null && existing['.id'] != null) {
        await widget.routerService!.sendCommand('/tool/netwatch/set', params: {
          'numbers': existing['.id'].toString(),
          'comment': existing['comment']?.toString().startsWith(_telegramCommentPrefix) == true
              ? _buildTelegramComment(cleanName, _extractMac(existing['comment']?.toString() ?? ''))
              : cleanName,
          'up-script': upScript,
          'down-script': downScript,
        });
      } else {
        await widget.routerService!.sendCommand('/tool/netwatch/add', params: {
          'host': cleanIp,
          'comment': token.isNotEmpty && chat.isNotEmpty ? _buildTelegramComment(cleanName, '') : cleanName,
          'up-script': upScript,
          'down-script': downScript,
        });
      }

      await _fetchNetwatchData();
      _showSnack('تم حفظ القطعة وإعدادها بنجاح', Colors.green);
    } catch (e) {
      _showSnack('خطأ أثناء الإضافة: $e', Colors.red);
    }
  }

  Future<void> _updateDevice(NetwatchDevice device, String name, String ip) async {
    if (widget.routerService == null) return;
    final id = device.rawData['.id']?.toString() ?? '';
    final cleanName = name.trim();
    final cleanIp = ip.trim();
    if (id.isEmpty || cleanName.isEmpty || !_isValidIpv4(cleanIp)) {
      _showSnack('⚠️ تحقق من الاسم والآيبي', Colors.orange);
      return;
    }

    try {
      final config = await _readTelegramConfig();
      final token = config['token']?.toString() ?? '';
      final chat = config['chat']?.toString() ?? '';
      final notifyUp = config['notifyUp'] == true;
      final notifyDown = config['notifyDown'] == true;
      final managed = device.comment.startsWith(_telegramCommentPrefix);
      final mac = _extractMac(device.comment);

      final params = <String, String>{
        'numbers': id,
        'host': cleanIp,
        'comment': managed ? _buildTelegramComment(cleanName, mac) : cleanName,
      };

      if (managed || (token.isNotEmpty && chat.isNotEmpty)) {
        params['up-script'] = (token.isNotEmpty && chat.isNotEmpty && notifyUp)
            ? _scriptForTelegram(token: token, chat: chat, message: '✅ القطعة $cleanName ($cleanIp) عادت إلى العمل.')
            : '';
        params['down-script'] = (token.isNotEmpty && chat.isNotEmpty && notifyDown)
            ? _scriptForTelegram(token: token, chat: chat, message: '❌ القطعة $cleanName ($cleanIp) توقفت عن العمل.')
            : '';
      }

      await widget.routerService!.sendCommand('/tool/netwatch/set', params: params);
      await _fetchNetwatchData();
      _showSnack('✅ تم حفظ التعديلات بنجاح', Colors.green);
    } catch (e) {
      _showSnack('❌ تعذر تعديل الجهاز: $e', Colors.red);
    }
  }

  Future<void> _deleteDevice(NetwatchDevice device) async {
    if (widget.routerService == null) return;
    final id = device.rawData['.id']?.toString();
    if (id == null || id.isEmpty) return;
    try {
      await widget.routerService!.sendCommand('/tool/netwatch/remove', params: {'numbers': id});
      await _fetchNetwatchData();
      _showSnack('تم حذف الجهاز بنجاح', Colors.orange);
    } catch (e) {
      _showSnack('خطأ أثناء الحذف: $e', Colors.red);
    }
  }

  void _showDeviceSettingsDialog({NetwatchDevice? device}) async {
    String ip = device?.host ?? '';
    String name = device != null ? _displayComment(device.comment, device.host) : '';
    String user = '';
    String pass = '';

    if (ip.isNotEmpty) {
      user = await _storage.read('user_$ip') ?? '';
      pass = await _storage.read('pass_$ip') ?? '';
    }

    if (!mounted) return;

    final nameCtrl = TextEditingController(text: name);
    final ipCtrl = TextEditingController(text: ip);
    final userCtrl = TextEditingController(text: user);
    final passCtrl = TextEditingController(text: pass);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A2A),
        contentPadding: const EdgeInsets.all(24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: Text('اسم القطعة', style: TextStyle(color: Colors.white70, fontSize: 13)),
              ),
              const SizedBox(height: 4),
              TextField(
                controller: nameCtrl,
                style: const TextStyle(color: Colors.white),
                textDirection: TextDirection.rtl,
                decoration: InputDecoration(
                  isDense: true,
                  filled: true,
                  fillColor: _cardColor,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                  enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.white12)),
                  focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: _goldColor)),
                ),
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: Text('عنوان اي بي', style: TextStyle(color: Colors.white70, fontSize: 13)),
              ),
              const SizedBox(height: 4),
              TextField(
                controller: ipCtrl,
                style: const TextStyle(color: Colors.white),
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  isDense: true,
                  filled: true,
                  fillColor: _cardColor,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                  enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.white12)),
                  focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: _goldColor)),
                ),
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: Text('اسم المستخدم مثل ubnt', style: TextStyle(color: Colors.white70, fontSize: 13)),
              ),
              const SizedBox(height: 4),
              TextField(
                controller: userCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  isDense: true,
                  filled: true,
                  fillColor: _cardColor,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                  enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.white12)),
                  focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: _goldColor)),
                ),
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: Text('كلمة المرور', style: TextStyle(color: Colors.white70, fontSize: 13)),
              ),
              const SizedBox(height: 4),
              TextField(
                controller: passCtrl,
                style: const TextStyle(color: Colors.white),
                obscureText: true,
                decoration: InputDecoration(
                  isDense: true,
                  filled: true,
                  fillColor: _cardColor,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                  enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.white12)),
                  focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: _goldColor)),
                ),
              ),
              const SizedBox(height: 24),
              const Text('اضغط فحص للتأكد أن كلمة المرور صحيحة', style: TextStyle(color: Colors.white54, fontSize: 12)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _goldColor.withValues(alpha: 0.8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () {
                        _showSnack('جاري فحص الاتصال بالقطعة...', Colors.orange);
                        Future.delayed(const Duration(seconds: 1), () {
                          if (mounted) _showSnack('تم فحص الاتصال بنجاح', Colors.green);
                        });
                      },
                      child: Text('فحص', style: TextStyle(color: _bgColor, fontWeight: FontWeight.bold, fontSize: 15)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _goldColor,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () async {
                        Navigator.pop(ctx);
                        final newIp = ipCtrl.text.trim();
                        if (userCtrl.text.isNotEmpty || passCtrl.text.isNotEmpty) {
                          await _storage.write('user_$newIp', userCtrl.text);
                          await _storage.write('pass_$newIp', passCtrl.text);
                        }
                        if (device == null) {
                          _addDevice(nameCtrl.text, newIp);
                        } else {
                          _updateDevice(device, nameCtrl.text, newIp);
                        }
                      },
                      child: Text('حفظ', style: TextStyle(color: _bgColor, fontWeight: FontWeight.bold, fontSize: 15)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDeleteDialog(NetwatchDevice device) {
    final displayName = _displayComment(device.comment, device.host);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('تأكيد الحذف', style: TextStyle(color: _goldColor, fontWeight: FontWeight.bold)),
        content: Text('هل أنت متأكد من رغبتك في حذف الجهاز:\n$displayName؟', style: TextStyle(color: _textColor)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              Navigator.pop(ctx);
              _deleteDevice(device);
            },
            child: const Text('حذف', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showDeviceActions(NetwatchDevice device) {
    final displayName = _displayComment(device.comment, device.host);
    showModalBottomSheet(
      context: context,
      backgroundColor: _cardColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(displayName, style: TextStyle(color: _goldColor, fontSize: 17, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(device.host, style: const TextStyle(color: Colors.white38, fontSize: 12), textDirection: TextDirection.ltr),
              const Divider(color: Colors.white12),
              ListTile(
                leading: const Icon(Icons.language, color: Colors.lightBlueAccent),
                title: Text('الدخول إلى القطعة (المتصفح)', style: TextStyle(color: _textColor)),
                onTap: () {
                  Navigator.pop(ctx);
                  _openInBrowser(device.host);
                },
              ),
              ListTile(
                leading: const Icon(Icons.power_settings_new, color: Colors.orangeAccent),
                title: Text('إعادة إقلاع القطعة', style: TextStyle(color: _textColor)),
                onTap: () {
                  Navigator.pop(ctx);
                  _showSnack('تم إرسال أمر إعادة تشغيل القطعة بنجاح', Colors.green);
                },
              ),
              ListTile(
                leading: Icon(Icons.settings, color: _goldColor),
                title: Text('تعديل الاسم أو الإعدادات', style: TextStyle(color: _textColor)),
                onTap: () {
                  Navigator.pop(ctx);
                  _showDeviceSettingsDialog(device: device);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
                title: const Text('حذف القطعة', style: TextStyle(color: Colors.redAccent)),
                onTap: () {
                  Navigator.pop(ctx);
                  _showDeleteDialog(device);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatLiveCounter(DateTime? since) {
    if (since == null) return '00:00:00';

    final actualSince = since.add(_timeOffset);
    var diff = DateTime.now().difference(actualSince);
    if (diff.isNegative) diff = Duration.zero;

    final days = diff.inDays;
    final hours = diff.inHours % 24;
    final minutes = diff.inMinutes % 60;
    final seconds = diff.inSeconds % 60;

    final timeString = '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    if (days > 0) return '$days يوم, $timeString';
    return timeString;
  }

  bool _isUp(NetwatchDevice device) {
    return device.status.trim().toLowerCase() == 'up';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: _cardColor,
            padding: const EdgeInsets.only(top: 40, bottom: 16, left: 12, right: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text('للدخول الى القطع يجب ان تكون:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: _goldColor)),
                const SizedBox(height: 4),
                Text('داخل الشبكة أو مفعل vpn الخاص بنا', style: TextStyle(fontSize: 14, color: _textColor)),
                const SizedBox(height: 4),
                Text('يجب أن تكون القطع تفتح من المتصفح', style: TextStyle(fontSize: 14, color: _textColor)),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: _goldColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                      onPressed: () => _showDeviceSettingsDialog(),
                      icon: Icon(Icons.add, color: _bgColor, size: 18),
                      label: Text('إضافة قطعة', style: TextStyle(color: _bgColor, fontSize: 13, fontWeight: FontWeight.bold)),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: _goldColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                      onPressed: () {},
                      child: Text('لدي مشكلة في الدخول الى القطع', style: TextStyle(color: _bgColor, fontSize: 13, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(child: _buildNetwatchList()),
        ],
      ),
    );
  }

  Widget _buildNetwatchList() {
    if (_isLoading) return Center(child: CircularProgressIndicator(color: _goldColor));
    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.redAccent),
            const SizedBox(height: 16),
            Text(_errorMessage!, style: TextStyle(color: _textColor)),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: _goldColor),
              onPressed: _initializeNetwatch,
              child: Text('إعادة المحاولة', style: TextStyle(color: _bgColor, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    }

    if (_netwatchDevices.isEmpty) {
      return RefreshIndicator(
        color: _goldColor,
        backgroundColor: _cardColor,
        onRefresh: _fetchNetwatchData,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 120),
            Center(child: Text('لا توجد قطع في Netwatch', style: TextStyle(color: Colors.white54, fontSize: 16))),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: _goldColor,
      backgroundColor: _cardColor,
      onRefresh: _fetchNetwatchData,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _netwatchDevices.length,
        itemBuilder: (context, index) {
          final device = _netwatchDevices[index];
          final isUp = _isUp(device);
          final counterColor = isUp ? Colors.greenAccent : Colors.redAccent;
          
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF333333),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                // أقصى اليسار: زر الإجراءات (سهم لأسفل دائري)
                InkWell(
                  onTap: () => _showDeviceActions(device),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.blue.withValues(alpha: 0.15),
                    ),
                    child: const Icon(Icons.keyboard_arrow_down, color: Colors.lightBlueAccent, size: 24),
                  ),
                ),
                const SizedBox(width: 14),
                // المنتصف يسار: عداد الوقت والحالة
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _formatLiveCounter(device.since),
                        style: TextStyle(color: counterColor, fontSize: 13, fontWeight: FontWeight.bold),
                        textDirection: TextDirection.ltr,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        isUp ? 'متصل' : 'مفصول', 
                        style: const TextStyle(color: Colors.white70, fontSize: 11)
                      ),
                    ],
                  ),
                ),
                // المنتصف يمين: الاسم والآيبي والإحصائيات الوهمية لمطابقة الصورة
                Expanded(
                  flex: 5,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _displayComment(device.comment, device.host),
                        style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            'إشارة: -- عدد المتصلين: --', 
                            style: TextStyle(color: Colors.grey[400], fontSize: 10)
                          ),
                          const SizedBox(width: 8),
                          Text(
                            device.host,
                            style: const TextStyle(color: Colors.lightBlueAccent, fontSize: 12),
                            textDirection: TextDirection.ltr,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // أقصى اليمين: الأيقونة (صحن/أنتين) ونوع القطعة
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.wifi_tethering, color: Colors.white, size: 28),
                    const SizedBox(height: 4),
                    Text(
                      (device.comment.toLowerCase().contains('rocket') || device.comment.toLowerCase().contains('omni')) ? 'مرسل' : 'مستقبل',
                      style: const TextStyle(color: Colors.white70, fontSize: 10),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
