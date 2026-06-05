import 'dart:async';
import 'package:flutter/material.dart';
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

  double _rxSpeed = 0;
  double _txSpeed = 0;
  bool _showRxMain = true;

  String _routerModel = '...';
  String _uptime = '...';

  int _activeUsers = 0;
  int _totalUsers = 0;
  int _pppActive = 0;
  int _pppTotal = 0;
  int _interfaceCount = 0;

  String? _selectedInterface = 'bridge1';
  List<String> _availableInterfaces = ['bridge1'];

  StreamSubscription<Map<String, double>>? _speedSubscription;
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

    _statsTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => _fetchStats(),
    );

    if (_selectedInterface != null) {
      _speedSubscription?.cancel();
      _speedSubscription = _routerService!
          .monitorTrafficDetailsStream(_selectedInterface!)
          .listen((speed) {
        if (!mounted) return;
        setState(() {
          _rxSpeed = (speed['rx-bits-per-second'] ?? 0) / 1000000;
          _txSpeed = (speed['tx-bits-per-second'] ?? 0) / 1000000;
        });
      });
    }
  }

  bool _isPortOrBridge(Map<String, dynamic> iface) {
    final name = iface['name']?.toString().toLowerCase().trim() ?? '';
    final type = iface['type']?.toString().toLowerCase().trim() ?? '';
    final kind =
        iface['actual-interface-type']?.toString().toLowerCase().trim() ?? '';

    bool startsWithAny(List<String> prefixes) => prefixes.any(
        (p) => name.startsWith(p) || type.startsWith(p) || kind.startsWith(p));

    return startsWithAny([
      'ether',
      'bridge',
      'sfp',
      'wlan',
      'bond',
    ]);
  }

  Future<void> _loadInterfaces() async {
    if (_routerService == null || !_routerService!.isConnected) return;

    try {
      final interfaces = await _routerService!.getInterfaceList();
      final names = interfaces
          .where(_isPortOrBridge)
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
            .monitorTrafficDetailsStream(_selectedInterface!)
            .listen((speed) {
          if (!mounted) return;
          setState(() {
            _rxSpeed = (speed['rx-bits-per-second'] ?? 0) / 1000000;
            _txSpeed = (speed['tx-bits-per-second'] ?? 0) / 1000000;
          });
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
    if (health.isEmpty) return 0;

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
            _speedSubscription = _routerService!
                .monitorTrafficDetailsStream(val)
                .listen((speed) {
              if (!mounted) return;
              setState(() {
                _rxSpeed = (speed['rx-bits-per-second'] ?? 0) / 1000000;
                _txSpeed = (speed['tx-bits-per-second'] ?? 0) / 1000000;
              });
            });
            Navigator.pop(context);
          },
        ),
      ),
    );
  }

  void _toggleSpeedView() {
    setState(() => _showRxMain = !_showRxMain);
  }

  String _formatSpeed(double speed) {
    if (speed >= 1000) return '${(speed / 1000).toStringAsFixed(1)} Gbps';
    if (speed >= 1) return '${speed.toStringAsFixed(1)} Mbps';
    return '${(speed * 1000).toStringAsFixed(0)} Kbps';
  }

  @override
  Widget build(BuildContext context) {
    final surfaceText = Theme.of(context).colorScheme.onSurface;

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
              if (mounted) setState(() => _currentIndex = 0);
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
        return Center(
          child: Text('قسم المستخدمون',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
        );
      case 2:
        return Center(
          child: Text('الإشعارات',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
        );
      case 3:
        return Center(
          child: Text('التقارير',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
        );
      case 4:
        return Center(
          child: Text('الإعدادات',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
        );
      default:
        return _buildDashboardContent();
    }
  }

  Widget _buildDashboardContent() {
    final onSurface = Theme.of(context).colorScheme.onSurface;

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
          _buildSpeedCard(onSurface),
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    _routerModel,
                    style: TextStyle(
                      color: onSurface,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Uptime: $_uptime',
                    style: TextStyle(
                      color: onSurface.withOpacity(0.7),
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

  Widget _buildSpeedCard(Color onSurface) {
    final primary = _showRxMain ? _rxSpeed : _txSpeed;
    final secondary = _showRxMain ? _txSpeed : _rxSpeed;
    final primaryLabel = _showRxMain ? 'RX' : 'TX';
    final secondaryLabel = _showRxMain ? 'TX' : 'RX';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.black,
            AppTheme.darkGrey,
            AppTheme.semiBlack,
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
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 18, horizontal: 14),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        primaryLabel,
                        style: const TextStyle(
                          color: AppTheme.gold,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          _formatSpeed(primary),
                          style: TextStyle(
                            color: onSurface,
                            fontSize: 34,
                            fontWeight: FontWeight.bold,
                            height: 1,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'الأولوية الآن: $primaryLabel',
                        style: TextStyle(
                          color: onSurface.withOpacity(0.72),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 84,
                child: Column(
                  children: [
                    ElevatedButton(
                      onPressed: _toggleSpeedView,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 10),
                        minimumSize: const Size.fromHeight(40),
                      ),
                      child: Icon(
                        _showRxMain ? Icons.swap_vert : Icons.swap_vert,
                        size: 18,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Column(
                        children: [
                          Text(
                            secondaryLabel,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _formatSpeed(secondary),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              height: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSmallCard(String title, String value) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              title,
              style: TextStyle(
                color: AppTheme.gold,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                color: onSurface,
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
    final onSurface = Theme.of(context).colorScheme.onSurface;
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
              style: TextStyle(color: onSurface, fontSize: 12),
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
    final onSurface = Theme.of(context).colorScheme.onSurface;
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
              style: TextStyle(color: onSurface, fontSize: 12),
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
