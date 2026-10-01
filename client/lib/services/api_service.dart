import 'dart:convert';

import 'package:client/core/constants.dart';
import 'package:client/models/alert.dart';
import 'package:client/models/device.dart';
import 'package:client/models/reading.dart';
import 'package:client/models/risk_prediction.dart';
import 'package:client/services/secure_token_storage.dart';
import 'package:http/http.dart' as http;

class ApiException implements Exception {
  const ApiException(this.statusCode, this.message);
  final int statusCode;
  final String message;
  @override
  String toString() => message;
}

class SessionExpiredException extends ApiException {
  const SessionExpiredException(String message) : super(401, message);
}

class ApiService {
  ApiService({
    http.Client? client,
    String? baseUrl,
    SecureTokenStorage? tokenStorage,
  }) : _client = client ?? http.Client(),
       _baseUrl = baseUrl ?? resolvedApiBaseUrl,
       _tokenStorage = tokenStorage ?? SecureTokenStorage();

  final http.Client _client;
  final String _baseUrl;
  final SecureTokenStorage _tokenStorage;
  static const timeout = Duration(seconds: 12);

  void Function(String deviceId)? onSessionExpired;

  Future<dynamic> _request(
    String method,
    String path, {
    Map<String, String>? query,
    Object? body,
    String? deviceId,
  }) async {
    final uri = Uri.parse('$_baseUrl$path').replace(queryParameters: query);
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (deviceId != null) {
      final token = await _tokenStorage.readToken(deviceId);
      if (token == null || token.isEmpty) {
        throw const SessionExpiredException('This device needs to reconnect.');
      }
      headers['Authorization'] = 'Bearer $token';
    }

    final encodedBody = body == null ? null : jsonEncode(body);
    final response = switch (method) {
      'GET' => await _client.get(uri, headers: headers).timeout(timeout),
      'PATCH' =>
        await _client
            .patch(uri, headers: headers, body: encodedBody)
            .timeout(timeout),
      'DELETE' => await _client.delete(uri, headers: headers).timeout(timeout),
      _ =>
        await _client
            .post(uri, headers: headers, body: encodedBody)
            .timeout(timeout),
    };

    if (response.statusCode == 401 && deviceId != null) {
      await _tokenStorage.deleteToken(deviceId);
      onSessionExpired?.call(deviceId);
      throw const SessionExpiredException('This device needs to reconnect.');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(response.statusCode, _message(response));
    }
    return response.body.isEmpty ? null : jsonDecode(response.body);
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

  Future<List<String>> connectedDeviceIds() =>
      _tokenStorage.connectedDeviceIds();

  Future<List<Device>> fetchDevices() async =>
      (await _request('GET', '/api/devices') as List<dynamic>)
          .map((item) => Device.fromJson(item as Map<String, dynamic>))
          .toList();

  Future<Device> updateReadingState(String deviceId, bool enabled) async =>
      Device.fromJson(
        await _request(
          'PATCH',
          '/api/devices/$deviceId/reading-state',
          body: {'enabled': enabled},
          deviceId: deviceId,
        ) as Map<String, dynamic>,
      );

  Future<String> connectDevice({
    required String deviceId,
    required String deviceKey,
  }) async {
    try {
      final response = await _request(
        'POST',
        '/api/devices/connect',
        body: {'device_id': deviceId, 'device_key': deviceKey},
      ) as Map<String, dynamic>;
      final token = response['token'] as String?;
      if (token == null || token.isEmpty) {
        throw const ApiException(500, 'The server returned no session token.');
      }
      await _tokenStorage.saveToken(deviceId, token);
      return token;
    } on ApiException catch (error) {
      if (error.statusCode == 401) {
        throw const ApiException(401, 'Invalid device ID or key.');
      }
      rethrow;
    }
  }

  Future<void> disconnectDevice(String deviceId) async {
    try {
      await _request('DELETE', '/api/devices/disconnect', deviceId: deviceId);
    } finally {
      await _tokenStorage.deleteToken(deviceId);
    }
  }

  Future<Reading> fetchLatest(String deviceId) async => Reading.fromJson(
    await _request(
      'GET',
      '/api/readings/latest',
      query: {'device_id': deviceId},
      deviceId: deviceId,
    ) as Map<String, dynamic>,
  );

  Future<List<WaterAlert>> fetchAlerts(String deviceId) async =>
      (await _request(
        'GET',
        '/api/devices/$deviceId/alerts',
        deviceId: deviceId,
      ) as List<dynamic>)
          .map((item) => WaterAlert.fromJson(item as Map<String, dynamic>))
          .toList();

  Future<void> resolveAlert(String deviceId, int alertId) async {
    await _request(
      'DELETE',
      '/api/devices/$deviceId/alerts/$alertId',
      deviceId: deviceId,
    );
  }

  Future<List<Reading>> fetchReadings(
    String deviceId, {
    int limit = 200,
  }) async =>
      (await _request(
            'GET',
            '/api/readings',
            query: {'device_id': deviceId, 'limit': '$limit'},
            deviceId: deviceId,
          ) as List<dynamic>)
          .map((item) => Reading.fromJson(item as Map<String, dynamic>))
          .toList();

  Future<RiskPrediction> fetchLatestRisk(String deviceId) async =>
      RiskPrediction.fromJson(
        await _request(
          'GET',
          '/api/devices/$deviceId/risk/latest',
          deviceId: deviceId,
        ) as Map<String, dynamic>,
      );

  Future<RiskPrediction> runAssessment(String deviceId) async =>
      RiskPrediction.fromJson(
        await _request(
          'POST',
          '/api/devices/$deviceId/predict',
          deviceId: deviceId,
        ) as Map<String, dynamic>,
      );
}

final apiService = ApiService();
