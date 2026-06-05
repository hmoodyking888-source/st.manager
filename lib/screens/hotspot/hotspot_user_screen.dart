import 'package:flutter/material.dart';
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
  final _nameController = TextEditingController();
  final _passController = TextEditingController();
  final _phoneController = TextEditingController();
  final _commentController = TextEditingController();
  final _manualProfileController = TextEditingController();

  String? _selectedProfile;
  List<String> _profiles = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();

    if (widget.initialData != null) {
      _nameController.text = widget.initialData!['name']?.toString() ?? '';
      _passController.text = widget.initialData!['password']?.toString() ?? '';

      final profile = widget.initialData!['profile']?.toString().trim();
      if (profile != null && profile.isNotEmpty) {
        _selectedProfile = profile;
        _manualProfileController.text = profile;
      }

      final rawComment = widget.initialData!['comment']?.toString() ?? '';
      _parseComment(rawComment);
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

  Future<void> _loadProfiles() async {
    if (widget.routerService == null) return;

    try {
      final profiles = await widget.routerService!.getHotspotProfiles();
      final names = profiles
          .map((p) => p['name']?.toString().trim() ?? '')
          .where((name) => name.isNotEmpty)
          .toList();

      final currentProfile = widget.initialData?['profile']?.toString().trim();
      if (currentProfile != null &&
          currentProfile.isNotEmpty &&
          !names.contains(currentProfile)) {
        names.insert(0, currentProfile);
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

  Future<void> _save() async {
    if (widget.routerService == null) return;

    final name = _nameController.text.trim();
    final pass = _passController.text.trim();

    if (name.isEmpty) return;

    if (!mounted) return;
    setState(() => _loading = true);

    try {
      final profile = (_selectedProfile?.trim().isNotEmpty == true)
          ? _selectedProfile!.trim()
          : _manualProfileController.text.trim();

      final params = <String, dynamic>{
        'name': name,
        'password': pass,
        'comment': _buildComment(),
      };

      if (profile.isNotEmpty) {
        params['profile'] = profile;
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
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('فشل حفظ المستخدم')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
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
            .map(
              (p) => DropdownMenuItem(
                value: p,
                child: Text(p),
              ),
            )
            .toList(),
        onChanged: (v) {
          setState(() {
            _selectedProfile = v;
            if (v != null) {
              _manualProfileController.text = v;
            }
          });
        },
      );
    }

    return TextField(
      controller: _manualProfileController,
      decoration: const InputDecoration(
        labelText: 'البروفايل',
        hintText: 'إن لم يتم جلب البروفايلات',
      ),
      style: const TextStyle(color: Colors.white),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:
            Text(widget.isEdit ? 'تعديل حساب هوتسبوت' : 'إضافة حساب هوتسبوت'),
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
