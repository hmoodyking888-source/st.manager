import 'package:flutter/material.dart';
import 'package:st_manager/services/router_service.dart';
import 'package:st_manager/theme/app_theme.dart';

class InterfaceScreen extends StatefulWidget {
  final RouterService? routerService;
  const InterfaceScreen({super.key, required this.routerService});

  @override
  State<InterfaceScreen> createState() => _InterfaceScreenState();
}

class _InterfaceScreenState extends State<InterfaceScreen> {
  List<Map<String, dynamic>> _interfaces = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadInterfaces();
  }

  Future<void> _loadInterfaces() async {
    if (widget.routerService == null) return;
    setState(() => _loading = true);
    try {
      final data = await widget.routerService!.getInterfaceList();
      setState(() => _interfaces = data);
    } catch (_) {}
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الواجهات (Interfaces)')),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.gold))
          : ListView.builder(
              itemCount: _interfaces.length,
              itemBuilder: (_, i) {
                final iface = _interfaces[i];
                final name = iface['name'] ?? '';
                final running = iface['running'] == 'true';
                final speed = iface['speed'] ?? iface['rate'] ?? 'غير معروف';
                final rxByte = iface['rx-byte'] ?? '0';
                final txByte = iface['tx-byte'] ?? '0';
                return Card(
                  child: ListTile(
                    leading: Icon(
                      running ? Icons.check_circle : Icons.cancel,
                      color:
                          running ? AppTheme.greenOnline : AppTheme.redOffline,
                    ),
                    title:
                        Text(name, style: const TextStyle(color: Colors.white)),
                    subtitle: Text('السرعة: $speed',
                        style: const TextStyle(color: Colors.white54)),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('RX: ${_formatBytes(rxByte)}',
                            style: const TextStyle(
                                color: Colors.white54, fontSize: 10)),
                        Text('TX: ${_formatBytes(txByte)}',
                            style: const TextStyle(
                                color: Colors.white54, fontSize: 10)),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  String _formatBytes(String byteStr) {
    final bytes = int.tryParse(byteStr) ?? 0;
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024)
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}
