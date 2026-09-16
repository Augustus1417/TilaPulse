import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class SensorReadingData {
  const SensorReadingData({
    required this.deviceId,
    required this.temperature,
    required this.ph,
    required this.dissolvedOxygen,
    required this.timestamp,
  });

  factory SensorReadingData.fromJson(Map<String, dynamic> json) {
    return SensorReadingData(
      deviceId: json['device_id'] as String,
      temperature: (json['temperature'] as num).toDouble(),
      ph: (json['ph'] as num).toDouble(),
      dissolvedOxygen: (json['dissolved_oxygen'] as num).toDouble(),
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }

  final String deviceId;
  final double temperature;
  final double ph;
  final double dissolvedOxygen;
  final DateTime timestamp;
}

class SensorApi {
  SensorApi({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        _baseUrl = baseUrl ?? _defaultBaseUrl;

  final http.Client _client;
  final String _baseUrl;

  static String get _defaultBaseUrl {
    const configuredUrl = String.fromEnvironment('API_BASE_URL');
    if (configuredUrl.isNotEmpty) return configuredUrl;
    if (kIsWeb) return 'http://localhost:8000';
    if (Platform.isAndroid) return 'http://10.0.2.2:8000';
    return 'http://localhost:8000';
  }

  Future<SensorReadingData> fetchLatest(String deviceId) async {
    final response = await _client.get(
      Uri.parse('$_baseUrl/api/readings/latest').replace(
        queryParameters: {'device_id': deviceId},
      ),
    );

    if (response.statusCode != 200) {
      throw Exception('Sensor API returned ${response.statusCode}');
    }

    return SensorReadingData.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }
}

final sensorApi = SensorApi();
const defaultDeviceId = 'ESP32-TILAPIA-001';