import 'package:flutter/material.dart';
import 'package:st_manager/services/router_service.dart';
import 'package:st_manager/theme/app_theme.dart';

class HotspotUsersScreen extends StatefulWidget {
  final RouterService? routerService;
  const HotspotUsersScreen({super.key, required this.routerService});

  @override
  State<HotspotUsersScreen> createState() => _HotspotUsersScreenState();
}

class _HotspotUsersScreenState extends State<HotspotUsersScreen> {
  List<Map<String, dynamic>> _users = [];
  String _filter = 'all'; // all, active, expired, unused

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    if (widget.routerService == null) return;
    try {
      final active =
          await widget.routerService!.sendCommand('/ip/hotspot/active/print');
      final allUsers =
          await widget.routerService!.sendCommand('/ip/hotspot/user/print');
      // دمج البيانات...
      setState(() {
        _users = allUsers.map((u) {
          final isActive = active.any((a) => a['user'] == u['name']);
          return {...u, 'active': isActive};
        }).toList();
      });
    } catch (_) {}
  }

  List<Map<String, dynamic>> get filteredUsers {
    switch (_filter) {
      case 'active':
        return _users.where((u) => u['active'] == true).toList();
      case 'expired':
        return _users.where((u) => u['disabled'] == 'true').toList(); // مثال
      case 'unused':
        return _users
            .where((u) => u['bytes-out'] == '0' && u['bytes-in'] == '0')
            .toList();
      default:
        return _users;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('مستخدمي الهوتسبوت')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: ['all', 'active', 'expired', 'unused'].map((f) {
                return ChoiceChip(
                  label: Text(f),
                  selected: _filter == f,
                  onSelected: (v) => setState(() => _filter = f),
                  selectedColor: AppTheme.gold,
                  backgroundColor: AppTheme.semiBlack,
                  labelStyle: TextStyle(
                      color: _filter == f ? Colors.black : AppTheme.gold),
                );
              }).toList(),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: filteredUsers.length,
              itemBuilder: (_, i) {
                final u = filteredUsers[i];
                return ListTile(
                  leading: Icon(
                    u['active'] == true ? Icons.person : Icons.person_off,
                    color: u['active'] == true
                        ? AppTheme.greenOnline
                        : Colors.grey,
                  ),
                  title: Text(u['name'] ?? '',
                      style: const TextStyle(color: Colors.white)),
                  subtitle: Text('${u['profile']} - ${u['uptime']}',
                      style: const TextStyle(color: Colors.white54)),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
