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
  List<Map<String, dynamic>> _active = [];
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
      final data = await widget.routerService!.getPppActive();
      setState(() => _active = data);
    } catch (_) {}
    setState(() => _loading = false);
  }

  void _showActions(Map<String, dynamic> user) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.semiBlack,
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('قطع الاتصال',
                  style: TextStyle(color: Colors.white)),
              onTap: () async {
                Navigator.pop(context);
                await widget.routerService
                    ?.sendCommand('/ppp/active/remove', params: {
                  'numbers': user['.id']?.toString() ?? '',
                });
                _load();
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit, color: AppTheme.gold),
              title: const Text('تعديل', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                // الانتقال إلى تعديل المستخدم
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
      appBar: AppBar(title: const Text('متصلو البرودباند')),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.gold))
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.builder(
                itemCount: _active.length,
                itemBuilder: (_, i) {
                  final u = _active[i];
                  return ListTile(
                    leading: const Icon(Icons.person, color: AppTheme.gold),
                    title: Text(u['name'] ?? '',
                        style: const TextStyle(color: Colors.white)),
                    subtitle: Text(u['caller-id'] ?? u['address'] ?? '',
                        style: const TextStyle(color: Colors.white54)),
                    trailing: Text(u['uptime'] ?? '',
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 12)),
                    onTap: () => _showActions(u),
                  );
                },
              ),
            ),
    );
  }
}
