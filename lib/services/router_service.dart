import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

class RouterService {
  final String host;
  final String username;
  final String password;
  bool _connected = false;

  RouterService({
    required this.host,
    required this.username,
    required this.password,
  });

  Map<String, String> _authHeaders() {
    final basicAuth =
        'Basic ${base64Encode(utf8.encode('$username:$password'))}';
    return {
      'Authorization': basicAuth,
      'Content-Type': 'application/json',
    };
  }

  Future<bool> connect() async {
    for (int i = 0; i < 3; i++) {
      try {
        final response = await http
            .get(
              Uri.parse('https://$host/rest/system/resource'),
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

  Future<List<Map<String, dynamic>>> sendCommand(
    String command, {
    Map<String, dynamic>? params,
    bool usePost = false,
  }) async {
    if (!_connected) throw Exception('Not connected');
    final url = Uri.https(host, '/rest/$command');
    http.Response response;
    for (int i = 0; i < 3; i++) {
      try {
        if (usePost) {
          response = await http
              .post(url,
                  headers: _authHeaders(), body: jsonEncode(params ?? {}))
              .timeout(const Duration(seconds: 3));
        } else {
          response = await http
              .get(url, headers: _authHeaders())
              .timeout(const Duration(seconds: 3));
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
    final url = Uri.https(host, '/rest/interface/monitor-traffic');
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
      final List<Map<String, String>> response =
          await sendCommand('system/health/print')
              .then((data) => data.cast<Map<String, String>>());
      final healthData = <String, String>{};
      for (var item in response) {
        if (item.containsKey('name') && item.containsKey('value')) {
          final name = item['name']!.toLowerCase();
          final value = item['value']!;
          if (name.contains('temp')) {
            double temp = double.tryParse(value) ?? 0;
            if (temp > 100) temp = temp / 10;
            healthData['temperature'] = temp.toStringAsFixed(1);
          } else if (name.contains('volt')) {
            healthData['voltage'] = value;
          } else {
            healthData[name] = value;
          }
        } else {
          if (item.containsKey('temperature')) {
            double temp = double.tryParse(item['temperature']!) ?? 0;
            if (temp > 100) temp = temp / 10;
            healthData['temperature'] = temp.toStringAsFixed(1);
          }
          if (item.containsKey('voltage'))
            healthData['voltage'] = item['voltage']!;
        }
      }
      return healthData;
    } catch (_) {
      return {};
    }
  }

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
  Future<List<Map<String, dynamic>>> getInterfaceList() =>
      sendCommand('interface/print');

  void disconnect() {
    _connected = false;
  }

  bool get isConnected => _connected;
}
