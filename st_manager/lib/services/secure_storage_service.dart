import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  final _storage = const FlutterSecureStorage();

  Future<void> write(String key, String value) async {
    await _storage.write(key: key, value: value);
  }

  Future<String?> read(String key) async {
    return await _storage.read(key: key);
  }

  Future<void> delete(String key) async {
    await _storage.delete(key: key);
  }

  // تخزين بيانات الراوتر مشفرة
  Future<void> saveRouterCredentials({
    required String host,
    required String username,
    required String password,
  }) async {
    await write('router_host', host);
    await write('router_username', username);
    await write('router_password', password);
  }

  Future<Map<String, String?>?> getRouterCredentials() async {
    final host = await read('router_host');
    final username = await read('router_username');
    final password = await read('router_password');
    if (host == null || username == null || password == null) return null;
    return {'host': host, 'username': username, 'password': password};
  }

  Future<void> clearAll() async {
    await _storage.deleteAll();
  }
}
