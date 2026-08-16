import 'dart:async';
import 'package:flutter/material.dart';
import 'package:st_manager/services/router_service.dart';
import 'package:url_launcher/url_launcher.dart'; // تأكد من إضافة هذه الحزمة في pubspec.yaml

/// نموذج بيانات يمثل جهاز متصل بالشبكة (من الـ Neighbors)
class NetworkDevice {
  final String name;
  final String ip;
  final String mac;
  final String interface;
  final String model;
  final String type; 
  final String uptime;
  final String status;
  final Map<String, dynamic> rawData; // تمت إضافته لحفظ كل التفاصيل الأصلية لعرضها لاحقاً

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

class DevicesScreen extends StatefulWidget {
  final RouterService? routerService;
  const DevicesScreen({super.key, required this.routerService});

  @override
  State<DevicesScreen> createState() => _DevicesScreenState();
}

class _DevicesScreenState extends State<DevicesScreen> {
  List<NetworkDevice> _devices = [];
  
  bool _isLoading = true;
  String? _errorMessage;

  // الألوان الأساسية للواجهة الفاخرة والنقية
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

  /// تحديد نوع القطعة بناءً على الموديل
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

  /// ترجمة واجهات الميكروتيك
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

  /// جلب البيانات من الميكروتيك (Neighbors فقط)
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

      for (var n in neighbors) {
        final identity = n['identity']?.toString() ?? 'جهاز غير مسمى';
        final ip = n['address']?.toString() ?? 'لا يوجد IP';
        final mac = n['mac-address']?.toString() ?? 'غير معروف';
        final interface = n['interface']?.toString() ?? 'غير معروف';
        final board = n['board']?.toString() ?? 'غير معروف';
        final uptime = n['uptime']?.toString() ?? '-';

        loadedDevices.add(
          NetworkDevice(
            name: identity,
            ip: ip,
            mac: mac,
            interface: _formatInterface(interface),
            model: board != 'غير معروف' ? board : 'جهاز عام',
            type: _determineDeviceType(board),
            uptime: uptime,
            status: 'متصل', // أجهزة الـ Neighbors تعتبر متصلة
            rawData: n as Map<String, dynamic>,
          )
        );
      }

      // ترتيب الأجهزة أبجدياً
      loadedDevices.sort((a, b) => a.name.compareTo(b.name));

      if (mounted) {
        setState(() {
          _devices = loadedDevices;
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

  /// اختيار الأيقونة بناءً على نوع الجهاز
  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'مستقبل': return Icons.wifi_tethering;
      case 'مرسل': return Icons.cell_tower;
      case 'راوتر/سويتش': return Icons.router;
      default: return Icons.devices_other;
    }
  }

  /// فتح رابط في المتصفح
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

  /// عرض خيارات الجهاز (BottomSheet)
  void _showDeviceOptions(NetworkDevice device) {
    showModalBottomSheet(
      context: context,
      backgroundColor: _cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // عنوان القائمة
              Text(
                device.name,
                style: TextStyle(color: _goldColor, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Divider(color: _subTextColor.withValues(alpha: 0.3)),
              
              // خيار الفتح في المتصفح
              ListTile(
                leading: Icon(Icons.language, color: _textColor),
                title: Text('فتح في المتصفح', style: TextStyle(color: _textColor)),
                subtitle: Text(device.ip, style: TextStyle(color: _subTextColor, fontSize: 12)),
                onTap: () {
                  Navigator.pop(context);
                  _openInBrowser(device.ip);
                },
              ),
              
              // خيار إعادة التشغيل
              ListTile(
                leading: const Icon(Icons.restart_alt, color: Colors.orangeAccent),
                title: const Text('إعادة تشغيل الجهاز', style: TextStyle(color: Colors.orangeAccent)),
                onTap: () {
                  Navigator.pop(context);
                  _showRebootConfirmation(device);
                },
              ),

              // خيار عرض التفاصيل الكاملة
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

  /// نافذة تأكيد إعادة التشغيل
  void _showRebootConfirmation(NetworkDevice device) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cardColor,
        title: Text('تأكيد إعادة التشغيل', style: TextStyle(color: _goldColor)),
        content: Text(
          'هل أنت متأكد أنك تريد إعادة تشغيل الجهاز:\n${device.name}؟',
          style: TextStyle(color: _textColor),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              Navigator.pop(context);
              // TODO: ضع كود أمر إعادة التشغيل الخاص بك هنا
              // مثال: widget.routerService!.sendCommand('....');
              
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('تم إرسال أمر إعادة التشغيل إلى ${device.name}', style: const TextStyle(fontFamily: 'Cairo')),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text('إعادة تشغيل', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  /// نافذة عرض تفاصيل الجهاز الكاملة
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
                    Expanded(
                      flex: 2,
                      child: Text(key, style: TextStyle(color: _goldColor, fontSize: 13)),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text(
                        value, 
                        style: TextStyle(color: _textColor, fontSize: 13),
                        textDirection: TextDirection.ltr,
                        textAlign: TextAlign.left,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('إغلاق', style: TextStyle(color: _goldColor)),
          ),
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
        title: Text(
          'أجهزة الشبكة (Neighbors)',
          style: TextStyle(color: _goldColor, fontWeight: FontWeight.bold, letterSpacing: 1, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: _goldColor),
            onPressed: _isLoading ? null : _fetchNetworkData,
            tooltip: 'تحديث البيانات',
          )
        ],
      ),
      body: _buildDeviceList(),
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

    if (_devices.isEmpty) {
      return Center(
        child: Text(
          'لا توجد أجهزة متصلة',
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
        itemCount: _devices.length,
        itemBuilder: (context, index) {
          final device = _devices[index];
          return _buildDeviceCard(device);
        },
      ),
    );
  }

  /// تصميم بطاقة الجهاز الفاخرة والنقية (تم جعلها قابلة للضغط)
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
      child: Material( // إضافة Material و InkWell لجعل البطاقة قابلة للضغط مع تأثير مرئي
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
                // الصف العلوي: الأيقونة، الاسم، النوع والحالة
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
                          const SizedBox(height: 6),
                          Row(
                            children: [
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
                              const SizedBox(width: 8),
                              // إظهار حالة الجهاز
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.green.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  device.status,
                                  style: const TextStyle(
                                    color: Colors.green,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // أيقونة صغيرة تدل على أن البطاقة قابلة للضغط
                    Icon(Icons.more_vert, color: _subTextColor.withValues(alpha: 0.5)),
                  ],
                ),
                
                const SizedBox(height: 16),
                const Divider(color: Color(0xFF2A2A2A), height: 1),
                const SizedBox(height: 16),
                
                // شبكة البيانات الأساسية
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
