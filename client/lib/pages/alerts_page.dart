import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:client/models/alert.dart';
import 'package:client/services/api_service.dart';
import 'package:client/state/device_state.dart';
import 'package:client/widgets/design_system.dart';

class AlertsPage extends StatefulWidget {
  const AlertsPage({super.key});
  @override
  State<AlertsPage> createState() => _AlertsPageState();
}

class _AlertsPageState extends State<AlertsPage> {
  Future<List<WaterAlert>>? _future;
  String? _deviceId;
  void _sync(String? id) {
    if (id != null && id != _deviceId) {
      _deviceId = id;
      _future = apiService.fetchAlerts(id);
    }
  }

  void _refreshAlerts() {
    final deviceId = _deviceId;
    if (deviceId == null) return;
    setState(() => _future = apiService.fetchAlerts(deviceId));
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<DeviceState>();
    _sync(state.selected?.deviceId);
    if (state.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.devices.isEmpty) {
      return const EmptyState(
        title: 'No devices connected',
        body: 'Open Settings to connect a device first.',
      );
    }
    return FutureBuilder<List<WaterAlert>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const EmptyState(
            title: 'Alerts are unavailable',
            body: 'The server could not load alerts for this device.',
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final alerts = snapshot.data!;
        return ListView(
          children: [
            PageHeader(title: 'Alerts', onRefresh: _refreshAlerts),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: alerts.isEmpty
                  ? const EmptyState(
                      title: 'All clear',
                      body: 'Current readings are inside the configured healthy ranges.',
                    )
                  : Column(
                      children: alerts.map((alert) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: SimpleCard(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Checkbox(
                                  value: false,
                                  onChanged: (value) async {
                                    if (value != true) return;
                                    await apiService.resolveAlert(
                                      state.selected!.deviceId,
                                      alert.id,
                                    );
                                    if (mounted) {
                                      setState(() {
                                        _future = apiService.fetchAlerts(
                                          state.selected!.deviceId,
                                        );
                                      });
                                    }
                                  },
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              alert.title,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .titleMedium,
                                            ),
                                          ),
                                          const StatusPill(
                                            label: 'Active',
                                            tone: StatusTone.warning,
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 5),
                                      Text(
                                        '${alert.message} Current: ${alert.value.toStringAsFixed(2)}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
            ),
            const SizedBox(height: 24),
          ],
        );
      },
    );
  }
}
