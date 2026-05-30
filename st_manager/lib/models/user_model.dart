class ActiveUser {
  final String name;
  final String speed; // e.g., "2M/512k"
  final double usage; // بالميغابت للفرز

  ActiveUser({required this.name, required this.speed, required this.usage});
}
