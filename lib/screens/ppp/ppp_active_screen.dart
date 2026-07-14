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

  static const Duration _dataFetchTimeout = Duration(seconds: 20);
  static const Duration _actionTimeout = Duration(seconds: 12);
  static const Duration _trafficTimeout = Duration(seconds: 8);

  final SecureStorageService _storage = SecureStorageService();

  List<Map<String, dynamic>> _accounts = [];
  List<Map<String, dynamic>> _lastSecrets = [];
  List<Map<String, dynamic>> _lastActive = [];

  bool _loading = false;
  String _searchQuery = '';
  String _sortBy = 'status';
  String _filter = 'all';
  bool _showRxFirst = true;

  Timer? _refreshTimer;
  bool _isLoading = false;
  bool _isFetchingTraffic = false;
  String? _lastExpirationCheckIso;
  final Map<String, Map<String, double>> _trafficCache = {};

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    _lastExpirationCheckIso = await _storage.read(_expirationCheckKey);
    await _load(initial: true);
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _load(background: true),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  String _normalizeText(dynamic value) => value?.toString().trim() ?? '';

  double _toDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }

  bool _isDisabled(Map<String, dynamic> user) {
    final raw = user['disabled'];
    if (raw == null) return false;
    final v = raw.toString().toLowerCase().trim();
    return v == 'true' || v == 'yes' || v == '1' || v == 'on';
  }

  bool _isExpired(DateTime? expiryDate) {
    if (expiryDate == null) return false;
    final end = DateTime(
      expiryDate.year,
      expiryDate.month,
      expiryDate.day,
      23,
      59,
      59,
    );
    return DateTime.now().isAfter(end);
  }

  bool _isNewAccount(
    Map<String, dynamic> secret,
    bool isActive,
    bool isDisabled,
    bool isExpired,
    _CommentData parsed,
  ) {
    if (isActive || isDisabled || isExpired) return false;

    final lastLoggedOut = _normalizeText(secret['last-logged-out']).toLowerCase();

    if (lastLoggedOut.isNotEmpty &&
        !lastLoggedOut.contains('jan/01/1970') &&
        !lastLoggedOut.contains('1970-01-01')) {
      return false;
    }

    return true;
  }

  String _dateOnlyString(DateTime date) => DateFormat('yyyy-MM-dd').format(date);

  String _formatUptime(String uptime) {
    final v = uptime.trim();
    if (v.isEmpty) return '0';
    return v;
  }

  _CommentData _parseComment(String raw) {
    if (raw.trim().isEmpty) {
      return const _CommentData(
        phone: '',
        note: '',
        expiryDate: null,
        isPaid: false,
      );
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
        final parsed = DateTime.tryParse(token.substring(4).trim());
        if (parsed != null) expiryDate = parsed;
        continue;
      }

      if (token.toLowerCase().startsWith('paid:')) {
        final v = token.substring(5).trim().toLowerCase();
        isPaid = v == 'true' || v == 'yes' || v == '1' || v == 'on';
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

  String _buildComment(_CommentData data, {bool? paidOverride}) {
    final parts = <String>[];

    if (data.phone.trim().isNotEmpty) {
      parts.add('phone:${data.phone.trim()}');
    }

    if (data.expiryDate != null) {
      parts.add('exp:${_dateOnlyString(data.expiryDate!)}');
    }

    parts.add('paid:${(paidOverride ?? data.isPaid) ? 'true' : 'false'}');

    if (data.note.trim().isNotEmpty) {
      parts.add(data.note.trim());
    }

    return parts.join(' | ');
  }

  String _sessionKey(Map<String, dynamic> item) {
    for (final key in ['.id', 'name', 'user', 'username', 'caller-id', 'address']) {
      final v = _normalizeText(item[key]);
      if (v.isNotEmpty) return v;
    }
    return 'session-${item.hashCode}';
  }

  List<String> _candidateKeys(Map<String, dynamic> item) {
    return ['name', 'user', 'username', 'caller-id', 'address']
        .map((k) => _normalizeText(item[k]).toLowerCase())
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList();
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
        if (activeKeys.contains(key)) return entry.key;
      }
    }
    return null;
  }

  Future<bool> _shouldRunExpirationCheck() async {
    final now = DateTime.now();
    final todayNoon = DateTime(now.year, now.month, now.day, 12);

    if (now.isBefore(todayNoon)) return false;

    if (_lastExpirationCheckIso != null) {
      final last = DateTime.tryParse(_lastExpirationCheckIso!);
      if (last != null &&
          last.year == now.year &&
          last.month == now.month &&
          last.day == now.day) {
        return false;
      }
    }

    return true;
  }

  Future<void> _markExpirationCheckDone() async {
    final now = DateTime.now();
    _lastExpirationCheckIso = now.toIso8601String();
    await _storage.write(_expirationCheckKey, _lastExpirationCheckIso!);
  }

  Future<void> _ensureExpiredProfile() async {
    if (widget.routerService == null) return;

    final profiles = await widget.routerService!
        .sendCommand('/ppp/profile/print', useCache: false)
        .timeout(_actionTimeout);

    final existing = profiles
        .where(
          (p) =>
              _normalizeText(p['name']).toLowerCase() ==
              _expiredProfileName.toLowerCase(),
        )
        .toList();

    if (existing.isEmpty) {
      await widget.routerService!.sendCommand(
        '/ppp/profile/add',
        params: {
          'name': _expiredProfileName,
          'rate-limit': _expiredRateLimit,
          'only-one': 'no',
          'change-tcp-mss': 'yes',
        },
      ).timeout(_actionTimeout);
      return;
    }

    final id = _normalizeText(existing.first['.id']);
    if (id.isNotEmpty) {
      await widget.routerService!.sendCommand(
        '/ppp/profile/set',
        params: {'numbers': id, 'rate-limit': _expiredRateLimit},
      ).timeout(_actionTimeout);
    }
  }

  Future<bool> _applyExpirationRules(
    List<Map<String, dynamic>> secrets,
    Map<String, Map<String, dynamic>> activeBySession,
  ) async {
    if (widget.routerService == null) return true;

    try {
      await _ensureExpiredProfile();
    } catch (_) {
      return false;
    }

    final expiredSecrets = secrets.where((secret) {
      final parsed = _parseComment(secret['comment']?.toString() ?? '');
      return parsed.expiryDate != null && _isExpired(parsed.expiryDate);
    }).toList();

    if (expiredSecrets.isEmpty) return true;

    bool allSucceeded = true;

    await Future.wait(expiredSecrets.map((secret) async {
      try {
        final secretId = _normalizeText(secret['.id']);

        if (secretId.isNotEmpty &&
            _normalizeText(secret['profile']).toLowerCase() !=
                _expiredProfileName.toLowerCase()) {
          await widget.routerService!.sendCommand(
            '/ppp/secret/set',
            params: {'numbers': secretId, 'profile': _expiredProfileName},
          ).timeout(_actionTimeout);
          secret['profile'] = _expiredProfileName;
        }

        final sessionKey = _matchActiveSessionKey(secret, activeBySession);
        if (sessionKey != null) {
          final activeEntry = activeBySession[sessionKey];
          final activeId = _normalizeText(activeEntry?['.id']);
          if (activeId.isNotEmpty) {
            await widget.routerService!.sendCommand(
              '/ppp/active/remove',
              params: {'numbers': activeId},
            ).timeout(_actionTimeout);
            activeBySession.remove(sessionKey);
          }
        }
      } catch (_) {
        allSucceeded = false;
      }
    }));

    return allSucceeded;
  }

  String _buildTrafficInterfaceName(Map<String, dynamic> active) {
    final service = _normalizeText(active['service']).toLowerCase();
    final name = _normalizeText(active['name']);

    if (name.isEmpty) return '';

    if (service.isNotEmpty) {
      return '<$service-$name>';
    }

    return '<pppoe-$name>';
  }

  Future<Map<String, double>> _getSessionTraffic(
    Map<String, dynamic> activeSession,
  ) async {
    if (widget.routerService == null) {
      return {'rx': 0, 'tx': 0};
    }

    final ifName = _buildTrafficInterfaceName(activeSession);
    if (ifName.isEmpty) {
      return {'rx': 0, 'tx': 0};
    }

    try {
      final result = await widget.routerService!.sendCommand(
        '/interface/monitor-traffic',
        params: {
          'interface': ifName,
          'once': '',
        },
        useCache: false,
      ).timeout(_trafficTimeout);

      if (result.isNotEmpty) {
        final row = result.first;
        final rx = double.tryParse(row['rx-bits-per-second']?.toString() ?? '') ?? 0;
        final tx = double.tryParse(row['tx-bits-per-second']?.toString() ?? '') ?? 0;
        return {'rx': rx / 1000000, 'tx': tx / 1000000};
      }
    } catch (_) {}

    return {'rx': 0, 'tx': 0};
  }

  Future<void> _fetchTrafficInBackground(
    List<Map<String, dynamic>> activeList,
  ) async {
    if (activeList.isEmpty) return;
    if (_isFetchingTraffic) return;

    _isFetchingTraffic = true;
    try {
      const batchSize = 6;
      final trafficBySession = <String, Map<String, double>>{};

      for (var i = 0; i < activeList.length; i += batchSize) {
        final end = (i + batchSize < activeList.length) ? i + batchSize : activeList.length;
        final batch = activeList.sublist(i, end);

        final entries = await Future.wait(
          batch.map((active) async {
            final key = _sessionKey(active);
            final traffic = await _getSessionTraffic(active);
            return MapEntry(key, traffic);
          }),
        );

        for (final entry in entries) {
          trafficBySession[entry.key] = entry.value;
        }
      }

      if (!mounted) return;

      setState(() {
        final updated = _accounts.map((account) {
          final key = _normalizeText(account['session-key']);
          final traffic = trafficBySession[key] ??
              _trafficCache[key] ??
              {'rx': 0.0, 'tx': 0.0};

          final rx = (traffic['rx'] ?? 0).toDouble();
          final tx = (traffic['tx'] ?? 0).toDouble();

          _trafficCache[key] = {'rx': rx, 'tx': tx};

          return {
            ...account,
            'rx-speed': rx,
            'tx-speed': tx,
            'speed-mbps': rx + tx,
          };
        }).toList();

        _accounts = updated;
      });
    } finally {
      _isFetchingTraffic = false;
    }
  }

  int _parseUptime(String uptime) {
    final str = uptime.trim();
    if (str.isEmpty) return 0;

    int total = 0;
    final reg = RegExp(r'(\d+)([wdhms])');

    for (final m in reg.allMatches(str.toLowerCase())) {
      final val = int.tryParse(m.group(1) ?? '0') ?? 0;
      final unit = m.group(2) ?? '';

      switch (unit) {
        case 'w':
          total += val * 7 * 24 * 3600;
          break;
        case 'd':
          total += val * 24 * 3600;
          break;
        case 'h':
          total += val * 3600;
          break;
        case 'm':
          total += val * 60;
          break;
        case 's':
          total += val;
          break;
      }
    }

    return total;
  }

  Future<List<Map<String, dynamic>>?> _safeFetchList(String command) async {
    if (widget.routerService == null) return null;

    try {
      final result = await widget.routerService!
          .sendCommand(command, useCache: false)
          .timeout(_dataFetchTimeout);
      return List<Map<String, dynamic>>.from(result);
    } on TimeoutException {
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _load({bool initial = false, bool background = false}) async {
    if (_isLoading) return;
    if (widget.routerService == null) return;

    _isLoading = true;
    if (initial || !background) {
      if (mounted) setState(() => _loading = true);
    }

    try {
      final results = await Future.wait([
        _safeFetchList('/ppp/secret/print'),
        _safeFetchList('/ppp/active/print'),
      ]);

      final secretsResult = results[0] as List<Map<String, dynamic>>?;
      final activeResult = results[1] as List<Map<String, dynamic>>?;

      if (secretsResult != null) {
        _lastSecrets = secretsResult;
      }
      if (activeResult != null) {
        _lastActive = activeResult;
      }

      final secrets = secretsResult ?? _lastSecrets;
      final activeList = activeResult ?? _lastActive;
      final activeBySession = _buildActiveBySession(activeList);

      if (await _shouldRunExpirationCheck()) {
        final expirationSucceeded =
            await _applyExpirationRules(secrets, activeBySession);
        if (expirationSucceeded) {
          await _markExpirationCheckDone();
        }
      }

      final accounts = _buildAccountList(
        secrets,
        activeBySession.values.toList(),
      );

      if (!mounted) return;
      setState(() {
        _accounts = accounts;
        _loading = false;
      });

      _fetchTrafficInBackground(activeBySession.values.toList());
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
      }
    } finally {
      _isLoading = false;
    }
  }

  List<Map<String, dynamic>> _buildAccountList(
    List<Map<String, dynamic>> secrets,
    List<Map<String, dynamic>> activeList,
  ) {
    final activeBySession = _buildActiveBySession(activeList);

    return secrets.map((secret) {
      final sessionKey = _matchActiveSessionKey(secret, activeBySession);
      final activeEntry =
          sessionKey != null ? activeBySession[sessionKey] : null;
      final parsed = _parseComment(secret['comment']?.toString() ?? '');

      final isDisabled = _isDisabled(secret);
      final isExpired = _isExpired(parsed.expiryDate);
      final isActive = activeEntry != null;
      final isNew = _isNewAccount(
        secret,
        isActive,
        isDisabled,
        isExpired,
        parsed,
      );

      final rx = sessionKey != null ? (_trafficCache[sessionKey]?['rx'] ?? 0) : 0;
      final tx = sessionKey != null ? (_trafficCache[sessionKey]?['tx'] ?? 0) : 0;
      final totalSpeed = rx + tx;
      final uptime = _normalizeText(activeEntry?['uptime']);

      String status;
      if (isDisabled) {
        status = 'disabled';
      } else if (isExpired) {
        status = 'expired';
      } else if (isActive) {
        status = 'active';
      } else if (isNew) {
        status = 'new';
      } else {
        status = 'offline';
      }

      final address = _normalizeText(activeEntry?['address']);
      final remote = _normalizeText(secret['remote-address']);
      final local = _normalizeText(secret['local-address']);
      final browserIp = address.isNotEmpty
          ? address
          : (remote.isNotEmpty ? remote : local);

      return {
        ...secret,
        'phone': parsed.phone,
        'note': parsed.note,
        'expiry-date': parsed.expiryDate,
        'expiry-label': parsed.expiryDate == null
            ? ''
            : _dateOnlyString(parsed.expiryDate!),
        'is-paid': parsed.isPaid,
        'is-new': isNew,
        'active': isActive,
        'disabled': isDisabled,
        'expired': isExpired,
        'status': status,
        'active-id': _normalizeText(activeEntry?['.id']),
        'session-key': sessionKey ?? '',
        'rx-speed': rx,
        'tx-speed': tx,
        'speed-mbps': totalSpeed,
        'uptime': uptime,
        'uptime-seconds': _parseUptime(uptime),
        'browser-ip': browserIp,
      };
    }).toList();
  }

  List<Map<String, dynamic>> _sortAccounts(List<Map<String, dynamic>> list) {
    const statusOrder = {
      'active': 0,
      'new': 1,
      'offline': 2,
      'disabled': 3,
      'expired': 4,
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

      case 'new':
        list.sort((a, b) {
          final aNew = a['is-new'] == true;
          final bNew = b['is-new'] == true;
          if (aNew && !bNew) return -1;
          if (!aNew && bNew) return 1;
          return _normalizeText(a['name'])
              .toLowerCase()
              .compareTo(_normalizeText(b['name']).toLowerCase());
        });
        break;

      case 'name':
        list.sort((a, b) => _normalizeText(a['name'])
            .toLowerCase()
            .compareTo(_normalizeText(b['name']).toLowerCase()));
        break;

      case 'uptime':
        list.sort((a, b) {
          final aa = a['active'] == true;
          final ba = b['active'] == true;
          if (aa && !ba) return -1;
          if (!aa && ba) return 1;
          if (aa && ba) {
            final diff = ((b['uptime-seconds'] as int?) ?? 0)
                .compareTo((a['uptime-seconds'] as int?) ?? 0);
            if (diff != 0) return diff;
          }
          return _normalizeText(a['name'])
              .toLowerCase()
              .compareTo(_normalizeText(b['name']).toLowerCase());
        });
        break;

      case 'usage':
        list.sort((a, b) {
          final aa = a['active'] == true;
          final ba = b['active'] == true;
          if (aa && !ba) return -1;
          if (!aa && ba) return 1;
          if (aa && ba) {
            final at = _toDouble(a['rx-speed']) + _toDouble(a['tx-speed']);
            final bt = _toDouble(b['rx-speed']) + _toDouble(b['tx-speed']);
            if (bt != at) return bt.compareTo(at);
          }
          return _normalizeText(a['name'])
              .toLowerCase()
              .compareTo(_normalizeText(b['name']).toLowerCase());
        });
        break;

      case 'profile':
        list.sort((a, b) {
          final pc = _normalizeText(a['profile'])
              .toLowerCase()
              .compareTo(_normalizeText(b['profile']).toLowerCase());
          if (pc != 0) return pc;
          return _normalizeText(a['name'])
              .toLowerCase()
              .compareTo(_normalizeText(b['name']).toLowerCase());
        });
        break;

      default:
        list.sort((a, b) => _normalizeText(a['name'])
            .toLowerCase()
            .compareTo(_normalizeText(b['name']).toLowerCase()));
    }

    return list;
  }

  int _countFilter(String filterType) {
    if (_accounts.isEmpty) return 0;

    switch (filterType) {
      case 'all':
        return _accounts.length;
      case 'active':
        return _accounts.where((u) => u['status'] == 'active').length;
      case 'offline':
        return _accounts.where((u) => u['status'] == 'offline').length;
      case 'disabled':
        return _accounts.where((u) => u['status'] == 'disabled').length;
      case 'expired':
        return _accounts.where((u) => u['status'] == 'expired').length;
      case 'paid':
        return _accounts.where((u) => u['is-paid'] == true).length;
      case 'unpaid':
        return _accounts.where((u) => u['is-paid'] != true).length;
      case 'with-expiry':
        return _accounts.where((u) => u['expiry-date'] != null).length;
      case 'without-expiry':
        return _accounts.where((u) => u['expiry-date'] == null).length;
      case 'new':
        return _accounts.where((u) => u['is-new'] == true).length;
      default:
        return 0;
    }
  }

  List<Map<String, dynamic>> get filtered {
    var result = _sortAccounts(List<Map<String, dynamic>>.from(_accounts));

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
      case 'paid':
        result = result.where((u) => u['is-paid'] == true).toList();
        break;
      case 'unpaid':
        result = result.where((u) => u['is-paid'] != true).toList();
        break;
      case 'with-expiry':
        result = result.where((u) => u['expiry-date'] != null).toList();
        break;
      case 'without-expiry':
        result = result.where((u) => u['expiry-date'] == null).toList();
        break;
      case 'new':
        result = result.where((u) => u['is-new'] == true).toList();
        break;
      default:
        break;
    }

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      result = result.where((u) {
        final s = [
          u['name'],
          u['phone'],
          u['note'],
          u['profile'],
          u['expiry-label'],
          u['status'],
          u['browser-ip'],
          u['uptime'],
        ].map((e) => e?.toString().toLowerCase() ?? '').join(' | ');
        return s.contains(q);
      }).toList();
    }

    return result;
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
      case 'new':
        return 'جديد';
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
      case 'new':
        return Colors.amber;
      default:
        return AppTheme.gold;
    }
  }

  Widget _buildPill(String text, Color color, {IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, color: color, size: 12),
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(Map<String, dynamic> user) {
    final status = _normalizeText(user['status']).isEmpty
        ? 'offline'
        : user['status'].toString();
    final color = _statusColor(status);
    return _buildPill(_statusLabel(status), color);
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

  Widget _buildSpeedBadge(
    double rxSpeed,
    double txSpeed,
  ) {
    final primaryLabel = _showRxFirst ? 'RX' : 'TX';
    final primaryValue = _showRxFirst ? rxSpeed : txSpeed;
    final secondaryLabel = _showRxFirst ? 'TX' : 'RX';
    final secondaryValue = _showRxFirst ? txSpeed : rxSpeed;

    return Container(
      width: 132,
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

  String _formatSpeed(double speedMbps) {
    if (speedMbps >= 1000) return '${(speedMbps / 1000).toStringAsFixed(1)} Gbps';
    if (speedMbps >= 1) return '${speedMbps.toStringAsFixed(1)} Mbps';
    if (speedMbps > 0) return '${(speedMbps * 1000).toStringAsFixed(0)} Kbps';
    return '0';
  }

  Future<void> _togglePaid(Map<String, dynamic> user) async {
    final id = _normalizeText(user['.id']);
    if (id.isEmpty) return;

    final parsed = _parseComment(user['comment']?.toString() ?? '');
    final newComment = _buildComment(parsed, paidOverride: !parsed.isPaid);

    try {
      await widget.routerService?.sendCommand(
        '/ppp/secret/set',
        params: {'numbers': id, 'comment': newComment},
      ).timeout(_actionTimeout);
      _load(background: true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تعذر تحديث حالة الدفع: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteAccount(Map<String, dynamic> user) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.semiBlack,
        title: const Text('تأكيد الحذف', style: TextStyle(color: Colors.white)),
        content: Text(
          'هل أنت متأكد من حذف "${user['name']}"؟',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final id = _normalizeText(user['.id']);
    if (id.isNotEmpty) {
      try {
        await widget.routerService?.sendCommand(
          '/ppp/secret/remove',
          params: {'numbers': id},
        ).timeout(_actionTimeout);
        _load(background: true);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('تعذر حذف الحساب: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _openBrowser(Map<String, dynamic> user) async {
    String ip = _normalizeText(user['browser-ip']);

    if (ip.isEmpty) {
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
            decoration: const InputDecoration(
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
              child: const Text('إلغاء', style: TextStyle(color: Colors.white54)),
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

    ip = ip.replaceAll(RegExp(r'^https?://'), '').trim();
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في فتح المتصفح: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showActions(Map<String, dynamic> user) {
    final isDisabled = user['status'] == 'disabled';
    final isPaid = user['is-paid'] == true;
    final browserIp = _normalizeText(user['browser-ip']);

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
              subtitle: browserIp.isNotEmpty
                  ? Text(
                      'http://$browserIp/login.html',
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 11,
                      ),
                    )
                  : null,
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
                await _togglePaid(user);
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
                  final activeId = _normalizeText(user['active-id']);
                  if (activeId.isNotEmpty) {
                    try {
                      await widget.routerService?.sendCommand(
                        '/ppp/active/remove',
                        params: {'numbers': activeId},
                      ).timeout(_actionTimeout);
                      _load(background: true);
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('تعذر قطع الاتصال: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
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
                ).then((_) => _load(background: true));
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
                final secretId = _normalizeText(user['.id']);
                if (secretId.isEmpty) return;

                try {
                  if (!isDisabled && user['active'] == true) {
                    final activeId = _normalizeText(user['active-id']);
                    if (activeId.isNotEmpty) {
                      await widget.routerService?.sendCommand(
                        '/ppp/active/remove',
                        params: {'numbers': activeId},
                      ).timeout(_actionTimeout);
                    }
                  }

                  await widget.routerService?.sendCommand(
                    '/ppp/secret/set',
                    params: {
                      'numbers': secretId,
                      'disabled': isDisabled ? 'no' : 'yes',
                    },
                  ).timeout(_actionTimeout);

                  _load(background: true);
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('تعذر تغيير حالة الحساب: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
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

  Future<void> _applySpeedProfile(Map<String, dynamic> user) async {
    final secretId = _normalizeText(user['.id']);
    final activeId = _normalizeText(user['active-id']);
    if (secretId.isEmpty) return;

    try {
      await widget.routerService?.sendCommand(
        '/ppp/secret/set',
        params: {'numbers': secretId, 'profile': 'Speed'},
      ).timeout(_actionTimeout);

      if (user['active'] == true && activeId.isNotEmpty) {
        await widget.routerService?.sendCommand(
          '/ppp/active/remove',
          params: {'numbers': activeId},
        ).timeout(_actionTimeout);
      }

      _load(background: true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تعذر تطبيق باقة السرعة: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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
    ).then((_) => _load(background: true));
  }

  void _openProfilesPage() {
    Navigator.push(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: '/ppp-profiles'),
        builder: (_) => _PppProfilesScreen(routerService: widget.routerService),
      ),
    );
  }

  Widget _buildAccountCard(Map<String, dynamic> user) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final status = _normalizeText(user['status']).isEmpty
        ? 'offline'
        : user['status'].toString();
    final isActive = user['active'] == true;
    final rx = _toDouble(user['rx-speed']);
    final tx = _toDouble(user['tx-speed']);
    final note = _normalizeText(user['note']);
    final phone = _normalizeText(user['phone']);
    final expiry = _normalizeText(user['expiry-label']);
    final profile = _normalizeText(user['profile']);
    final isPaid = user['is-paid'] == true;
    final browserIp = _normalizeText(user['browser-ip']);
    final isNew = user['is-new'] == true;
    final uptime = _normalizeText(user['uptime']);
    final cardAccent = isNew ? Colors.amber : _statusColor(status);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isNew
            ? Colors.amber.withOpacity(0.08)
            : Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: cardAccent.withOpacity(0.45)),
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
                      color: cardAccent.withOpacity(0.12),
                      border: Border.all(
                        color: cardAccent.withOpacity(0.4),
                      ),
                    ),
                    child: Icon(
                      isNew
                          ? Icons.fiber_new
                          : (isActive ? Icons.person : Icons.person_off),
                      color: cardAccent,
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
                                _normalizeText(user['name']),
                                style: TextStyle(
                                  color: onSurface,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            if (browserIp.isNotEmpty)
                              GestureDetector(
                                onTap: () => _openBrowser(user),
                                child: Tooltip(
                                  message: 'http://$browserIp/login.html',
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.cyan.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: Colors.cyan.withOpacity(0.35),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.open_in_browser,
                                          color: Colors.cyan,
                                          size: 14,
                                        ),
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
                            if (isNew)
                              _buildPill(
                                'جديد',
                                Colors.amber,
                                icon: Icons.fiber_new,
                              ),
                            if (profile.isNotEmpty)
                              _buildPill(
                                'الباقة: $profile',
                                AppTheme.gold,
                              ),
                            _buildPill(
                              isPaid ? 'مدفوع' : 'غير مدفوع',
                              isPaid ? Colors.green : Colors.red,
                            ),
                            if (user['expiry-date'] != null)
                              _buildPill('له تاريخ', Colors.teal),
                            if (user['expiry-date'] == null)
                              _buildPill('بدون تاريخ', Colors.blueGrey),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (isActive) ...[
                    const SizedBox(width: 8),
                    _buildSpeedBadge(rx, tx),
                  ],
                ],
              ),
              if (isActive) ...[
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Icon(
                      Icons.access_time_rounded,
                      size: 12,
                      color: onSurface.withOpacity(0.65),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _formatUptime(uptime),
                      style: TextStyle(
                        color: onSurface.withOpacity(0.8),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              if (phone.isNotEmpty) _buildInfoLine('الهاتف', phone),
              if (expiry.isNotEmpty) _buildInfoLine('الصلاحية', expiry),
              if (note.isNotEmpty) _buildInfoLine('الكومنت', note),
              const SizedBox(height: 8),
              if (status == 'active')
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
                    color: Colors.red,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                )
              else if (status == 'expired')
                Text(
                  isActive
                      ? 'منتهي - ما زال يعمل'
                      : 'منتهي - سيُنقل إلى بروفايل Xpirer',
                  style: TextStyle(
                    color: Colors.orange,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                )
              else if (isNew)
                Text(
                  'حساب جديد لم يتصل بعد',
                  style: TextStyle(
                    color: Colors.amber,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                )
              else
                Text(
                  'غير متصل',
                  style: TextStyle(
                    color: Colors.blue,
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
    final chips = [
      ('all', 'الكل', _countFilter('all')),
      ('active', 'متصل', _countFilter('active')),
      ('offline', 'غير متصل', _countFilter('offline')),
      ('disabled', 'معطل', _countFilter('disabled')),
      ('expired', 'منتهي', _countFilter('expired')),
      ('paid', 'مدفوع', _countFilter('paid')),
      ('unpaid', 'غير مدفوع', _countFilter('unpaid')),
      ('with-expiry', 'له تاريخ', _countFilter('with-expiry')),
      ('without-expiry', 'بدون تاريخ', _countFilter('without-expiry')),
      ('new', 'جديد', _countFilter('new')),
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

  Widget _buildBottomBar({required bool onMain}) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: onMain ? () => _load(background: true) : () => Navigator.of(context).pop(),
                icon: const Icon(Icons.people_alt_outlined),
                label: const Text('المستخدمين'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: onMain ? AppTheme.gold : Theme.of(context).cardColor,
                  foregroundColor: onMain ? Colors.black : Theme.of(context).colorScheme.onSurface,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onMain ? _openProfilesPage : null,
                icon: const Icon(Icons.folder_open),
                label: const Text('بروفايل'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: onMain ? Theme.of(context).colorScheme.onSurface : AppTheme.gold,
                  side: BorderSide(
                    color: onMain ? Theme.of(context).dividerColor : AppTheme.gold,
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final filteredList = filtered;

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) {
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
          ),
          title: const Text('البرودباند'),
          actions: [
            IconButton(
              onPressed: () => _load(background: true),
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
                        prefixIcon: const Icon(Icons.search, color: AppTheme.gold),
                        filled: true,
                        fillColor: Theme.of(context).cardColor,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        hintStyle: TextStyle(color: onSurface.withOpacity(0.4)),
                      ),
                      style: TextStyle(color: onSurface),
                      onChanged: (q) => setState(() => _searchQuery = q),
                    ),
                  ),
                  const SizedBox(width: 8),
                  DropdownButton<String>(
                    value: _sortBy,
                    dropdownColor: Theme.of(context).cardColor,
                    underline: const SizedBox(),
                    style: TextStyle(color: onSurface),
                    icon: Icon(Icons.sort, color: AppTheme.gold),
                    items: const [
                      DropdownMenuItem(value: 'status', child: Text('الحالة')),
                      DropdownMenuItem(value: 'new', child: Text('الجديدة')),
                      DropdownMenuItem(value: 'name', child: Text('الاسم')),
                      DropdownMenuItem(value: 'uptime', child: Text('الوقت')),
                      DropdownMenuItem(value: 'usage', child: Text('الاستخدام')),
                      DropdownMenuItem(value: 'profile', child: Text('الباقة')),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _sortBy = val);
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
                              _accounts.isEmpty
                                  ? (_loading ? 'جاري التحميل...' : 'لا توجد حسابات')
                                  : 'لا توجد نتائج',
                              style: TextStyle(color: onSurface.withOpacity(0.6)),
                            ),
                          ),
                        ],
                      )
                    : ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        itemCount: filteredList.length,
                        itemBuilder: (_, i) => _buildAccountCard(filteredList[i]),
                      ),
              ),
            ),
          ],
        ),
        bottomNavigationBar: _buildBottomBar(onMain: true),
      ),
    );
  }
}

class _ProfileField {
  final String title;
  final String value;
  const _ProfileField(this.title, this.value);
}

class _PppProfilesScreen extends StatefulWidget {
  final RouterService? routerService;
  const _PppProfilesScreen({required this.routerService});

  @override
  State<_PppProfilesScreen> createState() => _PppProfilesScreenState();
}

class _PppProfilesScreenState extends State<_PppProfilesScreen> {
  static const Duration _fetchTimeout = Duration(seconds: 18);
  static const Duration _actionTimeout = Duration(seconds: 12);

  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _rateLimitController = TextEditingController();

  Timer? _refreshTimer;
  bool _loading = false;
  String _searchQuery = '';
  List<Map<String, dynamic>> _profiles = [];
  List<Map<String, dynamic>> _lastProfiles = [];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      if (mounted) {
        setState(() => _searchQuery = _searchController.text.trim());
      }
    });
    _load(initial: true);
    _refreshTimer = Timer.periodic(const Duration(seconds: 12), (_) {
      _load(background: true);
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _searchController.dispose();
    _nameController.dispose();
    _rateLimitController.dispose();
    super.dispose();
  }

  String _normalize(dynamic value) => value?.toString().trim() ?? '';

  Future<List<Map<String, dynamic>>?> _safeFetchProfiles() async {
    if (widget.routerService == null) return null;
    try {
      final result = await widget.routerService!
          .sendCommand('/ppp/profile/print', useCache: false)
          .timeout(_fetchTimeout);
      return List<Map<String, dynamic>>.from(result);
    } catch (_) {
      return null;
    }
  }

  Future<void> _load({bool initial = false, bool background = false}) async {
    if (widget.routerService == null) return;
    if (_loading) return;

    _loading = true;
    if (mounted && (initial || !background)) {
      setState(() {});
    }

    try {
      final result = await _safeFetchProfiles();
      if (result != null) {
        _lastProfiles = result;
      }
      if (!mounted) return;
      setState(() {
        _profiles = result ?? _lastProfiles;
        _loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _loading = false);
      }
    } finally {
      _loading = false;
    }
  }

  String _pick(Map<String, dynamic> item, List<String> keys) {
    for (final key in keys) {
      final v = _normalize(item[key]);
      if (v.isNotEmpty) return v;
    }
    return '';
  }

  List<Map<String, dynamic>> get _filteredProfiles {
    final q = _searchQuery.toLowerCase();
    final list = List<Map<String, dynamic>>.from(_profiles);
    list.sort((a, b) {
      final an = _normalize(a['name']).toLowerCase();
      final bn = _normalize(b['name']).toLowerCase();
      return an.compareTo(bn);
    });
    if (q.isEmpty) return list;
    return list.where((p) {
      final blob = [
        p['name'],
        p['rate-limit'],
        p['only-one'],
        p['change-tcp-mss'],
        p['use-compression'],
        p['use-vj-compression'],
        p['session-timeout'],
        p['bridge'],
        p['local-address'],
        p['remote-address'],
        p['incoming-filter'],
        p['outgoing-filter'],
        p['dns-server'],
        p['address-list'],
        p['parent-queue'],
        p['limit-bytes-in'],
        p['limit-bytes-out'],
      ].map((e) => e?.toString().toLowerCase() ?? '').join(' | ');
      return blob.contains(q);
    }).toList();
  }

  Future<void> _saveProfile({Map<String, dynamic>? profile}) async {
    final isEdit = profile != null;
    String selectedPool = '';

    if (isEdit) {
      _nameController.text = _normalize(profile['name']);
      _rateLimitController.text = _normalize(profile['rate-limit']);
      selectedPool = _normalize(profile['remote-address']);
    } else {
      _nameController.clear();
      _rateLimitController.clear();
    }

    List<String> pools = [];
    if (widget.routerService != null) {
      try {
        final res = await widget.routerService!
            .sendCommand('/ip/pool/print', useCache: false)
            .timeout(_actionTimeout);
        pools = res
            .map((e) => _normalize(e['name']))
            .where((name) => name.isNotEmpty)
            .toList();
      } catch (_) {}
    }

    if (selectedPool.isNotEmpty && !pools.contains(selectedPool)) {
      pools.add(selectedPool);
    }
    if (pools.isNotEmpty && selectedPool.isEmpty) {
      selectedPool = pools.first;
    }

    if (!mounted) return;

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setStateBuilder) {
          return AlertDialog(
            backgroundColor: AppTheme.semiBlack,
            title: Text(
              isEdit ? 'تعديل بروفايل' : 'إضافة بروفايل',
              style: const TextStyle(color: Colors.white),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: _nameController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'الاسم',
                      labelStyle: TextStyle(color: Colors.white70),
                      filled: true,
                      fillColor: Colors.white10,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _rateLimitController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'تحديد السرعة (Rate Limit)',
                      hintText: 'مثال: 2M/2M',
                      hintStyle: TextStyle(color: Colors.white38),
                      labelStyle: TextStyle(color: Colors.white70),
                      filled: true,
                      fillColor: Colors.white10,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (pools.isNotEmpty)
                    DropdownButtonFormField<String>(
                      value: selectedPool.isNotEmpty ? selectedPool : null,
                      dropdownColor: AppTheme.semiBlack,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'رنج الآيبي (IP Pool)',
                        labelStyle: TextStyle(color: Colors.white70),
                        filled: true,
                        fillColor: Colors.white10,
                      ),
                      items: pools.map((String pool) {
                        return DropdownMenuItem<String>(
                          value: pool,
                          child: Text(pool),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          setStateBuilder(() {
                            selectedPool = newValue;
                          });
                        }
                      },
                    )
                  else
                    const Text(
                      'لا توجد Pool Address متوفرة',
                      style: TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('إلغاء', style: TextStyle(color: Colors.white54)),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(
                  isEdit ? 'حفظ' : 'إضافة',
                  style: TextStyle(color: AppTheme.gold),
                ),
              ),
            ],
          );
        },
      ),
    );

    if (result != true) return;
    final name = _nameController.text.trim();
    final rateLimit = _rateLimitController.text.trim();
    
    if (name.isEmpty) return;

    final numbers = isEdit ? _normalize(profile['.id']) : '';

    Map<String, String> params = {
      'name': name,
    };
    
    if (rateLimit.isNotEmpty) params['rate-limit'] = rateLimit;
    if (selectedPool.isNotEmpty) params['remote-address'] = selectedPool;

    try {
      if (isEdit) {
        params['numbers'] = numbers;
        await widget.routerService?.sendCommand(
          '/ppp/profile/set',
          params: params,
        ).timeout(_actionTimeout);
      } else {
        params['only-one'] = 'yes';
        params['change-tcp-mss'] = 'yes';
        await widget.routerService?.sendCommand(
          '/ppp/profile/add',
          params: params,
        ).timeout(_actionTimeout);
      }
      await _load(background: true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isEdit ? 'تعذر تعديل البروفايل: $e' : 'تعذر إضافة البروفايل: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteProfile(Map<String, dynamic> profile) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.semiBlack,
        title: const Text('تأكيد الحذف', style: TextStyle(color: Colors.white)),
        content: Text(
          'هل تريد حذف البروفايل "${_normalize(profile['name'])}"؟',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final id = _normalize(profile['.id']);
    if (id.isEmpty) return;

    try {
      await widget.routerService?.sendCommand(
        '/ppp/profile/remove',
        params: {'numbers': id},
      ).timeout(_actionTimeout);
      await _load(background: true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تعذر حذف البروفايل: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showProfileActions(Map<String, dynamic> profile) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.semiBlack,
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.edit, color: AppTheme.gold),
              title: const Text('تعديل', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _saveProfile(profile: profile);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_forever, color: Colors.red),
              title: const Text('حذف', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _deleteProfile(profile);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileCard(Map<String, dynamic> profile) {
    final name = _normalize(profile['name']);
    final rateLimit = _normalize(profile['rate-limit']);
    final server = _pick(profile, ['service', 'server', 'bridge', 'interface']);
    final remoteAddress = _pick(profile, ['remote-address']);

    final fields = <_ProfileField>[
      _ProfileField('السيرفر', server.isEmpty ? '-' : server),
      _ProfileField('السرعة', rateLimit.isEmpty ? '-' : rateLimit),
      _ProfileField('رنج الآيبي', remoteAddress.isEmpty ? '-' : remoteAddress),
      _ProfileField('Rate Limit', rateLimit.isEmpty ? '-' : rateLimit),
      _ProfileField('Only One', _pick(profile, ['only-one']).isEmpty ? '-' : _pick(profile, ['only-one'])),
      _ProfileField('Change TCP MSS', _pick(profile, ['change-tcp-mss']).isEmpty ? '-' : _pick(profile, ['change-tcp-mss'])),
      _ProfileField('Local Address', _pick(profile, ['local-address']).isEmpty ? '-' : _pick(profile, ['local-address'])),
      _ProfileField('Remote Address', remoteAddress.isEmpty ? '-' : remoteAddress),
      _ProfileField('Session Timeout', _pick(profile, ['session-timeout']).isEmpty ? '-' : _pick(profile, ['session-timeout'])),
      _ProfileField('Keepalive Timeout', _pick(profile, ['keepalive-timeout']).isEmpty ? '-' : _pick(profile, ['keepalive-timeout'])),
      _ProfileField('Address List', _pick(profile, ['address-list']).isEmpty ? '-' : _pick(profile, ['address-list'])),
      _ProfileField('Incoming Filter', _pick(profile, ['incoming-filter']).isEmpty ? '-' : _pick(profile, ['incoming-filter'])),
      _ProfileField('Outgoing Filter', _pick(profile, ['outgoing-filter']).isEmpty ? '-' : _pick(profile, ['outgoing-filter'])),
      _ProfileField('DNS', _pick(profile, ['dns-server']).isEmpty ? '-' : _pick(profile, ['dns-server'])),
      _ProfileField('Parent Queue', _pick(profile, ['parent-queue']).isEmpty ? '-' : _pick(profile, ['parent-queue'])),
      _ProfileField('Bridge Path Cost', _pick(profile, ['bridge-path-cost']).isEmpty ? '-' : _pick(profile, ['bridge-path-cost'])),
      _ProfileField('Bridge Horizon', _pick(profile, ['bridge-horizon']).isEmpty ? '-' : _pick(profile, ['bridge-horizon'])),
      _ProfileField('Bridge Learning', _pick(profile, ['bridge-learning']).isEmpty ? '-' : _pick(profile, ['bridge-learning'])),
      _ProfileField('Comment', _pick(profile, ['comment']).isEmpty ? '-' : _pick(profile, ['comment'])),
    ];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.gold.withOpacity(0.35)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () => _showProfileActions(profile),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.gold.withOpacity(0.12),
                      border: Border.all(color: AppTheme.gold.withOpacity(0.35)),
                    ),
                    child: const Icon(Icons.folder, color: AppTheme.gold),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name.isEmpty ? '-' : name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _pill('السرعة: ${rateLimit.isEmpty ? '-' : rateLimit}', Colors.green),
                            if (remoteAddress.isNotEmpty)
                              _pill('IP Pool: $remoteAddress', Colors.cyan),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: fields.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 3.1,
                ),
                itemBuilder: (_, index) {
                  final item = fields[index];
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          item.title,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          item.value,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.people_alt_outlined),
                label: const Text('المستخدمين'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).cardColor,
                  foregroundColor: Theme.of(context).colorScheme.onSurface,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _load(background: true),
                icon: const Icon(Icons.folder_open),
                label: const Text('بروفايل'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.gold,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final list = _filteredProfiles;

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) {
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
          ),
          title: const Text('البروفايلات'),
          actions: [
            IconButton(
              onPressed: () => _load(background: true),
              icon: const Icon(Icons.refresh),
              tooltip: 'تحديث',
            ),
            IconButton(
              onPressed: () => _saveProfile(),
              icon: const Icon(Icons.add),
              tooltip: 'إضافة بروفايل',
            ),
          ],
        ),
        body: Column(
          children: [
            if (_loading) const LinearProgressIndicator(color: AppTheme.gold),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'بحث في البروفايلات...',
                  prefixIcon: const Icon(Icons.search, color: AppTheme.gold),
                  filled: true,
                  fillColor: Theme.of(context).cardColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.35)),
                ),
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _load,
                child: widget.routerService == null
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: const [
                          SizedBox(height: 120),
                          Center(
                            child: Text(
                              'لا يوجد RouterService',
                              style: TextStyle(color: Colors.white70),
                            ),
                          ),
                        ],
                      )
                    : list.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [
                              const SizedBox(height: 120),
                              Center(
                                child: Text(
                                  _profiles.isEmpty
                                      ? (_loading ? 'جاري التحميل...' : 'لا توجد بروفايلات')
                                      : 'لا توجد نتائج',
                                  style: const TextStyle(color: Colors.white70),
                                ),
                              ),
                            ],
                          )
                        : ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            itemCount: list.length,
                            itemBuilder: (_, i) => _buildProfileCard(list[i]),
                          ),
              ),
            ),
          ],
        ),
        bottomNavigationBar: _buildBottomBar(),
      ),
    );
  }
}
