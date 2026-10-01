class WaterAlert {
  const WaterAlert({
    required this.id,
    required this.deviceId,
    required this.parameter,
    required this.value,
    required this.thresholdBreached,
    required this.message,
    required this.createdAt,
  });

  factory WaterAlert.fromJson(Map<String, dynamic> json) => WaterAlert(
        id: json['id'] as int,
        deviceId: json['device_id'] as String,
        parameter: json['parameter'] as String,
        value: (json['value'] as num).toDouble(),
        thresholdBreached: json['threshold_breached'] as String,
        message: json['message'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  final int id;
  final String deviceId;
  final String parameter;
  final double value;
  final String thresholdBreached;
  final String message;
  final DateTime createdAt;

  String get title => switch (parameter) {
        'temperature' => 'Temperature alert',
        'ph' => 'pH alert',
        'dissolved_oxygen' => 'Dissolved oxygen alert',
        _ => 'Water-quality alert',
      };
}
