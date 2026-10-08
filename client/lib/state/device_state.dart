import 'package:flutter/foundation.dart';
import 'package:client/models/device.dart';
import 'package:client/services/api_service.dart';

class DeviceState extends ChangeNotifier {
  DeviceState({ApiService? api}) : _api = api ?? apiService {
    _api.onSessionExpired = _handleSessionExpired;
  }

  final ApiService _api;
  List<Device> devices = const [];
  Device? selected;
  bool loading = true;
  Object? error;
  String? sessionMessage;
  VoidCallback? onReconnectRequired;
  bool _reconnectRequested = false;

  Future<void> load() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      await _loadConnectedDevices();
    } catch (value) {
      error = value;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    try {
      await _loadConnectedDevices();
      error = null;
    } catch (value) {
      error = value;
    }
    notifyListeners();
  }

  Device? deviceForId(String deviceId) =>
      devices.where((device) => device.deviceId == deviceId).firstOrNull;

  void replaceDevice(Device device) {
    devices = devices
        .map((item) => item.deviceId == device.deviceId ? device : item)
        .toList(growable: false);
    if (selected?.deviceId == device.deviceId) selected = device;
    notifyListeners();
  }

  Future<Device> renameDevice(String deviceId, String name) async {
    final updated = await _api.renameDevice(deviceId, name);
    replaceDevice(updated);
    return updated;
  }

  Future<void> _loadConnectedDevices() async {
    final ids = await _api.connectedDeviceIds();
    final remoteDevices = await _api.fetchDevices();
    final byId = {for (final device in remoteDevices) device.deviceId: device};
    devices = ids
        .map((id) => byId[id] ?? Device(deviceId: id, name: id))
        .toList(growable: false);
    if (selected == null ||
        !devices.any((device) => device.deviceId == selected!.deviceId)) {
      selected = devices.isEmpty ? null : devices.first;
    } else {
      selected = devices.firstWhere(
        (device) => device.deviceId == selected!.deviceId,
      );
    }
  }

  void select(Device? device) {
    selected = device;
    sessionMessage = null;
    notifyListeners();
  }

  Future<void> connect({
    required String deviceId,
    required String deviceKey,
  }) async {
    await _api.connectDevice(deviceId: deviceId, deviceKey: deviceKey);
    _reconnectRequested = false;
    sessionMessage = null;
    await load();
    selected = devices.firstWhere(
      (device) => device.deviceId == deviceId,
      orElse: () => Device(deviceId: deviceId, name: deviceId),
    );
    notifyListeners();
  }

  Future<void> disconnect(String deviceId) async {
    await _api.disconnectDevice(deviceId);
    devices = devices
        .where((device) => device.deviceId != deviceId)
        .toList(growable: false);
    if (selected?.deviceId == deviceId) {
      selected = devices.isEmpty ? null : devices.first;
    }
    notifyListeners();
  }

  void _handleSessionExpired(String deviceId) {
    devices = devices
        .where((device) => device.deviceId != deviceId)
        .toList(growable: false);
    if (selected?.deviceId == deviceId) {
      selected = devices.isEmpty ? null : devices.first;
    }
    sessionMessage = 'This device needs to reconnect.';
    notifyListeners();
    if (!_reconnectRequested) {
      _reconnectRequested = true;
      onReconnectRequired?.call();
    }
  }
}
