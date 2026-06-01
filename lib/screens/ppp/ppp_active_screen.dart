import 'package:flutter/material.dart';
import 'package:st_manager/services/router_service.dart';
import 'package:st_manager/theme/app_theme.dart';

class PppActiveScreen extends StatefulWidget {
  final RouterService? routerService;
  const PppActiveScreen({super.key, required this.routerService});

  @override
  State<PppActiveScreen> createState() => _PppActiveScreenState();
}

class _PppActiveScreenState extends State<PppActiveScreen> {
  List<Map<String, dynamic>> _secrets = [];
  List<Map<String, dynamic>> _active = [];
  String _searchQuery = '';
  String _sortBy = 'name';
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (widget.routerService == null) return;
    setState(() => _loading = true);
    try {
      final secrets = await widget.routerService!.getPppSecrets();
      final active = await widget.routerService!.getPppActive();
      setState(() {
        _secrets = secrets;
        _active = active;
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> get filtered {
    var list = _secrets.map((s) {
      final name = s['name']?.toString() ?? '';
      final activeEntry =
          _active.firstWhere((a) => a['name'] == name, orElse: () => {});
      final isActive = activeEntry.isNotEmpty;
      return {
        ...s,
        'active': isActive,
        'caller-id': activeEntry['caller-id'] ?? '',
        'uptime': activeEntry['uptime'] ?? '',
      };
    }).toList();

    if (_searchQuery.isNotEmpty) {
      list = list
          .where((u) => (u['name'] ?? '')
              .toString()
              .toLowerCase()
              .contains(_searchQuery.toLowerCase()))
          .toList();
    }

    switch (_sortBy) {
      case 'uptime':
        list.sort((a, b) => (a['uptime'] ?? '').compareTo(b['uptime'] ?? ''));
        break;
      default:
        list.sort((a, b) => (a['name'] ?? '').compareTo(b['name'] ?? ''));
    }
    return list;
  }

  void _showActions(Map<String, dynamic> user) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.semiBlack,
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
            if (user['active'] == true)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('قطع الاتصال',
                    style: TextStyle(color: Colors.white)),
                onTap: () async {
                  Navigator.pop(context);
                  await widget.routerService?.sendCommand('ppp/active/remove',
                      params: {'numbers': user['.id']?.toString() ?? ''});
                  _load();
                },
              ),
            ListTile(
              leading: const Icon(Icons.edit, color: AppTheme.gold),
              title: const Text('تعديل', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: Icon(Icons.block,
                  color: user['disabled'] == 'true'
                      ? Colors.green
                      : Colors.orange),
              title: Text(user['disabled'] == 'true' ? 'تفعيل' : 'تعطيل',
                  style: const TextStyle(color: Colors.white)),
              onTap: () async {
                Navigator.pop(context);
                final disable = user['disabled'] == 'true' ? 'no' : 'yes';
                await widget.routerService?.sendCommand('ppp/secret/set',
                    params: {
                      'numbers': user['.id']?.toString() ?? '',
                      'disabled': disable
                    });
                _load();
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
      appBar: AppBar(title: const Text('جميع حسابات البرودباند')),
      body: Column(
        children: [
          if (_loading) const LinearProgressIndicator(color: AppTheme.gold),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
              onRefresh: _load,
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
                        isActive ? 'متصل | ${u['uptime']}' : 'غير متصل',
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 11),
                      ),
                      trailing: isActive
                          ? Text(
                              '${(int.tryParse(u['bytes-out']?.toString() ?? '0') ?? 0) ~/ 1024} KB/s',
                              style: const TextStyle(
                                  color: AppTheme.gold, fontSize: 10),
                            )
                          : null,
                      onTap: () => _showActions(u),
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
