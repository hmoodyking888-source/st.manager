import 'dart:async';
import 'dart:math' as math;
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

    return startsWithAny(['ether', 'bridge', 'sfp', 'wlan', 'bond']);
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
        backgroundColor: AppTheme.semiBlack,
        title:
            const Text('اختر الواجهة', style: TextStyle(color: Colors.white)),
        content: DropdownButtonFormField<String>(
          value: _selectedInterface,
          isExpanded: true,
          dropdownColor: AppTheme.semiBlack,
          style: const TextStyle(color: Colors.white),
          items: _availableInterfaces
              .map((e) => DropdownMenuItem<String>(
                    value: e,
                    child: Text(e),
                  ))
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

  void _toggleSpeedView() => setState(() => _showRxMain = !_showRxMain);

  String _formatSpeed(double speed) {
    if (speed >= 1000) return '${(speed / 1000).toStringAsFixed(1)} Gbps';
    if (speed >= 1) return '${speed.toStringAsFixed(1)} Mbps';
    return '${(speed * 1000).toStringAsFixed(0)} Kbps';
  }

  // ═══════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.black,
      appBar: _buildAppBar(),
      drawer: SideDrawer(routerService: _routerService),
      body: _buildBody(),
    );
  }

  // ═══════════════════════════════════════════
  // AppBar جديد
  // ═══════════════════════════════════════════
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppTheme.black,
      elevation: 0,
      automaticallyImplyLeading: false,
      leading: IconButton(
        icon: const Icon(Icons.settings_rounded, color: Colors.white, size: 24),
        onPressed: () => Navigator.pushNamed(context, '/settings'),
      ),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'ST_Manager',
            style: TextStyle(
              color: AppTheme.gold,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(width: 8),
          Icon(Icons.verified, color: AppTheme.gold, size: 22),
        ],
      ),
      centerTitle: true,
      actions: [
        Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu_rounded, color: Colors.white, size: 26),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  // ═══════════════════════════════════════════
  // Body
  // ═══════════════════════════════════════════
  Widget _buildBody() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildWelcomeBanner(),
          const SizedBox(height: 16),
          _buildBridgeSelector(),
          const SizedBox(height: 12),
          _buildBentoTitle(),
          const SizedBox(height: 12),
          _buildBentoGrid(),
          const SizedBox(height: 20),
          _buildSectionTitle('لوحة التحكم وإدارة العملاء'),
          const SizedBox(height: 12),
          _buildHorizontalCards(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════
  // Banner ترحيبي
  // ═══════════════════════════════════════════
  Widget _buildWelcomeBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF2A2400),
            const Color(0xFF1A1800),
            AppTheme.black,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppTheme.gold.withOpacity(0.25),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // أيقونة واي فاي
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: [
                  AppTheme.gold.withOpacity(0.3),
                  AppTheme.gold.withOpacity(0.05),
                ],
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.wifi_tethering_rounded,
              color: AppTheme.gold.withOpacity(0.9),
              size: 36,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'أهلاً بك في نظام ST_Manager الذكي',
                  style: TextStyle(
                    color: AppTheme.gold,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'الراوتر النشط : ${widget.routerData['name'] ?? 'ST_Manager'}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '«تحكم متكامل في راوتري ميكروتك بنقرة واحدة لتحقيق',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.55),
                    fontSize: 11,
                  ),
                ),
                Text(
                  'أفضل أداء لعملائك»',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.55),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════
  // Bridge Selector
  // ═══════════════════════════════════════════
  Widget _buildBridgeSelector() {
    return GestureDetector(
      onTap: _showInterfacePicker,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.gold.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppTheme.gold.withOpacity(0.25),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'منفذ ${_selectedInterface ?? '---'}',
              style: TextStyle(
                color: AppTheme.gold,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              Icons.swap_horiz_rounded,
              color: AppTheme.gold,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════
  // عنوان Bento
  // ═══════════════════════════════════════════
  Widget _buildBentoTitle() {
    return Text(
      'مؤشرات الأداء المباشرة (Bento)',
      style: TextStyle(
        color: Colors.white.withOpacity(0.9),
        fontSize: 16,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  // ═══════════════════════════════════════════
  // Bento Grid
  // ═══════════════════════════════════════════
  Widget _buildBentoGrid() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // الجانب الأيسر: 2x2 بطاقات صغيرة
        Expanded(
          flex: 5,
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildBentoSmallCard(
                      icon: Icons.bolt_rounded,
                      iconColor: AppTheme.gold,
                      value: '${_voltage.toStringAsFixed(1)}V',
                      label: 'سحب طاقة واط',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildBentoSmallCard(
                      icon: Icons.thermostat_rounded,
                      iconColor: Colors.redAccent,
                      value: '${_temperature.toStringAsFixed(1)}°',
                      label: 'حرارة المعالج',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildBentoSmallCard(
                      icon: Icons.speed_rounded,
                      iconColor: Colors.blueAccent,
                      value: _formatSpeed(_rxSpeed + _txSpeed),
                      label: 'السرعة الإجمالية',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildBentoSmallCard(
                      icon: Icons.memory_rounded,
                      iconColor: Colors.orangeAccent,
                      value: '${_cpuLoad.toStringAsFixed(0)}%',
                      label: 'استهلاك CPU',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        // الجانب الأيمن: بطاقة السرعة الكبيرة مع العداد الدائري
        Expanded(
          flex: 5,
          child: _buildSpeedGaugeCard(),
        ),
      ],
    );
  }

  Widget _buildBentoSmallCard({
    required IconData icon,
    required Color iconColor,
    required String value,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.06),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.45),
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════
  // عداد السرعة الدائري
  // ═══════════════════════════════════════════
  Widget _buildSpeedGaugeCard() {
    final speed = _showRxMain ? _rxSpeed : _txSpeed;
    final label = _showRxMain ? 'RX' : 'TX';
    final secondary = _showRxMain ? _txSpeed : _rxSpeed;
    final secondaryLabel = _showRxMain ? 'TX' : 'RX';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.06),
        ),
      ),
      child: Column(
        children: [
          Text(
            'سرعة السحب',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          // العداد الدائري
          GestureDetector(
            onTap: _toggleSpeedView,
            child: SizedBox(
              width: 110,
              height: 110,
              child: CustomPaint(
                painter: _GaugePainter(
                  value: speed,
                  maxValue: math.max(100, speed * 1.5),
                  color: AppTheme.gold,
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        speed >= 1 ? speed.toStringAsFixed(1) : (speed * 1000).toStringAsFixed(0),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        speed >= 1 ? 'Mbps' : 'Kbps',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.5),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          // الواجهة
          GestureDetector(
            onTap: _showInterfacePicker,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${_selectedInterface ?? '---'}',
                  style: TextStyle(
                    color: AppTheme.gold,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  ' | ${_formatSpeed(secondary)}',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Gigabit Fiber',
            style: TextStyle(
              color: Colors.white.withOpacity(0.35),
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════
  // عنوان القسم
  // ═══════════════════════════════════════════
  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        color: Colors.white.withOpacity(0.9),
        fontSize: 16,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  // ═══════════════════════════════════════════
  // البطاقات الأفقية
  // ═══════════════════════════════════════════
  Widget _buildHorizontalCards() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildHorizontalCard(
                titleAr: 'هوتسبوت',
                titleEn: 'Hotspot',
                subtitle: 'تعديل، تجميد وسرعات',
                icon: Icons.wifi_tethering_rounded,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => HotspotActiveUsersScreen(routerService: _routerService),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildHorizontalCard(
                titleAr: 'برودباند',
                titleEn: 'PPPoE',
                subtitle: 'جميع الحسابات والبروفايلات',
                icon: Icons.router_rounded,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PppActiveScreen(routerService: _routerService),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildHorizontalCard(
                titleAr: 'بطاقات',
                titleEn: '',
                subtitle: 'توليد كرت مستخدم فردي تعليق',
                icon: Icons.credit_card_rounded,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CardsScreen(routerService: _routerService),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildHorizontalCard(
                titleAr: 'نسخ/استعادة',
                titleEn: '',
                subtitle: 'طباعة و PDF تخصيص خط',
                icon: Icons.backup_rounded,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => BackupRestoreScreen(routerService: _routerService),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildHorizontalCard(
                titleAr: 'الأجهزة',
                titleEn: '',
                subtitle: 'إدارة الأجهزة المتصلة',
                icon: Icons.devices_rounded,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => DevicesScreen(routerService: _routerService),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildHorizontalCard(
                titleAr: 'الواجهات',
                titleEn: '',
                subtitle: 'إدارة واجهات الشبكة',
                icon: Icons.settings_ethernet_rounded,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => InterfaceScreen(routerService: _routerService),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildHorizontalCard(
                titleAr: 'قياس السرعة',
                titleEn: '',
                subtitle: 'اختيار الواجهة وعرض السرعة',
                icon: Icons.speed_rounded,
                onTap: _showInterfacePicker,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildHorizontalCard(
                titleAr: 'Simple Queue',
                titleEn: '',
                subtitle: 'إدارة قوائم التحكم',
                icon: Icons.queue_rounded,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SimpleQueueScreen(routerService: _routerService),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildHorizontalCard(
                titleAr: 'User Manager',
                titleEn: '',
                subtitle: 'إدارة المستخدمين',
                icon: Icons.manage_accounts_rounded,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => UserManagerScreen(routerService: _routerService),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            // بطاقة الموديل والأبتايم
            Expanded(
              child: _buildHorizontalCard(
                titleAr: _routerModel,
                titleEn: '',
                subtitle: 'Uptime: $_uptime',
                icon: Icons.router_rounded,
                onTap: () {},
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildHorizontalCard({
    required String titleAr,
    required String titleEn,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white.withOpacity(0.06),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // أيقونة
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppTheme.gold.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: AppTheme.gold,
                size: 24,
              ),
            ),
            const SizedBox(height: 14),
            // العنوان
            Row(
              children: [
                Text(
                  titleAr,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (titleEn.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  Text(
                    titleEn,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 6),
            // وصف
            Text(
              subtitle,
              style: TextStyle(
                color: Colors.white.withOpacity(0.4),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════
// Custom Painter للعداد الدائري
// ═══════════════════════════════════════════
class _GaugePainter extends CustomPainter {
  final double value;
  final double maxValue;
  final Color color;

  _GaugePainter({
    required this.value,
    required this.maxValue,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 6;
    final strokeWidth = 8.0;

    // الخلفية الرمادية
    final bgPaint = Paint()
      ..color = Colors.white.withOpacity(0.08)
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      math.pi * 0.75,
      math.pi * 1.5,
      false,
      bgPaint,
    );

    // القيمة
    final progress = math.min(value / maxValue, 1.0);
    final progressPaint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      math.pi * 0.75,
      math.pi * 1.5 * progress,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _GaugePainter oldDelegate) {
    return oldDelegate.value != value || oldDelegate.maxValue != maxValue;
  }
}
