import 'dart:async';
import 'package:flutter/material.dart';
import 'package:st_manager/services/router_service.dart';
import 'package:url_launcher/url_launcher.dart'; 

// ============================================================================
// نماذج البيانات (Models)
// ============================================================================

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

// ============================================================================
// الشاشة الرئيسية (DevicesScreen)
// ============================================================================

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
      backgroundColor: const Color(0xFF0A0A0A), // تم التعديل للون الأسود
      body: IndexedStack(
        index: _currentIndex,
        children: [
          NeighborsTab(routerService: widget.routerService),
          NetwatchTab(routerService: widget.routerService),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: const Color(0xFF141414), // تم التعديل للون البطاقات الداكن
        currentIndex: _currentIndex,
        selectedItemColor: const Color(0xFFFFD700), // تم التعديل للون الذهبي
        unselectedItemColor: Colors.white60,
        type: BottomNavigationBarType.fixed,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.router),
            label: 'أجهزة الشبكة',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.monitor_heart),
            label: 'مراقبة Netwatch',
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// التبويب الأول: صفحة الأجهزة (Neighbors)
// ============================================================================

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
    if (b.contains('litebeam') || b.contains('powerbeam') || b.contains('nanobeam') || b.contains('loco') || b.contains('sxt') || b.contains('lhg') || b.contains('disc') || b.contains('cpe')) {
      return 'مستقبل';
    } else if (b.contains('rocket') || b.contains('base') || b.contains('mant') || b.contains('netmetal') || b.contains('omnitik')) {
      return 'مرسل';
    } else if (b.contains('rb') || b.contains('crs') || b.contains('ccr') || b.contains('edgerouter') || b.contains('hap') || b.contains('hex')) {
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
        final identity = n['identity']?.toString() ?? 'جهاز غير مسمى';
        final ip = n['address']?.toString() ?? 'لا يوجد IP';
        final mac = n['mac-address']?.toString() ?? 'غير معروف';
        final interface = _formatInterface(n['interface']?.toString() ?? 'غير معروف');
        final board = n['board']?.toString() ?? 'غير معروف';
        final uptime = n['uptime']?.toString() ?? '-';

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
            rawData: n as Map<String, dynamic>,
          ),
        );
      }

      loadedDevices.sort((a, b) => a.name.compareTo(b.name));

      if (mounted) {
        setState(() {
          _devices = loadedDevices;
          _availableInterfaces = interfacesSet.toList();
          _applyFilters();
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

  void _applyFilters() {
    setState(() {
      _filteredDevices = _devices.where((d) {
        final matchesType = _selectedTypeFilter == 'الكل' || d.type == _selectedTypeFilter;
        final matchesInterface = _selectedInterfaceFilter == 'الكل' || d.interface == _selectedInterfaceFilter;
        final query = _searchQuery.toLowerCase();
        final matchesSearch = query.isEmpty ||
            d.name.toLowerCase().contains(query) ||
            d.ip.toLowerCase().contains(query) ||
            d.mac.toLowerCase().contains(query) ||
            d.model.toLowerCase().contains(query);

        return matchesType && matchesInterface && matchesSearch;
      }).toList();
    });
  }

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'مستقبل': return Icons.wifi_tethering;
      case 'مرسل': return Icons.cell_tower;
      case 'راوتر/سويتش': return Icons.router;
      default: return Icons.devices_other;
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
                    Expanded(
                      flex: 3,
                      child: Text(value, style: TextStyle(color: _textColor, fontSize: 13), textDirection: TextDirection.ltr, textAlign: TextAlign.left),
                    ),
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
          IconButton(icon: Icon(Icons.refresh, color: _goldColor), onPressed: _isLoading ? null : _fetchNetworkData, tooltip: 'تحديث البيانات')
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
                        setState(() {
                          _selectedTypeFilter = filter;
                          _applyFilters();
                        });
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
                        setState(() {
                          _selectedInterfaceFilter = filter;
                          _applyFilters();
                        });
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
            )
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
        itemBuilder: (context, index) {
          final device = _filteredDevices[index];
          return _buildDeviceCard(device);
        },
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

// ============================================================================
// التبويب الثاني: صفحة مراقبة الأجهزة (Netwatch) بالهوية الموحدة
// ============================================================================

class NetwatchTab extends StatefulWidget {
  final RouterService? routerService;
  const NetwatchTab({super.key, required this.routerService});

  @override
  State<NetwatchTab> createState() => _NetwatchTabState();
}

class _NetwatchTabState extends State<NetwatchTab> {
  List<NetwatchDevice> _netwatchDevices = [];
  bool _isLoading = true;
  String? _errorMessage;
  Timer? _timer;
  Duration _timeOffset = Duration.zero; 

  // توحيد الألوان بناءً على تصميم سلطان الذهبي والأسود
  final Color _bgColor = const Color(0xFF0A0A0A);
  final Color _cardColor = const Color(0xFF141414);
  final Color _goldColor = const Color(0xFFFFD700);
  final Color _textColor = const Color(0xFFE0E0E0);

  @override
  void initState() {
    super.initState();
    _fetchNetwatchData();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  DateTime? _parseMikrotikSince(String sinceText) {
    try {
      final now = DateTime.now();
      if (sinceText.length <= 8) {
        final parts = sinceText.split(':');
        return DateTime(now.year, now.month, now.day, int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
      } else {
        final parts = sinceText.split(' ');
        final dateParts = parts[0].split('/');
        final timeParts = parts[1].split(':');
        
        final months = {'jan':1, 'feb':2, 'mar':3, 'apr':4, 'may':5, 'jun':6, 'jul':7, 'aug':8, 'sep':9, 'oct':10, 'nov':11, 'dec':12};
        final month = months[dateParts[0].toLowerCase()] ?? 1;
        final day = int.parse(dateParts[1]);
        final year = int.parse(dateParts[2]);
        
        return DateTime(year, month, day, int.parse(timeParts[0]), int.parse(timeParts[1]), int.parse(timeParts[2]));
      }
    } catch (e) {
      return null;
    }
  }

  Future<void> _fetchNetwatchData() async {
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
      try {
        final clockRes = await widget.routerService!.sendCommand('/system/clock/print');
        if (clockRes is List && clockRes.isNotEmpty) {
          final rTime = clockRes[0]['time'];
          final rDate = clockRes[0]['date'];
          final parsedRouterTime = _parseMikrotikSince("$rDate $rTime");
          if (parsedRouterTime != null) {
            _timeOffset = DateTime.now().difference(parsedRouterTime);
          }
        }
      } catch (_) {}

      final res = await widget.routerService!.sendCommand('/tool/netwatch/print');
      
      List<NetwatchDevice> loadedList = [];
      if (res is List) {
        for (var item in res) {
          final host = item['host']?.toString() ?? 'غير معروف';
          final comment = item['comment']?.toString() ?? 'بدون اسم';
          final status = item['status']?.toString() ?? 'unknown';
          final sinceStr = item['since']?.toString() ?? '';
          
          DateTime? sinceTime;
          if (sinceStr.isNotEmpty) {
            sinceTime = _parseMikrotikSince(sinceStr);
          }
          
          loadedList.add(NetwatchDevice(
            host: host,
            comment: comment,
            status: status,
            since: sinceTime,
            rawData: item as Map<String, dynamic>,
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

  // دوال الإضافة والحذف
  Future<void> _addDevice(String name, String ip) async {
    if (widget.routerService == null) return;
    try {
      await widget.routerService!.sendCommand('/tool/netwatch/add host=$ip comment="$name"');
      _fetchNetwatchData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تمت إضافة الجهاز بنجاح', style: TextStyle(fontFamily: 'Cairo')), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ أثناء الإضافة: $e', style: const TextStyle(fontFamily: 'Cairo')), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _deleteDevice(NetwatchDevice device) async {
    if (widget.routerService == null) return;
    final id = device.rawData['.id'];
    if (id == null) return;
    try {
      await widget.routerService!.sendCommand('/tool/netwatch/remove numbers=$id');
      _fetchNetwatchData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حذف الجهاز بنجاح', style: TextStyle(fontFamily: 'Cairo')), backgroundColor: Colors.orange));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ أثناء الحذف: $e', style: const TextStyle(fontFamily: 'Cairo')), backgroundColor: Colors.red));
      }
    }
  }

  // النوافذ المنبثقة
  void _showAddDialog() {
    final nameCtrl = TextEditingController();
    final ipCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('إضافة قطعة جديدة', style: TextStyle(color: _goldColor, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              style: TextStyle(color: _textColor),
              textDirection: TextDirection.rtl,
              decoration: InputDecoration(labelText: 'اسم الجهاز', labelStyle: TextStyle(color: _textColor.withValues(alpha: 0.7))),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: ipCtrl,
              style: TextStyle(color: _textColor),
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: 'الآيبي (IP)', labelStyle: TextStyle(color: _textColor.withValues(alpha: 0.7))),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _goldColor),
            onPressed: () {
              Navigator.pop(ctx);
              if (nameCtrl.text.isNotEmpty && ipCtrl.text.isNotEmpty) {
                _addDevice(nameCtrl.text, ipCtrl.text);
              }
            },
            child: Text('إضافة', style: TextStyle(color: _bgColor, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(NetwatchDevice device) {
    final displayName = device.comment != 'بدون اسم' ? device.comment : device.host;
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

  // تنسيق الوقت
  String _formatLiveCounter(DateTime? since) {
    if (since == null) return "";
    
    final actualSince = since.add(_timeOffset);
    final diff = DateTime.now().difference(actualSince);
    
    if (diff.isNegative) return "00:00:00"; 
    
    final days = diff.inDays;
    final hours = diff.inHours % 24;
    final minutes = diff.inMinutes % 60;
    final seconds = diff.inSeconds % 60;
    
    String timeString = "${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}";
    if (days > 0) {
      return "$days يوم, $timeString";
    }
    return timeString;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      body: Column(
        children: [
          // الهيدر العلوي المحدث
          Container(
            width: double.infinity,
            color: _cardColor, // تم تغييره للون البطاقات الداكن ليتماشى مع الهوية
            padding: const EdgeInsets.only(top: 40, bottom: 16, left: 12, right: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text("للدخول الى القطع يجب ان تكون:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: _goldColor)),
                const SizedBox(height: 4),
                Text("داخل الشبكة أو مفعل vpn الخاص بنا", style: TextStyle(fontSize: 14, color: _textColor)),
                const SizedBox(height: 4),
                Text("يجب أن تكون القطع تفتح من المتصفح", style: TextStyle(fontSize: 14, color: _textColor)),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _goldColor, // أزرار ذهبية
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: _showAddDialog,
                      child: Text("إضافة قطعة", style: TextStyle(color: _bgColor, fontSize: 13, fontWeight: FontWeight.bold)),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _goldColor, // أزرار ذهبية
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () {}, 
                      child: Text("لدي مشكلة في الدخول الى القطع", style: TextStyle(color: _bgColor, fontSize: 13, fontWeight: FontWeight.bold)),
                    ),
                  ],
                )
              ],
            ),
          ),
          // قائمة الأجهزة
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
              onPressed: _fetchNetwatchData,
              child: Text('إعادة المحاولة', style: TextStyle(color: _bgColor, fontWeight: FontWeight.bold)),
            )
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
          final isUp = device.status.toLowerCase() == 'up';
          
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF2A2A2A)), // إضافة إطار يتناسب مع التصميم
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 8, offset: const Offset(0, 4))],
            ),
            child: Row(
              children: [
                // زر الحذف والإعدادات
                InkWell(
                  onTap: () => _showDeleteDialog(device), 
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _bgColor,
                      border: Border.all(color: _goldColor.withValues(alpha: 0.5)),
                    ),
                    child: Icon(Icons.keyboard_arrow_down, color: _goldColor, size: 28),
                  ),
                ),
                const SizedBox(width: 8),
                // الوقت وحالة الاتصال
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _formatLiveCounter(device.since),
                        style: TextStyle(color: isUp ? Colors.greenAccent : Colors.redAccent, fontSize: 13, fontWeight: FontWeight.bold),
                        textDirection: TextDirection.rtl,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        isUp ? 'الحالة: متصل' : 'الحالة: مفصول',
                        style: TextStyle(color: _textColor.withValues(alpha: 0.7), fontSize: 12),
                      ),
                    ],
                  ),
                ),
                // الاسم والآيبي
                Expanded(
                  flex: 4,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        device.comment != 'بدون اسم' ? device.comment : device.host,
                        style: TextStyle(color: _textColor, fontSize: 16, fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        device.host,
                        style: TextStyle(color: _goldColor, fontSize: 14),
                        textDirection: TextDirection.ltr,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // الأيقونة الدائرية اليمنى
                Column(
                  children: [
                    CircleAvatar(
                      backgroundColor: _bgColor,
                      radius: 22,
                      child: Icon(Icons.wifi_tethering, color: _goldColor, size: 24),
                    ),
                    const SizedBox(height: 4),
                    Text("جهاز", style: TextStyle(color: _textColor, fontSize: 11)),
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
