import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:st_manager/screens/ppp/ppp_user_screen.dart';
import 'package:st_manager/services/router_service.dart';
import 'package:st_manager/theme/app_theme.dart';

class _TrafficSnapshot {
  final int bytesIn;
  final int bytesOut;
  final DateTime time;

  const _TrafficSnapshot({
    required this.bytesIn,
    required this.bytesOut,
    required this.time,
  });
}

class _CommentData {
  final String phone;
  final String note;
  final DateTime? expiryDate;

  const _CommentData({
    required this.phone,
    required this.note,
    required this.expiryDate,
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

  List<Map<String, dynamic>> _secrets = [];
  List<Map<String, dynamic>> _active = [];
  List<Map<String, dynamic>> _profiles = [];

  String _searchQuery = '';
  String _sortBy = 'name';
  String _filter = 'all';
  bool _loading = false;
  bool _showRxFirst = true;

  final Map<String, _TrafficSnapshot> _previousTraffic = {};
  final Map<String, double> _rxSpeeds = {};
  final Map<String, double> _txSpeeds = {};

  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _load(initial: true);
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => _load(),
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

  int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? 0;
  }

  bool _isDisabled(Map<String, dynamic> user) {
    final value = user['disabled']?.toString().toLowerCase();
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
      return const _CommentData(phone: '', note: '', expiryDate: null);
    }

    String phone = '';
    DateTime? expiryDate;
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

      notes.add(token);
    }

    return _CommentData(
      phone: phone,
      note: notes.join(' | '),
      expiryDate: expiryDate,
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

  Map<String, Map<String, dynamic>> _buildActiveIndex(
    List<Map<String, dynamic>> active,
  ) {
    final index = <String, Map<String, dynamic>>{};
    for (final a in active) {
      final sessionKey = _sessionKey(a);
      index['_sid:$sessionKey'] = a;
      for (final key in _candidateKeys(a)) {
        index[key] = a;
      }
    }
    return index;
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

  Map<String, dynamic>? _matchActiveEntry(
    Map<String, dynamic> secret,
    Map<String, Map<String, dynamic>> activeIndex,
  ) {
    for (final key in _candidateKeys(secret)) {
      final active = activeIndex[key];
      if (active != null) return active;
    }
    return null;
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

  int _extractBytesIn(Map<String, dynamic> activeEntry) {
    final bytesIn = _toInt(activeEntry['bytes-in']);
    if (bytesIn > 0) return bytesIn;

    final rxByte = _toInt(activeEntry['rx-byte']);
    if (rxByte > 0) return rxByte;

    return _toInt(activeEntry['total-bytes']);
  }

  int _extractBytesOut(Map<String, dynamic> activeEntry) {
    final bytesOut = _toInt(activeEntry['bytes-out']);
    if (bytesOut > 0) return bytesOut;

    final txByte = _toInt(activeEntry['tx-byte']);
    if (txByte > 0) return txByte;

    return _toInt(activeEntry['total-bytes']);
  }

  void _updateTrafficSpeed(Map<String, Map<String, dynamic>> activeBySession) {
    final now = DateTime.now();
    final nextKeys = <String>{};

    for (final entry in activeBySession.entries) {
      final key = entry.key;
      final activeEntry = entry.value;

      final currentIn = _extractBytesIn(activeEntry);
      final currentOut = _extractBytesOut(activeEntry);
      final previous = _previousTraffic[key];

      double rxMbps = 0;
      double txMbps = 0;

      if (previous != null) {
        final elapsedSeconds =
            now.difference(previous.time).inMilliseconds / 1000.0;

        if (elapsedSeconds > 0) {
          final diffIn = currentIn - previous.bytesIn;
          final diffOut = currentOut - previous.bytesOut;

          if (diffIn >= 0) {
            rxMbps = (diffIn * 8) / elapsedSeconds / 1000000;
          }

          if (diffOut >= 0) {
            txMbps = (diffOut * 8) / elapsedSeconds / 1000000;
          }
        }
      }

      _rxSpeeds[key] = rxMbps;
      _txSpeeds[key] = txMbps;
      _previousTraffic[key] = _TrafficSnapshot(
        bytesIn: currentIn,
        bytesOut: currentOut,
        time: now,
      );
      nextKeys.add(key);
    }

    _previousTraffic.removeWhere((key, _) => !nextKeys.contains(key));
    _rxSpeeds.removeWhere((key, _) => !nextKeys.contains(key));
    _txSpeeds.removeWhere((key, _) => !nextKeys.contains(key));
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

  Future<void> _load({bool initial = false}) async {
    if (widget.routerService == null) return;

    if (initial && mounted) {
      setState(() => _loading = true);
    }

    try {
      final results = await Future.wait([
        widget.routerService!.sendCommand(
          '/ppp/secret/print',
          useCache: false,
        ),
        widget.routerService!.sendCommand(
          '/ppp/active/print',
          useCache: false,
        ),
        widget.routerService!.sendCommand(
          '/ppp/profile/print',
          useCache: false,
        ),
      ]);

      final secrets = List<Map<String, dynamic>>.from(results[0]);
      final active = List<Map<String, dynamic>>.from(results[1]);
      final profiles = List<Map<String, dynamic>>.from(results[2]);

      final activeBySession = _buildActiveBySession(active);
      _updateTrafficSpeed(activeBySession);

      await _applyExpirationRules(secrets, activeBySession);

      if (!mounted) return;

      setState(() {
        _secrets = secrets;
        _active = activeBySession.values.toList();
        _profiles = profiles;
        _loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  List<Map<String, dynamic>> get filtered {
    final activeIndex = _buildActiveIndex(_active);

    final list = _secrets.map((secret) {
      final activeEntry = _matchActiveEntry(secret, activeIndex);
      final sessionKey = activeEntry != null ? _sessionKey(activeEntry) : '';
      final parsed = _parseComment(secret['comment']?.toString() ?? '');

      final isDisabled = _isDisabled(secret);
      final isExpired = _isExpired(parsed.expiryDate);
      final isActive = activeEntry != null;
      final speedRx = sessionKey.isNotEmpty ? (_rxSpeeds[sessionKey] ?? 0) : 0;
      final speedTx = sessionKey.isNotEmpty ? (_txSpeeds[sessionKey] ?? 0) : 0;

      String status = 'offline';
      if (isDisabled) {
        status = 'disabled';
      } else if (isExpired) {
        status = 'expired';
      } else if (isActive) {
        status = 'active';
      }

      return {
        ...secret,
        'phone': parsed.phone,
        'note': parsed.note,
        'expiry-date': parsed.expiryDate,
        'expiry-label': parsed.expiryDate == null
            ? ''
            : _dateOnlyString(parsed.expiryDate!),
        'active': isActive,
        'disabled': isDisabled,
        'expired': isExpired,
        'status': status,
        'active-id': _normalizeText(activeEntry?['.id']),
        'session-key': sessionKey,
        'rx-speed': speedRx,
        'tx-speed': speedTx,
        'speed-mbps': speedRx + speedTx,
      };
    }).toList();

    List<Map<String, dynamic>> result = list;

    switch (_filter) {
      case 'active':
        result = result.where((u) => u['status'] == 'active').toList();
        break;
      case 'offline':
        result = result.where((u) => u['status'] == 'offline').toList();
        break;
      case 'disabled':
        result = result.where((u) => u['status'] == 'disabled').toList();
        break;
      case 'expired':
        result = result.where((u) => u['status'] == 'expired').toList();
        break;
      default:
        break;
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

    switch (_sortBy) {
      case 'status':
        result.sort((a, b) => (a['status'] ?? '')
            .toString()
            .compareTo((b['status'] ?? '').toString()));
        break;
      case 'uptime':
        result.sort((a, b) => (a['uptime'] ?? '')
            .toString()
            .compareTo((b['uptime'] ?? '').toString()));
        break;
      case 'usage':
        result.sort((a, b) {
          final aSpeed = (a['speed-mbps'] as double?) ?? 0;
          final bSpeed = (b['speed-mbps'] as double?) ?? 0;
          return bSpeed.compareTo(aSpeed);
        });
        break;
      case 'profile':
        result.sort((a, b) => (a['profile'] ?? '')
            .toString()
            .compareTo((b['profile'] ?? '').toString()));
        break;
      default:
        result.sort((a, b) => (a['name'] ?? '')
            .toString()
            .compareTo((b['name'] ?? '').toString()));
    }

    return result;
  }

  int _countStatus(List<Map<String, dynamic>> list, String status) {
    return list.where((u) => u['status'] == status).length;
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
      case 'offline':
        return Colors.blueGrey;
      case 'disabled':
        return Colors.orange;
      case 'expired':
        return AppTheme.redOffline;
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
    } catch (_) {}
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

  void _showActions(Map<String, dynamic> user) {
    final isDisabled = user['status'] == 'disabled';

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.semiBlack,
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
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
                isDisabled ? 'تفعيل' : 'تعطيل',
                style: const TextStyle(color: Colors.white),
              ),
              onTap: () async {
                Navigator.pop(context);
                final disable = isDisabled ? 'no' : 'yes';
                final secretId = user['.id']?.toString() ?? '';
                if (secretId.isNotEmpty) {
                  await widget.routerService?.sendCommand(
                    '/ppp/secret/set',
                    params: {
                      'numbers': secretId,
                      'disabled': disable,
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

  Widget _buildSummaryCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: onSurface,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: onSurface.withOpacity(0.7),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpeedOverview(List<Map<String, dynamic>> list) {
    final activeItems = list.where((u) => u['status'] == 'active').toList();

    final totalRx = activeItems.fold<double>(
        0, (sum, item) => sum + ((item['rx-speed'] as double?) ?? 0));
    final totalTx = activeItems.fold<double>(
        0, (sum, item) => sum + ((item['tx-speed'] as double?) ?? 0));

    final primaryLabel = _showRxFirst ? 'RX' : 'TX';
    final primaryValue = _showRxFirst ? totalRx : totalTx;
    final secondaryLabel = _showRxFirst ? 'TX' : 'RX';
    final secondaryValue = _showRxFirst ? totalTx : totalRx;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.semiBlack,
            AppTheme.darkGrey,
            AppTheme.black,
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.gold.withOpacity(0.35)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'السرعة اللحظية',
                  style: TextStyle(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.85),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  primaryLabel,
                  style: const TextStyle(
                    color: AppTheme.gold,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  _formatSpeed(primaryValue),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '$secondaryLabel: ${_formatSpeed(secondaryValue)}',
                  style: TextStyle(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.7),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Column(
            children: [
              IconButton(
                onPressed: () => setState(() => _showRxFirst = !_showRxFirst),
                icon: const Icon(Icons.swap_vert, color: AppTheme.gold),
                tooltip: 'عكس RX / TX',
              ),
              Text(
                _showRxFirst ? 'RX أولاً' : 'TX أولاً',
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSpeedBadge(double rxSpeed, double txSpeed) {
    final primaryLabel = _showRxFirst ? 'RX' : 'TX';
    final primaryValue = _showRxFirst ? rxSpeed : txSpeed;
    final secondaryLabel = _showRxFirst ? 'TX' : 'RX';
    final secondaryValue = _showRxFirst ? txSpeed : rxSpeed;

    return Container(
      width: 112,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.greenOnline.withOpacity(0.14),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.greenOnline.withOpacity(0.85),
          width: 1,
        ),
      ),
      child: Column(
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
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            '$secondaryLabel: ${_formatSpeed(secondaryValue)}',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 9,
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
    final isActive = status == 'active';
    final rxSpeed = (user['rx-speed'] as double?) ?? 0;
    final txSpeed = (user['tx-speed'] as double?) ?? 0;
    final note = user['note']?.toString() ?? '';
    final phone = user['phone']?.toString() ?? '';
    final expiryLabel = user['expiry-label']?.toString() ?? '';
    final profile = user['profile']?.toString() ?? '';
    final totalSpeed = (user['speed-mbps'] as double?) ?? 0;

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
                        Text(
                          user['name']?.toString() ?? '',
                          style: TextStyle(
                            color: onSurface,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
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
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (isActive) _buildSpeedBadge(rxSpeed, txSpeed),
                ],
              ),
              const SizedBox(height: 12),
              _buildInfoLine(
                'السرعة اللحظية',
                isActive ? '${_formatSpeed(totalSpeed)}' : '0',
              ),
              if (phone.isNotEmpty) _buildInfoLine('الهاتف', phone),
              if (expiryLabel.isNotEmpty)
                _buildInfoLine('الصلاحية', expiryLabel),
              if (note.isNotEmpty) _buildInfoLine('الكومنت', note),
              const SizedBox(height: 8),
              if (isActive)
                Text(
                  'متصل الآن',
                  style: TextStyle(
                    color: AppTheme.greenOnline,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                )
              else if (status == 'disabled')
                Text(
                  'معطل',
                  style: TextStyle(
                    color: AppTheme.redOffline,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                )
              else if (status == 'expired')
                Text(
                  'منتهي - سيُنقل إلى بروفايل Xpirer بسرعة 512K/512K',
                  style: TextStyle(
                    color: AppTheme.redOffline,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                )
              else
                Text(
                  'غير متصل',
                  style: TextStyle(
                    color: onSurface.withOpacity(0.65),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilters() {
    final all = _secrets.length;
    final active = _secrets.where((u) => u['status'] == 'active').length;
    final offline = _secrets.where((u) => u['status'] == 'offline').length;
    final disabled = _secrets.where((u) => u['status'] == 'disabled').length;
    final expired = _secrets.where((u) => u['status'] == 'expired').length;

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
          Padding(
            padding: const EdgeInsets.all(16),
            child: _buildSpeedOverview(filteredList),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.6,
              children: [
                _buildSummaryCard(
                  title: 'متصل',
                  value: '${_countStatus(_secrets, 'active')}',
                  icon: Icons.wifi,
                  color: AppTheme.greenOnline,
                ),
                _buildSummaryCard(
                  title: 'غير متصل',
                  value: '${_countStatus(_secrets, 'offline')}',
                  icon: Icons.wifi_off,
                  color: Colors.blueGrey,
                ),
                _buildSummaryCard(
                  title: 'معطل',
                  value: '${_countStatus(_secrets, 'disabled')}',
                  icon: Icons.block,
                  color: Colors.orange,
                ),
                _buildSummaryCard(
                  title: 'منتهي',
                  value: '${_countStatus(_secrets, 'expired')}',
                  icon: Icons.hourglass_bottom,
                  color: AppTheme.redOffline,
                ),
              ],
            ),
          ),
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
                      hintText: 'بحث باسم المستخدم أو الهاتف أو الكومنت...',
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
                    DropdownMenuItem(value: 'name', child: Text('الاسم')),
                    DropdownMenuItem(value: 'status', child: Text('الحالة')),
                    DropdownMenuItem(value: 'usage', child: Text('الأعلى سحب')),
                    DropdownMenuItem(value: 'profile', child: Text('الباقة')),
                    DropdownMenuItem(
                        value: 'uptime', child: Text('وقت التشغيل')),
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
