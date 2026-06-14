import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:st_manager/screens/ppp/ppp_user_screen.dart';
import 'package:st_manager/services/router_service.dart';
import 'package:st_manager/services/secure_storage_service.dart';
import 'package:st_manager/theme/app_theme.dart';
import 'package:url_launcher/url_launcher.dart';

class _CommentData {
  final String phone;
  final String note;
  final DateTime? expiryDate;
  final bool isPaid;
  const _CommentData({
    required this.phone,
    required this.note,
    required this.expiryDate,
    this.isPaid = false,
  });
}

class PppActiveScreen extends StatefulWidget {
  final RouterService? routerService;
  const PppActiveScreen({super.key, required this.routerService});

  @override
  State<PppActiveScreen> createState() => _PppActiveScreenState();
}

class _PppActiveScreenState extends State<PppActiveScreen> {
  static const String _expiredProfileName = 'Xpirer';
  static const String _expiredRateLimit = '512K/512K';
  static const String _expirationCheckKey = 'ppp_last_expiration_check';

  final SecureStorageService _storage = SecureStorageService();

  List<Map<String, dynamic>> _secrets = [];
  List<Map<String, dynamic>> _active = [];

  String _searchQuery = '';
  String _sortBy = 'status';
  String _filter = 'all';
  bool _loading = false;
  bool _showRxFirst = true;

  String? _lastExpirationCheckIso;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    _lastExpirationCheckIso = await _storage.read(_expirationCheckKey);
    await _load(initial: true);
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _load(), // تم الإصلاح هنا بإضافة المعامل الـ _ الخاص بالـ Timer
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  String _normalizeText(dynamic value) {
    return value?.toString().trim() ?? '';
  }

  bool _isDisabled(Map<String, dynamic> user) {
    final raw = user['disabled'];
    if (raw == null) return false;
    final value = raw.toString().toLowerCase().trim();
    return value == 'true' || value == 'yes' || value == '1';
  }

  bool _isExpired(DateTime? expiryDate) {
    if (expiryDate == null) return false;
    final endOfDay = DateTime(
      expiryDate.year,
      expiryDate.month,
      expiryDate.day,
      23,
      59,
      59,
    );
    return DateTime.now().isAfter(endOfDay);
  }

  String _dateOnlyString(DateTime date) {
    return DateFormat('yyyy-MM-dd').format(date);
  }

  _CommentData _parseComment(String raw) {
    if (raw.trim().isEmpty) {
      return const _CommentData(
          phone: '', note: '', expiryDate: null, isPaid: false);
    }

    String phone = '';
    DateTime? expiryDate;
    bool isPaid = false;
    final notes = <String>[];

    for (final part in raw.split('|')) {
      final token = part.trim();
      if (token.isEmpty) continue;

      if (token.toLowerCase().startsWith('phone:')) {
        phone = token.substring(6).trim();
        continue;
      }

      if (token.toLowerCase().startsWith('exp:')) {
        final rawDate = token.substring(4).trim();
        final parsed = DateTime.tryParse(rawDate);
        if (parsed != null) {
          expiryDate = parsed;
        }
        continue;
      }

      if (token.toLowerCase().startsWith('paid:')) {
        isPaid = token.substring(5).trim().toLowerCase() == 'true';
        continue;
      }

      notes.add(token);
    }

    return _CommentData(
      phone: phone,
      note: notes.join(' | '),
      expiryDate: expiryDate,
      isPaid: isPaid,
    );
  }

  String _formatSpeed(double speedMbps) {
    if (speedMbps >= 1000) {
      return '${(speedMbps / 1000).toStringAsFixed(1)} Gbps';
    }
    if (speedMbps >= 1) {
      return '${speedMbps.toStringAsFixed(1)} Mbps';
    }
    if (speedMbps > 0) {
      return '${(speedMbps * 1000).toStringAsFixed(0)} Kbps';
    }
    return '0';
  }

  String _sessionKey(Map<String, dynamic> item) {
    final id = _normalizeText(item['.id']);
    if (id.isNotEmpty) return id;

    final name = _normalizeText(item['name']);
    if (name.isNotEmpty) return name;

    final user = _normalizeText(item['user']);
    if (user.isNotEmpty) return user;

    final username = _normalizeText(item['username']);
    if (username.isNotEmpty) return username;

    final caller = _normalizeText(item['caller-id']);
    if (caller.isNotEmpty) return caller;

    final address = _normalizeText(item['address']);
    if (address.isNotEmpty) return address;

    return 'session-${item.hashCode}';
  }

  List<String> _candidateKeys(Map<String, dynamic> item) {
    final keys = <String>[
      _normalizeText(item['name']),
      _normalizeText(item['user']),
      _normalizeText(item['username']),
      _normalizeText(item['caller-id']),
      _normalizeText(item['address']),
      _normalizeText(item['service']),
    ].where((e) => e.isNotEmpty).toList();

    return keys.map((e) => e.toLowerCase()).toSet().toList(growable: false);
  }

  Map<String, Map<String, dynamic>> _buildActiveBySession(
    List<Map<String, dynamic>> active,
  ) {
    final map = <String, Map<String, dynamic>>{};
    for (final a in active) {
      map[_sessionKey(a)] = a;
    }
    return map;
  }

  String? _matchActiveSessionKey(
    Map<String, dynamic> secret,
    Map<String, Map<String, dynamic>> activeBySession,
  ) {
    final secretKeys = _candidateKeys(secret);

    for (final entry in activeBySession.entries) {
      final activeKeys = _candidateKeys(entry.value);
      for (final key in secretKeys) {
        if (activeKeys.contains(key)) {
          return entry.key;
        }
      }
    }

    return null;
  }

  Future<bool> _shouldRunExpirationCheck() async {
    final now = DateTime.now();
    final todayAtNoon = DateTime(now.year, now.month, now.day, 12);

    if (now.isBefore(todayAtNoon)) {
      return false;
    }

    if (_lastExpirationCheckIso != null) {
      final last = DateTime.tryParse(_lastExpirationCheckIso!);
      if (last != null &&
          last.year == now.year &&
          last.month == now.month &&
          last.day == now.day) {
        return false;
      }
    }

    _lastExpirationCheckIso = now.toIso8601String();
    await _storage.write(_expirationCheckKey, _lastExpirationCheckIso!);
    return true;
  }

  Future<void> _ensureExpiredProfile() async {
    if (widget.routerService == null) return;

    final profiles = await widget.routerService!.sendCommand(
      '/ppp/profile/print',
      useCache: false,
    );

    final existing = profiles.where((p) {
      return _normalizeText(p['name']).toLowerCase() ==
          _expiredProfileName.toLowerCase();
    }).toList();

    if (existing.isEmpty) {
      await widget.routerService!.sendCommand(
        '/ppp/profile/add',
        params: {
          'name': _expiredProfileName,
          'rate-limit': _expiredRateLimit,
          'only-one': 'no',
          'change-tcp-mss': 'yes',
        },
      );
      return;
    }

    final profileId = _normalizeText(existing.first['.id']);
    if (profileId.isNotEmpty) {
      await widget.routerService!.sendCommand(
        '/ppp/profile/set',
        params: {
          'numbers': profileId,
          'rate-limit': _expiredRateLimit,
        },
      );
    }
  }

  Future<bool> _applyExpirationRules(
    List<Map<String, dynamic>> secrets,
    Map<String, Map<String, dynamic>> activeBySession,
  ) async {
    if (widget.routerService == null) return false;

    bool changed = false;
    await _ensureExpiredProfile();

    for (final secret in secrets) {
      final commentRaw = secret['comment']?.toString() ?? '';
      final parsed = _parseComment(commentRaw);
      final expiryDate = parsed.expiryDate;

      if (expiryDate == null || !_isExpired(expiryDate)) {
        continue;
      }

      final currentProfile = _normalizeText(secret['profile']);
      final secretId = _normalizeText(secret['.id']);

      if (currentProfile.toLowerCase() != _expiredProfileName.toLowerCase() &&
          secretId.isNotEmpty) {
        await widget.routerService!.sendCommand(
          '/ppp/secret/set',
          params: {
            'numbers': secretId,
            'profile': _expiredProfileName,
          },
        );
        secret['profile'] = _expiredProfileName;
        changed = true;
      }

      final sessionKey = _matchActiveSessionKey(secret, activeBySession);
      if (sessionKey != null) {
        final activeEntry = activeBySession[sessionKey];
        final activeId = _normalizeText(activeEntry?['.id']);
        if (activeId.isNotEmpty) {
          await widget.routerService!.sendCommand(
            '/ppp/active/remove',
            params: {'numbers': activeId},
          );
          activeBySession.remove(sessionKey);
          changed = true;
        }
      }
    }

    return changed;
  }

  Future<Map<String, double>> _getTrafficForInterface(
      String interfaceName) async {
    if (widget.routerService == null || interfaceName.trim().isEmpty) {
      return {
        'rx-bits-per-second': 0,
        'tx-bits-per-second': 0,
      };
    }

    try {
      return await widget.routerService!
          .getPortCurrentRate(interfaceName.trim());
    } catch (_) {
      return {
        'rx-bits-per-second': 0,
        'tx-bits-per-second': 0,
      };
    }
  }

  Future<List<Map<String, dynamic>>> _attachLiveTrafficToActive(
    List<Map<String, dynamic>> active,
  ) async {
    final trafficBySession = <String, Map<String, double>>{};

    await Future.wait(
      active.map((a) async {
        var service = _normalizeText(a['service']).toLowerCase();
        if (service.isEmpty) service = 'pppoe';

        final username = _normalizeText(a['name']);

        if (username.isNotEmpty) {
          final interfaceName = '<$service-$username>';
          trafficBySession[_sessionKey(a)] =
              await _getTrafficForInterface(interfaceName);
        }
      }),
    );

    return active.map((a) {
      final traffic = trafficBySession[_sessionKey(a)] ??
          {
            'rx-bits-per-second': 0,
            'tx-bits-per-second': 0,
          };

      final rxBits = traffic['rx-bits-per-second'] ?? 0;
      final txBits = traffic['tx-bits-per-second'] ?? 0;

      var service = _normalizeText(a['service']).toLowerCase();
      if (service.isEmpty) service = 'pppoe';
      final username = _normalizeText(a['name']);

      return {
        ...a,
        'traffic-interface': '<$service-$username>',
        'rx-speed': rxBits / 1000000,
        'tx-speed': txBits / 1000000,
        'speed-mbps': (rxBits + txBits) / 1000000,
      };
    }).toList();
  }

  Future<void> _load({bool initial = false}) async {
    if (widget.routerService == null) return;

    if (initial && mounted) {
      setState(() => _loading = true);
    }

    try {
      widget.routerService!.clearCache();

      final secrets = await widget.routerService!.getPppSecrets();
      final rawActive = await widget.routerService!.getPppActive();
      final active = await _attachLiveTrafficToActive(rawActive);

      final activeBySession = _buildActiveBySession(active);

      if (await _shouldRunExpirationCheck()) {
        await _applyExpirationRules(secrets, activeBySession);
      }

      if (!mounted) return;

      setState(() {
        _secrets = secrets;
        _active = activeBySession.values.toList();
        _loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  List<Map<String, dynamic>> _buildAccounts() {
    final activeBySession = _buildActiveBySession(_active);

    final list = _secrets.map((secret) {
      final sessionKey = _matchActiveSessionKey(secret, activeBySession);
      final activeEntry =
          (sessionKey != null) ? activeBySession[sessionKey] : null;
      final parsed = _parseComment(secret['comment']?.toString() ?? '');

      final isDisabled = _isDisabled(secret);
      final isExpired = _isExpired(parsed.expiryDate);
      final isActive = activeEntry != null;

      final rxSpeed = (activeEntry?['rx-speed'] as num?)?.toDouble() ?? 0;
      final txSpeed = (activeEntry?['tx-speed'] as num?)?.toDouble() ?? 0;
      final totalSpeed = (activeEntry?['speed-mbps'] as num?)?.toDouble() ?? 0;

      String status;
      if (isActive) {
        status = 'active';
      } else if (isExpired) {
        status = 'expired';
      } else if (isDisabled) {
        status = 'disabled';
      } else {
        status = 'offline';
      }

      final activeAddress = _normalizeText(activeEntry?['address']);
      final secretRemoteAddress = _normalizeText(secret['remote-address']);
      final secretLocalAddress = _normalizeText(secret['local-address']);

      String browserIp = '';
      if (activeAddress.isNotEmpty) {
        browserIp = activeAddress;
      } else if (secretRemoteAddress.isNotEmpty) {
        browserIp = secretRemoteAddress;
      } else if (secretLocalAddress.isNotEmpty) {
        browserIp = secretLocalAddress;
      }

      return {
        ...secret,
        'phone': parsed.phone,
        'note': parsed.note,
        'expiry-date': parsed.expiryDate,
        'expiry-label': parsed.expiryDate == null
            ? ''
            : _dateOnlyString(parsed.expiryDate!),
        'is-paid': parsed.isPaid,
        'active': isActive,
        'disabled': isDisabled,
        'expired': isExpired,
        'status': status,
        'active-id': _normalizeText(activeEntry?['.id']),
        'session-key': sessionKey ?? '',
        'rx-speed': rxSpeed,
        'tx-speed': txSpeed,
        'speed-mbps': totalSpeed,
        'browser-ip': browserIp,
      };
    }).toList();

    const statusOrder = {
      'active': 0,
      'offline': 1,
      'disabled': 2,
      'expired': 3
    };

    switch (_sortBy) {
      case 'status':
        list.sort((a, b) {
          final aOrder = statusOrder[a['status']] ?? 99;
          final bOrder = statusOrder[b['status']] ?? 99;
          if (aOrder != bOrder) return aOrder.compareTo(bOrder);
          return _normalizeText(a['name'])
              .toLowerCase()
              .compareTo(_normalizeText(b['name']).toLowerCase());
        });
        break;
      case 'uptime':
        list.sort((a, b) =>
            _normalizeText(a['uptime']).compareTo(_normalizeText(b['uptime'])));
        break;
      case 'usage':
        list.sort((a, b) {
          final aSpeed = (a['speed-mbps'] as double?) ?? 0.0;
          final bSpeed = (b['speed-mbps'] as double?) ?? 0.0;
          return bSpeed.compareTo(aSpeed);
        });
        break;
      case 'profile':
        list.sort((a, b) => _normalizeText(a['profile'])
            .toLowerCase()
            .compareTo(_normalizeText(b['profile']).toLowerCase()));
        break;
      default:
        list.sort((a, b) => _normalizeText(a['name'])
            .toLowerCase()
            .compareTo(_normalizeText(b['name']).toLowerCase()));
    }
    return list;
  }

  List<Map<String, dynamic>> get filtered {
    var result = _buildAccounts();

    if (_filter != 'all') {
      result = result.where((u) => u['status'] == _filter).toList();
    }

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      result = result.where((u) {
        final searchable = [
          u['name'],
          u['phone'],
          u['note'],
          u['profile'],
          u['expiry-label'],
          u['status'],
        ].map((e) => e?.toString().toLowerCase() ?? '').join(' | ');
        return searchable.contains(q);
      }).toList();
    }

    return result;
  }

  int _countStatus(List<Map<String, dynamic>> list, String filterType) {
    if (filterType == 'all') return list.length;
    return list.where((u) => u['status'] == filterType).length;
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'active':
        return 'متصل';
      case 'offline':
        return 'غير متصل';
      case 'disabled':
        return 'معطل';
      case 'expired':
        return 'منتهي';
      default:
        return 'الكل';
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'active':
        return AppTheme.greenOnline;
      case 'expired':
        return Colors.orange;
      case 'disabled':
        return Colors.red;
      case 'offline':
        return Colors.blue;
      default:
        return AppTheme.gold;
    }
  }

  Future<void> _ensureSpeedProfile() async {
    try {
      await widget.routerService!.sendCommand(
        '/ppp/profile/add',
        params: {
          'name': 'Speed',
          'rate-limit': '',
          'only-one': 'no',
        },
      );
    } catch (_) {} // تم تصحيح الـ catch الفارغة هنا لمنع مشاكل الكومبايلر
  }

  Future<void> _applySpeedProfile(Map<String, dynamic> user) async {
    if (widget.routerService == null) return;

    final secretId = user['.id']?.toString() ?? '';
    final activeId = user['active-id']?.toString() ?? '';

    await _ensureSpeedProfile();

    if (secretId.isNotEmpty) {
      await widget.routerService!.sendCommand(
        '/ppp/secret/set',
        params: {
          'numbers': secretId,
          'profile': 'Speed',
        },
      );
    }

    if (user['active'] == true && activeId.isNotEmpty) {
      await widget.routerService!.sendCommand(
        '/ppp/active/remove',
        params: {'numbers': activeId},
      );
    }

    _load();
  }

  Future<void> _deleteAccount(Map<String, dynamic> user) async {
    if (widget.routerService == null) return;

    final id = user['.id']?.toString() ?? '';
    if (id.isEmpty) return;

    await widget.routerService!.sendCommand(
      '/ppp/secret/remove',
      params: {'numbers': id},
    );

    _load();
  }

  Future<void> _openBrowser(Map<String, dynamic> user) async {
    String ip = user['browser-ip']?.toString().trim() ?? '';

    if (ip.isEmpty) {
      if (!mounted) return;
      final controller = TextEditingController();
      final result = await showDialog<String>(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: AppTheme.semiBlack,
          title: const Text(
            'أدخل IP العميل',
            style: TextStyle(color: Colors.white),
          ),
          content: TextField(
            controller: controller,
            style: const TextStyle(color: Colors.white),
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              hintText: 'مثال: 10.16.255.213',
              hintStyle: TextStyle(color: Colors.white38),
              filled: true,
              fillColor: Colors.white10,
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child:
                  const Text('إلغاء', style: TextStyle(color: Colors.white54)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: Text('فتح', style: TextStyle(color: AppTheme.gold)),
            ),
          ],
        ),
      );
      if (result == null || result.isEmpty) return;
      ip = result;
    }

    ip = ip.replaceAll(RegExp(r'^https?://'), '');

    if (!RegExp(r'^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$').hasMatch(ip)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('IP غير صالح: $ip'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final url = Uri.parse('http://$ip/login.html');

    try {
      final launched = await launchUrl(
        url,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تعذر فتح المتصفح: http://$ip/login.html'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطأ في فتح المتصفح: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showActions(Map<String, dynamic> user) {
    final isDisabled = _isDisabled(user);
    final isPaid = user['is-paid'] == true;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.semiBlack,
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.open_in_browser, color: Colors.cyan),
              title: const Text(
                'فتح في المتصفح',
                style: TextStyle(color: Colors.white),
              ),
              subtitle: () {
                final ip = user['browser-ip']?.toString().trim() ?? '';
                if (ip.isNotEmpty) {
                  return Text(
                    'http://$ip/login.html',
                    style: const TextStyle(color: Colors.white38, fontSize: 11),
                  );
                }
                return null;
              }(),
              onTap: () {
                Navigator.pop(context);
                _openBrowser(user);
              },
            ),
            ListTile(
              leading: Icon(
                isPaid ? Icons.money_off : Icons.attach_money,
                color: isPaid ? Colors.red : Colors.green,
              ),
              title: Text(
                isPaid ? 'تغيير إلى: لم يتم الدفع' : 'تغيير إلى: تم الدفع',
                style: const TextStyle(color: Colors.white),
              ),
              onTap: () async {
                Navigator.pop(context);
                final secretId = user['.id']?.toString() ?? '';
                if (secretId.isNotEmpty) {
                  final parsed =
                      _parseComment(user['comment']?.toString() ?? '');
                  final newParts = <String>[];
                  if (parsed.phone.isNotEmpty) {
                    newParts.add('phone:${parsed.phone}');
                  }
                  if (parsed.expiryDate != null) {
                    newParts.add(
                        'exp:${DateFormat('yyyy-MM-dd').format(parsed.expiryDate!)}');
                  }
                  newParts.add('paid:${!isPaid}');
                  if (parsed.note.isNotEmpty) newParts.add(parsed.note);

                  await widget.routerService?.sendCommand(
                    '/ppp/secret/set',
                    params: {
                      'numbers': secretId,
                      'comment': newParts.join(' | ')
                    },
                  );
                  _load();
                }
              },
            ),
            if (user['active'] == true)
              ListTile(
                leading: const Icon(Icons.link_off, color: Colors.red),
                title: const Text(
                  'قطع الاتصال',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  final activeId = user['active-id']?.toString() ?? '';
                  if (activeId.isNotEmpty) {
                    await widget.routerService?.sendCommand(
                      '/ppp/active/remove',
                      params: {'numbers': activeId},
                    );
                    _load();
                  }
                },
              ),
            ListTile(
              leading: const Icon(Icons.edit, color: AppTheme.gold),
              title: const Text(
                'تعديل',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PppUserScreen(
                      routerService: widget.routerService,
                      isEdit: true,
                      initialData: user,
                    ),
                  ),
                ).then((_) => _load());
              },
            ),
            ListTile(
              leading: Icon(
                Icons.block,
                color: isDisabled ? Colors.green : Colors.orange,
              ),
              title: Text(
                isDisabled ? 'تفعيل الحساب' : 'تعطيل الحساب',
                style: const TextStyle(color: Colors.white),
              ),
              onTap: () async {
                Navigator.pop(context);
                final newDisabledValue = isDisabled ? 'no' : 'yes';
                final secretId = user['.id']?.toString() ?? '';
                if (secretId.isNotEmpty) {
                  await widget.routerService?.sendCommand(
                    '/ppp/secret/set',
                    params: {
                      'numbers': secretId,
                      'disabled': newDisabledValue,
                    },
                  );
                  _load();
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.speed, color: AppTheme.gold),
              title: const Text(
                'فتح السرعة',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(context);
                _applySpeedProfile(user);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_forever, color: Colors.red),
              title: const Text(
                'حذف الحساب',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () async {
                Navigator.pop(context);
                await _deleteAccount(user);
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
        builder: (_) => PppUserScreen(
          routerService: widget.routerService,
          isEdit: false,
        ),
      ),
    ).then((_) => _load());
  }

  Widget _buildSpeedBadge(double rxSpeed, double txSpeed) {
    final primaryLabel = _showRxFirst ? 'RX' : 'TX';
    final primaryValue = _showRxFirst ? rxSpeed : txSpeed;
    final secondaryLabel = _showRxFirst ? 'TX' : 'RX';
    final secondaryValue = _showRxFirst ? txSpeed : rxSpeed;

    return Container(
      width: 122,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.greenOnline.withOpacity(0.14),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.greenOnline.withOpacity(0.85),
          width: 1,
        ),
      ),
      child: Stack(
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                primaryLabel,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                _formatSpeed(primaryValue),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$secondaryLabel: ${_formatSpeed(secondaryValue)}',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 9,
                ),
              ),
            ],
          ),
          Positioned(
            top: -6,
            right: -6,
            child: InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: () => setState(() => _showRxFirst = !_showRxFirst),
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.2),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white24),
                ),
                child: const Icon(
                  Icons.swap_vert,
                  size: 14,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(Map<String, dynamic> user) {
    final status = user['status']?.toString() ?? 'offline';
    final color = _statusColor(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.45)),
      ),
      child: Text(
        _statusLabel(status),
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildInfoLine(String title, String value) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: RichText(
        text: TextSpan(
          style: TextStyle(
            color: onSurface.withOpacity(0.82),
            fontSize: 12,
            height: 1.25,
          ),
          children: [
            TextSpan(
              text: '$title: ',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountCard(Map<String, dynamic> user) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final status = user['status']?.toString() ?? 'offline';
    final isActive = user['active'] == true;
    final rxSpeed = (user['rx-speed'] as double?) ?? 0;
    final txSpeed = (user['tx-speed'] as double?) ?? 0;
    final note = user['note']?.toString() ?? '';
    final phone = user['phone']?.toString() ?? '';
    final expiryLabel = user['expiry-label']?.toString() ?? '';
    final profile = user['profile']?.toString() ?? '';
    final isPaid = user['is-paid'] == true;
    final browserIp = user['browser-ip']?.toString().trim() ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: _statusColor(status).withOpacity(0.45),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () => _showActions(user),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _statusColor(status).withOpacity(0.12),
                      border: Border.all(
                        color: _statusColor(status).withOpacity(0.4),
                      ),
                    ),
                    child: Icon(
                      isActive ? Icons.person : Icons.person_off,
                      color: _statusColor(status),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                user['name']?.toString() ?? '',
                                style: TextStyle(
                                  color: onSurface,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            if (browserIp.isNotEmpty)
                              Tooltip(
                                message: 'http://$browserIp/login.html',
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(8),
                                  onTap: () => _openBrowser(user),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.cyan.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                          color: Colors.cyan.withOpacity(0.35)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.open_in_browser,
                                            color: Colors.cyan, size: 14),
                                        const SizedBox(width: 4),
                                        Text(
                                          browserIp,
                                          style: const TextStyle(
                                            color: Colors.cyan,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _buildStatusChip(user),
                            if (profile.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.gold.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color: AppTheme.gold.withOpacity(0.35),
                                  ),
                                ),
                                child: Text(
                                  'الباقة: $profile',
                                  style: const TextStyle(
                                    color: AppTheme.gold,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: (isPaid ? Colors.green : Colors.red)
                                    .withOpacity(0.12),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: (isPaid ? Colors.green : Colors.red)
                                      .withOpacity(0.35),
                                ),
                              ),
                              child: Text(
                                isPaid ? 'مدفوع' : 'غير مدفوع',
                                style: TextStyle(
                                  color: isPaid ? Colors.green : Colors.red,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (isActive) ...[
                    const SizedBox(width: 8),
                    _buildSpeedBadge(rxSpeed, txSpeed),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              if (phone.isNotEmpty) _buildInfoLine('الهاتف', phone),
              if (expiryLabel.isNotEmpty)
                _buildInfoLine('الصلاحية', expiryLabel),
              if (note.isNotEmpty) _buildInfoLine('الكومنت', note),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilters() {
    final accounts = _buildAccounts();
    final all = accounts.length;
    final active = _countStatus(accounts, 'active');
    final offline = _countStatus(accounts, 'offline');
    final disabled = _countStatus(accounts, 'disabled');
    final expired = _countStatus(accounts, 'expired');

    final chips = [
      ('all', 'الكل', all),
      ('active', 'متصل', active),
      ('offline', 'غير متصل', offline),
      ('disabled', 'معطل', disabled),
      ('expired', 'منتهي', expired),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: chips.map((item) {
          final selected = _filter == item.$1;
          return Padding(
            padding: const EdgeInsets.only(left: 8),
            child: ChoiceChip(
              label: Text('${item.$2} (${item.$3})'),
              selected: selected,
              selectedColor: AppTheme.gold,
              backgroundColor: Theme.of(context).cardColor,
              labelStyle: TextStyle(
                color: selected
                    ? Colors.black
                    : Theme.of(context).colorScheme.onSurface,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
              onSelected: (_) => setState(() => _filter = item.$1),
            ),
          );
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final filteredList = filtered;

    return Scaffold(
      appBar: AppBar(
        title: const Text('البرودباند'),
        actions: [
          IconButton(
            onPressed: _load,
            icon: const Icon(Icons.refresh),
            tooltip: 'تحديث',
          ),
          IconButton(
            onPressed: _addNewAccount,
            icon: const Icon(Icons.person_add),
            tooltip: 'إضافة مستخدم',
          ),
        ],
      ),
      body: Column(
        children: [
          if (_loading) const LinearProgressIndicator(color: AppTheme.gold),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _buildFilters(),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'بحث...',
                      prefixIcon:
                          const Icon(Icons.search, color: AppTheme.gold),
                      filled: true,
                      fillColor: Theme.of(context).cardColor,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                    ),
                    style: TextStyle(color: onSurface, fontSize: 13),
                    onChanged: (v) => setState(() => _searchQuery = v),
                  ),
                ),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  value: _sortBy,
                  dropdownColor: Theme.of(context).cardColor,
                  style: TextStyle(color: onSurface, fontSize: 12),
                  underline: const SizedBox(),
                  items: const [
                    DropdownMenuItem(value: 'status', child: Text('الحالة')),
                    DropdownMenuItem(value: 'name', child: Text('الاسم')),
                    DropdownMenuItem(value: 'usage', child: Text('الأعلى سحب')),
                    DropdownMenuItem(value: 'profile', child: Text('الباقة')),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => _sortBy = v);
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              child: filteredList.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        const SizedBox(height: 120),
                        Center(
                          child: Text(
                            'لا توجد حسابات مطابقة',
                            style: TextStyle(
                              color: onSurface.withOpacity(0.6),
                            ),
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                      itemCount: filteredList.length,
                      itemBuilder: (_, i) {
                        return _buildAccountCard(filteredList[i]);
                      },
                    ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTheme.gold,
        onPressed: _addNewAccount,
        child: const Icon(Icons.add),
      ),
    );
  }
}
