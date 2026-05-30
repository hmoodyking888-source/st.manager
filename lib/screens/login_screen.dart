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
  final _pinConfirmController = TextEditingController();
  final SecureStorageService _storage = SecureStorageService();
  bool _loading = false;
  bool _isPinSet = false; // هل يوجد PIN مخزن مسبقاً
  bool _showConfirmPin = false; // هل نعرض حقل تأكيد الرمز

  @override
  void initState() {
    super.initState();
    _checkExistingData();
  }

  Future<void> _checkExistingData() async {
    final phone = await _storage.getPhone();
    final pin = await _storage.getPin();
    if (phone != null && pin != null) {
      setState(() {
        _phoneController.text = phone;
        _isPinSet = true;
      });
    }
  }

  Future<void> _submit() async {
    final phone = _phoneController.text.trim();
    final pin = _pinController.text.trim();

    if (phone.isEmpty) {
      _showError('الرجاء إدخال رقم الهاتف');
      return;
    }

    setState(() => _loading = true);

    if (_isPinSet) {
      // وضع تسجيل الدخول: التحقق من PIN
      final storedPin = await _storage.getPin();
      if (pin != storedPin) {
        setState(() => _loading = false);
        _showError('رمز PIN غير صحيح');
        return;
      }
    } else {
      // وضع إنشاء PIN جديد
      if (pin.length < 4) {
        setState(() => _loading = false);
        _showError('يجب أن يكون رمز PIN 4 خانات على الأقل');
        return;
      }
      // إذا كان يظهر حقل التأكيد، تأكد من التطابق
      if (_showConfirmPin) {
        final confirm = _pinConfirmController.text.trim();
        if (pin != confirm) {
          setState(() => _loading = false);
          _showError('رمز PIN غير متطابق');
          return;
        }
      } else {
        // أول مرة: اعرض حقل التأكيد
        setState(() {
          _showConfirmPin = true;
          _loading = false;
        });
        return;
      }
      // حفظ PIN ورقم الهاتف
      await _storage.setPin(pin);
      await _storage.setPhone(phone);
    }

    // التحقق من الترخيص (Firestore)
    final licensed = await FirebaseService.checkLicense(phone);
    if (licensed) {
      _navigateTo('/routers');
    } else {
      // الفترة التجريبية 3 أيام
      final firstLaunchStr = await _storage.getFirstLaunch();
      if (firstLaunchStr == null) {
        await _storage.setFirstLaunch(DateTime.now().toIso8601String());
        _navigateTo('/routers');
      } else {
        final firstLaunch = DateTime.parse(firstLaunchStr);
        final trialEnd = firstLaunch.add(const Duration(days: 3));
        if (DateTime.now().isBefore(trialEnd)) {
          _navigateTo('/routers');
        } else {
          setState(() => _loading = false);
          _showError('انتهت الفترة التجريبية. يرجى الحصول على ترخيص.');
        }
      }
    }
    setState(() => _loading = false);
  }

  void _forgotPin() async {
    // إعادة تعيين PIN: نطلب رقم الهاتف المسجل مسبقاً للمقارنة
    final storedPhone = await _storage.getPhone();
    if (storedPhone == null) {
      _showError('لا يوجد رقم هاتف مسجل، أعد تشغيل التطبيق');
      return;
    }
    final phoneInput = _phoneController.text.trim();
    if (phoneInput != storedPhone) {
      _showError('رقم الهاتف لا يتطابق مع المسجل');
      return;
    }
    // مسح PIN والسماح بإنشاء جديد
    await _storage.deletePin();
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
                enabled: !_isPinSet, // لا يمكن تغيير الرقم بعد التسجيل
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
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _loading ? null : _submit,
                child: _loading
                    ? const CircularProgressIndicator(color: Colors.black)
                    : Text(_isPinSet ? 'دخول' : 'متابعة'),
              ),
              if (_isPinSet) ...[
                TextButton(
                  onPressed: _forgotPin,
                  child: const Text('نسيت الرمز؟',
                      style: TextStyle(color: AppTheme.gold)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
