import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class SensorReadingData {
  const SensorReadingData({
    required this.temperature,
    required this.ph,
    required this.dissolvedOxygen,
    required this.timestamp,
  });

  factory SensorReadingData.fromJson(Map<String, dynamic> json) {
    return SensorReadingData(
      temperature: (json['temperature'] as num).toDouble(),
      ph: (json['ph'] as num).toDouble(),
      dissolvedOxygen: (json['dissolved_oxygen'] as num).toDouble(),
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }

  final double temperature;
  final double ph;
  final double dissolvedOxygen;
  final DateTime timestamp;
}

class PredictionData {
  const PredictionData({required this.riskScore});

  factory PredictionData.fromJson(Map<String, dynamic> json) {
    return PredictionData(riskScore: (json['risk_score'] as num).toDouble());
  }

  final double riskScore;
}

class DeviceData {
  const DeviceData({required this.deviceId, this.name, this.lastSeen});

  factory DeviceData.fromJson(Map<String, dynamic> json) {
    return DeviceData(
      deviceId: json['device_id'] as String,
      name: json['name'] as String?,
      lastSeen: json['last_seen'] as String?,
    );
  }

  final String deviceId;
  final String? name;
  final String? lastSeen;
}

class SensorApiException implements Exception {
  const SensorApiException(this.statusCode);
  final int statusCode;
}

class SensorApi {
  SensorApi({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        _baseUrl = baseUrl ?? _defaultBaseUrl;

  final http.Client _client;
  final String _baseUrl;
  static const defaultDeviceId = 'pond-1';

  static String get _defaultBaseUrl {
    const configuredUrl = String.fromEnvironment('API_BASE_URL');
    if (configuredUrl.isNotEmpty) return configuredUrl;
    if (kIsWeb) return 'http://localhost:8000';
    if (Platform.isAndroid) return 'http://10.0.2.2:8000';
    return 'http://localhost:8000';
  }

  static const _requestTimeout = Duration(seconds: 8);

  Future<SensorReadingData> fetchLatest(String deviceId) async {
    final uri = Uri.parse('$_baseUrl/api/readings/latest').replace(
      queryParameters: {'device_id': deviceId},
    );
    final response = await _client.get(uri).timeout(_requestTimeout);

    if (response.statusCode != 200) {
      throw SensorApiException(response.statusCode);
    }

    return SensorReadingData.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<PredictionData> fetchPrediction(String deviceId) async {
    final response = await _client
        .post(
          Uri.parse('$_baseUrl/api/predict'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'device_id': deviceId}),
        )
        .timeout(_requestTimeout);
    if (response.statusCode != 200) throw SensorApiException(response.statusCode);
    return PredictionData.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<List<DeviceData>> fetchDevices() async {
    final response = await _client.get(Uri.parse('$_baseUrl/api/devices')).timeout(_requestTimeout);
    if (response.statusCode != 200) throw SensorApiException(response.statusCode);
    return (jsonDecode(response.body) as List<dynamic>)
        .map((item) => DeviceData.fromJson(item as Map<String, dynamic>))
        .toList();
  }
}

final sensorApi = SensorApi();
