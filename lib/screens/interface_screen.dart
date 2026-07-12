import 'dart:async';
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
  String? _errorMessage;

  /// مؤقت لتحديث السرعات
  Timer? _trafficTimer;

  /// علم للتحقق مما إذا تم التخلص من الـ Widget
  bool _disposed = false;
  
  /// علم لمنع تداخل طلبات الـ API إذا تأخر الراوتر في الرد
  bool _isFetchingTraffic = false;

  /// خريطة لتخزين بيانات السرعة والاستهلاك لكل واجهة
  /// المفتاح: اسم الواجهة
  /// القيمة: {rxSpeed, txSpeed, totalRxBytes, totalTxBytes}
  final Map<String, Map<String, dynamic>> _trafficData = {};

  @override
  void initState() {
    super.initState();
    _loadInterfaces();
  }

  @override
  void dispose() {
    _disposed = true;
    _trafficTimer?.cancel();
    _trafficTimer = null;
    super.dispose();
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

  /// تحميل قائمة الواجهات والقراءات الأولية للاستهلاك الإجمالي
  Future<void> _loadInterfaces() async {
    if (widget.routerService == null) {
      if (mounted && !_disposed) {
        setState(() {
          _loading = false;
          _errorMessage = 'خدمة الراوتر غير متوفرة';
        });
      }
      return;
    }

    if (mounted && !_disposed) {
      setState(() {
        _loading = true;
        _errorMessage = null;
      });
    }

    try {
      // هذه الدالة تجلب أسماء الواجهات والاستهلاك الإجمالي (وقد تكون مُخزنة بالكاش)
      final data = await widget.routerService!.getInterfaceList();
      final filtered = data.where(_isPortOrBridge).toList();

      for (final iface in filtered) {
        final name = iface['name']?.toString() ?? '';
        if (name.isEmpty) continue;

        // دعم اختلاف التسميات بين إصدارات المايكروتك (مفرد/جمع)
        final rxBytes = int.tryParse(iface['rx-byte']?.toString() ?? iface['rx-bytes']?.toString() ?? '0') ?? 0;
        final txBytes = int.tryParse(iface['tx-byte']?.toString() ?? iface['tx-bytes']?.toString() ?? '0') ?? 0;

        // نحافظ على السرعة اللحظية إن كانت موجودة مسبقاً كي لا تصبح 0 أثناء تحديث الصفحة
        final currentRxSpeed = _trafficData[name]?['rxSpeed'] ?? 0;
        final currentTxSpeed = _trafficData[name]?['txSpeed'] ?? 0;

        _trafficData[name] = {
          'rxSpeed': currentRxSpeed,
          'txSpeed': currentTxSpeed,
          'totalRxBytes': rxBytes,
          'totalTxBytes': txBytes,
        };
      }

      if (mounted && !_disposed) {
        setState(() => _interfaces = filtered);
      }

      /// بدء مراقبة السرعة والتحديثات بعد تحميل الواجهات
      _startTrafficMonitoring();
    } catch (e) {
      if (mounted && !_disposed) {
        setState(() {
          _errorMessage = 'فشل تحميل الواجهات: ${e.toString()}';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_errorMessage!),
            backgroundColor: AppTheme.redOffline,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted && !_disposed) setState(() => _loading = false);
    }
  }

  /// بدء المراقبة عبر جدولة التحديثات بطريقة متسلسلة لمنع تراكم الطلبات
  void _startTrafficMonitoring() {
    _trafficTimer?.cancel();
    _scheduleNextTrafficUpdate(const Duration(seconds: 1));
  }

  /// جدولة الطلب القادم
  void _scheduleNextTrafficUpdate(Duration delay) {
    if (_disposed) return;
    
    _trafficTimer = Timer(delay, () async {
      if (_disposed) return;
      
      await _updateTrafficSpeeds();
      
      // التحديث كل 1.5 ثانية يعطي شعوراً بالسرعة ولا يرهق الراوتر بفضل الكاش الذي مدته 900ms
      _scheduleNextTrafficUpdate(const Duration(milliseconds: 1500));
    });
  }

  /// جلب السرعة اللحظية المباشرة للواجهات باستخدام getBulkTraffic
  Future<void> _updateTrafficSpeeds() async {
    if (widget.routerService == null || _disposed || _isFetchingTraffic) return;
    if (_interfaces.isEmpty) return;

    _isFetchingTraffic = true;

    try {
      // استخراج أسماء الواجهات النشطة
      final names = _interfaces.map((e) => e['name']?.toString() ?? '').where((n) => n.isNotEmpty).toList();

      // الاعتماد على الدالة المخصصة في RouterService التي تجلب السرعة جاهزة وبشكل متوازي
      final trafficResults = await widget.routerService!.getBulkTraffic(names);

      if (_disposed) return;

      for (final name in names) {
        final data = trafficResults[name];
        int rxSpeed = 0;
        int txSpeed = 0;

        // استخراج السرعات الجاهزة (bps)
        if (data != null) {
          rxSpeed = (data['rx-bits-per-second'] ?? 0).round();
          txSpeed = (data['tx-bits-per-second'] ?? 0).round();
        }

        // نحتفظ بالاستهلاك الإجمالي الذي جلبناه في _loadInterfaces
        final prev = _trafficData[name];
        final totalRx = prev?['totalRxBytes'] ?? 0;
        final totalTx = prev?['totalTxBytes'] ?? 0;

        _trafficData[name] = {
          'rxSpeed': rxSpeed,
          'txSpeed': txSpeed,
          'totalRxBytes': totalRx,
          'totalTxBytes': totalTx,
        };
      }

      // تحديث واجهة المستخدم بالسرعات الجديدة
      if (mounted && !_disposed) {
        setState(() {});
      }
    } catch (_) {
      /// نتجاهل أخطاء تحديث السرعة لعدم إزعاج المستخدم
    } finally {
      _isFetchingTraffic = false;
    }
  }

  /// تنسيق الاستهلاك الإجمالي (B / KB / MB / GB / TB)
  String _formatBytes(dynamic byteValue) {
    final bytes = int.tryParse(byteValue?.toString() ?? '0') ?? 0;
    if (bytes < 0) return '0 B';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    if (bytes < 1024 * 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
    return '${(bytes / (1024 * 1024 * 1024 * 1024)).toStringAsFixed(2)} TB';
  }

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return Scaffold(
      appBar: AppBar(title: const Text('الواجهات (Interfaces)')),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.gold))
          : _errorMessage != null && _interfaces.isEmpty
              ? _buildErrorView(onSurface)
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

                      /// بيانات السرعة والاستهلاك
                      final traffic = _trafficData[name];
                      final rxSpeed = traffic?['rxSpeed'] as int? ?? 0;
                      final txSpeed = traffic?['txSpeed'] as int? ?? 0;
                      final totalRx = traffic?['totalRxBytes'] as int? ?? 0;
                      final totalTx = traffic?['totalTxBytes'] as int? ?? 0;

                      return Card(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        child: ListTile(
                          key: ValueKey(name),
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
                            style: TextStyle(
                                color: onSurface.withValues(alpha: 0.65)),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              /// مربع السرعة والاستهلاك — واحد فقط يقلب بين TX و RX
                              _SpeedBox(
                                rxSpeed: rxSpeed,
                                txSpeed: txSpeed,
                                totalRx: _formatBytes(totalRx),
                                totalTx: _formatBytes(totalTx),
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

  Widget _buildErrorView(Color onSurface) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline,
              size: 48,
              color: AppTheme.redOffline.withValues(alpha: 0.7)),
          const SizedBox(height: 16),
          Text(
            _errorMessage!,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: onSurface.withValues(alpha: 0.7),
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _loadInterfaces,
            icon: const Icon(Icons.refresh),
            label: const Text('إعادة المحاولة'),
          ),
        ],
      ),
    );
  }
}

/// مربع السرعة — مربع واحد يقلب بين TX و RX عند الضغط
/// يعرض: اللabel (TX/RX) + السرعة اللحظية + الاستهلاك الإجمالي
class _SpeedBox extends StatefulWidget {
  final int rxSpeed;
  final int txSpeed;
  final String totalRx;
  final String totalTx;

  const _SpeedBox({
    super.key,
    required this.rxSpeed,
    required this.txSpeed,
    required this.totalRx,
    required this.totalTx,
  });

  @override
  State<_SpeedBox> createState() => _SpeedBoxState();
}

class _SpeedBoxState extends State<_SpeedBox> {
  /// هل نعرض TX أم RX؟ افتراضياً TX
  bool _showTx = true;

  void _toggle() {
    setState(() {
      _showTx = !_showTx;
    });
  }

  String _formatSpeed(int bps) {
    if (bps < 0) bps = 0;
    if (bps < 1000) return '${bps}bps';
    if (bps < 1000 * 1000) return '${(bps / 1000).toStringAsFixed(1)} Kbps';
    if (bps < 1000 * 1000 * 1000) {
      return '${(bps / (1000 * 1000)).toStringAsFixed(1)} Mbps';
    }
    return '${(bps / (1000 * 1000 * 1000)).toStringAsFixed(2)} Gbps';
  }

  @override
  Widget build(BuildContext context) {
    final label = _showTx ? 'TX' : 'RX';
    final speed = _showTx ? widget.txSpeed : widget.rxSpeed;
    final total = _showTx ? widget.totalTx : widget.totalRx;

    /// لون أخضر فاتح شبه شفاف يتغير حسب شدة السرعة
    final baseColor = Colors.green.shade400;
    final opacity = speed > 0
        ? 0.15 + (speed.clamp(0, 100000000) / 100000000) * 0.35
        : 0.08;

    return GestureDetector(
      onTap: _toggle,
      child: Tooltip(
        message: 'اضغط للتبديل | الإجمالي: $total',
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 80,
          height: 56,
          decoration: BoxDecoration(
            color: baseColor.withValues(alpha: opacity),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: baseColor.withValues(alpha: 0.4),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: baseColor.withValues(alpha: 0.15),
                blurRadius: 6,
                spreadRadius: 0.5,
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              /// TX / RX label
              Text(
                label,
                style: TextStyle(
                  color: Colors.green.shade700,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              /// السرعة اللحظية
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                transitionBuilder: (child, animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: child,
                  );
                },
                child: Text(
                  _formatSpeed(speed),
                  key: ValueKey<String>('${label}_${_formatSpeed(speed)}'),
                  style: TextStyle(
                    color: Colors.green.shade800,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
              const SizedBox(height: 1),
              /// الاستهلاك الإجمالي
              Text(
                total,
                style: TextStyle(
                  color: Colors.green.shade600,
                  fontSize: 9,
                  fontWeight: FontWeight.w500,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
