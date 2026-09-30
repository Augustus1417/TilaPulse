class Device {
  const Device({
    required this.deviceId,
    required this.name,
    this.createdAt,
    this.lastSeen,
  });

  factory Device.fromJson(Map<String, dynamic> json) => Device(
    deviceId: json['device_id'] as String,
    name: json['name'] as String,
    createdAt: json['created_at'] as String?,
    lastSeen: json['last_seen'] as String?,
  );

  final String deviceId;
  final String name;
  final String? createdAt;
  final String? lastSeen;
}
