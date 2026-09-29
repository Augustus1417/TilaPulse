import 'package:flutter/foundation.dart';
import 'package:client/models/device.dart';
import 'package:client/services/api_service.dart';

class DeviceState extends ChangeNotifier {
  DeviceState({ApiService? api}) : _api = api ?? apiService;
  final ApiService _api;
  List<Device> devices = const [];
  Device? selected;
  bool loading = true;
  Object? error;

  Future<void> load() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      devices = await _api.fetchDevices();
      if (selected == null ||
          !devices.any((device) => device.deviceId == selected!.deviceId)) {
        selected = devices.isEmpty ? null : devices.first;
      } else {
        selected = devices.firstWhere(
          (device) => device.deviceId == selected!.deviceId,
        );
      }
    } catch (value) {
      error = value;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  void select(Device? device) {
    selected = device;
    notifyListeners();
  }

  Future<Device?> register({
    required String deviceId,
    required String name,
    String? deviceKey,
  }) async {
    final created = await _api.registerDevice(
      deviceId: deviceId,
      name: name,
      deviceKey: deviceKey,
    );

    devices = [
      ...devices.where((device) => device.deviceId != created.deviceId),
      created,
    ];
    selected = created;
    notifyListeners();
    return created;
  }
}
