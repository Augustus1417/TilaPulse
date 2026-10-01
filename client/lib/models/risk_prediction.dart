class RiskPrediction {
  const RiskPrediction({
    required this.deviceId,
    required this.lstmProbability,
    required this.bocpdProbability,
    required this.riskScore,
    required this.riskLabel,
    required this.createdAt,
  });

  factory RiskPrediction.fromJson(Map<String, dynamic> json) => RiskPrediction(
    deviceId: json['device_id'] as String,
    lstmProbability: (json['lstm_probability'] as num).toDouble(),
    bocpdProbability:
      (json['bocpd_change_point_probability'] as num).toDouble(),
    riskScore: (json['risk_score'] as num).toDouble(),
    riskLabel: json['risk_label'] as String,
    createdAt: DateTime.parse(json['created_at'] as String),
  );

  final String deviceId;
  final double lstmProbability;
  final double bocpdProbability;
  final double riskScore;
  final String riskLabel;
  final DateTime createdAt;
}
