import 'package:cloud_firestore/cloud_firestore.dart';

class FirebaseService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static Future<bool> checkLicense(String phoneNumber) async {
    try {
      final doc =
          await _firestore.collection('licenses').doc(phoneNumber).get();
      if (!doc.exists) return false;
      final expiry = doc.data()?['expiryDate'] as Timestamp?;
      if (expiry == null) return false;
      return expiry.toDate().isAfter(DateTime.now());
    } catch (_) {
      return false;
    }
  }

  /// ✅ دالة جديدة: جلب تاريخ انتهاء الترخيص
  static Future<DateTime?> getLicenseExpiry(String phoneNumber) async {
    try {
      final doc =
          await _firestore.collection('licenses').doc(phoneNumber).get();
      if (!doc.exists) return null;
      final expiry = doc.data()?['expiryDate'] as Timestamp?;
      return expiry?.toDate();
    } catch (_) {
      return null;
    }
  }

  static Future<void> saveUserPhone(
      String phone, Map<String, String> routerData) async {
    await _firestore.collection('users').doc(phone).set({
      'phone': phone,
      'lastLogin': FieldValue.serverTimestamp(),
      'routers': FieldValue.arrayUnion([routerData]),
    }, SetOptions(merge: true));
  }

  static Future<void> saveChatId(String phoneNumber, String chatId) async {
    await _firestore.collection('users').doc(phoneNumber).set({
      'chatId': chatId,
      'lastUpdated': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
