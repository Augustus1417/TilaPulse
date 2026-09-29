import 'package:client/models/reading.dart';

enum AlertType { temperature, ph, dissolvedOxygen }

class WaterAlert {
  const WaterAlert({
    required this.type,
    required this.title,
    required this.description,
    required this.value,
    required this.timestamp,
  });

  final AlertType type;
  final String title;
  final String description;
  final double value;
  final DateTime timestamp;

  String get key => type.name;
}

List<WaterAlert> alertsForReading(Reading reading) {
  final alerts = <WaterAlert>[];
  if (reading.temperature < 24 || reading.temperature > 32) {
    alerts.add(
      WaterAlert(
        type: AlertType.temperature,
        title: 'Temperature out of range',
        description: 'Healthy range is 24-32 C.',
        value: reading.temperature,
        timestamp: reading.timestamp,
      ),
    );
  }
  if (reading.ph < 6.5 || reading.ph > 8.5) {
    alerts.add(
      WaterAlert(
        type: AlertType.ph,
        title: 'pH out of range',
        description: 'Healthy range is 6.5-8.5.',
        value: reading.ph,
        timestamp: reading.timestamp,
      ),
    );
  }
  if (reading.dissolvedOxygen < 5) {
    alerts.add(
      WaterAlert(
        type: AlertType.dissolvedOxygen,
        title: 'Dissolved oxygen low',
        description: 'Healthy level is at least 5.0 mg/L.',
        value: reading.dissolvedOxygen,
        timestamp: reading.timestamp,
      ),
    );
  }
  return alerts;
}
