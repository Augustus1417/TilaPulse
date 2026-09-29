import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:client/core/constants.dart';
import 'package:client/models/reading.dart';
import 'package:client/services/api_service.dart';
import 'package:client/state/device_state.dart';
import 'package:client/widgets/design_system.dart';

class MonitorPage extends StatefulWidget {
  const MonitorPage({super.key});
  @override
  State<MonitorPage> createState() => _MonitorPageState();
}

class _MonitorPageState extends State<MonitorPage> {
  Future<List<Reading>>? _future;
  String? _deviceId;

  void _sync(String? id) {
    if (id != null && id != _deviceId) {
      _deviceId = id;
      _future = apiService.fetchReadings(id, limit: 200);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<DeviceState>();
    _sync(state.selected?.deviceId);
    if (state.loading) return const Center(child: CircularProgressIndicator());
    if (state.devices.isEmpty)
      return const EmptyState(
        title: 'No ponds registered',
        body: 'Open Settings to register a device and start monitoring.',
      );
    return FutureBuilder<List<Reading>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.hasError)
          return const EmptyState(
            title: 'Unable to load history',
            body: 'Check the API connection and try again.',
          );
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        final readings = snapshot.data!;
        return RefreshIndicator(
          onRefresh: () async {
            setState(() {
              _deviceId = null;
              _sync(state.selected?.deviceId);
            });
            await _future;
          },
          child: ListView(
            children: [
              const PageHeader(title: 'Water Quality Monitoring'),
              if (readings.isEmpty)
                const EmptyState(
                  title: 'No readings yet',
                  body: 'This device has not sent any readings.',
                ),
              if (readings.isNotEmpty) ...[
                _ReadingSection(
                  title: 'Latest',
                  readings: [readings.last],
                  highlighted: true,
                ),
                _ReadingSection(
                  title: 'Past Days',
                  readings: _within(
                    readings,
                    const Duration(days: 7),
                    excludeLatest: true,
                  ),
                ),
                _ReadingSection(
                  title: 'Past Month',
                  readings: _within(
                    readings,
                    const Duration(days: 30),
                    excludeLatest: true,
                    olderOnly: true,
                  ),
                ),
              ],
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  List<Reading> _within(
    List<Reading> readings,
    Duration age, {
    required bool excludeLatest,
    bool olderOnly = false,
  }) {
    final latest = readings.last.timestamp;
    return readings
        .where((reading) {
          final delta = latest.difference(reading.timestamp);
          return delta >= Duration.zero &&
              delta <= age &&
              (!excludeLatest || reading.timestamp != latest) &&
              (!olderOnly || delta > const Duration(days: 7));
        })
        .toList()
        .reversed
        .toList();
  }
}

class _ReadingSection extends StatelessWidget {
  const _ReadingSection({
    required this.title,
    required this.readings,
    this.highlighted = false,
  });
  final String title;
  final List<Reading> readings;
  final bool highlighted;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        if (readings.isEmpty)
          Text(
            'No readings in this period.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ...readings.map(
          (reading) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: SimpleCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (highlighted)
                    const StatusPill(
                      label: 'Most recent',
                      tone: StatusTone.info,
                    ),
                  if (highlighted) const SizedBox(height: 8),
                  Text(
                    formatTimestamp(reading.timestamp),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${reading.temperature.toStringAsFixed(1)} C',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        'pH ${reading.ph.toStringAsFixed(2)}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        '${reading.dissolvedOxygen.toStringAsFixed(1)} mg/L',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
