class NetworkDevice {
  final String name;
  final String ip;
  final String? username;
  final String? password;
  final String type;
  bool isOnline;

  NetworkDevice({
    required this.name,
    required this.ip,
    this.username,
    this.password,
    required this.type,
    this.isOnline = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'ip': ip,
      'username': username,
      'password': password,
      'type': type,
    };
  }

  factory NetworkDevice.fromMap(Map<String, dynamic> map) {
    return NetworkDevice(
      name: map['name'] ?? '',
      ip: map['ip'] ?? '',
      username: map['username'],
      password: map['password'],
      type: map['type'] ?? 'Access Point',
      isOnline: map['isOnline'] ?? false,
    );
  }
}
