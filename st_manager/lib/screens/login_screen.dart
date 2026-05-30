import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart'; // <-- أضفناها
import 'package:st_manager/services/firebase_service.dart';
import 'package:st_manager/theme/app_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  String? _verificationId;
  bool _isOtpSent = false;
  bool _loading = false;

  void _sendOtp() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) return;
    setState(() => _loading = true);
    await FirebaseService.verifyPhoneNumber(
      phoneNumber: phone,
      onVerificationCompleted: (credential) async {
        await FirebaseService.signInWithCredential(credential);
        if (!mounted) return; // <-- فحص mounted
        _navigateToDashboard();
      },
      onVerificationFailed: (e) {
        setState(() => _loading = false);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل التحقق: ${e.message}')),
        );
      },
      onCodeSent: (verificationId, resendToken) {
        setState(() {
          _verificationId = verificationId;
          _isOtpSent = true;
          _loading = false;
        });
      },
      onCodeAutoRetrievalTimeout: (verificationId) {
        setState(() {
          _verificationId = verificationId;
          _loading = false;
        });
      },
    );
  }

  void _verifyOtp() async {
    final otp = _otpController.text.trim();
    if (otp.isEmpty || _verificationId == null) return;
    setState(() => _loading = true);
    try {
      final credential = PhoneAuthProvider.credential(
        // <-- الآن معرفة
        verificationId: _verificationId!,
        smsCode: otp,
      );
      await FirebaseService.signInWithCredential(credential);
      if (!mounted) return;
      _navigateToDashboard();
    } catch (e) {
      setState(() => _loading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('رمز OTP غير صحيح')),
      );
    }
  }

  void _navigateToDashboard() {
    Navigator.of(context).pushReplacementNamed('/dashboard');
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
              if (!_isOtpSent) ...[
                TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'رقم الهاتف',
                    hintText: '+963...',
                  ),
                  style: const TextStyle(color: AppTheme.gold),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _loading ? null : _sendOtp,
                  child: _loading
                      ? const CircularProgressIndicator(color: Colors.black)
                      : const Text('إرسال رمز التحقق'),
                ),
              ] else ...[
                TextField(
                  controller: _otpController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'رمز OTP',
                    hintText: 'أدخل الرمز المكون من 6 خانات',
                  ),
                  style: const TextStyle(color: AppTheme.gold),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _loading ? null : _verifyOtp,
                  child: _loading
                      ? const CircularProgressIndicator(color: Colors.black)
                      : const Text('تأكيد الدخول'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
