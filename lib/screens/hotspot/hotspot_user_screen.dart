import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:st_manager/services/router_service.dart';
import 'package:st_manager/theme/app_theme.dart';

class HotspotUserScreen extends StatefulWidget {
  final RouterService? routerService;
  final bool isEdit;
  final Map<String, dynamic>? initialData;

  const HotspotUserScreen({
    super.key,
    required this.routerService,
    required this.isEdit,
    this.initialData,
  });

  @override
  State<HotspotUserScreen> createState() => _HotspotUserScreenState();
}

class _HotspotUserScreenState extends State<HotspotUserScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _passController = TextEditingController();
  final _phoneController = TextEditingController();
  final _commentController = TextEditingController();
  final _manualProfileController = TextEditingController();

  String? _selectedProfile;
  List<String> _profiles = [];
  bool _loading = false;
  bool _showPass = false;
  bool _isDisabled = false;

  // ─── حقول إضافية ───
  int _timeLimitHours = 0; // 0 = بلا حد
  int _dataLimitMb = 0; // 0 = بلا حد
  int _macLimit = 0; // 0 = بلا حد (عدد أجهزة)

  @override
  void initState() {
    super.initState();
    if (widget.initialData != null) {
      final d = widget.initialData!;
      _nameController.text = d['name']?.toString() ?? '';
      _passController.text = d['password']?.toString() ?? '';

      final disabled = d['disabled']?.toString().toLowerCase().trim();
      _isDisabled = disabled == 'true' || disabled == 'yes' || disabled == '1';

      final limitUptime =
          int.tryParse(d['limit-uptime']?.toString() ?? '') ?? 0;
      _timeLimitHours = limitUptime ~/ 3600;

      _dataLimitMb =
          int.tryParse(d['limit-bytes-total']?.toString() ?? '') ?? 0;
      if (_dataLimitMb > 0)
        _dataLimitMb = (_dataLimitMb / (1024 * 1024)).round();

      _macLimit = int.tryParse(d['mac-addresses']?.toString() ?? '0') ?? 0;

      final profile = d['profile']?.toString().trim();
      if (profile != null && profile.isNotEmpty) {
        _selectedProfile = profile;
        _manualProfileController.text = profile;
      }

      _parseComment(d['comment']?.toString() ?? '');
    }

    _loadProfiles();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _passController.dispose();
    _phoneController.dispose();
    _commentController.dispose();
    _manualProfileController.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────
  // تحليل وبناء التعليق
  // ─────────────────────────────────────────────
  void _parseComment(String raw) {
    if (raw.isEmpty) return;
    final parts = raw.split('|').map((e) => e.trim()).toList();

    for (final part in parts) {
      if (part.toLowerCase().startsWith('phone:')) {
        _phoneController.text = part.substring(6).trim();
      } else {
        if (_commentController.text.isEmpty) {
          _commentController.text = part;
        } else {
          _commentController.text += ' | $part';
        }
      }
    }
  }

  String _buildComment() {
    final phone = _phoneController.text.trim();
    final comment = _commentController.text.trim();

    final parts = <String>[];
    if (phone.isNotEmpty) parts.add('phone:$phone');
    if (comment.isNotEmpty) parts.add(comment);
    return parts.join(' | ');
  }

  // ─────────────────────────────────────────────
  // جلب البروفايلات
  // ─────────────────────────────────────────────
  Future<void> _loadProfiles() async {
    if (widget.routerService == null) return;
    try {
      final profiles = await widget.routerService!.getHotspotProfiles();
      final names = profiles
          .map((p) => p['name']?.toString().trim() ?? '')
          .where((n) => n.isNotEmpty)
          .toList();

      final current = widget.initialData?['profile']?.toString().trim();
      if (current != null && current.isNotEmpty && !names.contains(current)) {
        names.insert(0, current);
      }

      if (!mounted) return;
      setState(() {
        _profiles = names;
        if (_selectedProfile == null && names.isNotEmpty) {
          _selectedProfile = names.first;
          _manualProfileController.text = names.first;
        }
      });
    } catch (_) {}
  }

  // ─────────────────────────────────────────────
  // ✅ حفظ المستخدم مع جميع الحقول
  // ─────────────────────────────────────────────
  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (widget.routerService == null) return;

    setState(() => _loading = true);

    try {
      final name = _nameController.text.trim();
      final pass = _passController.text.trim();
      final profile = (_selectedProfile?.trim().isNotEmpty == true)
          ? _selectedProfile!.trim()
          : _manualProfileController.text.trim();

      final params = <String, dynamic>{
        'name': name,
        'password': pass,
        'comment': _buildComment(),
        'disabled': _isDisabled ? 'yes' : 'no',
      };

      if (profile.isNotEmpty) params['profile'] = profile;

      // حد وقت الاستخدام
      if (_timeLimitHours > 0) {
        params['limit-uptime'] = '${_timeLimitHours * 3600}'; // بالثواني
      } else {
        params['limit-uptime'] = '0';
      }

      // حد البيانات بالميغابايت
      if (_dataLimitMb > 0) {
        params['limit-bytes-total'] = '${_dataLimitMb * 1024 * 1024}';
      } else {
        params['limit-bytes-total'] = '0';
      }

      if (widget.isEdit && widget.initialData != null) {
        params['numbers'] = widget.initialData!['.id']?.toString() ?? '';
        await widget.routerService!
            .sendCommand('/ip/hotspot/user/set', params: params);
      } else {
        await widget.routerService!
            .sendCommand('/ip/hotspot/user/add', params: params);
      }

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ فشل حفظ المستخدم: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ─────────────────────────────────────────────
  // بناء الواجهة
  // ─────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isEdit ? 'تعديل مستخدم هوتسبوت' : 'إضافة مستخدم هوتسبوت',
        ),
        actions: [
          IconButton(
            onPressed: _loadProfiles,
            icon: const Icon(Icons.refresh),
            tooltip: 'تحديث البروفايلات',
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── بيانات الدخول ──
              _sectionTitle('بيانات الدخول'),
              const SizedBox(height: 10),

              // ✅ اسم المستخدم مع validation
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'اسم المستخدم *',
                  prefixIcon: const Icon(Icons.person, size: 18),
                  suffixIcon: widget.isEdit
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.auto_fix_high,
                              size: 18, color: AppTheme.gold),
                          tooltip: 'توليد تلقائي',
                          onPressed: () {
                            final chars =
                                'abcdefghijklmnopqrstuvwxyz0123456789';
                            final rnd = List.generate(
                                6,
                                (_) => chars[DateTime.now().microsecond %
                                    chars.length]).join();
                            _nameController.text = rnd;
                          },
                        ),
                ),
                style: const TextStyle(color: Colors.white),
                enabled: !widget.isEdit,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'اسم المستخدم مطلوب';
                  }
                  if (v.trim().length < 3) {
                    return 'يجب أن يكون 3 أحرف على الأقل';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),

              // ✅ كلمة المرور مع زر الإظهار والتوليد التلقائي
              TextFormField(
                controller: _passController,
                obscureText: !_showPass,
                decoration: InputDecoration(
                  labelText: 'كلمة المرور *',
                  prefixIcon: const Icon(Icons.lock, size: 18),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(
                          _showPass ? Icons.visibility_off : Icons.visibility,
                          size: 18,
                          color: Colors.white54,
                        ),
                        onPressed: () => setState(() => _showPass = !_showPass),
                      ),
                      IconButton(
                        icon: const Icon(Icons.auto_fix_high,
                            size: 18, color: AppTheme.gold),
                        tooltip: 'توليد كلمة مرور',
                        onPressed: () {
                          const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
                          final pass = List.generate(
                              8,
                              (_) => chars[DateTime.now().microsecond %
                                  chars.length]).join();
                          setState(() {
                            _passController.text = pass;
                            _showPass = true;
                          });
                        },
                      ),
                    ],
                  ),
                ),
                style: const TextStyle(color: Colors.white),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'كلمة المرور مطلوبة';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),

              // ── البروفايل ──
              _buildProfileField(),
              const SizedBox(height: 16),

              // ── معلومات العميل ──
              _sectionTitle('معلومات العميل'),
              const SizedBox(height: 10),

              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: 'رقم هاتف العميل',
                  hintText: '963xxxxxxxxx',
                  prefixIcon: Icon(Icons.phone, size: 18),
                ),
                keyboardType: TextInputType.phone,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _commentController,
                decoration: const InputDecoration(
                  labelText: 'ملاحظات',
                  hintText: 'أي ملاحظات إضافية',
                  prefixIcon: Icon(Icons.notes, size: 18),
                ),
                style: const TextStyle(color: Colors.white),
                maxLines: 2,
              ),
              const SizedBox(height: 16),

              // ── حدود الاستخدام ──
              _sectionTitle('حدود الاستخدام'),
              const SizedBox(height: 10),

              // حد الوقت
              _limitField(
                label: 'حد وقت الاستخدام (ساعات)',
                hint: '0 = بلا حد',
                value: _timeLimitHours,
                icon: Icons.timer,
                onChanged: (v) => setState(() => _timeLimitHours = v),
              ),
              const SizedBox(height: 10),

              // حد البيانات
              _limitField(
                label: 'حد البيانات (ميغابايت)',
                hint: '0 = بلا حد',
                value: _dataLimitMb,
                icon: Icons.data_usage,
                onChanged: (v) => setState(() => _dataLimitMb = v),
              ),
              const SizedBox(height: 16),

              // ── إعدادات الحساب ──
              _sectionTitle('إعدادات الحساب'),
              const SizedBox(height: 6),

              // تعطيل/تفعيل
              Container(
                decoration: BoxDecoration(
                  color: (_isDisabled ? Colors.red : Colors.green)
                      .withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: (_isDisabled ? Colors.red : Colors.green)
                        .withOpacity(0.3),
                  ),
                ),
                child: SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  title: Text(
                    _isDisabled ? 'الحساب معطل' : 'الحساب مفعل',
                    style: TextStyle(
                      color: _isDisabled ? Colors.red : Colors.green,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    _isDisabled
                        ? 'لن يتمكن المستخدم من الاتصال'
                        : 'المستخدم يمكنه الاتصال',
                    style: const TextStyle(color: Colors.white54, fontSize: 11),
                  ),
                  value: !_isDisabled,
                  onChanged: (v) => setState(() => _isDisabled = !v),
                  activeColor: Colors.green,
                  inactiveThumbColor: Colors.red,
                ),
              ),
              const SizedBox(height: 24),

              // ── زر الحفظ ──
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.gold,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: _loading ? null : _save,
                child: _loading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            color: Colors.black, strokeWidth: 2.5),
                      )
                    : Text(
                        widget.isEdit ? 'حفظ التعديلات' : 'إضافة المستخدم',
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.bold),
                      ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Row(
      children: [
        Container(
            width: 3,
            height: 14,
            margin: const EdgeInsets.only(left: 6),
            color: AppTheme.gold),
        Text(title,
            style: const TextStyle(
                color: AppTheme.gold,
                fontSize: 12,
                fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _limitField({
    required String label,
    required String hint,
    required int value,
    required IconData icon,
    required ValueChanged<int> onChanged,
  }) {
    return TextFormField(
      initialValue: value == 0 ? '' : value.toString(),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, size: 18),
      ),
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      style: const TextStyle(color: Colors.white),
      onChanged: (v) => onChanged(int.tryParse(v) ?? 0),
    );
  }

  Widget _buildProfileField() {
    if (_profiles.isNotEmpty) {
      return DropdownButtonFormField<String>(
        value: _selectedProfile,
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'البروفايل'),
        dropdownColor: AppTheme.semiBlack,
        style: const TextStyle(color: Colors.white),
        items: _profiles
            .map((p) => DropdownMenuItem(value: p, child: Text(p)))
            .toList(),
        onChanged: (v) {
          setState(() {
            _selectedProfile = v;
            if (v != null) _manualProfileController.text = v;
          });
        },
        validator: (v) => v == null || v.isEmpty ? 'اختر البروفايل' : null,
      );
    }

    return TextFormField(
      controller: _manualProfileController,
      decoration: const InputDecoration(
        labelText: 'البروفايل',
        hintText: 'مثلاً default',
        prefixIcon: Icon(Icons.settings_input_component, size: 18),
      ),
      style: const TextStyle(color: Colors.white),
    );
  }
}
