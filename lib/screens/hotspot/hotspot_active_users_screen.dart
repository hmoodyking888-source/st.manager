import 'package:flutter/material.dart';
import 'package:st_manager/services/router_service.dart';
import 'package:st_manager/screens/hotspot/hotspot_user_screen.dart';
import 'package:st_manager/theme/app_theme.dart';

class HotspotActiveUsersScreen extends StatefulWidget {
  final RouterService? routerService;
  const HotspotActiveUsersScreen({super.key, required this.routerService});

  @override
  State<HotspotActiveUsersScreen> createState() =>
      _HotspotActiveUsersScreenState();
}

class _HotspotActiveUsersScreenState extends State<HotspotActiveUsersScreen> {
  List<Map<String, dynamic>> _users = [];
  String _filter = 'all';
  String _searchQuery = '';
  String _sortBy = 'name';
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    if (widget.routerService == null) return;
    setState(() => _loading = true);
    try {
      final active = await widget.routerService!.getHotspotActive();
      final all = await widget.routerService!.getHotspotUsers();
      setState(() {
        _users = all.map((u) {
          final isActive = active.any((a) => a['user'] == u['name']);
          return {...u, 'active': isActive};
        }).toList();
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> get filtered {
    var list = _users.where((u) {
      if (_filter == 'active') return u['active'] == true;
      if (_filter == 'disabled') return u['disabled'] == 'true';
      if (_filter == 'expired') return u['disabled'] == 'true';
      return true;
    }).toList();

    if (_searchQuery.isNotEmpty) {
      list = list.where((u) {
        final name = (u['name'] ?? '').toString().toLowerCase();
        return name.contains(_searchQuery.toLowerCase());
      }).toList();
    }

    switch (_sortBy) {
      case 'uptime':
        list.sort((a, b) => (a['uptime'] ?? '').compareTo(b['uptime'] ?? ''));
        break;
      case 'usage':
        list.sort((a, b) {
          final aOut = int.tryParse(a['bytes-out']?.toString() ?? '0') ?? 0;
          final bOut = int.tryParse(b['bytes-out']?.toString() ?? '0') ?? 0;
          return bOut.compareTo(aOut);
        });
        break;
      case 'profile':
        list.sort((a, b) => (a['profile'] ?? '').compareTo(b['profile'] ?? ''));
        break;
      default:
        list.sort((a, b) => (a['name'] ?? '').compareTo(b['name'] ?? ''));
    }
    return list;
  }

  // ---------- دوال فتح السرعة ----------
  Future<void> _ensureSpeedProfile() async {
    try {
      await widget.routerService!
          .sendCommand('/ip/hotspot/user/profile/add', params: {
        'name': 'Speed',
        'rate-limit': '',
      });
    } catch (_) {}
  }

  Future<void> _boostUserSpeed(Map<String, dynamic> user) async {
    await _ensureSpeedProfile();
    await widget.routerService?.sendCommand('/ip/hotspot/user/set', params: {
      'numbers': user['.id']?.toString() ?? '',
      'profile': 'Speed',
    });
    if (user['active'] == true) {
      await widget.routerService
          ?.sendCommand('/ip/hotspot/active/remove', params: {
        'numbers': user['.id']?.toString() ?? '',
      });
    }
    _loadUsers();
  }

  void _showUserActions(Map<String, dynamic> user) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.semiBlack,
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.edit, color: AppTheme.gold),
              title: const Text('تعديل', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => HotspotUserScreen(
                            routerService: widget.routerService,
                            isEdit: true,
                            initialData: user)));
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('حذف', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                widget.routerService?.sendCommand('ip/hotspot/user/remove',
                    params: {'numbers': user['.id']?.toString() ?? ''});
                _loadUsers();
              },
            ),
            ListTile(
              leading: Icon(Icons.block,
                  color: user['disabled'] == 'true'
                      ? Colors.green
                      : Colors.orange),
              title: Text(user['disabled'] == 'true' ? 'تفعيل' : 'تعطيل',
                  style: const TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                final disable = user['disabled'] == 'true' ? 'no' : 'yes';
                widget.routerService?.sendCommand('ip/hotspot/user/set',
                    params: {
                      'numbers': user['.id']?.toString() ?? '',
                      'disabled': disable
                    });
                _loadUsers();
              },
            ),
            ListTile(
              leading: const Icon(Icons.speed, color: AppTheme.gold),
              title: const Text('فتح السرعة',
                  style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _boostUserSpeed(user);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _addNewAccount() {
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => HotspotUserScreen(
                  routerService: widget.routerService,
                  isEdit: false,
                ))).then((_) => _loadUsers());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('جميع حسابات الهوتسبوت')),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTheme.gold,
        onPressed: _addNewAccount,
        child: const Icon(Icons.person_add),
      ),
      body: Column(
        children: [
          if (_loading) const LinearProgressIndicator(color: AppTheme.gold),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                for (final entry in {
                  'all': 'الكل',
                  'active': 'متصل',
                  'disabled': 'معطل',
                  'expired': 'منتهي'
                }.entries)
                  ChoiceChip(
                    label:
                        Text(entry.value, style: const TextStyle(fontSize: 11)),
                    selected: _filter == entry.key,
                    onSelected: (v) => setState(() => _filter = entry.key),
                    selectedColor: AppTheme.gold,
                    backgroundColor: AppTheme.darkGrey,
                    labelStyle: TextStyle(
                        color: _filter == entry.key
                            ? Colors.black
                            : AppTheme.gold),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      hintText: 'بحث...',
                      prefixIcon: Icon(Icons.search, color: AppTheme.gold),
                      contentPadding: EdgeInsets.symmetric(vertical: 8),
                    ),
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    onChanged: (v) => setState(() => _searchQuery = v),
                  ),
                ),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  value: _sortBy,
                  dropdownColor: AppTheme.semiBlack,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                  underline: const SizedBox(),
                  items: [
                    ['name', 'الاسم'],
                    ['uptime', 'وقت التشغيل'],
                    ['usage', 'الأعلى سحب'],
                    ['profile', 'البروفايل'],
                  ]
                      .map((e) =>
                          DropdownMenuItem(value: e[0], child: Text(e[1])))
                      .toList(),
                  onChanged: (v) => setState(() => _sortBy = v!),
                ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadUsers,
              child: ListView.builder(
                itemCount: filtered.length,
                itemBuilder: (_, i) {
                  final u = filtered[i];
                  final isActive = u['active'] == true;
                  return Card(
                    margin:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    child: ListTile(
                      leading: Icon(
                        isActive ? Icons.person : Icons.person_off,
                        color: isActive ? AppTheme.greenOnline : Colors.grey,
                      ),
                      title: Text(u['name'] ?? '',
                          style: const TextStyle(color: Colors.white)),
                      subtitle: Text(
                        '${u['profile'] ?? ''} | ${u['uptime'] ?? ''}',
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 11),
                      ),
                      trailing: Text(
                        '${(int.tryParse(u['bytes-out']?.toString() ?? '0') ?? 0) ~/ 1024} KB/s',
                        style: TextStyle(
                            color: isActive ? AppTheme.gold : Colors.grey,
                            fontSize: 10),
                      ),
                      onTap: () => _showUserActions(u),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
