import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart'; // <-- تمت الإضافة

class RouterService {
  final String host;
  final int port;
  final String username;
  final String password;
  final bool useHttps;
  bool _connected = false;
  late http.Client _client;

  RouterService({
    required this.host,
    this.port = 443,
    required this.username,
    required this.password,
    this.useHttps = true,
  }) {
    final ioClient = HttpClient()
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
    _client = IOClient(ioClient);
  }

  String get _scheme => useHttps ? 'https' : 'http';
  String get _baseUrl => '$_scheme://$host:$port/rest';

  Future<bool> connect() async {
    for (int i = 0; i < 3; i++) {
      try {
        final response = await _client
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
          response = await _client.post(url,
              headers: _authHeaders(), body: jsonEncode(params ?? {}));
        } else {
          response = await _client.get(url, headers: _authHeaders());
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
    final response = await _client.post(
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
    _client.close();
  }

  bool get isConnected => _connected;
}
