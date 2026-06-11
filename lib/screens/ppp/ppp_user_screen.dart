import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:st_manager/services/router_service.dart';
import 'package:st_manager/theme/app_theme.dart';

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

class PppUserScreen extends StatefulWidget {
  final RouterService? routerService;
  final bool isEdit;
  final Map<String, dynamic>? initialData;
  const PppUserScreen({
    super.key,
    required this.routerService,
    required this.isEdit,
    this.initialData,
  });

  @override
  State<PppUserScreen> createState() => _PppUserScreenState();
}

class _PppUserScreenState extends State<PppUserScreen> {
  final _nameController = TextEditingController();
  final _passController = TextEditingController();
  final _profileController = TextEditingController();
  final _phoneController = TextEditingController();
  final _commentController = TextEditingController();

  bool _loading = false;
  bool _loadingProfiles = false;
  bool _isPaid = false;

  List<String> _profiles = [];
  String? _selectedProfile;
  DateTime? _expiryDate;

  @override
  void initState() {
    super.initState();

    if (widget.initialData != null) {
      _nameController.text = widget.initialData!['name']?.toString() ?? '';
      _passController.text = widget.initialData!['password']?.toString() ?? '';
      _profileController.text =
          widget.initialData!['profile']?.toString() ?? '';

      final rawComment = widget.initialData!['comment']?.toString() ?? '';
      final parsed = _parseComment(rawComment);
      _phoneController.text = parsed.phone;
      _commentController.text = parsed.note;
      _expiryDate = parsed.expiryDate;
      _isPaid = parsed.isPaid;
    }

    _loadProfiles();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _passController.dispose();
    _profileController.dispose();
    _phoneController.dispose();
    _commentController.dispose();
    super.dispose();
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

  String _buildComment() {
    final parts = <String>[];

    final phone = _phoneController.text.trim();
    final comment = _commentController.text.trim();

    if (phone.isNotEmpty) {
      parts.add('phone:$phone');
    }

    if (_expiryDate != null) {
      parts.add('exp:${DateFormat('yyyy-MM-dd').format(_expiryDate!)}');
    }

    if (_isPaid) {
      parts.add('paid:true');
    } else {
      parts.add('paid:false');
    }

    if (comment.isNotEmpty) {
      parts.add(comment);
    }

    return parts.join(' | ');
  }

  Future<void> _loadProfiles() async {
    if (widget.routerService == null) return;

    setState(() => _loadingProfiles = true);

    try {
      final result = await widget.routerService!.sendCommand(
        '/ppp/profile/print',
        useCache: false,
      );

      final names = result
          .map((e) => e['name']?.toString().trim() ?? '')
          .where((name) => name.isNotEmpty)
          .toList();

      final currentProfile = widget.initialData?['profile']?.toString().trim();

      if (currentProfile != null &&
          currentProfile.isNotEmpty &&
          !names.contains(currentProfile)) {
        names.insert(0, currentProfile);
      }

      if (mounted) {
        setState(() {
          _profiles = names;
          _selectedProfile = currentProfile?.isNotEmpty == true
              ? currentProfile
              : (names.isNotEmpty ? names.first : null);

          if (_selectedProfile != null) {
            _profileController.text = _selectedProfile!;
          }

          _loadingProfiles = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loadingProfiles = false);
      }
    }
  }

  Future<void> _pickExpiryDate() async {
    final initial = _expiryDate ?? DateTime.now().add(const Duration(days: 30));

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime(2100),
    );

    if (picked != null && mounted) {
      setState(() => _expiryDate = picked);
    }
  }

  Future<void> _clearExpiryDate() async {
    if (!mounted) return;
    setState(() => _expiryDate = null);
  }

  Future<void> _save() async {
    if (widget.routerService == null) return;

    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    setState(() => _loading = true);

    try {
      final profile = (_selectedProfile?.trim().isNotEmpty == true)
          ? _selectedProfile!.trim()
          : _profileController.text.trim();

      final params = <String, dynamic>{
        'name': name,
        'password': _passController.text.trim(),
        'comment': _buildComment(),
      };

      if (profile.isNotEmpty) {
        params['profile'] = profile;
      }

      if (widget.isEdit && widget.initialData != null) {
        params['numbers'] = widget.initialData!['.id']?.toString() ?? '';
        await widget.routerService!.sendCommand(
          '/ppp/secret/set',
          params: params,
        );
      } else {
        await widget.routerService!.sendCommand(
          '/ppp/secret/add',
          params: params,
        );
      }

      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('فشل الحفظ')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Widget _buildProfileField() {
    if (_loadingProfiles) {
      return const LinearProgressIndicator(color: AppTheme.gold);
    }

    if (_profiles.isNotEmpty) {
      return DropdownButtonFormField<String>(
        value: _selectedProfile,
        isExpanded: true,
        decoration: const InputDecoration(
          labelText: 'البروفايل',
          hintText: 'اختر بروفايل من الراوتر',
        ),
        dropdownColor: AppTheme.semiBlack,
        style: const TextStyle(color: Colors.white),
        items: _profiles
            .map(
              (profile) => DropdownMenuItem<String>(
                value: profile,
                child: Text(profile),
              ),
            )
            .toList(),
        onChanged: (value) {
          setState(() {
            _selectedProfile = value;
            if (value != null) {
              _profileController.text = value;
            }
          });
        },
      );
    }

    return TextField(
      controller: _profileController,
      decoration: const InputDecoration(
        labelText: 'البروفايل (يدوي)',
        hintText: 'إذا لم يتم جلب البروفايلات',
      ),
      style: const TextStyle(color: Colors.white),
    );
  }

  Widget _buildExpiryCard() {
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.gold.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'صلاحية الحساب',
            style: TextStyle(
              color: onSurface,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _expiryDate == null
                ? 'بدون صلاحية محددة'
                : 'تنتهي في: ${DateFormat('yyyy-MM-dd').format(_expiryDate!)}',
            style: TextStyle(
              color: onSurface.withOpacity(0.75),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              TextButton.icon(
                onPressed: _pickExpiryDate,
                icon: const Icon(Icons.date_range, color: AppTheme.gold),
                label: const Text('تحديد الصلاحية'),
              ),
              const SizedBox(width: 8),
              if (_expiryDate != null)
                TextButton.icon(
                  onPressed: _clearExpiryDate,
                  icon: const Icon(Icons.clear, color: Colors.red),
                  label: const Text('إلغاء'),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'عند انتهاء الصلاحية سيتم نقل الحساب إلى بروفايل Xpirer بسرعة 512K/512K.',
            style: TextStyle(
              color: onSurface.withOpacity(0.65),
              fontSize: 11,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEdit ? 'تعديل حساب PPP' : 'إضافة حساب PPP'),
        actions: [
          IconButton(
            onPressed: _loadProfiles,
            icon: const Icon(Icons.refresh),
            tooltip: 'تحديث البروفايلات',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'اسم المستخدم',
                  filled: true,
                  fillColor: Theme.of(context).cardColor,
                ),
                style: TextStyle(color: onSurface),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _passController,
                decoration: InputDecoration(
                  labelText: 'كلمة المرور',
                  filled: true,
                  fillColor: Theme.of(context).cardColor,
                ),
                style: TextStyle(color: onSurface),
                obscureText: true,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _phoneController,
                decoration: InputDecoration(
                  labelText: 'رقم هاتف الزبون (للإشعارات)',
                  hintText: 'مثلاً 963xxxxxxxxx',
                  filled: true,
                  fillColor: Theme.of(context).cardColor,
                ),
                keyboardType: TextInputType.phone,
                style: TextStyle(color: onSurface),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _commentController,
                decoration: InputDecoration(
                  labelText: 'تعليق / ملاحظات',
                  hintText: 'أي ملاحظات إضافية',
                  filled: true,
                  fillColor: Theme.of(context).cardColor,
                ),
                style: TextStyle(color: onSurface),
              ),
              const SizedBox(height: 12),
              _buildExpiryCard(),
              const SizedBox(height: 12),
              _buildProfileField(),
              const SizedBox(height: 12),
              SwitchListTile(
                title: const Text('تم دفع الاشتراك'),
                value: _isPaid,
                activeColor: AppTheme.gold,
                tileColor: Theme.of(context).cardColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                onChanged: (val) {
                  setState(() {
                    _isPaid = val;
                  });
                },
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : _save,
                  child: _loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.black,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text('حفظ'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
