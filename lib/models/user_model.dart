class ActiveUser {
  final String id;
  final String name;
  final String? password;
  final String? profile;
  final String? uptime;
  final String? bytesIn;
  final String? bytesOut;
  final bool disabled;
  final bool active;

  ActiveUser({
    required this.id,
    required this.name,
    this.password,
    this.profile,
    this.uptime,
    this.bytesIn,
    this.bytesOut,
    this.disabled = false,
    this.active = false,
  });

  factory ActiveUser.fromMap(Map<String, dynamic> map,
      {bool isActive = false}) {
    return ActiveUser(
      id: map['.id']?.toString() ?? '',
      name: map['name']?.toString() ?? (map['user']?.toString() ?? ''),
      password: map['password']?.toString(),
      profile: map['profile']?.toString(),
      uptime: map['uptime']?.toString(),
      bytesIn: map['bytes-in']?.toString(),
      bytesOut: map['bytes-out']?.toString(),
      disabled: map['disabled'] == 'true',
      active: isActive,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      '.id': id,
      'name': name,
      'password': password,
      'profile': profile,
      'uptime': uptime,
      'bytes-in': bytesIn,
      'bytes-out': bytesOut,
      'disabled': disabled.toString(),
    };
  }
}
