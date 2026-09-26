import 'package:flutter/material.dart';
import 'package:st_manager/services/router_service.dart';
import 'package:st_manager/theme/app_theme.dart';

class FirewallScreen extends StatefulWidget {
  final RouterService? routerService;
  const FirewallScreen({super.key, required this.routerService});

  @override
  State<FirewallScreen> createState() => _FirewallScreenState();
}

class _FirewallScreenState extends State<FirewallScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _loading = false;

  List<Map<String, dynamic>> _filterRules = [];
  List<Map<String, dynamic>> _mangleRules = [];
  List<Map<String, dynamic>> _natRules = [];
  List<Map<String, dynamic>> _interfaces = []; // لجلب المنافذ لدمج الخطوط

  // Sets to track selected items for multiple actions
  final Set<String> _selectedFilters = {};
  final Set<String> _selectedMangles = {};
  final Set<String> _selectedNats = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      setState(() {}); // To update FAB and Selection based on tab
    });
    _loadAllData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    if (widget.routerService == null) return;
    setState(() => _loading = true);

    try {
      final filters =
          await widget.routerService!.sendCommand('/ip/firewall/filter/print');
      final mangles =
          await widget.routerService!.sendCommand('/ip/firewall/mangle/print');
      final nats =
          await widget.routerService!.sendCommand('/ip/firewall/nat/print');
      final interfaces =
          await widget.routerService!.sendCommand('/interface/print');

      setState(() {
        _filterRules =
            filters != null ? List<Map<String, dynamic>>.from(filters) : [];
        _mangleRules =
            mangles != null ? List<Map<String, dynamic>>.from(mangles) : [];
        _natRules = nats != null ? List<Map<String, dynamic>>.from(nats) : [];
        _interfaces = interfaces != null
            ? List<Map<String, dynamic>>.from(interfaces)
            : [];

        // Clear selections after reload
        _selectedFilters.clear();
        _selectedMangles.clear();
        _selectedNats.clear();
      });
    } catch (_) {
      // Handle or ignore errors
    } finally {
      setState(() => _loading = false);
    }
  }

  String _getCurrentPath() {
    if (_tabController.index == 0) return '/ip/firewall/filter';
    if (_tabController.index == 1) return '/ip/firewall/mangle';
    return '/ip/firewall/nat';
  }

  Set<String> _getCurrentSelection() {
    if (_tabController.index == 0) return _selectedFilters;
    if (_tabController.index == 1) return _selectedMangles;
    return _selectedNats;
  }

  void _toggleSelection(String id) {
    setState(() {
      final selection = _getCurrentSelection();
      if (selection.contains(id)) {
        selection.remove(id);
      } else {
        selection.add(id);
      }
    });
  }

  Future<void> _performActionOnSelected(String actionCommand) async {
    final selection = _getCurrentSelection();
    if (selection.isEmpty || widget.routerService == null) return;

    final path = _getCurrentPath();
    final ids = selection.join(',');

    setState(() => _loading = true);
    try {
      await widget.routerService!
          .sendCommand('$path/$actionCommand', params: {'numbers': ids});
      await _loadAllData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('حدث خطأ أثناء تنفيذ العملية: $e')));
      }
      setState(() => _loading = false);
    }
  }

  // ==========================================
  // 1. إنشاء Fasttrack
  // ==========================================
  Future<void> _createFasttrack() async {
    Navigator.pop(context); // Close bottom sheet
    if (widget.routerService == null) return;
    setState(() => _loading = true);

    try {
      final existingFilters = _filterRules;
      bool exists = false;
      String existingId = '';

      for (var rule in existingFilters) {
        if (rule['action'] == 'fasttrack-connection') {
          exists = true;
          existingId = rule['.id']?.toString() ?? '';
          break;
        }
      }

      if (exists && existingId.isNotEmpty) {
        await widget.routerService!.sendCommand('/ip/firewall/filter/enable',
            params: {'numbers': existingId});
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('قاعدة Fasttrack موجودة بالفعل، تم تفعيلها.')));
        }
      } else {
        await widget.routerService!
            .sendCommand('/ip/firewall/filter/add', params: {
          'chain': 'forward',
          'action': 'fasttrack-connection',
          'connection-state': 'established,related',
          'comment': 'Auto Fasttrack - App',
        });
        await widget.routerService!
            .sendCommand('/ip/firewall/filter/add', params: {
          'chain': 'forward',
          'action': 'accept',
          'connection-state': 'established,related',
          'comment': 'Auto Accept Fasttrack - App',
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('تم إنشاء وتفعيل Fasttrack بنجاح.')));
        }
      }
      await _loadAllData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('فشل إعداد Fasttrack: $e')));
      }
      setState(() => _loading = false);
    }
  }

  // ==========================================
  // 2. إنشاء قواعد حماية الشبكة الأساسية (Security Rules)
  // ==========================================
  Future<void> _createSecurityRules() async {
    Navigator.pop(context);
    if (widget.routerService == null) return;
    setState(() => _loading = true);

    try {
      // إسقاط الاتصالات غير الصالحة
      await widget.routerService!
          .sendCommand('/ip/firewall/filter/add', params: {
        'chain': 'input',
        'action': 'drop',
        'connection-state': 'invalid',
        'comment': 'Drop Invalid Connections',
      });
      // حماية سيرفر DNS من الخارج
      await widget.routerService!
          .sendCommand('/ip/firewall/filter/add', params: {
        'chain': 'input',
        'action': 'drop',
        'protocol': 'udp',
        'dst-port': '53',
        'in-interface': 'ether1', // منفذ افتراضي للإنترنت
        'comment': 'Drop DNS from outside',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('تم إضافة قواعد الحماية الأساسية بنجاح.')));
      }
      await _loadAllData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('فشل إعداد قواعد الحماية: $e')));
      }
      setState(() => _loading = false);
    }
  }

  // ==========================================
  // 3. إنشاء دمج الخطوط (Load Balancing PCC)
  // ==========================================
  void _showLoadBalancingDialog() {
    Navigator.pop(context); // إغلاق القائمة السفلية
    String? wan1;
    String? wan2;
    String? lan;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: AppTheme.semiBlack,
            title: const Text('إعداد دمج الخطوط (PCC)',
                style: TextStyle(color: Colors.white)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'اختر المنافذ لإنشاء رولات Mangle لدمج خطين.',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  const SizedBox(height: 15),
                  // إختيار WAN 1
                  DropdownButtonFormField<String>(
                    dropdownColor: AppTheme.semiBlack,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'خط الإنترنت الأول (WAN 1)',
                      labelStyle: TextStyle(color: Colors.white54),
                    ),
                    items: _interfaces.map((i) {
                      final name = i['name'].toString();
                      return DropdownMenuItem(value: name, child: Text(name));
                    }).toList(),
                    onChanged: (val) => setDialogState(() => wan1 = val),
                  ),
                  // إختيار WAN 2
                  DropdownButtonFormField<String>(
                    dropdownColor: AppTheme.semiBlack,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'خط الإنترنت الثاني (WAN 2)',
                      labelStyle: TextStyle(color: Colors.white54),
                    ),
                    items: _interfaces.map((i) {
                      final name = i['name'].toString();
                      return DropdownMenuItem(value: name, child: Text(name));
                    }).toList(),
                    onChanged: (val) => setDialogState(() => wan2 = val),
                  ),
                  // إختيار LAN
                  DropdownButtonFormField<String>(
                    dropdownColor: AppTheme.semiBlack,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'منفذ الخروج للشبكة (LAN)',
                      labelStyle: TextStyle(color: Colors.white54),
                    ),
                    items: _interfaces.map((i) {
                      final name = i['name'].toString();
                      return DropdownMenuItem(value: name, child: Text(name));
                    }).toList(),
                    onChanged: (val) => setDialogState(() => lan = val),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('إلغاء',
                    style: TextStyle(color: Colors.white54)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.gold),
                onPressed: () {
                  if (wan1 != null && wan2 != null && lan != null) {
                    Navigator.pop(ctx);
                    _executeLoadBalancing(wan1!, wan2!, lan!);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('يرجى اختيار جميع المنافذ.')));
                  }
                },
                child: const Text('إنشاء الدمج',
                    style: TextStyle(color: Colors.black)),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _executeLoadBalancing(
      String wan1, String wan2, String lan) async {
    if (widget.routerService == null) return;
    setState(() => _loading = true);

    try {
      // 1. Accept LAN
      await widget.routerService!
          .sendCommand('/ip/firewall/mangle/add', params: {
        'chain': 'prerouting',
        'in-interface': lan,
        'action': 'accept',
        'comment': 'PCC - Accept LAN',
      });

      // 2. Mark Connections WAN 1
      await widget.routerService!
          .sendCommand('/ip/firewall/mangle/add', params: {
        'chain': 'prerouting',
        'in-interface': wan1,
        'connection-mark': 'no-mark',
        'action': 'mark-connection',
        'new-connection-mark': 'WAN1_conn',
        'comment': 'PCC - Mark Conn WAN1',
      });
      // 3. Mark Connections WAN 2
      await widget.routerService!
          .sendCommand('/ip/firewall/mangle/add', params: {
        'chain': 'prerouting',
        'in-interface': wan2,
        'connection-mark': 'no-mark',
        'action': 'mark-connection',
        'new-connection-mark': 'WAN2_conn',
        'comment': 'PCC - Mark Conn WAN2',
      });

      // 4. PCC 2/0 (WAN1)
      await widget.routerService!
          .sendCommand('/ip/firewall/mangle/add', params: {
        'chain': 'prerouting',
        'in-interface': lan,
        'connection-mark': 'no-mark',
        'per-connection-classifier': 'both-addresses:2/0',
        'action': 'mark-connection',
        'new-connection-mark': 'WAN1_conn',
        'comment': 'PCC - PCC 2/0',
      });
      // 5. PCC 2/1 (WAN2)
      await widget.routerService!
          .sendCommand('/ip/firewall/mangle/add', params: {
        'chain': 'prerouting',
        'in-interface': lan,
        'connection-mark': 'no-mark',
        'per-connection-classifier': 'both-addresses:2/1',
        'action': 'mark-connection',
        'new-connection-mark': 'WAN2_conn',
        'comment': 'PCC - PCC 2/1',
      });

      // 6. Mark Routing WAN1
      await widget.routerService!
          .sendCommand('/ip/firewall/mangle/add', params: {
        'chain': 'prerouting',
        'in-interface': lan,
        'connection-mark': 'WAN1_conn',
        'action': 'mark-routing',
        'new-routing-mark': 'to_WAN1',
      });
      // 7. Mark Routing WAN2
      await widget.routerService!
          .sendCommand('/ip/firewall/mangle/add', params: {
        'chain': 'prerouting',
        'in-interface': lan,
        'connection-mark': 'WAN2_conn',
        'action': 'mark-routing',
        'new-routing-mark': 'to_WAN2',
      });

      // 8. Output WAN1
      await widget.routerService!
          .sendCommand('/ip/firewall/mangle/add', params: {
        'chain': 'output',
        'connection-mark': 'WAN1_conn',
        'action': 'mark-routing',
        'new-routing-mark': 'to_WAN1',
      });
      // 9. Output WAN2
      await widget.routerService!
          .sendCommand('/ip/firewall/mangle/add', params: {
        'chain': 'output',
        'connection-mark': 'WAN2_conn',
        'action': 'mark-routing',
        'new-routing-mark': 'to_WAN2',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'تم إنشاء رولات دمج الخطوط بنجاح (يرجى مراجعة الـ Routes).')));
      }
      await _loadAllData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('فشل إعداد دمج الخطوط: $e')));
      }
      setState(() => _loading = false);
    }
  }

  // ==========================================
  // قائمة الخيارات السريعة السفلية
  // ==========================================
  void _showQuickActionsMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.semiBlack,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('إضافات سريعة للجدار الناري',
                  style: TextStyle(
                      color: AppTheme.gold,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 15),
              ListTile(
                leading: const Icon(Icons.flash_on, color: Colors.orangeAccent),
                title: const Text('تفعيل Fasttrack',
                    style: TextStyle(color: Colors.white)),
                subtitle: const Text(
                    'لتسريع معالجة البيانات وتخفيف الحمل على المعالج.',
                    style: TextStyle(color: Colors.white54, fontSize: 12)),
                onTap: _createFasttrack,
              ),
              const Divider(color: Colors.white12),
              ListTile(
                leading: const Icon(Icons.security, color: Colors.greenAccent),
                title: const Text('رولات الحماية الأساسية',
                    style: TextStyle(color: Colors.white)),
                subtitle: const Text(
                    'إسقاط الاتصالات غير الصالحة ومنع استغلال الـ DNS.',
                    style: TextStyle(color: Colors.white54, fontSize: 12)),
                onTap: _createSecurityRules,
              ),
              const Divider(color: Colors.white12),
              ListTile(
                leading: const Icon(Icons.call_split, color: Colors.blueAccent),
                title: const Text('إعداد دمج خطين (Load Balancing PCC)',
                    style: TextStyle(color: Colors.white)),
                subtitle: const Text('توزيع الحمل بين خطين إنترنت متساويين.',
                    style: TextStyle(color: Colors.white54, fontSize: 12)),
                onTap: _showLoadBalancingDialog,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildList(List<Map<String, dynamic>> items, Set<String> selection) {
    if (items.isEmpty) {
      return const Center(
          child: Text('لا توجد قواعد هنا',
              style: TextStyle(color: Colors.white54)));
    }
    return ListView.builder(
      itemCount: items.length,
      padding: const EdgeInsets.only(bottom: 80),
      itemBuilder: (context, index) {
        final item = items[index];
        final id = item['.id']?.toString() ?? '';
        final disabled = item['disabled'] == 'true';
        final isSelected = selection.contains(id);

        final chain = item['chain'] ?? 'غير معروف';
        final action = item['action'] ?? 'غير معروف';
        final comment = item['comment'] ?? '';

        return Card(
          color:
              isSelected ? AppTheme.gold.withOpacity(0.2) : AppTheme.semiBlack,
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: ListTile(
            leading: Checkbox(
              value: isSelected,
              activeColor: AppTheme.gold,
              onChanged: (val) => _toggleSelection(id),
            ),
            title: Text(
              '$chain  ➜  $action',
              style: TextStyle(
                color: disabled ? Colors.grey : Colors.white,
                fontWeight: FontWeight.bold,
                decoration: disabled ? TextDecoration.lineThrough : null,
              ),
            ),
            subtitle: comment.isNotEmpty
                ? Text('ملاحظة: $comment',
                    style: const TextStyle(color: Colors.white70))
                : null,
            trailing: Icon(
              disabled ? Icons.pause_circle_filled : Icons.check_circle,
              color: disabled ? Colors.redAccent : Colors.greenAccent,
            ),
            onTap: () => _toggleSelection(id),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasSelection = _getCurrentSelection().isNotEmpty;

    return Scaffold(
      backgroundColor: AppTheme.black,
      appBar: AppBar(
        title: const Text('إدارة الجدار الناري (Firewall)'),
        backgroundColor: AppTheme.semiBlack,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline, color: AppTheme.gold),
            tooltip: 'إضافات سريعة',
            onPressed: _showQuickActionsMenu,
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadAllData,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.gold,
          labelColor: AppTheme.gold,
          unselectedLabelColor: Colors.white54,
          tabs: const [
            Tab(text: 'Filter Rules'),
            Tab(text: 'Mangle'),
            Tab(text: 'NAT'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.gold))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildList(_filterRules, _selectedFilters),
                _buildList(_mangleRules, _selectedMangles),
                _buildList(_natRules, _selectedNats),
              ],
            ),
      floatingActionButton: hasSelection
          ? Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                FloatingActionButton(
                  heroTag: 'btn_enable',
                  backgroundColor: Colors.green,
                  onPressed: () => _performActionOnSelected('enable'),
                  child: const Icon(Icons.play_arrow, color: Colors.white),
                ),
                const SizedBox(width: 10),
                FloatingActionButton(
                  heroTag: 'btn_disable',
                  backgroundColor: Colors.orange,
                  onPressed: () => _performActionOnSelected('disable'),
                  child: const Icon(Icons.pause, color: Colors.white),
                ),
                const SizedBox(width: 10),
                FloatingActionButton(
                  heroTag: 'btn_delete',
                  backgroundColor: Colors.red,
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: AppTheme.semiBlack,
                        title: const Text('تأكيد الحذف',
                            style: TextStyle(color: Colors.white)),
                        content: const Text(
                            'هل أنت متأكد من حذف العناصر المحددة؟',
                            style: TextStyle(color: Colors.white70)),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('إلغاء',
                                style: TextStyle(color: Colors.white54)),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.pop(ctx);
                              _performActionOnSelected('remove');
                            },
                            child: const Text('حذف',
                                style: TextStyle(color: Colors.red)),
                          ),
                        ],
                      ),
                    );
                  },
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
              ],
            )
          : null,
    );
  }
}
