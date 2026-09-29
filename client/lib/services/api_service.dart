import 'dart:convert';

import 'package:client/core/constants.dart';
import 'package:client/models/device.dart';
import 'package:client/models/reading.dart';
import 'package:client/models/risk_prediction.dart';
import 'package:http/http.dart' as http;

class ApiException implements Exception {
  const ApiException(this.statusCode, this.message);
  final int statusCode;
  final String message;
  @override
  String toString() => message;
}

class ApiService {
  ApiService({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      _baseUrl = baseUrl ?? resolvedApiBaseUrl;
  final http.Client _client;
  final String _baseUrl;
  static const timeout = Duration(seconds: 12);

  Future<dynamic> _request(
    String method,
    String path, {
    Map<String, String>? query,
    Object? body,
    bool admin = false,
  }) async {
    final uri = Uri.parse('$_baseUrl$path').replace(queryParameters: query);
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (admin) headers['X-Admin-Key'] = adminKey;
    final response = method == 'GET'
        ? await _client.get(uri, headers: headers).timeout(timeout)
        : await _client
              .post(uri, headers: headers, body: jsonEncode(body))
              .timeout(timeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(response.statusCode, _message(response));
    }
    return jsonDecode(response.body);
  }

  String _message(http.Response response) {
    try {
      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      return payload['detail']?.toString() ??
          'Request failed (${response.statusCode}).';
    } catch (_) {
      return 'Request failed (${response.statusCode}).';
    }
  }

  Future<List<Device>> fetchDevices() async =>
      (await _request('GET', '/api/devices') as List<dynamic>)
          .map((item) => Device.fromJson(item as Map<String, dynamic>))
          .toList();

  Future<List<Device>> fetchAdminDevices() async =>
      (await _request('GET', '/api/admin/devices', admin: true)
              as List<dynamic>)
          .map((item) => Device.fromJson(item as Map<String, dynamic>))
          .toList();

  Future<Device> registerDevice({
    required String deviceId,
    required String name,
    String? deviceKey,
  }) async => Device.fromJson(
    await _request(
      'POST',
      '/api/admin/devices',
      admin: true,
      body: {
        'device_id': deviceId,
        'name': name,
        if (deviceKey?.isNotEmpty == true) 'device_key': deviceKey,
      },
    ) as Map<String, dynamic>,
  );

  Future<Reading> fetchLatest(String deviceId) async => Reading.fromJson(
    await _request(
      'GET',
      '/api/readings/latest',
      query: {'device_id': deviceId},
    ) as Map<String, dynamic>,
  );

  Future<List<Reading>> fetchReadings(
    String deviceId, {
    int limit = 200,
  }) async =>
      (await _request(
            'GET',
            '/api/readings',
            query: {'device_id': deviceId, 'limit': '$limit'},
          ) as List<dynamic>)
          .map((item) => Reading.fromJson(item as Map<String, dynamic>))
          .toList();

  Future<RiskPrediction> predict(String deviceId) async =>
      RiskPrediction.fromJson(
        await _request('POST', '/api/predict', body: {'device_id': deviceId})
            as Map<String, dynamic>,
      );
}

final apiService = ApiService();
