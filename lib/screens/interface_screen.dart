import 'package:flutter/material.dart';
import 'package:st_manager/services/router_service.dart';
import 'package:st_manager/theme/app_theme.dart';

/// شاشة عرض الواجهات (Interfaces) مع عداد سرعة TX/RX وبحث وتفاصيل
class InterfaceScreen extends StatefulWidget {
  final RouterService? routerService;
  const InterfaceScreen({super.key, required this.routerService});

  @override
  State<InterfaceScreen> createState() => _InterfaceScreenState();
}

class _InterfaceScreenState extends State<InterfaceScreen> {
  List<Map<String, dynamic>> _interfaces = [];
  List<Map<String, dynamic>> _filteredInterfaces = [];
  bool _loading = true;
  String? _errorMessage;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadInterfaces();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// التحقق مما إذا كانت الواجهة من نوع منفذ أو جسر
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

  /// تحميل قائمة الواجهات من الخدمة
  Future<void> _loadInterfaces() async {
    if (widget.routerService == null) {
      if (mounted) {
        setState(() {
          _loading = false;
          _errorMessage = 'خدمة الراوتر غير متوفرة';
        });
      }
      return;
    }

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final data = await widget.routerService!.getInterfaceList();
      final filtered = data.where(_isPortOrBridge).toList();
      if (mounted) {
        setState(() {
          _interfaces = filtered;
          _applySearch();
        });
      }
    } catch (e) {
      if (mounted) {
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
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  /// تنسيق البايتات إلى وحدات قابلة للقراءة
  String _formatBytes(dynamic byteValue) {
    final bytes = int.tryParse(byteValue?.toString() ?? '0') ?? 0;
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  /// تطبيق البحث على القائمة
  void _applySearch() {
    if (_searchQuery.isEmpty) {
      _filteredInterfaces = List.from(_interfaces);
    } else {
      final query = _searchQuery.toLowerCase();
      _filteredInterfaces = _interfaces.where((iface) {
        final name = iface['name']?.toString().toLowerCase() ?? '';
        final type = iface['type']?.toString().toLowerCase() ?? '';
        return name.contains(query) || type.contains(query);
      }).toList();
    }
  }

  /// تحديث نص البحث
  void _onSearchChanged(String value) {
    setState(() {
      _searchQuery = value;
      _applySearch();
    });
  }

  /// مسح البحث
  void _clearSearch() {
    _searchController.clear();
    _onSearchChanged('');
  }

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return Scaffold(
      appBar: AppBar(
        title: const Text('الواجهات (Interfaces)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'إعادة التحميل',
            onPressed: _loading ? null : _loadInterfaces,
          ),
        ],
      ),
      body: Column(
        children: [
          /// شريط البحث
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              textDirection: TextDirection.rtl,
              decoration: InputDecoration(
                hintText: 'ابحث عن واجهة...',
                hintTextDirection: TextDirection.rtl,
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: _clearSearch,
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
            ),
          ),

          /// عداد الواجهات
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                Icon(Icons.network_check,
                    color: onSurface.withValues(alpha: 0.6)),
                const SizedBox(width: 8),
                Text(
                  'عدد الواجهات: ${_filteredInterfaces.length}',
                  style: TextStyle(
                    color: onSurface.withValues(alpha: 0.7),
                    fontSize: 14,
                  ),
                ),
                const Spacer(),
                if (_loading)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.gold,
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          /// المحتوى الرئيسي
          Expanded(
            child: _buildBody(onSurface),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(Color onSurface) {
    if (_loading && _interfaces.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.gold),
      );
    }

    if (_errorMessage != null && _interfaces.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline,
                size: 48, color: AppTheme.redOffline.withValues(alpha: 0.7)),
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

    if (_filteredInterfaces.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off,
                size: 48, color: onSurface.withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isEmpty
                  ? 'لا توجد واجهات متاحة'
                  : 'لا توجد نتائج مطابقة للبحث',
              style: TextStyle(
                color: onSurface.withValues(alpha: 0.5),
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadInterfaces,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _filteredInterfaces.length,
        itemBuilder: (_, i) {
          final iface = _filteredInterfaces[i];
          return _InterfaceCard(
            key: ValueKey(iface['name']?.toString() ?? i),
            iface: iface,
            onSurface: onSurface,
            formatBytes: _formatBytes,
          );
        },
      ),
    );
  }
}

/// بطاقة واجهة فردية مع عداد سرعة TX/RX
class _InterfaceCard extends StatefulWidget {
  final Map<String, dynamic> iface;
  final Color onSurface;
  final String Function(dynamic) formatBytes;

  const _InterfaceCard({
    super.key,
    required this.iface,
    required this.onSurface,
    required this.formatBytes,
  });

  @override
  State<_InterfaceCard> createState() => _InterfaceCardState();
}

class _InterfaceCardState extends State<_InterfaceCard> {
  bool _showTx = false; // false = RX, true = TX

  @override
  Widget build(BuildContext context) {
    final iface = widget.iface;
    final name = iface['name']?.toString() ?? '';
    final running = iface['running']?.toString() == 'true';
    final speed = iface['speed']?.toString() ??
        iface['rate']?.toString() ??
        'غير معروف';
    final rxByte = iface['rx-byte'];
    final txByte = iface['tx-byte'];
    final type = iface['type']?.toString() ?? '';
    final actualType = iface['actual-interface-type']?.toString() ?? '';
    final macAddress = iface['mac-address']?.toString() ?? '';
    final mtu = iface['mtu']?.toString() ?? '';

    final currentValue = _showTx ? txByte : rxByte;
    final currentLabel = _showTx ? 'TX' : 'RX';
    final oppositeLabel = _showTx ? 'RX' : 'TX';
    final oppositeValue = _showTx ? rxByte : txByte;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      elevation: 2,
      child: ExpansionTile(
        leading: Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: running ? AppTheme.greenOnline : AppTheme.redOffline,
            boxShadow: [
              BoxShadow(
                color: (running ? AppTheme.greenOnline : AppTheme.redOffline)
                    .withValues(alpha: 0.4),
                blurRadius: 6,
                spreadRadius: 1,
              ),
            ],
          ),
        ),
        title: Text(
          name,
          style: TextStyle(
            color: widget.onSurface,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        subtitle: Text(
          '${running ? "متصل" : "غير متصل"} • السرعة: $speed',
          style: TextStyle(
            color: widget.onSurface.withValues(alpha: 0.65),
            fontSize: 12,
          ),
        ),
        children: [
          /// قسم عداد السرعة
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(
              children: [
                /// شريط التبديل RX/TX
                Container(
                  decoration: BoxDecoration(
                    color: widget.onSurface.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _ToggleButton(
                          label: 'RX',
                          isSelected: !_showTx,
                          onTap: () => setState(() => _showTx = false),
                          color: Colors.blue,
                        ),
                      ),
                      Expanded(
                        child: _ToggleButton(
                          label: 'TX',
                          isSelected: _showTx,
                          onTap: () => setState(() => _showTx = true),
                          color: Colors.orange,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                /// العداد الدائري
                _SpeedMeter(
                  value: currentValue,
                  label: currentLabel,
                  formattedValue: widget.formatBytes(currentValue),
                  color: _showTx ? Colors.orange : Colors.blue,
                ),

                const SizedBox(height: 8),

                /// عرض القيمة المقابلة بشكل ثانوي
                Text(
                  '$oppositeLabel: ${widget.formatBytes(oppositeValue)}',
                  style: TextStyle(
                    color: widget.onSurface.withValues(alpha: 0.5),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),

          /// التفاصيل الإضافية
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _DetailRow(label: 'النوع', value: type),
                if (actualType.isNotEmpty)
                  _DetailRow(label: 'النوع الفعلي', value: actualType),
                if (macAddress.isNotEmpty)
                  _DetailRow(label: 'عنوان MAC', value: macAddress),
                if (mtu.isNotEmpty) _DetailRow(label: 'MTU', value: mtu),
                _DetailRow(
                  label: 'الحالة',
                  value: running ? 'يعمل' : 'متوقف',
                  valueColor:
                      running ? AppTheme.greenOnline : AppTheme.redOffline,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// زر تبديل RX/TX
class _ToggleButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final Color color;

  const _ToggleButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: isSelected
              ? Border.all(color: color.withValues(alpha: 0.5), width: 1.5)
              : null,
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? color : Colors.grey,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}

/// عداد سرعة دائري
class _SpeedMeter extends StatelessWidget {
  final dynamic value;
  final String label;
  final String formattedValue;
  final Color color;

  const _SpeedMeter({
    required this.value,
    required this.label,
    required this.formattedValue,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final bytes = int.tryParse(value?.toString() ?? '0') ?? 0;
    // حساب النسبة المئوية للعداد (تقريبية)
    final maxBytes = 1024 * 1024 * 1024; // 1 GB كحد أقصى للعرض
    final progress = (bytes / maxBytes).clamp(0.0, 1.0);

    return Column(
      children: [
        SizedBox(
          width: 120,
          height: 120,
          child: Stack(
            alignment: Alignment.center,
            children: [
              /// الدائرة الخلفية
              CircularProgressIndicator(
                value: 1.0,
                strokeWidth: 10,
                color: Colors.grey.withValues(alpha: 0.15),
              ),
              /// الدائرة الأمامية المتحركة
              TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: progress),
                duration: const Duration(milliseconds: 800),
                curve: Curves.easeOutCubic,
                builder: (context, animatedProgress, child) {
                  return CircularProgressIndicator(
                    value: animatedProgress,
                    strokeWidth: 10,
                    strokeCap: StrokeCap.round,
                    color: color,
                    backgroundColor: Colors.transparent,
                  );
                },
              ),
              /// النص في المنتصف
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: color,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    formattedValue,
                    style: TextStyle(
                      color: color.withValues(alpha: 0.9),
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// صف تفاصيل
class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _DetailRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              fontSize: 13,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: valueColor ??
                  Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.9),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
