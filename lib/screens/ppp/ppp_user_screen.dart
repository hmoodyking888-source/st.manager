import 'package:flutter/material.dart';
import 'package:st_manager/services/router_service.dart';
import 'package:st_manager/theme/app_theme.dart';

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

  List<String> _profiles = [];
  String? _selectedProfile;

  @override
  void initState() {
    super.initState();

    if (widget.initialData != null) {
      _nameController.text = widget.initialData!['name']?.toString() ?? '';
      _passController.text = widget.initialData!['password']?.toString() ?? '';
      _profileController.text =
          widget.initialData!['profile']?.toString() ?? '';

      final rawComment = widget.initialData!['comment']?.toString() ?? '';
      _parseComment(rawComment);
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

  Future<void> _loadProfiles() async {
    if (widget.routerService == null) return;

    setState(() => _loadingProfiles = true);

    try {
      final result = await widget.routerService!.getPppProfiles();
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

  void _parseComment(String raw) {
    if (raw.startsWith('phone:')) {
      final parts = raw.split('|');
      if (parts.isNotEmpty) {
        final phonePart = parts[0].replaceFirst('phone:', '').trim();
        _phoneController.text = phonePart;

        if (parts.length > 1) {
          _commentController.text = parts.sublist(1).join('|').trim();
        }
      }
    } else {
      _commentController.text = raw;
    }
  }

  String _buildComment() {
    final phone = _phoneController.text.trim();
    final comment = _commentController.text.trim();
    if (phone.isNotEmpty) {
      return 'phone:$phone | $comment';
    }
    return comment;
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
        await widget.routerService!
            .sendCommand('/ppp/secret/set', params: params);
      } else {
        await widget.routerService!
            .sendCommand('/ppp/secret/add', params: params);
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

  @override
  Widget build(BuildContext context) {
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
                decoration: const InputDecoration(labelText: 'اسم المستخدم'),
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _passController,
                decoration: const InputDecoration(labelText: 'كلمة المرور'),
                style: const TextStyle(color: Colors.white),
                obscureText: true,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: 'رقم هاتف الزبون (للإشعارات)',
                  hintText: 'مثلاً 963xxxxxxxxx',
                ),
                keyboardType: TextInputType.phone,
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _commentController,
                decoration: const InputDecoration(
                  labelText: 'تعليق / ملاحظات',
                  hintText: 'أي ملاحظات إضافية',
                ),
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 12),
              _buildProfileField(),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _loading ? null : _save,
                child: _loading
                    ? const CircularProgressIndicator(color: Colors.black)
                    : const Text('حفظ'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
