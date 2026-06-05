import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  final _storage = const FlutterSecureStorage();

  Future<void> write(String key, String value) async =>
      await _storage.write(key: key, value: value);

  Future<String?> read(String key) async => await _storage.read(key: key);

  Future<void> delete(String key) async => await _storage.delete(key: key);

  Future<void> setPin(String pin) async => await write('app_pin', pin);
  Future<String?> getPin() async => await read('app_pin');
  Future<void> deletePin() async => await delete('app_pin');

  Future<void> setPhone(String phone) async =>
      await write('phone_number', phone);
  Future<String?> getPhone() async => await read('phone_number');

  Future<List<Map<String, String>>> getRouters() async {
    final jsonStr = await read('routers_list');
    if (jsonStr == null) return [];
    final List<dynamic> decoded = jsonDecode(jsonStr);
    return decoded.map((e) => Map<String, String>.from(e)).toList();
  }

  Future<void> saveRouters(List<Map<String, String>> routers) async {
    final jsonStr = jsonEncode(routers);
    await write('routers_list', jsonStr);
  }

  Future<void> addRouter(Map<String, String> router) async {
    final routers = await getRouters();
    routers.add(router);
    await saveRouters(routers);
  }

  Future<void> updateRouter(int index, Map<String, String> router) async {
    final routers = await getRouters();
    if (index < routers.length) {
      routers[index] = router;
      await saveRouters(routers);
    }
  }

  Future<void> deleteRouter(int index) async {
    final routers = await getRouters();
    if (index < routers.length) {
      routers.removeAt(index);
      await saveRouters(routers);
    }
  }

  Future<String?> getFirstLaunch() async => await read('first_launch');
  Future<void> setFirstLaunch(String date) async =>
      await write('first_launch', date);
}
