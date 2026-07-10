import 'dart:async';
import 'package:flutter/material.dart';
import 'package:st_manager/services/router_service.dart';

/// نموذج بيانات يمثل أي جهاز متصل بالشبكة (مرسل، مستقبل، أو هوتسبوت)
class NetworkDevice {
  final String name;
  final String ip;
  final String mac;
  final String interface;
  final String model;
  final String type; // 'مستقبل', 'مرسل', 'هوتسبوت', 'راوتر/سويتش'
  final String uptime;

  NetworkDevice({
    required this.name,
    required this.ip,
    required this.mac,
    required this.interface,
    required this.model,
    required this.type,
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
  String _selectedFilter = 'الكل'; // الكل, مستقبل, مرسل, هوتسبوت

  // الألوان الأساسية للواجهة الفاخرة والنقية
  final Color _bgColor = const Color(0xFF0A0A0A); // أسود عميق
  final Color _cardColor = const Color(0xFF141414); // رمادي داكن جداً
  final Color _goldColor = const Color(0xFFFFD700); // ذهبي
  final Color _textColor = const Color(0xFFE0E0E0); // أبيض رمادي للقراءة
  final Color _subTextColor = const Color(0xFF888888); // لون النصوص الفرعية

  @override
  void initState() {
    super.initState();
    _fetchNetworkData();
  }

  /// تحديد نوع القطعة بناءً على الموديل (Board Name)
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

  /// ترجمة واجهات الميكروتيك (Interfaces) لتكون أوضح
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

  /// جلب البيانات من الميكروتيك (Neighbors + Hotspot)
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
      // نستخدم طلبين أساسيين فقط لتقليل الضغط على الراوتر
      final results = await Future.wait([
        widget.routerService!.sendCommand('/ip/neighbor/print'),
        widget.routerService!.sendCommand('/ip/hotspot/active/print').catchError((_) => []),
      ]);

      final List<dynamic> neighbors = results[0] ?? [];
      final List<dynamic> hotspots = results[1] ?? [];
      
      List<NetworkDevice> loadedDevices = [];

      // 1. معالجة القطع والأجهزة (Neighbors)
      for (var n in neighbors) {
        final identity = n['identity']?.toString() ?? 'جهاز غير مسمى';
        final ip = n['address']?.toString() ?? 'لا يوجد IP';
        final mac = n['mac-address']?.toString() ?? 'غير معروف';
        final interface = n['interface']?.toString() ?? 'غير معروف';
        final board = n['board']?.toString() ?? 'غير معروف';
        final uptime = n['uptime']?.toString() ?? '-';

        // تخطي الأجهزة الوهمية أو الفارغة تماماً
        if (ip == 'لا يوجد IP' && mac == 'غير معروف') continue;

        loadedDevices.add(NetworkDevice(
          name: identity,
          ip: ip,
          mac: mac,
          interface: _formatInterface(interface),
          model: board != 'غير معروف' ? board : 'جهاز عام',
          type: _determineDeviceType(board),
          uptime: uptime,
        ));
      }

      // 2. معالجة مستخدمي الهوتسبوت النشطين
      for (var h in hotspots) {
        final user = h['user']?.toString() ?? 'مستخدم غير معروف';
        final ip = h['address']?.toString() ?? 'لا يوجد IP';
        final mac = h['mac-address']?.toString() ?? 'غير معروف';
        final server = h['server']?.toString() ?? 'الهوتسبوت';
        final uptime = h['uptime']?.toString() ?? '-';

        loadedDevices.add(NetworkDevice(
          name: user,
          ip: ip,
          mac: mac,
          interface: server, // نضع اسم سيرفر الهوتسبوت مكان المدخل
          model: 'Hotspot Client',
          type: 'هوتسبوت',
          uptime: uptime,
        ));
      }

      // فرز الأجهزة (الهوتسبوت أولاً ثم المستقبلات ثم المرسلات)
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
          _errorMessage = 'حدث خطأ أثناء جلب البيانات: $e';
          _isLoading = false;
        });
      }
    }
  }

  /// تطبيق البحث والتصفية
  void _applyFilters() {
    setState(() {
      _filteredDevices = _devices.where((d) {
        // فلتر النوع
        final matchesType = _selectedFilter == 'الكل' || d.type == _selectedFilter;
        
        // فلتر البحث النصي
        final query = _searchQuery.toLowerCase();
        final matchesSearch = d.name.toLowerCase().contains(query) || 
                              d.ip.toLowerCase().contains(query) || 
                              d.mac.toLowerCase().contains(query) || 
                              d.model.toLowerCase().contains(query);
                              
        return matchesType && matchesSearch;
      }).toList();
    });
  }

  /// اختيار الأيقونة واللون بناءً على نوع الجهاز (تصميم فاخر)
  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'مستقبل': return Icons.wifi_tethering;
      case 'مرسل': return Icons.cell_tower;
      case 'هوتسبوت': return Icons.phonelink_ring;
      case 'راوتر/سويتش': return Icons.router;
      default: return Icons.devices_other;
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
        title: Text(
          'الشبكة والأجهزة',
          style: TextStyle(color: _goldColor, fontWeight: FontWeight.bold, letterSpacing: 1),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: _goldColor),
            onPressed: _isLoading ? null : _fetchNetworkData,
            tooltip: 'تحديث البيانات',
          )
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

  /// لوحة البحث والفلترة العلوية
  Widget _buildTopPanel() {
    return Container(
      color: _cardColor,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        children: [
          // شريط البحث
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
                hintText: 'ابحث عن اسم، آيبي، أو موديل...',
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
          const SizedBox(height: 16),
          // أزرار الفلترة السريعة (شريط التمرير الأفقي)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            reverse: true, // لتبدأ من اليمين
            child: Row(
              children: ['الكل', 'مستقبل', 'مرسل', 'هوتسبوت', 'راوتر/سويتش'].map((filter) {
                final isSelected = _selectedFilter == filter;
                return Padding(
                  padding: const EdgeInsets.only(left: 8.0),
                  child: ChoiceChip(
                    label: Text(filter),
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
                    labelStyle: TextStyle(
                      color: isSelected ? _goldColor : _subTextColor,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(
                        color: isSelected ? _goldColor : Colors.transparent,
                      ),
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

  /// قائمة الأجهزة
  Widget _buildDeviceList() {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(color: _goldColor),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.wifi_off, size: 64, color: Colors.redAccent.withValues(alpha: 0.8)),
            const SizedBox(height: 16),
            Text(_errorMessage!, style: TextStyle(color: _textColor), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: _goldColor, foregroundColor: _bgColor),
              onPressed: _fetchNetworkData,
              child: const Text('إعادة المحاولة', style: TextStyle(fontWeight: FontWeight.bold)),
            )
          ],
        ),
      );
    }

    if (_filteredDevices.isEmpty) {
      return Center(
        child: Text(
          'لا توجد أجهزة مطابقة للبحث',
          style: TextStyle(color: _subTextColor, fontSize: 16),
        ),
      );
    }

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

  /// تصميم بطاقة الجهاز الفاخرة والنقية
  Widget _buildDeviceCard(NetworkDevice device) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2A2A2A)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // الصف العلوي: الأيقونة، الاسم، والنوع
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _bgColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _goldColor.withValues(alpha: 0.5)),
                  ),
                  child: Icon(_getTypeIcon(device.type), color: _goldColor, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        device.name,
                        style: TextStyle(
                          color: _textColor,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _goldColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          device.type,
                          style: TextStyle(
                            color: _goldColor,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            const Divider(color: Color(0xFF2A2A2A), height: 1),
            const SizedBox(height: 16),
            
            // شبكة البيانات الأساسية بوضوح تام (الآيبي، الموديل، المدخل، الماك)
            Row(
              children: [
                Expanded(
                  child: _buildInfoColumn(Icons.memory, 'الموديل', device.model),
                ),
                Expanded(
                  child: _buildInfoColumn(Icons.settings_ethernet, 'المدخل', device.interface),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildInfoColumn(Icons.network_check, 'الآيبي (IP)', device.ip, isLtr: true),
                ),
                Expanded(
                  child: _buildInfoColumn(Icons.fingerprint, 'الماك (MAC)', device.mac, isLtr: true),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// مكون فرعي لعرض النصوص بوضوح داخل البطاقة
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
              Text(
                label,
                style: TextStyle(color: _subTextColor, fontSize: 11),
              ),
              const SizedBox(height: 2),
              Directionality(
                textDirection: isLtr ? TextDirection.ltr : TextDirection.rtl,
                child: Text(
                  value,
                  style: TextStyle(
                    color: _textColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: isLtr ? TextAlign.left : TextAlign.right,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
