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
  final _phoneController = TextEditingController(); // رقم هاتف الزبون
  final _commentController = TextEditingController(); // تعليق عام
  String? _selectedProfile;
  List<String> _profiles = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialData != null) {
      _nameController.text = widget.initialData!['name']?.toString() ?? '';
      _passController.text = widget.initialData!['password']?.toString() ?? '';
      _selectedProfile = widget.initialData!['profile']?.toString();

      // استخراج رقم الهاتف والتعليق من التعليق المخزّن
      final rawComment = widget.initialData!['comment']?.toString() ?? '';
      _parseComment(rawComment);
    }
    _loadProfiles();
  }

  /// يفصل رقم الهاتف عن التعليق إن وُجد
  void _parseComment(String raw) {
    if (raw.startsWith('phone:')) {
      final parts = raw.split('|');
      if (parts.isNotEmpty) {
        // الجزء الأول هو phone:xxxxxxxx
        final phonePart = parts[0].replaceFirst('phone:', '').trim();
        _phoneController.text = phonePart;
        // باقي الأجزاء هي التعليق
        if (parts.length > 1) {
          _commentController.text = parts.sublist(1).join('|').trim();
        }
      }
    } else {
      // لا يوجد رقم هاتف، التعليق كامل
      _commentController.text = raw;
    }
  }

  /// يدمج رقم الهاتف مع التعليق بالتنسيق المطلوب
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
      setState(() {
        _profiles = profiles.map((p) => p['name'].toString()).toList();
        if (_selectedProfile == null && _profiles.isNotEmpty) {
          _selectedProfile = _profiles.first;
        }
      });
    } catch (_) {}
  }

  Future<void> _save() async {
    if (widget.routerService == null) return;
    final name = _nameController.text.trim();
    final pass = _passController.text.trim();
    if (name.isEmpty) return;

    setState(() => _loading = true);
    try {
      final params = {
        'name': name,
        'password': pass,
        'profile': _selectedProfile ?? '',
        'comment': _buildComment(),
      };
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
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: Text(
              widget.isEdit ? 'تعديل حساب هوتسبوت' : 'إضافة حساب هوتسبوت')),
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
              // حقل رقم هاتف الزبون
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
              // حقل التعليق
              TextField(
                controller: _commentController,
                decoration: const InputDecoration(
                  labelText: 'تعليق / ملاحظات',
                  hintText: 'أي ملاحظات إضافية',
                ),
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _selectedProfile,
                items: _profiles
                    .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                    .toList(),
                onChanged: (v) => setState(() => _selectedProfile = v),
                decoration: const InputDecoration(labelText: 'البروفايل'),
              ),
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
