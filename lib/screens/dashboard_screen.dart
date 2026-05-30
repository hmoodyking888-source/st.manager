import 'dart:async';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart';
import 'package:st_manager/services/router_service.dart';
import 'package:st_manager/theme/app_theme.dart';
import 'package:st_manager/screens/hotspot_cards_screen.dart';
import 'package:st_manager/screens/devices_screen.dart';
import 'package:st_manager/screens/gaming_controls_screen.dart';
import 'package:url_launcher/url_launcher.dart';

class DashboardScreen extends StatefulWidget {
  final Map<String, String> routerData;
  const DashboardScreen({super.key, required this.routerData});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  RouterService? _routerService;
  bool _connected = false;
  double _cpuLoad = 0;
  double _temperature = 0;
  double _voltage = 0;
  double _currentSpeed = 0;
  String _routerModel = '...';
  String _uptime = '...';
  int _activeUsers = 0;
  List<Map<String, dynamic>> _recentLogs = [];
  List<Map<String, dynamic>> _topUsers = [];
  String? _selectedInterface = 'ether1';
  StreamSubscription? _speedSubscription;
  Timer? _statsTimer;

  @override
  void initState() {
    super.initState();
    _connectToRouter();
  }

  Future<void> _connectToRouter() async {
    final data = widget.routerData;
    _routerService = RouterService(
      host: data['ip']!,
      username: data['username']!,
      password: data['password']!,
    );
    final ok = await _routerService!.connect();
    setState(() => _connected = ok);
    if (ok) {
      _startMonitoring();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('فشل الاتصال بالراوتر')),
        );
      }
    }
  }

  void _startMonitoring() {
    _fetchStats();
    _statsTimer =
        Timer.periodic(const Duration(seconds: 1), (_) => _fetchStats());

    if (_selectedInterface != null) {
      _speedSubscription?.cancel();
      _speedSubscription =
          _routerService!.monitorTraffic(_selectedInterface!).listen((speed) {
        if (mounted) setState(() => _currentSpeed = speed);
      });
    }

    Timer.periodic(const Duration(seconds: 3), (_) async {
      if (_routerService != null && _routerService!.isConnected) {
        try {
          final logs = await _routerService!
              .sendCommand('/log/print', params: {'limit': '4'});
          if (mounted) setState(() => _recentLogs = logs);
        } catch (_) {}
      }
    });
  }

  Future<void> _fetchStats() async {
    if (_routerService == null || !_routerService!.isConnected) return;
    try {
      final cpu =
          await _routerService!.sendCommand('/system/resource/cpu/print');
      final health = await _routerService!.sendCommand('/system/health/print');
      final resource =
          await _routerService!.sendCommand('/system/resource/print');
      final identity =
          await _routerService!.sendCommand('/system/identity/print');
      final active =
          await _routerService!.sendCommand('/ip/hotspot/active/print');

      if (mounted) {
        setState(() {
          _cpuLoad = double.tryParse(cpu.first['load']?.toString() ?? '0') ?? 0;
          _temperature =
              double.tryParse(health.first['temperature']?.toString() ?? '0') ??
                  0;
          _voltage =
              double.tryParse(health.first['voltage']?.toString() ?? '0') ?? 0;
          _routerModel = resource.first['board-name']?.toString() ?? 'MikroTik';
          _uptime = resource.first['uptime']?.toString() ?? '...';
          _activeUsers = active.length;
          _topUsers = active.take(4).toList();
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _speedSubscription?.cancel();
    _statsTimer?.cancel();
    _routerService?.disconnect();
    super.dispose();
  }

  void _openTelegramBot() async {
    final url = Uri.parse('https://t.me/ST_ManagerBot');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  void _showInterfacePicker() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('اختر الواجهة'),
        content: DropdownButtonFormField(
          value: _selectedInterface,
          items: ['ether1', 'ether2', 'bridge1']
              .map((e) => DropdownMenuItem(value: e, child: Text(e)))
              .toList(),
          onChanged: (val) {
            setState(() => _selectedInterface = val);
            _speedSubscription?.cancel();
            _speedSubscription =
                _routerService!.monitorTraffic(val!).listen((speed) {
              if (mounted) setState(() => _currentSpeed = speed);
            });
            Navigator.pop(context);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => Scaffold.of(context).openDrawer(),
        ),
        title: Column(
          children: [
            Text(widget.routerData['name'] ?? 'ST_Manager'),
            Text('ربطك بالعالم بسرعة وثقة',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(fontSize: 10)),
          ],
        ),
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined),
                onPressed: () {},
              ),
              Positioned(
                right: 6,
                top: 6,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GridView.count(
              crossAxisCount: 4,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildSmallCard('المعالج', '${_cpuLoad.toStringAsFixed(1)}%'),
                _buildSmallCard(
                    'الحرارة', '${_temperature.toStringAsFixed(1)}°C'),
                _buildSmallCard('الفولت', '${_voltage.toStringAsFixed(1)}V'),
                _buildSmallCard('النشطاء', '$_activeUsers'),
              ],
            ),
            const SizedBox(height: 12),
            Center(
              child: SizedBox(
                height: 180,
                width: 180,
                child: SfRadialGauge(
                  axes: [
                    RadialAxis(
                      minimum: 0,
                      maximum: 100,
                      ranges: [
                        GaugeRange(
                          startValue: 0,
                          endValue: 100,
                          color: AppTheme.gold.withOpacity(0.1),
                        )
                      ],
                      pointers: [
                        NeedlePointer(
                          value: _currentSpeed,
                          needleColor: AppTheme.gold,
                        )
                      ],
                      annotations: [
                        GaugeAnnotation(
                          widget: Text(
                            '${_currentSpeed.toStringAsFixed(1)} Mbps',
                            style: const TextStyle(
                                color: AppTheme.gold, fontSize: 16),
                          ),
                          angle: 90,
                          positionFactor: 0.5,
                        )
                      ],
                    )
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Router: $_routerModel',
                        style: const TextStyle(color: Colors.white)),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.greenOnline,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text('Online',
                          style: TextStyle(color: Colors.black)),
                    ),
                    Text('Uptime: $_uptime',
                        style: const TextStyle(color: Colors.white70)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildMenuButton('الأكتف', Icons.people, () {}),
                _buildMenuButton('البرودباند', Icons.router, () {}),
                _buildMenuButton('هوتسبوت', Icons.wifi_password, () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => HotspotCardsScreen(
                              routerService: _routerService)));
                }),
                _buildMenuButton('نسخة/استعادة', Icons.backup, () {}),
                _buildMenuButton('قطع البث', Icons.block, () {}),
                _buildMenuButton('الاشعارات', Icons.notifications, () {}),
                _buildMenuButton('الواجهات', Icons.settings_ethernet, () {}),
                _buildMenuButton('قياس السرعة', Icons.speed, () {
                  _showInterfacePicker();
                }),
                _buildMenuButton('تحكم الألعاب', Icons.videogame_asset, () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const GamingControlsScreen()));
                }),
              ],
            ),
            const SizedBox(height: 16),
            Text('تنبيهات سريعة',
                style: Theme.of(context).textTheme.titleLarge),
            ...(_recentLogs.map((log) => ListTile(
                  dense: true,
                  leading: const Icon(Icons.warning, color: AppTheme.gold),
                  title: Text(
                    log['message']?.toString() ?? '',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ))),
            const SizedBox(height: 16),
            Text('أعلى المستخدمين',
                style: Theme.of(context).textTheme.titleLarge),
            ...(_topUsers.map((user) => ListTile(
                  leading: const Icon(Icons.person, color: AppTheme.gold),
                  title: Text(user['user']?.toString() ?? '',
                      style: const TextStyle(color: Colors.white)),
                  subtitle: Text(user['bytes-out']?.toString() ?? '',
                      style: const TextStyle(color: Colors.white54)),
                ))),
            const SizedBox(height: 20),
            Center(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.telegram),
                label: const Text('تفعيل بوت ST'),
                onPressed: _openTelegramBot,
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        onTap: (index) {},
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'الرئيسية'),
          BottomNavigationBarItem(
              icon: Icon(Icons.people), label: 'المستخدمون'),
          BottomNavigationBarItem(
              icon: Icon(Icons.notifications), label: 'الاشعارات'),
          BottomNavigationBarItem(icon: Icon(Icons.report), label: 'التقارير'),
          BottomNavigationBarItem(
              icon: Icon(Icons.settings), label: 'الإعدادات'),
        ],
      ),
    );
  }

  Widget _buildSmallCard(String title, String value) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(title,
                style: const TextStyle(color: AppTheme.gold, fontSize: 12)),
            const SizedBox(height: 4),
            Text(value,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuButton(String label, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Card(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppTheme.gold, size: 28),
            const SizedBox(height: 6),
            Text(label,
                style: const TextStyle(color: Colors.white, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
