class ReadingSeries {
  const ReadingSeries({
    required this.deviceId,
    required this.range,
    required this.bucketSeconds,
    required this.from,
    required this.to,
    required this.points,
    required this.thresholds,
  });

  factory ReadingSeries.fromJson(Map<String, dynamic> json) {
    final thresholdJson = json['thresholds'] as Map<String, dynamic>;
    return ReadingSeries(
      deviceId: json['device_id'] as String,
      range: json['range'] as String,
      bucketSeconds: (json['bucket_seconds'] as num).toInt(),
      from: DateTime.parse(json['from'] as String),
      to: DateTime.parse(json['to'] as String),
      points: (json['points'] as List<dynamic>)
          .map((item) => ReadingSeriesPoint.fromJson(item as Map<String, dynamic>))
          .toList(growable: false),
      thresholds: {
        for (final entry in thresholdJson.entries)
          entry.key: ReadingSeriesThreshold.fromJson(
            entry.value as Map<String, dynamic>,
          ),
      },
    );
  }

  final String deviceId;
  final String range;
  final int bucketSeconds;
  final DateTime from;
  final DateTime to;
  final List<ReadingSeriesPoint> points;
  final Map<String, ReadingSeriesThreshold> thresholds;
}

class ReadingSeriesPoint {
  const ReadingSeriesPoint({
    required this.time,
    required this.count,
    required this.metrics,
  });

  factory ReadingSeriesPoint.fromJson(Map<String, dynamic> json) =>
      ReadingSeriesPoint(
        time: DateTime.parse(json['t'] as String),
        count: (json['count'] as num).toInt(),
        metrics: {
          for (final key in const ['temperature', 'ph', 'dissolved_oxygen'])
            key: ReadingSeriesMetric.fromJson(
              json[key] as Map<String, dynamic>,
            ),
        },
      );

  final DateTime time;
  final int count;
  final Map<String, ReadingSeriesMetric> metrics;
}

class ReadingSeriesMetric {
  const ReadingSeriesMetric({
    required this.average,
    required this.minimum,
    required this.maximum,
  });

  factory ReadingSeriesMetric.fromJson(Map<String, dynamic> json) =>
      ReadingSeriesMetric(
        average: (json['avg'] as num).toDouble(),
        minimum: (json['min'] as num).toDouble(),
        maximum: (json['max'] as num).toDouble(),
      );

  final double average;
  final double minimum;
  final double maximum;
}

class ReadingSeriesThreshold {
  const ReadingSeriesThreshold({
    required this.minimum,
    required this.maximum,
    this.warningMinimum,
    this.warningMaximum,
    this.criticalMinimum,
    this.criticalMaximum,
  });

  factory ReadingSeriesThreshold.fromJson(Map<String, dynamic> json) =>
      ReadingSeriesThreshold(
        minimum: (json['min'] as num).toDouble(),
        maximum: (json['max'] as num?)?.toDouble(),
        warningMinimum: (json['warn_min'] as num?)?.toDouble(),
        warningMaximum: (json['warn_max'] as num?)?.toDouble(),
        criticalMinimum: (json['crit_min'] as num?)?.toDouble(),
        criticalMaximum: (json['crit_max'] as num?)?.toDouble(),
      );

  final double minimum;
  final double? maximum;
  final double? warningMinimum;
  final double? warningMaximum;
  final double? criticalMinimum;
  final double? criticalMaximum;
}
