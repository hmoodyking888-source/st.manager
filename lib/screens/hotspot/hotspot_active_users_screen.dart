import 'dart:async';
import 'package:flutter/material.dart';
import 'package:st_manager/services/router_service.dart';
import 'package:st_manager/screens/hotspot/hotspot_user_screen.dart';
import 'package:st_manager/theme/app_theme.dart';

class _TrafficSample {
  final int bytes;
  final DateTime time;
  const _TrafficSample(this.bytes, this.time);
}

class HotspotActiveUsersScreen extends StatefulWidget {
  final RouterService? routerService;
  const HotspotActiveUsersScreen({super.key, required this.routerService});

  @override
  State<HotspotActiveUsersScreen> createState() =>
      _HotspotActiveUsersScreenState();
}

class _HotspotActiveUsersScreenState extends State<HotspotActiveUsersScreen> {
  List<Map<String, dynamic>> _users = [];
  String _filter = 'all';
  String _searchQuery = '';
  String _sortBy = 'name';
  bool _loading = false;

  // وضع التحديد المتعدد
  bool _selectionMode = false;
  final Set<String> _selectedIds = {};

  final Map<String, _TrafficSample> _previousTraffic = {};
  final Map<String, double> _liveSpeeds = {};
  Timer? _refreshTimer;

  bool _showTx = false; // ✅ متغير التبديل بين RX و TX

  @override
  void initState() {
    super.initState();
    _loadUsers(initial: true);
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => _loadUsers(),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  String _userKey(Map<String, dynamic> item) {
    return item['name']?.toString().trim().isNotEmpty == true
        ? item['name'].toString().trim()
        : item['.id']?.toString().trim() ?? '';
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

  int _extractBytesTotal(Map<String, dynamic> activeEntry) {
    final bytesIn = _toInt(activeEntry['bytes-in']);
    final bytesOut = _toInt(activeEntry['bytes-out']);
    if (bytesIn + bytesOut > 0) return bytesIn + bytesOut;
    final rx = _toInt(activeEntry['rx-byte']);
    final tx = _toInt(activeEntry['tx-byte']);
    if (rx + tx > 0) return rx + tx;
    return _toInt(activeEntry['total-bytes']);
  }

  void _updateTrafficSpeed(Map<String, Map<String, dynamic>> activeByName) {
    final now = DateTime.now();
    final nextKeys = <String>{};
    for (final entry in activeByName.entries) {
      final key = entry.key;
      final activeEntry = entry.value;
      final totalBytes = _extractBytesTotal(activeEntry);
      final previous = _previousTraffic[key];
      double speedMbps = 0;
      if (previous != null) {
        final diffBytes = totalBytes - previous.bytes;
        final diffSeconds =
            now.difference(previous.time).inMilliseconds / 1000.0;
        if (diffBytes >= 0 && diffSeconds > 0) {
          speedMbps = (diffBytes * 8) / diffSeconds / 1000000;
        }
      }
      _liveSpeeds[key] = speedMbps;
      _previousTraffic[key] = _TrafficSample(totalBytes, now);
      nextKeys.add(key);
    }
    _previousTraffic.removeWhere((key, _) => !nextKeys.contains(key));
    _liveSpeeds.removeWhere((key, _) => !nextKeys.contains(key));
  }

  Future<void> _loadUsers({bool initial = false}) async {
    if (widget.routerService == null) return;
    if (initial && mounted) setState(() => _loading = true);
    try {
      widget.routerService!.clearCache();
      final active = await widget.routerService!.getHotspotActive();
      final all = await widget.routerService!.getHotspotUsers();
      final activeByName = <String, Map<String, dynamic>>{};
      for (final a in active) {
        final key =
            (a['user'] ?? a['name'] ?? a['username'] ?? '').toString().trim();
        if (key.isNotEmpty) activeByName[key] = a;
      }
      _updateTrafficSpeed(activeByName);
      final merged = all.map((u) {
        final name = u['name']?.toString().trim() ?? '';
        final activeData = activeByName[name] ?? <String, dynamic>{};
        return {
          ...u,
          'active': activeData.isNotEmpty,
          'active-id': activeData['.id']?.toString() ??
              activeData['id']?.toString() ??
              '',
          'bytes-out': activeData['bytes-out'] ?? u['bytes-out'] ?? '0',
          'uptime': activeData['uptime'] ?? u['uptime'] ?? '',
          'speed-mbps': _liveSpeeds[name] ?? 0,
        };
      }).toList();
      if (!mounted) return;
      setState(() {
        _users = merged;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> get filtered {
    var list = _users.where((u) {
      if (_filter == 'active') return u['active'] == true;
      if (_filter == 'disabled') return _isDisabled(u);
      if (_filter == 'expired') return _isDisabled(u);
      return true;
    }).toList();

    if (_searchQuery.isNotEmpty) {
      list = list.where((u) {
        final name = (u['name'] ?? '').toString().toLowerCase();
        return name.contains(_searchQuery.toLowerCase());
      }).toList();
    }

    switch (_sortBy) {
      case 'uptime':
        list.sort((a, b) => (a['uptime'] ?? '')
            .toString()
            .compareTo((b['uptime'] ?? '').toString()));
        break;
      case 'usage':
        list.sort((a, b) {
          final aSpeed = (a['speed-mbps'] as double?) ?? 0;
          final bSpeed = (b['speed-mbps'] as double?) ?? 0;
          return bSpeed.compareTo(aSpeed);
        });
        break;
      case 'profile':
        list.sort((a, b) => (a['profile'] ?? '')
            .toString()
            .compareTo((b['profile'] ?? '').toString()));
        break;
      default:
        list.sort((a, b) => (a['name'] ?? '')
            .toString()
            .compareTo((b['name'] ?? '').toString()));
    }
    return list;
  }

  int _countStatus(String status) {
    if (status == 'all') return _users.length;
    return _users.where((u) {
      if (status == 'active') return u['active'] == true;
      if (status == 'disabled') return _isDisabled(u);
      if (status == 'expired') return _isDisabled(u);
      return false;
    }).length;
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
        if (_selectedIds.isEmpty) _selectionMode = false;
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _selectAll() {
    setState(() {
      _selectionMode = true;
      for (final u in filtered) {
        final id = u['.id']?.toString() ?? '';
        if (id.isNotEmpty) _selectedIds.add(id);
      }
    });
  }

  void _clearSelection() {
    setState(() {
      _selectionMode = false;
      _selectedIds.clear();
    });
  }

  Future<void> _deleteSelected() async {
    if (_selectedIds.isEmpty) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.semiBlack,
        title: const Text('تأكيد الحذف', style: TextStyle(color: Colors.white)),
        content: Text('حذف ${_selectedIds.length} حساب؟',
            style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    for (final id in _selectedIds) {
      await widget.routerService?.sendCommand(
        '/ip/hotspot/user/remove',
        params: {'numbers': id},
      );
    }
    _clearSelection();
    _loadUsers();
  }

  Future<void> _ensureSpeedProfile() async {
    try {
      await widget.routerService!.sendCommand(
        '/ip/hotspot/user/profile/add',
        params: {'name': 'Speed', 'rate-limit': ''},
      );
    } catch (_) {}
  }

  Future<void> _boostUserSpeed(Map<String, dynamic> user) async {
    if (widget.routerService == null) return;
    final activeId = user['active-id']?.toString() ?? '';
    final userId = user['.id']?.toString() ?? '';
    await _ensureSpeedProfile();
    if (userId.isNotEmpty) {
      await widget.routerService?.sendCommand(
        '/ip/hotspot/user/set',
        params: {'numbers': userId, 'profile': 'Speed'},
      );
    }
    if (user['active'] == true && activeId.isNotEmpty) {
      await widget.routerService?.sendCommand(
        '/ip/hotspot/active/remove',
        params: {'numbers': activeId},
      );
    }
    _loadUsers();
  }

  void _showUserActions(Map<String, dynamic> user) {
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
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => HotspotUserScreen(
                      routerService: widget.routerService,
                      isEdit: true,
                      initialData: user,
                    ),
                  ),
                ).then((_) => _loadUsers());
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('حذف', style: TextStyle(color: Colors.white)),
              onTap: () async {
                Navigator.pop(context);
                final userId = user['.id']?.toString() ?? '';
                if (userId.isNotEmpty) {
                  await widget.routerService?.sendCommand(
                    '/ip/hotspot/user/remove',
                    params: {'numbers': userId},
                  );
                  _loadUsers();
                }
              },
            ),
            ListTile(
              leading: Icon(
                Icons.block,
                color: _isDisabled(user) ? Colors.green : Colors.orange,
              ),
              title: Text(
                _isDisabled(user) ? 'تفعيل' : 'تعطيل',
                style: const TextStyle(color: Colors.white),
              ),
              onTap: () async {
                Navigator.pop(context);
                final disable = _isDisabled(user) ? 'no' : 'yes';
                final userId = user['.id']?.toString() ?? '';
                if (userId.isNotEmpty) {
                  await widget.routerService?.sendCommand(
                    '/ip/hotspot/user/set',
                    params: {'numbers': userId, 'disabled': disable},
                  );
                  _loadUsers();
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.speed, color: AppTheme.gold),
              title: const Text('فتح السرعة',
                  style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _boostUserSpeed(user);
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
        builder: (_) => HotspotUserScreen(
          routerService: widget.routerService,
          isEdit: false,
        ),
      ),
    ).then((_) => _loadUsers());
  }

  String _formatSpeed(double speedMbps) {
    if (speedMbps >= 1000)
      return '${(speedMbps / 1000).toStringAsFixed(1)} Gbps';
    if (speedMbps >= 1) return '${speedMbps.toStringAsFixed(1)} Mbps';
    return '${(speedMbps * 1000).toStringAsFixed(0)} Kbps';
  }

  Widget _buildCommentBox(String comment) {
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white12),
      ),
      child: Text(
        comment,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: AppTheme.gold, fontSize: 10, height: 1.2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredList = filtered;
    final all = _users.length;
    final activeCnt = _countStatus('active');
    final disabledCnt = _countStatus('disabled');
    final expiredCnt = _countStatus('expired');

    return Scaffold(
      appBar: AppBar(
        title: const Text('جميع حسابات الهوتسبوت'),
        actions: [
          if (_selectionMode) ...[
            IconButton(
              icon: const Icon(Icons.select_all),
              tooltip: 'تحديد الكل',
              onPressed: _selectAll,
            ),
            IconButton(
              icon: const Icon(Icons.delete_sweep, color: Colors.red),
              tooltip: 'حذف المحدد',
              onPressed: _deleteSelected,
            ),
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: 'إلغاء التحديد',
              onPressed: _clearSelection,
            ),
          ] else ...[
            IconButton(
              icon: const Icon(Icons.checklist),
              tooltip: 'تحديد متعدد',
              onPressed: () => setState(() => _selectionMode = true),
            ),
          ],
        ],
      ),
      floatingActionButton: _selectionMode
          ? null
          : FloatingActionButton(
              backgroundColor: AppTheme.gold,
              onPressed: _addNewAccount,
              child: const Icon(Icons.person_add),
            ),
      body: Column(
        children: [
          if (_loading) const LinearProgressIndicator(color: AppTheme.gold),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final entry in {
                    'all': 'الكل ($all)',
                    'active': 'متصل ($activeCnt)',
                    'disabled': 'معطل ($disabledCnt)',
                    'expired': 'منتهي ($expiredCnt)',
                  }.entries)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text(entry.value,
                            style: const TextStyle(fontSize: 11)),
                        selected: _filter == entry.key,
                        onSelected: (v) => setState(() => _filter = entry.key),
                        selectedColor: AppTheme.gold,
                        backgroundColor: AppTheme.darkGrey,
                        labelStyle: TextStyle(
                          color: _filter == entry.key
                              ? Colors.black
                              : AppTheme.gold,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
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
                  items: const [
                    DropdownMenuItem(value: 'name', child: Text('الاسم')),
                    DropdownMenuItem(
                        value: 'uptime', child: Text('وقت التشغيل')),
                    DropdownMenuItem(value: 'usage', child: Text('الأعلى سحب')),
                    DropdownMenuItem(
                        value: 'profile', child: Text('البروفايل')),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => _sortBy = v);
                  },
                ),
              ],
            ),
          ),
          if (_selectionMode)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
              color: AppTheme.gold.withOpacity(0.1),
              child: Text(
                'تم تحديد ${_selectedIds.length} من ${filteredList.length}',
                style: const TextStyle(color: AppTheme.gold, fontSize: 12),
              ),
            ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadUsers,
              child: filteredList.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        const SizedBox(height: 120),
                        Center(
                          child: Text(
                            'لا توجد حسابات مطابقة',
                            style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withOpacity(0.6),
                            ),
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: filteredList.length,
                      itemBuilder: (_, i) {
                        final u = filteredList[i];
                        final isActive = u['active'] == true;
                        final comment = (u['comment'] ?? '').toString();
                        final phone = (u['phone'] ?? '').toString();
                        final speed = (u['speed-mbps'] as double?) ?? 0;
                        final id = u['.id']?.toString() ?? '';
                        final isSelected = _selectedIds.contains(id);

                        return Card(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          child: InkWell(
                            onTap: _selectionMode
                                ? () => _toggleSelection(id)
                                : () => _showUserActions(u),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 4, vertical: 4),
                              child: Row(
                                children: [
                                  if (_selectionMode)
                                    Checkbox(
                                      value: isSelected,
                                      onChanged: (_) => _toggleSelection(id),
                                      activeColor: AppTheme.gold,
                                    ),
                                  Icon(
                                    isActive ? Icons.person : Icons.person_off,
                                    color: isActive
                                        ? AppTheme.greenOnline
                                        : Colors.grey,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          u['name']?.toString() ?? '',
                                          style: const TextStyle(
                                              color: Colors.white),
                                        ),
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              isActive
                                                  ? 'متصل • ${u['uptime']?.toString() ?? ''}'
                                                  : 'غير متصل',
                                              style: const TextStyle(
                                                color: Colors.white54,
                                                fontSize: 11,
                                              ),
                                            ),
                                            if (phone.isNotEmpty)
                                              Text(
                                                '📞 $phone',
                                                style: const TextStyle(
                                                  color: Colors.white54,
                                                  fontSize: 11,
                                                ),
                                              ),
                                            if (comment.isNotEmpty)
                                              _buildCommentBox(comment),
                                            if (u['profile']
                                                    ?.toString()
                                                    .isNotEmpty ??
                                                false)
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                    top: 4),
                                                child: Text(
                                                  'البروفايل: ${u['profile']}',
                                                  style: const TextStyle(
                                                    color: Colors.white54,
                                                    fontSize: 11,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (isActive && !_selectionMode)
                                    GestureDetector(
                                      onTap: () =>
                                          setState(() => _showTx = !_showTx),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: AppTheme.greenOnline
                                              .withOpacity(0.14),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          border: Border.all(
                                              color: AppTheme.greenOnline
                                                  .withOpacity(0.5)),
                                        ),
                                        child: Column(children: [
                                          Text(
                                            _showTx ? 'TX' : 'RX',
                                            style: const TextStyle(
                                                color: Colors.white70,
                                                fontSize: 9),
                                          ),
                                          Text(
                                            _formatSpeed(speed),
                                            style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold),
                                          ),
                                        ]),
                                      ),
                                    ),
                                ],
                              ),
                            ),
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
