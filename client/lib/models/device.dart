class Device {
  const Device({
    required this.deviceId,
    required this.name,
    this.createdAt,
    this.lastSeen,
    this.online = false,
    this.readingEnabled = true,
  });

  factory Device.fromJson(Map<String, dynamic> json) => Device(
    deviceId: json['device_id'] as String,
    name: json['name'] as String,
    createdAt: json['created_at'] as String?,
    lastSeen: json['last_seen'] as String?,
    online: json['online'] as bool? ?? false,
    readingEnabled: json['reading_enabled'] as bool? ?? true,
  );

  final String deviceId;
  final String name;
  final String? createdAt;
  final String? lastSeen;
  final bool online;
  final bool readingEnabled;

  Device copyWith({
    String? name,
    String? createdAt,
    String? lastSeen,
    bool? online,
    bool? readingEnabled,
  }) => Device(
    deviceId: deviceId,
    name: name ?? this.name,
    createdAt: createdAt ?? this.createdAt,
    lastSeen: lastSeen ?? this.lastSeen,
    online: online ?? this.online,
    readingEnabled: readingEnabled ?? this.readingEnabled,
  );
}
