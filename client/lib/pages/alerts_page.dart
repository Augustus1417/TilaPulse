import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:client/models/alert.dart';
import 'package:client/models/reading.dart';
import 'package:client/services/api_service.dart';
import 'package:client/state/device_state.dart';
import 'package:client/widgets/design_system.dart';

class AlertsPage extends StatefulWidget {
  const AlertsPage({super.key});
  @override
  State<AlertsPage> createState() => _AlertsPageState();
}

class _AlertsPageState extends State<AlertsPage> {
  Future<Reading>? _future;
  String? _deviceId;
  final Set<String> _resolved = {};
  void _sync(String? id) {
    if (id != null && id != _deviceId) {
      _deviceId = id;
      _resolved.clear();
      _future = apiService.fetchLatest(id).then((reading) async {
        final prefs = await SharedPreferences.getInstance();
        for (final alert in alertsForReading(reading)) {
          final stored = prefs.getString(_key(id, alert.key));
          if (stored != null &&
              DateTime.tryParse(stored)?.isBefore(alert.timestamp) == false)
            _resolved.add(alert.key);
        }
        return reading;
      });
    }
  }

  String _key(String deviceId, String alertType) =>
      'alert_resolution_${deviceId}_$alertType';
  @override
  Widget build(BuildContext context) {
    final state = context.watch<DeviceState>();
    _sync(state.selected?.deviceId);
    if (state.loading) return const Center(child: CircularProgressIndicator());
    if (state.devices.isEmpty)
      return const EmptyState(
        title: 'No devices connected',
        body: 'Open Settings to connect a device first.',
      );
    return FutureBuilder<Reading>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.hasError)
          return const EmptyState(
            title: 'Alerts are unavailable',
            body: 'No latest reading is available for this device.',
          );
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        final alerts = alertsForReading(snapshot.data!);
        return ListView(
          children: [
            PageHeader(title: 'Alerts'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: alerts.isEmpty
                  ? const EmptyState(
                      title: 'All clear',
                      body: 'Current readings are inside the configured healthy ranges.',
                    )
                  : Column(
                      children: alerts.map((alert) {
                        final resolved = _resolved.contains(alert.key);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: SimpleCard(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Checkbox(
                                  value: resolved,
                                  onChanged: (value) async {
                                    if (value != true) return;
                                    final prefs =
                                        await SharedPreferences.getInstance();
                                    await prefs.setString(
                                      _key(state.selected!.deviceId, alert.key),
                                      alert.timestamp.toIso8601String(),
                                    );
                                    setState(() => _resolved.add(alert.key));
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
                                          StatusPill(
                                            label: resolved
                                                ? 'Resolved'
                                                : 'Active',
                                            tone: resolved
                                                ? StatusTone.normal
                                                : StatusTone.warning,
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 5),
                                      Text(
                                        '${alert.description} Current: ${alert.value.toStringAsFixed(2)}',
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
