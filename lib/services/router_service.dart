import 'dart:async';
import 'package:router_os_client/router_os_client.dart';

class RouterService {
  final String host;
  final int port;
  final String username;
  final String password;
  bool _connected = false;
  RouterOSClient? _client; // ✅ تم تصحيح اسم الكلاس

  RouterService({
    required this.host,
    this.port = 8728,
    required this.username,
    required this.password,
  });

  Future<bool> connect() async {
    for (int i = 0; i < 3; i++) {
      try {
        // ✅ استخدام المُنشئ الصحيح من التوثيق الرسمي (useSsl = false للـ API العادي)
        _client = RouterOSClient(
          address: host,
          user: username,
          password: password,
          port: port,
          useSsl: port == 8729,
          verbose: false,
        );
        _connected = await _client!.login(); // ✅ طريقة تسجيل الدخول الصحيحة
        return _connected;
      } catch (_) {
        await Future.delayed(Duration(seconds: i + 1));
      }
    }
    _connected = false;
    return false;
  }

  /// إرسال الأوامر إلى RouterOS. متوافق مع التوقيع القديم (sendCommand)
  Future<List<Map<String, dynamic>>> sendCommand(
    String command, {
    Map<String, dynamic>? params,
    bool usePost = false,
  }) async {
    if (!_connected || _client == null) throw Exception('Not connected');
    for (int i = 0; i < 3; i++) {
      try {
        // تحويل المعاملات إلى Map<String, String>
        final Map<String, String>? args = params?.map(
          (key, value) => MapEntry(key, value.toString()),
        );
        // ✅ استخدام talk() لإرسال الأمر
        final List<Map<String, String>> result =
            await _client!.talk(command, args);
        // تحويل Map<String, String> إلى Map<String, dynamic> للحفاظ على التوافق
        return result
            .map((e) => e.map((k, v) => MapEntry(k, v as dynamic)))
            .toList();
      } catch (_) {
        await Future.delayed(Duration(seconds: i + 1));
      }
    }
    throw Exception('Failed after retries');
  }

  // بقية الدوال (monitorTrafficStream, getPortCurrentRate, getSystemHealth, etc.) تبقى كما هي دون تغيير.
  // ... (جميع الدوال الأخرى لم تتغير)

  Stream<double> monitorTrafficStream(String interface) async* {
    while (_connected) {
      try {
        final data = await getPortCurrentRate(interface);
        final totalMbps = ((data['rx-bits-per-second'] ?? 0) +
                (data['tx-bits-per-second'] ?? 0)) /
            1000000;
        yield totalMbps;
      } catch (_) {
        yield 0;
      }
      await Future.delayed(const Duration(seconds: 1));
    }
  }

  Future<Map<String, double>> getPortCurrentRate(String interfaceName) async {
    final result = await sendCommand(
      '/interface/monitor-traffic',
      params: {'interface': interfaceName, 'once': ''},
    );
    if (result.isNotEmpty) {
      final bits =
          double.tryParse(result.first['bits-per-second']?.toString() ?? '0') ??
              0;
      return {
        'rx-bits-per-second': bits / 2,
        'tx-bits-per-second': bits / 2,
      };
    }
    return {'rx-bits-per-second': 0, 'tx-bits-per-second': 0};
  }

  Future<List<Map<String, dynamic>>> getSystemHealth() =>
      sendCommand('/system/health/print');

  Future<List<Map<String, dynamic>>> getInterfaceList() =>
      sendCommand('/interface/print');

  Future<List<Map<String, dynamic>>> getHotspotActive() =>
      sendCommand('/ip/hotspot/active/print');

  Future<List<Map<String, dynamic>>> getHotspotUsers() =>
      sendCommand('/ip/hotspot/user/print');

  Future<List<Map<String, dynamic>>> getHotspotProfiles() =>
      sendCommand('/ip/hotspot/user/profile/print');

  Future<List<Map<String, dynamic>>> getPppActive() =>
      sendCommand('/ppp/active/print');

  Future<List<Map<String, dynamic>>> getPppSecrets() =>
      sendCommand('/ppp/secret/print');

  Future<List<Map<String, dynamic>>> getSystemResource() =>
      sendCommand('/system/resource/print');

  void disconnect() {
    _client?.close(); // ✅ استخدام close()
    _client = null;
    _connected = false;
  }

  bool get isConnected => _connected;
}
