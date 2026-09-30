import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureTokenStorage {
  SecureTokenStorage({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _prefix = 'device_session_';
  static const _indexKey = 'connected_device_ids';
  final FlutterSecureStorage _storage;

  Future<String?> readToken(String deviceId) =>
      _storage.read(key: '$_prefix$deviceId');

  Future<List<String>> connectedDeviceIds() async {
    final storedIndex = await _storage.read(key: _indexKey);
    if (storedIndex != null && storedIndex.isNotEmpty) {
      try {
        final ids =
            (jsonDecode(storedIndex) as List<dynamic>)
                .whereType<String>()
                .where((id) => id.isNotEmpty)
                .toSet()
                .toList()
              ..sort();
        return ids;
      } catch (_) {
        await _storage.delete(key: _indexKey);
      }
    }

    final values = await _storage.readAll();
    final ids =
        values.keys
            .where((key) => key.startsWith(_prefix))
            .map((key) => key.substring(_prefix.length))
            .where((deviceId) => deviceId.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    if (ids.isNotEmpty) await _writeIndex(ids);
    return ids;
  }

  Future<void> saveToken(String deviceId, String token) async {
    await _storage.write(key: '$_prefix$deviceId', value: token);
    final ids = await connectedDeviceIds();
    if (!ids.contains(deviceId)) await _writeIndex([...ids, deviceId]);
  }

  Future<void> deleteToken(String deviceId) async {
    await _storage.delete(key: '$_prefix$deviceId');
    final ids = await connectedDeviceIds()
      ..removeWhere((id) => id == deviceId);
    await _writeIndex(ids);
  }

  Future<void> _writeIndex(List<String> ids) => _storage.write(
    key: _indexKey,
    value: jsonEncode(ids.toSet().toList()..sort()),
  );
}
