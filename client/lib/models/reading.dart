class Reading {
  const Reading({
    required this.deviceId,
    required this.temperature,
    required this.ph,
    required this.dissolvedOxygen,
    required this.timestamp,
  });

  factory Reading.fromJson(Map<String, dynamic> json) => Reading(
    deviceId: json['device_id'] as String,
    temperature: (json['temperature'] as num).toDouble(),
    ph: (json['ph'] as num).toDouble(),
    dissolvedOxygen: (json['dissolved_oxygen'] as num).toDouble(),
    timestamp: DateTime.parse(json['timestamp'] as String),
  );

  final String deviceId;
  final double temperature;
  final double ph;
  final double dissolvedOxygen;
  final DateTime timestamp;
}
