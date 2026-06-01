import 'package:flutter/material.dart';
import 'package:st_manager/services/router_service.dart';
import 'package:st_manager/theme/app_theme.dart';

class HotspotProfileScreen extends StatefulWidget {
  final RouterService? routerService;
  final bool isEdit;
  final Map<String, dynamic>? initialData;
  const HotspotProfileScreen({
    super.key,
    required this.routerService,
    required this.isEdit,
    this.initialData,
  });

  @override
  State<HotspotProfileScreen> createState() => _HotspotProfileScreenState();
}

class _HotspotProfileScreenState extends State<HotspotProfileScreen> {
  final _nameController = TextEditingController();
  final _rateLimitController = TextEditingController();
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialData != null) {
      _nameController.text = widget.initialData!['name']?.toString() ?? '';
      _rateLimitController.text =
          widget.initialData!['rate-limit']?.toString() ?? '';
    }
  }

  Future<void> _save() async {
    if (widget.routerService == null) return;
    setState(() => _loading = true);
    try {
      final params = {
        'name': _nameController.text.trim(),
        'rate-limit': _rateLimitController.text.trim(),
      };
      if (widget.isEdit && widget.initialData != null) {
        params['numbers'] = widget.initialData!['.id']?.toString() ?? '';
        await widget.routerService!
            .sendCommand('ip/hotspot/user/profile/set', params: params);
      } else {
        await widget.routerService!
            .sendCommand('ip/hotspot/user/profile/add', params: params);
      }
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('فشل الحفظ')));
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: Text(widget.isEdit ? 'تعديل بروفايل' : 'إضافة بروفايل')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'اسم البروفايل'),
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _rateLimitController,
              decoration:
                  const InputDecoration(labelText: 'محدد السرعة (مثلاً 2M/2M)'),
              style: const TextStyle(color: Colors.white),
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
    );
  }
}
