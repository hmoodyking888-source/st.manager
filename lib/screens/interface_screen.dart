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

  bool _isPortOrBridge(Map<String, dynamic> iface) {
    final name = iface['name']?.toString().toLowerCase().trim() ?? '';
    final type = iface['type']?.toString().toLowerCase().trim() ?? '';
    final actual =
        iface['actual-interface-type']?.toString().toLowerCase().trim() ?? '';

    bool matchAny(List<String> prefixes) {
      return prefixes.any(
        (p) => name.startsWith(p) || type.startsWith(p) || actual.startsWith(p),
      );
    }

    return matchAny(['ether', 'bridge', 'sfp', 'wlan', 'bond']);
  }

  Future<void> _loadInterfaces() async {
    if (widget.routerService == null) return;
    setState(() => _loading = true);
    try {
      final data = await widget.routerService!.getInterfaceList();
      final filtered = data.where(_isPortOrBridge).toList();
      if (mounted) {
        setState(() => _interfaces = filtered);
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  String _formatBytes(dynamic byteValue) {
    final bytes = int.tryParse(byteValue?.toString() ?? '0') ?? 0;
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return Scaffold(
      appBar: AppBar(title: const Text('الواجهات (Interfaces)')),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.gold))
          : RefreshIndicator(
              onRefresh: _loadInterfaces,
              child: ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: _interfaces.length,
                itemBuilder: (_, i) {
                  final iface = _interfaces[i];
                  final name = iface['name']?.toString() ?? '';
                  final running = iface['running']?.toString() == 'true';
                  final speed = iface['speed']?.toString() ??
                      iface['rate']?.toString() ??
                      'غير معروف';
                  final rxByte = iface['rx-byte'];
                  final txByte = iface['tx-byte'];

                  return Card(
                    child: ListTile(
                      leading: Icon(
                        running ? Icons.check_circle : Icons.cancel,
                        color: running
                            ? AppTheme.greenOnline
                            : AppTheme.redOffline,
                      ),
                      title: Text(
                        name,
                        style: TextStyle(color: onSurface),
                      ),
                      subtitle: Text(
                        'السرعة: $speed',
                        style: TextStyle(color: onSurface.withOpacity(0.65)),
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'RX: ${_formatBytes(rxByte)}',
                            style: TextStyle(
                              color: onSurface.withOpacity(0.85),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'TX: ${_formatBytes(txByte)}',
                            style: TextStyle(
                              color: onSurface.withOpacity(0.65),
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
