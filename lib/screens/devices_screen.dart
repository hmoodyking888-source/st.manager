import 'dart:async';
import 'package:flutter/material.dart';
import 'package:st_manager/services/router_service.dart';

/// نموذج البيانات النقي والموحد لكل قطة أو جهاز على الشبكة
class NetworkDevice {
  final String id;
  final String name;       // اسم العميل أو اسم القطعة (رعد عبدالله مثلاً)
  final String ip;         // عنوان IP
  final String mac;        // عنوان MAC
  final String interface;  // المنفذ (مثل: ايثرنت 3)
  final String model;      // موديل الجهاز (LiteBeam M5, PowerBeam)
  final String type;       // الفرز: 'مستقبل', 'مرسل', 'هوتسبوت', 'بنية تحتية'
  final String status;     // حالة الاتصال الافتراضية

  NetworkDevice({
    required this.id,
    required this.name,
    required this.ip,
    required this.mac,
    required this.interface,
    required this.model,
    required this.type,
    required this.status,
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
  String _selectedFilter = 'الكل'; // الفلاتر: الكل، مستقبل، مرسل، هوتسبوت

  // الألوان المعتمدة للهوية البصرية الفاخرة والنقية (Black & Gold)
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

  /// تحليل ذكي لموديل الجهاز وتحديد ما إذا كان مرسل أم مستقبل
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

  /// تنظيف وتنسيق أسماء المنافذ لتصبح واضحة ومفهومة باللغة العربية
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

  /// جلب البيانات المدمجة (Neighbor Discovery + Hotspot Host)
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

    try {
      // جلب الجيران والمضيفين في نفس الوقت لسرعة فائقة وأداء خفيف
      final results = await Future.wait([
        widget.routerService!.sendCommand('/ip/neighbor/print'),
        widget.routerService!.sendCommand('/ip/hotspot/host/print').catchError((_) => []),
      ]);

      final List<dynamic> neighbors = results[0] ?? [];
      final List<dynamic> hotspotHosts = results[1] ?? [];

      // خريطة وسيطة لدمج الأجهزة بناءً على الماك أدرس منعاً للتكرار
      final Map<String, Map<String, dynamic>> mergedMap = {};

      // 1. معالجة بيانات الـ Neighbors (البنية التحتية والقطع اللاسلكية)
      for (var n in neighbors) {
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
        };
      }

      // 2. معالجة بيانات الـ Hotspot Host ودمجها أو إضافتها
      for (var h in hotspotHosts) {
        final mac = h['mac-address']?.toString() ?? '';
        if (mac.isEmpty) continue;

        final ip = h['address']?.toString() ?? '';
        final server = h['server']?.toString() ?? 'hotspot';
        final comment = h['comment']?.toString() ?? '';
        final user = h['user']?.toString() ?? '';
        
        // اختيار الاسم الأفضل: التعليق (اسم المشترك) أولاً، ثم اليوزر، ثم الماك
        String hostName = mac;
        if (comment.isNotEmpty) {
          hostName = comment;
        } else if (user.isNotEmpty) {
          hostName = user;
        }

        if (mergedMap.containsKey(mac)) {
          // إذا كان الجهاز معروفاً كـ LiteBeam مثلاً، نحتفظ بنوعه وموديله ونحدث الاسم ليكون اسم المشترك
          if (comment.isNotEmpty || user.isNotEmpty) {
            mergedMap[mac]!['name'] = hostName;
          }
          if (mergedMap[mac]!['ip'].toString().isEmpty) {
            mergedMap[mac]!['ip'] = ip;
          }
        } else {
          // إذا كان جهاز موبايل أو كمبيوتر عميل عادي في الهوتسبوت
          mergedMap[mac] = {
            'name': hostName,
            'ip': ip,
            'mac': mac,
            'interface': server,
            'model': h['bypassed']?.toString() == 'true' ? 'بث مباشر (Bypass)' : 'جهاز عميل',
            'type': 'هوتسبوت',
            'status': h['authorized']?.toString() == 'true' ? 'online' : 'pending',
          };
        }
      }

      // تحويل الخريطة المدمجة إلى القائمة النهائية للموديل
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
        ));
      });

      // ترتيب عرض الأجهزة (مستقبلات ثم مرسلات ثم هوتسبوت)
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
          _errorMessage = 'فشل جلب وتحليل بيانات المضيفين: $e';
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
        title: Text(
          'استكشاف الأجهزة والمضيفين',
          style: TextStyle(color: _goldColor, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.sync, color: _goldColor),
            onPressed: _isLoading ? null : _fetchNetworkData,
          )
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
      return Center(
        child: Text('لا توجد قطع أو مضيفين مطابقين حالياً', style: TextStyle(color: _subTextColor)),
      );
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
            // الأيقونة الجانبية الفاخرة التي توضح نوع القطعة
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _bgColor,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _goldColor.withValues(alpha: 0.3)),
              ),
              child: Icon(_getTypeIcon(device.type), color: _goldColor, size: 24),
            ),
            // اسم العميل أو اسم القطعة الأساسي (رعد عبدالله)
            title: Text(
              device.name,
              style: TextStyle(color: _textColor, fontWeight: FontWeight.bold, fontSize: 16),
            ),
            // تفاصيل القطعة المباشرة بدون حشو (الموديل والمنفذ)
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 6.0),
              child: Row(
                children: [
                  Text(device.model, style: TextStyle(color: _goldColor, fontSize: 12, fontWeight: FontWeight.w500)),
                  const SizedBox(width: 8),
                  Text('•', style: TextStyle(color: _subTextColor)),
                  const SizedBox(width: 8),
                  Icon(Icons.lan_outlined, size: 12, color: _subTextColor),
                  const SizedBox(width: 4),
                  Text(device.interface, style: TextStyle(color: _subTextColor, fontSize: 12)),
                ],
              ),
            ),
            // الآيبي والماك منسقين في الجانب الأيسر بشكل خفيف ونظيف
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  device.ip,
                  style: TextStyle(color: _textColor, fontSize: 12, fontFamily: 'monospace', fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  device.mac,
                  style: TextStyle(color: _subTextColor, fontSize: 10, fontFamily: 'monospace'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
