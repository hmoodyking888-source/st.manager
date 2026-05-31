import 'dart:async';
import 'package:router_os_client/router_os_client.dart';

class RouterService {
  RouterOSClient? _api;
  final String host;
  final String username;
  final String password;
  bool _connected = false;

  RouterService({
    required this.host,
    required this.username,
    required this.password,
  });

  Future<bool> connect() async {
    try {
      _api = RouterOSClient(
        address:
            host, // استخدام 'address' بدلاً من 'host' و 'user' بدلاً من 'username'
        user: username,
        password: password,
        useSsl: false,
      );
      _connected = await _api!
          .login(); // مكتبة 'router_os_client' تستخدم login() للاتصال
      return _connected;
    } catch (e) {
      _connected = false;
      return false;
    }
  }

  Future<List<Map<String, String>>> sendCommand(
    String command, {
    Map<String, String>? params,
  }) async {
    // تم تعديل نوع القيمة المعادة إلى List<Map<String, String>>
    if (!_connected || _api == null) throw Exception('Not connected');
    try {
      // يمكننا تمرير الأوامر والمعاملات مباشرة إلى الدالة talk().
      final result = await _api!.talk(command, params);
      return result;
    } catch (e) {
      // إعادة طرح الخطأ أو معالجته كما تراه مناسباً.
      print('خطأ في إرسال الأمر: $e');
      rethrow;
    }
  }

  Stream<double> monitorTrafficStream(String interface) async* {
    while (_connected) {
      try {
        final result = await sendCommand(
          '/interface/monitor-traffic',
          params: {
            'interface': interface,
            'once': 'once'
          }, // 'once' لا تحتاج لقيمة، لكن تمريرها كـ'once' مناسب
        );
        if (result.isNotEmpty) {
          final bits = double.tryParse(
                  result.first['bits-per-second']?.toString() ?? '0') ??
              0;
          yield bits / 1000000;
        }
      } catch (_) {
        yield 0;
      }
      await Future.delayed(const Duration(seconds: 1));
    }
  }

  // ----- أوامر مختصرة -----
  Future<List<Map<String, String>>> getHotspotActive() =>
      sendCommand('/ip/hotspot/active/print');
  Future<List<Map<String, String>>> getHotspotUsers() =>
      sendCommand('/ip/hotspot/user/print');
  Future<List<Map<String, String>>> getHotspotProfiles() =>
      sendCommand('/ip/hotspot/user/profile/print');
  Future<List<Map<String, String>>> getPppActive() =>
      sendCommand('/ppp/active/print');
  Future<List<Map<String, String>>> getPppSecrets() =>
      sendCommand('/ppp/secret/print');
  Future<List<Map<String, String>>> getSystemResource() =>
      sendCommand('/system/resource/print');
  Future<List<Map<String, String>>> getSystemHealth() =>
      sendCommand('/system/health/print');

  void disconnect() {
    _api?.close();
    _api = null;
    _connected = false;
  }

  bool get isConnected => _connected;
}
