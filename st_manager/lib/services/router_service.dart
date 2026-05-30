import 'dart:async';
import 'package:routeros_api/routeros_api.dart';

class RouterService {
  RouterOsApi? _api; // RouterOsApi هو الاسم الصحيح
  final String host;
  final String username;
  final String password;

  RouterService({
    required this.host,
    required this.username,
    required this.password,
  });

  Future<bool> connect() async {
    try {
      _api = RouterOsApi(
        host: host,
        user: username,
        password: password,
      );
      await _api!.connect(timeout: const Duration(seconds: 5));
      return true;
    } catch (e) {
      _api = null;
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> sendCommand(
    String command, {
    Map<String, String>? params,
  }) async {
    if (_api == null) throw Exception('Not connected');
    final cmd = _api!.beginCommand(command);
    if (params != null) {
      params.forEach((key, value) {
        cmd.setArgument(key, value);
      });
    }
    final res = await cmd.execute();
    return res.asMapList();
  }

  Stream<double> monitorTraffic(String interface) async* {
    while (_api != null) {
      try {
        final result = await sendCommand(
          '/interface/monitor-traffic',
          params: {'interface': interface, 'once': ''},
        );
        if (result.isNotEmpty) {
          final bitsPerSecond = double.tryParse(
                  result.first['bits-per-second']?.toString() ?? '0') ??
              0;
          yield bitsPerSecond / 1000000;
        }
      } catch (_) {
        yield 0;
      }
      await Future.delayed(const Duration(seconds: 1));
    }
  }

  Stream<List<Map<String, dynamic>>> getLogStream() async* {
    while (_api != null) {
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
    _api?.close();
    _api = null;
  }

  bool get isConnected => _api != null;
}
