class RiskPrediction {
  const RiskPrediction({
    required this.deviceId,
    required this.lstmProbability,
    required this.bocpdProbability,
    required this.riskScore,
    required this.notice,
  });

  factory RiskPrediction.fromJson(Map<String, dynamic> json) => RiskPrediction(
    deviceId: json['device_id'] as String,
    lstmProbability: (json['lstm_probability'] as num).toDouble(),
    bocpdProbability: (json['bocpd_probability'] as num).toDouble(),
    riskScore: (json['risk_score'] as num).toDouble(),
    notice: json['synthetic_model_notice'] as String?,
  );

  final String deviceId;
  final double lstmProbability;
  final double bocpdProbability;
  final double riskScore;
  final String? notice;
}
