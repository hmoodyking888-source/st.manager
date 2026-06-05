import 'dart:async';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart';
import 'package:st_manager/services/router_service.dart';
import 'package:st_manager/theme/app_theme.dart';
import 'package:st_manager/screens/hotspot/hotspot_active_users_screen.dart';
import 'package:st_manager/screens/ppp/ppp_active_screen.dart';
import 'package:st_manager/screens/cards/cards_screen.dart';
import 'package:st_manager/screens/devices_screen.dart';
import 'package:st_manager/screens/backup_restore_screen.dart';
import 'package:st_manager/screens/interface_screen.dart';
import 'package:st_manager/screens/simple_queue_screen.dart';
import 'package:st_manager/screens/user_manager_screen.dart';
import 'package:st_manager/widgets/side_drawer.dart';

class DashboardScreen extends StatefulWidget {
  final Map<String, String> routerData;
  const DashboardScreen({super.key, required this.routerData});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  RouterService? _routerService;

  double _cpuLoad = 0;
  double _temperature = 0;
  double _voltage = 0;
  double _currentSpeed = 0;

  String _routerModel = '...';
  String _uptime = '...';

  int _activeUsers = 0;
  int _totalUsers = 0;
  int _pppActive = 0;
  int _pppTotal = 0;
  int _interfaceCount = 0;

  String? _selectedInterface = 'bridge1';
  List<String> _availableInterfaces = ['bridge1'];

  StreamSubscription<double>? _speedSubscription;
  Timer? _statsTimer;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _connectToRouter();
  }

  Future<void> _connectToRouter() async {
    final data = widget.routerData;

    _routerService = RouterService(
      host: data['ip']!,
      port: int.tryParse(data['port'] ?? '8728') ?? 8728,
      username: data['username']!,
      password: data['password']!,
    );

    final ok = await _routerService!.connect();

    if (ok) {
      _startMonitoring();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('فشل الاتصال بالراوتر')),
        );
        Navigator.pop(context);
      }
    }
  }

  void _startMonitoring() {
    _fetchStats();
    _loadInterfaces();

    _statsTimer =
        Timer.periodic(const Duration(seconds: 2), (_) => _fetchStats());

    if (_selectedInterface != null) {
      _speedSubscription?.cancel();
      _speedSubscription = _routerService!
          .monitorTrafficStream(_selectedInterface!)
          .listen((speed) {
        if (mounted) {
          setState(() => _currentSpeed = speed);
        }
      });
    }
  }

  Future<void> _loadInterfaces() async {
    if (_routerService == null || !_routerService!.isConnected) return;

    try {
      final interfaces = await _routerService!.getInterfaceList();
      final names = interfaces
          .map((e) => e['name']?.toString())
          .whereType<String>()
          .where((name) => name.trim().isNotEmpty)
          .toList();

      if (names.isNotEmpty && mounted) {
        setState(() {
          _availableInterfaces = names;
          _interfaceCount = names.length;

          if (!_availableInterfaces.contains(_selectedInterface)) {
            _selectedInterface = _availableInterfaces.first;
          }
        });

        _speedSubscription?.cancel();
        _speedSubscription = _routerService!
            .monitorTrafficStream(_selectedInterface!)
            .listen((speed) {
          if (mounted) setState(() => _currentSpeed = speed);
        });
      }
    } catch (_) {}
  }

  Future<void> _fetchStats() async {
    if (_routerService == null || !_routerService!.isConnected) return;

    try {
      final resource = await _routerService!.getSystemResource();
      final health = await _routerService!.getSystemHealth();
      final active = await _routerService!.getHotspotActive();
      final allUsers = await _routerService!.getHotspotUsers();
      final pppActive = await _routerService!.getPppActive();
      final pppSecrets = await _routerService!.getPppSecrets();

      if (!mounted) return;

      setState(() {
        if (resource.isNotEmpty) {
          _cpuLoad =
              double.tryParse(resource.first['cpu-load']?.toString() ?? '0') ??
                  0;
          _routerModel = resource.first['board-name']?.toString() ?? 'MikroTik';
          _uptime = resource.first['uptime']?.toString() ?? '...';
        }

        if (health.isNotEmpty) {
          _temperature = _parseTemperature(health);
          _voltage = _parseVoltage(health);
        }

        _activeUsers = active.length;
        _totalUsers = allUsers.length;
        _pppActive = pppActive.length;
        _pppTotal = pppSecrets.length;
      });
    } catch (_) {}
  }

  double _parseTemperature(List<Map<String, dynamic>> health) {
    for (var item in health) {
      if (item.containsKey('name') &&
          item['name'].toString().toLowerCase().contains('temp')) {
        double? temp = double.tryParse(item['value']?.toString() ?? '');
        if (temp != null) {
          if (temp > 100) temp = temp / 10;
          return temp;
        }
      }

      if (item.containsKey('temperature')) {
        double? temp = double.tryParse(item['temperature'].toString());
        if (temp != null) {
          if (temp > 100) temp = temp / 10;
          return temp;
        }
      }
    }
    return 0;
  }

  double _parseVoltage(List<Map<String, dynamic>> health) {
    final direct = double.tryParse(health.first['voltage']?.toString() ?? '');
    if (direct != null && direct > 0) return direct;

    for (var item in health) {
      if (item.containsKey('name') &&
          item['name'].toString().toLowerCase().contains('volt')) {
        final v = double.tryParse(item['value']?.toString() ?? '');
        if (v != null && v > 0) return v;
      }
    }
    return 0;
  }

  @override
  void dispose() {
    _speedSubscription?.cancel();
    _statsTimer?.cancel();
    _routerService?.disconnect();
    super.dispose();
  }

  void _showInterfacePicker() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('اختر الواجهة'),
        content: DropdownButtonFormField<String>(
          value: _selectedInterface,
          isExpanded: true,
          items: _availableInterfaces
              .map(
                (e) => DropdownMenuItem<String>(
                  value: e,
                  child: Text(e),
                ),
              )
              .toList(),
          onChanged: (val) {
            if (val == null) return;

            setState(() => _selectedInterface = val);
            _speedSubscription?.cancel();
            _speedSubscription =
                _routerService!.monitorTrafficStream(val).listen((speed) {
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
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.routerData['name'] ?? 'ST_Manager'),
            Text(
              'ربطك بالعالم بسرعة وثقة',
              style:
                  Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 10),
            ),
          ],
        ),
        actions: [
          Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
          ),
        ],
      ),
      drawer: SideDrawer(routerService: _routerService),
      body: _buildBody(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          if (index == 4) {
            Navigator.pushNamed(context, '/settings').then((_) {
              if (mounted) {
                setState(() => _currentIndex = 0);
              }
            });
            return;
          }
          setState(() => _currentIndex = index);
        },
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

  Widget _buildBody() {
    switch (_currentIndex) {
      case 0:
        return _buildDashboardContent();
      case 1:
        return const Center(
          child: Text('قسم المستخدمون', style: TextStyle(color: Colors.white)),
        );
      case 2:
        return const Center(
          child: Text('الإشعارات', style: TextStyle(color: Colors.white)),
        );
      case 3:
        return const Center(
          child: Text('التقارير', style: TextStyle(color: Colors.white)),
        );
      case 4:
        return const Center(
          child: Text('الإعدادات', style: TextStyle(color: Colors.white)),
        );
      default:
        return _buildDashboardContent();
    }
  }

  Widget _buildDashboardContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
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
              _buildSmallCard('الواجهات', '$_interfaceCount'),
            ],
          ),
          const SizedBox(height: 14),
          _buildSpeedGauge(),
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    _routerModel,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Uptime: $_uptime',
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 13,
                    ),
                  ),
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
              _buildMenuButtonWithCounter(
                'هوتسبوت',
                Icons.wifi_password,
                '$_totalUsers/$_activeUsers',
                () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => HotspotActiveUsersScreen(
                      routerService: _routerService,
                    ),
                  ),
                ),
              ),
              _buildMenuButtonWithCounter(
                'برودباند',
                Icons.router,
                '$_pppTotal/$_pppActive',
                () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PppActiveScreen(
                      routerService: _routerService,
                    ),
                  ),
                ),
              ),
              _buildMenuButton('بطاقات', Icons.credit_card, () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CardsScreen(routerService: _routerService),
                  ),
                );
              }),
              _buildMenuButton('نسخ/استعادة', Icons.backup, () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => BackupRestoreScreen(
                      routerService: _routerService,
                    ),
                  ),
                );
              }),
              _buildMenuButton('الأجهزة', Icons.cell_tower, () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        DevicesScreen(routerService: _routerService),
                  ),
                );
              }),
              _buildMenuButton('الواجهات', Icons.settings_ethernet, () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        InterfaceScreen(routerService: _routerService),
                  ),
                );
              }),
              _buildMenuButton(
                  'قياس السرعة', Icons.speed, _showInterfacePicker),
              _buildMenuButton('Simple Queue', Icons.queue, () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SimpleQueueScreen(
                      routerService: _routerService,
                    ),
                  ),
                );
              }),
              _buildMenuButton('User Manager', Icons.manage_accounts, () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => UserManagerScreen(
                      routerService: _routerService,
                    ),
                  ),
                );
              }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSpeedGauge() {
    final speedValue = _currentSpeed.clamp(0.0, 1000.0).toDouble();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF111111),
            const Color(0xFF1A1A1A),
            const Color(0xFF0B0B0B),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: AppTheme.gold.withOpacity(0.35),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.gold.withOpacity(0.08),
            blurRadius: 24,
            spreadRadius: 1,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'السرعة اللحظية',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                _selectedInterface ?? '---',
                style: const TextStyle(
                  color: AppTheme.gold,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 250,
            child: SfRadialGauge(
              axes: [
                RadialAxis(
                  minimum: 0,
                  maximum: 1000,
                  startAngle: 145,
                  endAngle: 35,
                  showLabels: true,
                  showTicks: true,
                  axisLabelStyle: GaugeTextStyle(
                    color: Colors.white54,
                    fontSize: 10,
                  ),
                  majorTickStyle: const MajorTickStyle(
                    length: 10,
                    thickness: 2,
                    color: Colors.white30,
                  ),
                  minorTickStyle: const MinorTickStyle(
                    length: 5,
                    thickness: 1,
                    color: Colors.white24,
                  ),
                  axisLineStyle: const AxisLineStyle(
                    thickness: 0.12,
                    thicknessUnit: GaugeSizeUnit.factor,
                    color: Color(0xFF2A2A2A),
                  ),
                  ranges: [
                    GaugeRange(
                      startValue: 0,
                      endValue: 350,
                      color: Colors.greenAccent.withOpacity(0.55),
                      startWidth: 0.12,
                      endWidth: 0.12,
                      sizeUnit: GaugeSizeUnit.factor,
                    ),
                    GaugeRange(
                      startValue: 350,
                      endValue: 700,
                      color: Colors.orangeAccent.withOpacity(0.75),
                      startWidth: 0.12,
                      endWidth: 0.12,
                      sizeUnit: GaugeSizeUnit.factor,
                    ),
                    GaugeRange(
                      startValue: 700,
                      endValue: 1000,
                      color: Colors.redAccent.withOpacity(0.75),
                      startWidth: 0.12,
                      endWidth: 0.12,
                      sizeUnit: GaugeSizeUnit.factor,
                    ),
                  ],
                  pointers: [
                    NeedlePointer(
                      value: speedValue,
                      needleColor: AppTheme.gold,
                      knobStyle: KnobStyle(
                        knobRadius: 0.08,
                        sizeUnit: GaugeSizeUnit.factor,
                        borderColor: AppTheme.gold,
                        color: Colors.black,
                        borderWidth: 0.04,
                      ),
                      needleLength: 0.75,
                      tailStyle: TailStyle(
                        length: 0.14,
                        width: 10,
                        color: AppTheme.gold.withOpacity(0.85),
                      ),
                    ),
                  ],
                  annotations: [
                    GaugeAnnotation(
                      positionFactor: 0.10,
                      angle: 90,
                      widget: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${_currentSpeed.toStringAsFixed(1)}',
                            style: const TextStyle(
                              color: AppTheme.gold,
                              fontSize: 34,
                              fontWeight: FontWeight.bold,
                              height: 1,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Mbps',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
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
            Text(
              title,
              style: const TextStyle(
                color: AppTheme.gold,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
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
            Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuButtonWithCounter(
    String label,
    IconData icon,
    String counter,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      child: Card(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppTheme.gold, size: 28),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 12),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 2),
            Text(
              counter,
              style: const TextStyle(
                color: AppTheme.greenOnline,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
