import 'package:flutter/material.dart';
import 'package:st_manager/services/firebase_service.dart';
import 'package:st_manager/services/secure_storage_service.dart';
import 'package:st_manager/theme/app_theme.dart';
import 'package:url_launcher/url_launcher.dart';

class RoutersScreen extends StatefulWidget {
  const RoutersScreen({super.key});

  @override
  State<RoutersScreen> createState() => _RoutersScreenState();
}

class _RoutersScreenState extends State<RoutersScreen> {
  final SecureStorageService _storage = SecureStorageService();

  List<Map<String, String>> _routers = [];
  int _remainingDays = 0;
  bool _loading = false;
  bool _checkingRemainingDays = false;

  @override
  void initState() {
    super.initState();
    _loadRouters();
    _checkRemainingDays();
  }

  Future<void> _refreshData() async {
    await Future.wait([
      _loadRouters(),
      _checkRemainingDays(),
    ]);
  }

  Future<void> _loadRouters() async {
    final routers = await _storage.getRouters();
    if (!mounted) return;
    setState(() => _routers = routers);
  }

  // دالة حساب الأيام المتبقية الدقيقة من فايرباس
  Future<void> _checkRemainingDays() async {
    if (mounted) {
      setState(() => _checkingRemainingDays = true);
    }

    try {
      final phone = await _storage.getPhone();
      if (!mounted) return;

      if (phone == null || phone.trim().isEmpty) {
        setState(() => _remainingDays = 0);
        return;
      }

      DateTime? expiryDate;

      try {
        // جلب التاريخ الفعلي من فايرباس
        expiryDate = await FirebaseService.getLicenseExpiry(phone).timeout(
          const Duration(seconds: 10),
        );

        // تخزين التاريخ الفعلي لاستخدامه في وضع عدم الاتصال
        if (expiryDate != null) {
          await _storage.write(
              'license_expiry_date', expiryDate.toIso8601String());
          await _storage.write('license_phone', phone);
        }
      } catch (_) {
        // في حال عدم وجود إنترنت، جلب التاريخ المحفوظ
        final cachedPhone = await _storage.read('license_phone');
        if (cachedPhone == phone) {
          final cachedExpiry = await _storage.read('license_expiry_date');
          if (cachedExpiry != null && cachedExpiry.isNotEmpty) {
            expiryDate = DateTime.tryParse(cachedExpiry);
          }
        }
      }

      if (!mounted) return;

      if (expiryDate != null) {
        // حساب الفارق بين تاريخ اليوم وتاريخ الانتهاء
        final today = DateTime(
            DateTime.now().year, DateTime.now().month, DateTime.now().day);
        final expDate =
            DateTime(expiryDate.year, expiryDate.month, expiryDate.day);
        final diff = expDate.difference(today).inDays;

        setState(() => _remainingDays = diff > 0 ? diff : 0);
      } else {
        setState(() => _remainingDays = 0);
      }
    } finally {
      if (mounted) {
        setState(() => _checkingRemainingDays = false);
      }
    }
  }

  // دالة فتح تطبيق Back to Home
  Future<void> _launchExternalVPN() async {
    try {
      // 1. محاولة الفتح عبر Scheme الخاص بالتطبيق
      final Uri appUrl = Uri.parse('bth://');

      // 2. محاولة الفتح عبر الـ Intent الخاص بالاندرويد (الأكثر فعالية لفتح التطبيقات المثبتة)
      final Uri intentUrl =
          Uri.parse('intent://#Intent;package=com.mikrotik.bth;end');

      // 3. رابط المتجر كخيار أخير
      final Uri storeUrl = Uri.parse(
          'https://play.google.com/store/apps/details?id=com.mikrotik.bth');

      bool launched = false;

      // محاولة الفتح المباشر
      try {
        if (await canLaunchUrl(appUrl)) {
          launched =
              await launchUrl(appUrl, mode: LaunchMode.externalApplication);
        }
      } catch (_) {}

      // محاولة الفتح عبر Intent إذا فشلت الطريقة الأولى
      if (!launched) {
        try {
          launched =
              await launchUrl(intentUrl, mode: LaunchMode.externalApplication);
        } catch (_) {}
      }

      // إذا لم يفتح، قم بتحويله للمتجر
      if (!launched) {
        await launchUrl(storeUrl, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('حدث خطأ أثناء محاولة فتح التطبيق')),
        );
      }
    }
  }

  Future<void> _saveRouter({
    required int? index,
    required String name,
    required String ip,
    required String username,
    required String password,
    required String port,
  }) async {
    final router = <String, String>{
      'name': name.trim(),
      'ip': ip.trim(),
      'username': username.trim(),
      'password': password.trim(),
      'port': port.trim(),
    };

    if (index == null) {
      await _storage.addRouter(router);
    } else {
      await _storage.updateRouter(index, router);
    }

    final phone = await _storage.getPhone();
    if (phone != null && phone.isNotEmpty) {
      await FirebaseService.saveUserPhone(phone, router);
    }
  }

  Future<void> _addOrEditRouter({int? index}) async {
    final nameController = TextEditingController();
    final ipController = TextEditingController();
    final userController = TextEditingController();
    final passController = TextEditingController();
    final portController = TextEditingController(text: '8728');

    if (index != null) {
      final r = _routers[index];
      nameController.text = r['name'] ?? '';
      ipController.text = r['ip'] ?? '';
      userController.text = r['username'] ?? '';
      passController.text = r['password'] ?? '';
      portController.text = r['port'] ?? '8728';
    }

    try {
      await showDialog(
        context: context,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                backgroundColor: AppTheme.semiBlack,
                title: Text(
                  index == null ? 'إضافة راوتر' : 'تعديل راوتر',
                  style: const TextStyle(color: Colors.white),
                ),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: nameController,
                        decoration:
                            const InputDecoration(labelText: 'اسم الراوتر'),
                        style: const TextStyle(color: Colors.white),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: ipController,
                        decoration: const InputDecoration(labelText: 'IP'),
                        style: const TextStyle(color: Colors.white),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: portController,
                        decoration: const InputDecoration(
                          labelText: 'منفذ API',
                          hintText: '8728 أو 8729',
                        ),
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.white),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: userController,
                        decoration:
                            const InputDecoration(labelText: 'اسم المستخدم'),
                        style: const TextStyle(color: Colors.white),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: passController,
                        decoration:
                            const InputDecoration(labelText: 'كلمة المرور'),
                        obscureText: true,
                        style: const TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text('إلغاء'),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      final name = nameController.text.trim();
                      final ip = ipController.text.trim();
                      final username = userController.text.trim();
                      final password = passController.text.trim();
                      final port = portController.text.trim();

                      if (name.isEmpty ||
                          ip.isEmpty ||
                          username.isEmpty ||
                          password.isEmpty ||
                          port.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('يرجى تعبئة الحقول الأساسية')),
                        );
                        return;
                      }

                      if (int.tryParse(port) == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('منفذ غير صالح')),
                        );
                        return;
                      }

                      setState(() => _loading = true);

                      try {
                        await _saveRouter(
                          index: index,
                          name: name,
                          ip: ip,
                          username: username,
                          password: password,
                          port: port,
                        );

                        if (!mounted) return;
                        Navigator.pop(dialogContext);
                        await _loadRouters();
                        await _checkRemainingDays();
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
                    },
                    child: const Text('حفظ'),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      nameController.dispose();
      ipController.dispose();
      userController.dispose();
      passController.dispose();
      portController.dispose();
    }
  }

  Future<void> _deleteRouter(int index) async {
    await _storage.deleteRouter(index);
    if (!mounted) return;
    await _loadRouters();
  }

  void _selectRouter(Map<String, String> router) {
    Navigator.pushNamed(context, '/dashboard', arguments: router);
  }

  Widget _buildSummaryCard() {
    final remainingText =
        _checkingRemainingDays ? '...' : '$_remainingDays يوم';

    return Container(
      margin: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.semiBlack,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppTheme.gold.withOpacity(0.25),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.gold.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.router, color: AppTheme.gold),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'الراوترات المحفوظة',
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(
                  'عدد الراوترات: ${_routers.length}',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text(
                'المدة المتبقية',
                style: TextStyle(color: Colors.white54, fontSize: 11),
              ),
              const SizedBox(height: 4),
              Text(
                remainingText,
                style: const TextStyle(
                  color: AppTheme.gold,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة الراوترات'),
        actions: [
          IconButton(
            onPressed: _refreshData,
            icon: const Icon(Icons.refresh),
            tooltip: 'تحديث',
          ),
        ],
      ),
      body: Column(
        children: [
          if (_loading) const LinearProgressIndicator(color: AppTheme.gold),
          _buildSummaryCard(),

          // زر فتح تطبيق Back to Home أسفل بطاقة الملخص
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.vpn_key_outlined, color: AppTheme.gold),
                label: const Text('تشغيل Back to Home',
                    style: TextStyle(color: AppTheme.gold)),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: AppTheme.gold.withOpacity(0.5)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _launchExternalVPN,
              ),
            ),
          ),
          const SizedBox(height: 8),

          Expanded(
            child: _routers.isEmpty
                ? const Center(
                    child: Text(
                      'لا يوجد راوترات مضافة',
                      style: TextStyle(color: Colors.white54),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _refreshData,
                    child: ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: _routers.length,
                      itemBuilder: (_, i) {
                        final r = _routers[i];
                        return Card(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 4),
                          child: ListTile(
                            leading:
                                const Icon(Icons.router, color: AppTheme.gold),
                            title: Text(
                              r['name'] ?? '',
                              style: const TextStyle(color: Colors.white),
                            ),
                            subtitle: Text(
                              '${r['ip']} :${r['port'] ?? '8728'}',
                              style: const TextStyle(color: Colors.white54),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit,
                                      color: Colors.white54),
                                  onPressed: () => _addOrEditRouter(index: i),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete,
                                      color: Colors.red),
                                  onPressed: () => _deleteRouter(i),
                                ),
                              ],
                            ),
                            onTap: () => _selectRouter(r),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTheme.gold,
        onPressed: _addOrEditRouter,
        child: const Icon(Icons.add),
      ),
    );
  }
}
