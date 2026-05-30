import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirebaseService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // تسجيل الدخول برقم الهاتف (OTP)
  static Future<void> verifyPhoneNumber({
    required String phoneNumber,
    required Function(PhoneAuthCredential) onVerificationCompleted,
    required Function(FirebaseAuthException) onVerificationFailed,
    required Function(String verificationId, int? resendToken) onCodeSent,
    required Function(String) onCodeAutoRetrievalTimeout,
  }) async {
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: onVerificationCompleted,
      verificationFailed: onVerificationFailed,
      codeSent: onCodeSent,
      codeAutoRetrievalTimeout: onCodeAutoRetrievalTimeout,
    );
  }

  static Future<UserCredential> signInWithCredential(
    PhoneAuthCredential credential,
  ) async {
    return await _auth.signInWithCredential(credential);
  }

  static User? get currentUser => _auth.currentUser;

  // التحقق من الترخيص في Firestore
  static Future<bool> checkLicense(String phoneNumber) async {
    try {
      final doc = await _firestore
          .collection('licenses')
          .doc(phoneNumber)
          .get();
      if (!doc.exists) return false;
      final expiry = doc.data()?['expiryDate'] as Timestamp?;
      if (expiry == null) return false;
      return expiry.toDate().isAfter(DateTime.now());
    } catch (e) {
      return false;
    }
  }

  // جلب بيانات الراوتر المحفوظة من البوت (المخزنة في Firestore)
  static Future<Map<String, dynamic>?> getRouterData(String phoneNumber) async {
    try {
      final doc = await _firestore.collection('routers').doc(phoneNumber).get();
      if (doc.exists) {
        return doc.data();
      }
    } catch (_) {}
    return null;
  }

  // حفظ Chat ID للبوت
  static Future<void> saveChatId(String phoneNumber, String chatId) async {
    await _firestore.collection('users').doc(phoneNumber).set({
      'chatId': chatId,
      'lastUpdated': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // تحديث حالة الترخيص (يستخدمها البوت لاحقاً)
  static Future<void> updateLicense(String phoneNumber, DateTime expiry) async {
    await _firestore.collection('licenses').doc(phoneNumber).set({
      'expiryDate': Timestamp.fromDate(expiry),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
