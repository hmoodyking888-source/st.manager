import 'dart:async';
import 'package:router_os_client/router_os_client.dart';

class RouterService {
  final String host;
  final int port;
  final String username;
  final String password;
  bool _connected = false;
  RouterOsClient? _client;

  RouterService({
    required this.host,
    this.port = 8728,
    required this.username,
    required this.password,
  });

  Future<bool> connect() async {
    for (int i = 0; i < 3; i++) {
      try {
        _client = RouterOsClient(
          host: host,
          port: port,
          username: username,
          password: password,
        );
        await _client!.connect();
        _connected = true;
        print('✅ Connected successfully');
        return true;
      } catch (e) {
        print('❌ Connection attempt ${i + 1} failed: $e');
        await Future.delayed(Duration(seconds: i + 1));
      }
    }
    _connected = false;
    return false;
  }

  // محاكاة sendCommand القديمة
  Future<List<Map<String, dynamic>>> sendCommand(
    String command, {
    Map<String, dynamic>? params,
    bool usePost = false,
  }) async {
    if (!_connected || _client == null) throw Exception('Not connected');
    for (int i = 0; i < 3; i++) {
      try {
        final Map<String, String>? args =
            params?.map((key, value) => MapEntry(key, value.toString()));
        final result = await _client!.execute(command, args: args);
        return result ?? [];
      } catch (_) {
        await Future.delayed(Duration(seconds: i + 1));
      }
    }
    throw Exception('Failed after retries');
  }

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

  Future<Map<String, String>> getSystemHealth() async {
    try {
      final List<Map<String, dynamic>> response =
          await sendCommand('/system/health/print');
      final healthData = <String, String>{};
      for (var item in response) {
        if (item.containsKey('name') && item.containsKey('value')) {
          final name = item['name'].toString().toLowerCase();
          final value = item['value'].toString();
          if (name.contains('temp')) {
            double? temp = double.tryParse(value);
            if (temp != null) {
              if (temp > 100) temp = temp / 10;
              healthData['temperature'] = temp.toStringAsFixed(1);
            }
          } else if (name.contains('volt')) {
            healthData['voltage'] = value;
          }
        } else {
          if (item.containsKey('temperature')) {
            double? temp = double.tryParse(item['temperature'].toString());
            if (temp != null) {
              if (temp > 100) temp = temp / 10;
              healthData['temperature'] = temp.toStringAsFixed(1);
            }
          }
          if (item.containsKey('voltage')) {
            healthData['voltage'] = item['voltage'].toString();
          }
        }
      }
      return healthData;
    } catch (e) {
      print('❌ getSystemHealth error: $e');
      return {};
    }
  }

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
    _client?.close();
    _client = null;
    _connected = false;
  }

  bool get isConnected => _connected;
}
