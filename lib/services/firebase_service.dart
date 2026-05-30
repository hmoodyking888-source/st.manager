import 'package:cloud_firestore/cloud_firestore.dart';

class FirebaseService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// التحقق من وجود ترخيص صالح لرقم الهاتف
  static Future<bool> checkLicense(String phoneNumber) async {
    try {
      final doc =
          await _firestore.collection('licenses').doc(phoneNumber).get();
      if (!doc.exists) return false;
      final expiry = doc.data()?['expiryDate'] as Timestamp?;
      if (expiry == null) return false;
      return expiry.toDate().isAfter(DateTime.now());
    } catch (e) {
      return false;
    }
  }

  /// جلب بيانات الراوتر من Firestore (خاص بالمستخدم)
  static Future<Map<String, dynamic>?> getRouterData(String phoneNumber) async {
    try {
      final doc = await _firestore.collection('routers').doc(phoneNumber).get();
      if (doc.exists) return doc.data();
    } catch (_) {}
    return null;
  }

  /// حفظ Chat ID للتلغرام
  static Future<void> saveChatId(String phoneNumber, String chatId) async {
    await _firestore.collection('users').doc(phoneNumber).set({
      'chatId': chatId,
      'lastUpdated': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
