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
    switch (_filter) {
      case 'active':
        return _users.where((u) => u['active'] == true).toList();
      case 'disabled':
        return _users.where((u) => u['disabled'] == 'true').toList();
      case 'expired':
        return _users.where((u) => u['disabled'] == 'true').toList();
      default:
        return _users;
    }
  }

  Future<void> _executeCommand(
      String command, Map<String, String> params) async {
    if (widget.routerService == null) return;
    try {
      await widget.routerService!.sendCommand(command, params: params);
      _loadUsers();
    } catch (_) {}
  }

  void _showUserActions(Map<String, dynamic> user) {
    final name = user['name']?.toString() ?? '';
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
                      initialData: user,
                    ),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('حذف', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _executeCommand('/ip/hotspot/user/remove',
                    {'numbers': user['.id']?.toString() ?? ''});
              },
            ),
            ListTile(
              leading: const Icon(Icons.block, color: Colors.orange),
              title: Text(
                user['disabled'] == 'true' ? 'تفعيل' : 'تعطيل',
                style: const TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(context);
                final disable = user['disabled'] == 'true' ? 'no' : 'yes';
                _executeCommand('/ip/hotspot/user/set', {
                  'numbers': user['.id']?.toString() ?? '',
                  'disabled': disable
                });
              },
            ),
            ListTile(
              leading: const Icon(Icons.speed, color: AppTheme.gold),
              title: const Text('فتح السرعة',
                  style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _executeCommand('/queue/simple/remove', {'target': name});
              },
            ),
            ListTile(
              leading: const Icon(Icons.refresh, color: AppTheme.greenOnline),
              title: const Text('تجديد الصلاحية',
                  style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _executeCommand('/ip/hotspot/user/reset-counters',
                    {'numbers': user['.id']?.toString() ?? ''});
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('مستخدمي الهوتسبوت')),
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
                    label: Text(entry.value),
                    selected: _filter == entry.key,
                    onSelected: (v) => setState(() => _filter = entry.key),
                    selectedColor: AppTheme.gold,
                    backgroundColor: AppTheme.darkGrey,
                    labelStyle: TextStyle(
                      color:
                          _filter == entry.key ? Colors.black : AppTheme.gold,
                      fontWeight: _filter == entry.key
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
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
                        style: const TextStyle(color: Colors.white54),
                      ),
                      trailing: Text(
                        isActive ? 'متصل' : 'غير متصل',
                        style: TextStyle(
                            color:
                                isActive ? AppTheme.greenOnline : Colors.grey,
                            fontSize: 12),
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
