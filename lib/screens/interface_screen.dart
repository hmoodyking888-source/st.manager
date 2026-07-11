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
  /// القيمة: {rxSpeed, txSpeed, lastRxBytes, lastTxBytes, lastTime, totalRxBytes, totalTxBytes}
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

  /// تحميل قائمة الواجهات والقراءات الأولية
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
      final data = await widget.routerService!.getInterfaceList();
      final filtered = data.where(_isPortOrBridge).toList();
      final now = DateTime.now();

      // تسجيل القراءات الأولية للعدادات لتجنب السرعة 0 في الثواني الأولى
      for (final iface in data) {
        final name = iface['name']?.toString() ?? '';
        if (name.isEmpty) continue;

        // دعم اختلاف التسميات بين إصدارات المايكروتك (مفرد/جمع)
        final rxBytes = int.tryParse(iface['rx-byte']?.toString() ?? iface['rx-bytes']?.toString() ?? '0') ?? 0;
        final txBytes = int.tryParse(iface['tx-byte']?.toString() ?? iface['tx-bytes']?.toString() ?? '0') ?? 0;

        _trafficData[name] = {
          'rxSpeed': 0,
          'txSpeed': 0,
          'lastRxBytes': rxBytes,
          'lastTxBytes': txBytes,
          'lastTime': now,
          'totalRxBytes': rxBytes,
          'totalTxBytes': txBytes,
        };
      }

      if (mounted && !_disposed) {
        setState(() => _interfaces = filtered);
      }

      /// بدء مراقبة السرعة والتحديثات
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

  /// جدولة الطلب القادم بذكاء
  void _scheduleNextTrafficUpdate(Duration delay) {
    if (_disposed) return;
    
    _trafficTimer = Timer(delay, () async {
      if (_disposed) return;
      
      await _updateTrafficSpeeds();
      
      // جدولة النبضة القادمة بعد 3 ثوانٍ من انتهاء الطلب الحالي
      _scheduleNextTrafficUpdate(const Duration(seconds: 3));
    });
  }

  /// حساب السرعة لكل واجهة وتحديث القائمة والاستهلاك الإجمالي
  Future<void> _updateTrafficSpeeds() async {
    if (widget.routerService == null || _disposed || _isFetchingTraffic) return;

    _isFetchingTraffic = true;

    try {
      final data = await widget.routerService!.getInterfaceList();
      final now = DateTime.now();

      if (_disposed) return;

      final filtered = data.where(_isPortOrBridge).toList();

      for (final iface in data) {
        final name = iface['name']?.toString() ?? '';
        if (name.isEmpty) continue;

        final rxBytes = int.tryParse(iface['rx-byte']?.toString() ?? iface['rx-bytes']?.toString() ?? '0') ?? 0;
        final txBytes = int.tryParse(iface['tx-byte']?.toString() ?? iface['tx-bytes']?.toString() ?? '0') ?? 0;

        final prev = _trafficData[name];
        
        int rxSpeed = 0;
        int txSpeed = 0;

        if (prev != null) {
          final prevRx = prev['lastRxBytes'] as int;
          final prevTx = prev['lastTxBytes'] as int;
          final prevTime = prev['lastTime'] as DateTime;

          final durationSec = now.difference(prevTime).inMilliseconds / 1000.0;

          if (durationSec > 0) {
            int rxDiff = rxBytes - prevRx;
            int txDiff = txBytes - prevTx;

            // معالجة حالة إعادة التشغيل أو تصفير العداد في الراوتر
            if (rxDiff < 0) rxDiff = rxBytes;
            if (txDiff < 0) txDiff = txBytes;

            /// السرعة بالبت في الثانية (bps)
            rxSpeed = (rxDiff * 8 / durationSec).round();
            txSpeed = (txDiff * 8 / durationSec).round();
          }
        }

        _trafficData[name] = {
          'rxSpeed': rxSpeed,
          'txSpeed': txSpeed,
          'lastRxBytes': rxBytes,
          'lastTxBytes': txBytes,
          'lastTime': now,
          'totalRxBytes': rxBytes,
          'totalTxBytes': txBytes,
        };
      }

      // تحديث قائمة الواجهات (لتحديث حالة الاتصال وسرعة المنفذ) مع القراءات الجديدة
      if (mounted && !_disposed) {
        setState(() {
          _interfaces = filtered;
        });
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

                      /// بيانات السرعة والاستهلاك المحسوبة
                      final traffic = _trafficData[name];
                      final rxSpeed = traffic?['rxSpeed'] as int? ?? 0;
                      final txSpeed = traffic?['txSpeed'] as int? ?? 0;
                      
                      // استخدم الاستهلاك من trafficData ليكون محدثاً دائماً
                      final totalRx = traffic?['totalRxBytes'] as int? ??
                          (int.tryParse(iface['rx-byte']?.toString() ?? iface['rx-bytes']?.toString() ?? '0') ?? 0);
                      final totalTx = traffic?['totalTxBytes'] as int? ??
                          (int.tryParse(iface['tx-byte']?.toString() ?? iface['tx-bytes']?.toString() ?? '0') ?? 0);

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
