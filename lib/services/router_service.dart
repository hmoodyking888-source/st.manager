import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

class RouterService {
  final String host;
  final int port;
  final String username;
  final String password;
  bool _connected = false;

  RouterService({
    required this.host,
    this.port = 80,
    required this.username,
    required this.password,
  });

  String get _baseUrl => 'http://$host:$port/rest';

  Future<bool> connect() async {
    for (int i = 0; i < 3; i++) {
      try {
        final response = await http
            .get(
              Uri.parse('$_baseUrl/system/resource'),
              headers: _authHeaders(),
            )
            .timeout(const Duration(seconds: 3));
        if (response.statusCode == 200) {
          _connected = true;
          return true;
        }
      } catch (_) {
        await Future.delayed(Duration(seconds: i + 1));
      }
    }
    _connected = false;
    return false;
  }

  Map<String, String> _authHeaders() {
    final basicAuth =
        'Basic ${base64Encode(utf8.encode('$username:$password'))}';
    return {'Authorization': basicAuth};
  }

  Future<List<Map<String, dynamic>>> sendCommand(
    String command, {
    Map<String, dynamic>? params,
    bool usePost = false,
  }) async {
    if (!_connected) throw Exception('Not connected');
    final url = Uri.parse('$_baseUrl$command');
    http.Response response;
    for (int i = 0; i < 3; i++) {
      try {
        if (usePost) {
          response = await http.post(url,
              headers: _authHeaders(), body: jsonEncode(params ?? {}));
        } else {
          response = await http.get(url, headers: _authHeaders());
        }
        if (response.statusCode == 200) {
          final List<dynamic> jsonList = jsonDecode(response.body);
          return jsonList.cast<Map<String, dynamic>>();
        }
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
    final url = Uri.parse('$_baseUrl/interface/monitor-traffic');
    final response = await http.post(
      url,
      headers: _authHeaders(),
      body: jsonEncode({'interface': interfaceName, 'duration': '1s'}),
    );
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      if (data.isNotEmpty) {
        return {
          'rx-bits-per-second': double.tryParse(
                  data[0]['rx-bits-per-second']?.toString() ?? '0') ??
              0,
          'tx-bits-per-second': double.tryParse(
                  data[0]['tx-bits-per-second']?.toString() ?? '0') ??
              0,
        };
      }
    }
    return {'rx-bits-per-second': 0, 'tx-bits-per-second': 0};
  }

  Future<Map<String, String>> getSystemHealth() async {
    try {
      final List<Map<String, dynamic>> response =
          await sendCommand('system/health/print');
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
    } catch (_) {
      return {};
    }
  }

  Future<List<Map<String, dynamic>>> getInterfaceList() =>
      sendCommand('interface/print');
  Future<List<Map<String, dynamic>>> getHotspotActive() =>
      sendCommand('ip/hotspot/active/print');
  Future<List<Map<String, dynamic>>> getHotspotUsers() =>
      sendCommand('ip/hotspot/user/print');
  Future<List<Map<String, dynamic>>> getHotspotProfiles() =>
      sendCommand('ip/hotspot/user/profile/print');
  Future<List<Map<String, dynamic>>> getPppActive() =>
      sendCommand('ppp/active/print');
  Future<List<Map<String, dynamic>>> getPppSecrets() =>
      sendCommand('ppp/secret/print');
  Future<List<Map<String, dynamic>>> getSystemResource() =>
      sendCommand('system/resource/print');

  void disconnect() {
    _connected = false;
  }

  bool get isConnected => _connected;
}
