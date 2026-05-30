import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

class RouterService {
  final String host;
  final String username;
  final String password;
  String? _baseUrl;
  bool _connected = false;

  RouterService({
    required this.host,
    required this.username,
    required this.password,
  });

  Future<bool> connect() async {
    _baseUrl = 'http://$host/rest';
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/system/resource'),
        headers: _authHeaders(),
      );
      if (response.statusCode == 200) {
        _connected = true;
        return true;
      }
    } catch (_) {}
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
    Map<String, String>? params,
  }) async {
    if (!_connected) throw Exception('Not connected');
    final uri = Uri.parse('$_baseUrl$command').replace(queryParameters: params);
    final response = await http.get(uri, headers: _authHeaders());
    if (response.statusCode == 200) {
      final List<dynamic> jsonList = jsonDecode(response.body);
      return jsonList.cast<Map<String, dynamic>>();
    }
    throw Exception('Failed: ${response.statusCode}');
  }

  Stream<double> monitorTraffic(String interface) async* {
    while (_connected) {
      try {
        final result = await sendCommand(
          '/interface/monitor-traffic',
          params: {'interface': interface, 'once': ''},
        );
        if (result.isNotEmpty) {
          final bits = double.tryParse(
                  result.first['bits-per-second']?.toString() ?? '0') ??
              0;
          yield bits / 1000000; // Mbps
        }
      } catch (_) {
        yield 0;
      }
      await Future.delayed(const Duration(seconds: 1));
    }
  }

  Stream<List<Map<String, dynamic>>> getLogStream() async* {
    while (_connected) {
      try {
        final logs = await sendCommand('/log/print', params: {'limit': '5'});
        yield logs;
      } catch (_) {
        yield [];
      }
      await Future.delayed(const Duration(seconds: 2));
    }
  }

  void disconnect() {
    _connected = false;
  }

  bool get isConnected => _connected;
}
