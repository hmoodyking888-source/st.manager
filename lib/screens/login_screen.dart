import 'package:flutter/material.dart';
import 'package:st_manager/services/firebase_service.dart';
import 'package:st_manager/services/secure_storage_service.dart';
import 'package:st_manager/theme/app_theme.dart';
import 'package:url_launcher/url_launcher.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const String _licenseCachePhoneKey = 'license_cache_phone';
  static const String _licenseCacheValueKey = 'license_cache_value';
  static const String _licenseCacheCheckedAtKey = 'license_cache_checked_at';
  static const Duration _licenseCacheDuration = Duration(hours: 12);

  final _phoneController = TextEditingController();
  final _pinController = TextEditingController();
  final _pinConfirmController = TextEditingController();
  final SecureStorageService _storage = SecureStorageService();

  bool _loading = false;
  bool _isPinSet = false;
  bool _showConfirmPin = false;

  @override
  void initState() {
    super.initState();
    _checkExistingData();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _pinController.dispose();
    _pinConfirmController.dispose();
    super.dispose();
  }

  Future<void> _checkExistingData() async {
    final phone = await _storage.getPhone();
    final pin = await _storage.getPin();

    if (!mounted) return;

    if (phone != null && pin != null) {
      setState(() {
        _phoneController.text = phone;
        _isPinSet = true;
      });
    }
  }

  Future<bool?> _readCachedLicense(String phone) async {
    final cachedPhone = await _storage.read(_licenseCachePhoneKey);
    final cachedValue = await _storage.read(_licenseCacheValueKey);
    final cachedAt = await _storage.read(_licenseCacheCheckedAtKey);

    if (cachedPhone == null ||
        cachedValue == null ||
        cachedAt == null ||
        cachedPhone.trim() != phone.trim()) {
      return null;
    }

    final parsedAt = DateTime.tryParse(cachedAt);
    if (parsedAt == null) return null;

    if (DateTime.now().difference(parsedAt) > _licenseCacheDuration) {
      return null;
    }

    return cachedValue == 'true';
  }

  Future<void> _saveCachedLicense(String phone, bool licensed) async {
    await _storage.write(_licenseCachePhoneKey, phone);
    await _storage.write(_licenseCacheValueKey, licensed ? 'true' : 'false');
    await _storage.write(
      _licenseCacheCheckedAtKey,
      DateTime.now().toIso8601String(),
    );
  }

  Future<bool> _resolveLicense(String phone) async {
    final cached = await _readCachedLicense(phone);
    if (cached != null) return cached;

    try {
      final licensed = await FirebaseService.checkLicense(phone).timeout(
        const Duration(seconds: 10),
      );
      await _saveCachedLicense(phone, licensed);
      return licensed;
    } catch (_) {
      final fallback = await _readCachedLicense(phone);
      if (fallback != null) return fallback;
      rethrow;
    }
  }

  Future<void> _submit() async {
    final phone = _phoneController.text.trim();
    final pin = _pinController.text.trim();

    if (phone.isEmpty) {
      _showError('الرجاء إدخال رقم الهاتف');
      return;
    }

    if (!_isPinSet && !_showConfirmPin && pin.length < 4) {
      _showError('يجب أن يكون رمز PIN 4 خانات على الأقل');
      return;
    }

    if (_showConfirmPin && !_isPinSet) {
      final confirm = _pinConfirmController.text.trim();
      if (pin != confirm) {
        _showError('رمز PIN غير متطابق');
        return;
      }
    }

    if (!mounted) return;
    setState(() => _loading = true);

    try {
      if (_isPinSet) {
        final storedPin = await _storage.getPin();
        if (pin != storedPin) {
          _showError('رمز PIN غير صحيح');
          return;
        }
      } else {
        if (!_showConfirmPin) {
          setState(() {
            _showConfirmPin = true;
          });
          return;
        }

        await _storage.setPin(pin);
        await _storage.setPhone(phone);

        if (mounted) {
          setState(() {
            _isPinSet = true;
            _showConfirmPin = false;
          });
        }
      }

      final licensed = await _resolveLicense(phone);

      if (licensed) {
        _navigateTo('/routers');
        return;
      }

      final firstLaunchStr = await _storage.getFirstLaunch();

      if (firstLaunchStr == null) {
        await _storage.setFirstLaunch(DateTime.now().toIso8601String());
        _navigateTo('/routers');
        return;
      }

      final firstLaunch = DateTime.parse(firstLaunchStr);
      final trialEnd = firstLaunch.add(const Duration(days: 3));

      if (DateTime.now().isBefore(trialEnd)) {
        _navigateTo('/routers');
        return;
      }

      if (!mounted) return;

      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: AppTheme.semiBlack,
          title: const Text('انتهت مدة الجلسة'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'يرجى التواصل مع الإدارة لتجديد اشتراكك',
                style: TextStyle(color: Colors.white),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.chat, color: Colors.green),
                  SizedBox(width: 8),
                  Text(
                    '+963995870655',
                    style: TextStyle(color: Colors.white),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إغلاق'),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.chat),
              label: const Text('واتساب'),
              onPressed: () async {
                final url = Uri.parse('https://wa.me/963995870655');
                if (await canLaunchUrl(url)) {
                  await launchUrl(url, mode: LaunchMode.externalApplication);
                }
                if (mounted) {
                  Navigator.pop(context);
                }
              },
            ),
          ],
        ),
      );
    } catch (_) {
      _showError('حدث خطأ أثناء تسجيل الدخول');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _forgotPin() async {
    final storedPhone = await _storage.getPhone();
    final phoneInput = _phoneController.text.trim();

    if (storedPhone == null || phoneInput != storedPhone) {
      _showError('رقم الهاتف لا يتطابق مع المسجل');
      return;
    }

    await _storage.deletePin();

    if (!mounted) return;

    setState(() {
      _isPinSet = false;
      _showConfirmPin = false;
      _pinController.clear();
      _pinConfirmController.clear();
    });

    _showError('تم مسح الرمز، أنشئ رمزاً جديداً');
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _navigateTo(String route) {
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, route);
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppTheme.gold.withOpacity(0.08),
            border: Border.all(
              color: AppTheme.gold.withOpacity(0.45),
              width: 1.4,
            ),
          ),
          child: Icon(
            Icons.shield_outlined,
            size: 72,
            color: AppTheme.gold,
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'ST_Manager',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: AppTheme.gold,
              ),
        ),
        const SizedBox(height: 8),
        const Text(
          'إدارة الشبكة بسرعة وثقة',
          style: TextStyle(
            color: Colors.white54,
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  Widget _buildFieldCard({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.semiBlack,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppTheme.gold.withOpacity(0.25),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.black,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 32),
                  _buildFieldCard(
                    child: Column(
                      children: [
                        TextField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          enabled: !_isPinSet,
                          decoration: const InputDecoration(
                            labelText: 'رقم الهاتف',
                            hintText: 'مثلاً 963XXXXXXXXX',
                          ),
                          style: const TextStyle(color: AppTheme.gold),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _pinController,
                          obscureText: true,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: _isPinSet ? 'رمز PIN' : 'أنشئ رمز PIN',
                            hintText: '4 خانات على الأقل',
                          ),
                          style: const TextStyle(color: AppTheme.gold),
                        ),
                        if (_showConfirmPin && !_isPinSet) ...[
                          const SizedBox(height: 16),
                          TextField(
                            controller: _pinConfirmController,
                            obscureText: true,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'تأكيد رمز PIN',
                              hintText: 'أعد إدخال الرمز',
                            ),
                            style: const TextStyle(color: AppTheme.gold),
                          ),
                        ],
                        const SizedBox(height: 22),
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            onPressed: _loading ? null : _submit,
                            child: _loading
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      color: Colors.black,
                                      strokeWidth: 2.5,
                                    ),
                                  )
                                : Text(_isPinSet ? 'دخول' : 'متابعة'),
                          ),
                        ),
                        if (_isPinSet) ...[
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: _forgotPin,
                            child: const Text(
                              'نسيت الرمز؟',
                              style: TextStyle(color: AppTheme.gold),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
