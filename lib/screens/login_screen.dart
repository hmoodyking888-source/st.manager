import 'package:flutter/material.dart';
import 'package:st_manager/services/firebase_service.dart';
import 'package:st_manager/services/secure_storage_service.dart';
import 'package:st_manager/theme/app_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneController = TextEditingController();
  final _pinController = TextEditingController();
  final SecureStorageService _storage = SecureStorageService();
  bool _loading = false;
  bool _hasStoredPin = false;

  @override
  void initState() {
    super.initState();
    _checkStoredPin();
  }

  Future<void> _checkStoredPin() async {
    final pin = await _storage.read('app_pin');
    if (pin != null && pin.isNotEmpty) {
      setState(() => _hasStoredPin = true);
    }
  }

  Future<void> _login() async {
    final phone = _phoneController.text.trim();
    final pin = _pinController.text.trim();
    if (phone.isEmpty) return;

    setState(() => _loading = true);

    // إذا كان هناك PIN مخزّن، تأكد من صحته
    if (_hasStoredPin) {
      final storedPin = await _storage.read('app_pin');
      if (pin != storedPin) {
        setState(() => _loading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('رمز PIN غير صحيح')),
          );
        }
        return;
      }
    } else {
      // أول مرة: خزّن الـ PIN الذي أدخله المستخدم
      if (pin.length < 4) {
        setState(() => _loading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content:
                    Text('يجب أن يكون رمز PIN مكوناً من 4 خانات على الأقل')),
          );
        }
        return;
      }
      await _storage.write('app_pin', pin);
      await _storage.write('phone_number', phone);
    }

    // حفظ رقم الهاتف (للاستخدام لاحقاً)
    await _storage.write('phone_number', phone);

    // التحقق من الترخيص في Firestore
    final licensed = await FirebaseService.checkLicense(phone);

    if (licensed) {
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/dashboard');
    } else {
      // لم يجد ترخيصاً، تحقق من الفترة التجريبية (3 أيام من أول استخدام)
      final firstLaunchStr = await _storage.read('first_launch');
      if (firstLaunchStr == null) {
        // أول تشغيل، ابدأ الفترة التجريبية
        await _storage.write('first_launch', DateTime.now().toIso8601String());
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/dashboard');
      } else {
        final firstLaunch = DateTime.parse(firstLaunchStr);
        final trialEnd = firstLaunch.add(const Duration(days: 3));
        if (DateTime.now().isBefore(trialEnd)) {
          // لا يزال في الفترة التجريبية
          if (!mounted) return;
          Navigator.pushReplacementNamed(context, '/dashboard');
        } else {
          // انتهت التجربة وليس لديه ترخيص
          setState(() => _loading = false);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content:
                      Text('انتهت الفترة التجريبية. يرجى الحصول على ترخيص.')),
            );
          }
        }
      }
    }
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.black,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.shield_outlined, size: 80, color: AppTheme.gold),
              const SizedBox(height: 20),
              Text('ST_Manager',
                  style: Theme.of(context)
                      .textTheme
                      .headlineMedium
                      ?.copyWith(fontSize: 32)),
              const SizedBox(height: 40),
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
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
                  labelText: _hasStoredPin ? 'رمز PIN' : 'أنشئ رمز PIN للتطبيق',
                  hintText: '4 خانات على الأقل',
                ),
                style: const TextStyle(color: AppTheme.gold),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _loading ? null : _login,
                child: _loading
                    ? const CircularProgressIndicator(color: Colors.black)
                    : const Text('دخول'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
