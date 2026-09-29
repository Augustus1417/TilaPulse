import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:client/models/reading.dart';
import 'package:client/models/risk_prediction.dart';
import 'package:client/core/constants.dart';
import 'package:client/services/api_service.dart';
import 'package:client/state/device_state.dart';
import 'package:client/widgets/design_system.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Future<(Reading, RiskPrediction)>? _future;
  String? _deviceId;
  void _sync(String? id) {
    if (id != null && id != _deviceId) {
      _deviceId = id;
      _future = Future.wait([
        apiService.fetchLatest(id),
        apiService.predict(id),
      ]).then((values) => (values[0] as Reading, values[1] as RiskPrediction));
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
        body:
            'Open Settings to register a device and start receiving readings.',
      );
    return FutureBuilder<(Reading, RiskPrediction)>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.hasError) return _ErrorState(error: snapshot.error);
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        final reading = snapshot.data!.$1;
        final prediction = snapshot.data!.$2;
        final score = (prediction.riskScore * 100).round().clamp(0, 100);
        final tone = score < 30
            ? StatusTone.normal
            : score < 60
            ? StatusTone.warning
            : StatusTone.critical;
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
              PageHeader(title: state.selected!.name),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SimpleCard(
                  child: Column(
                    children: [
                      Text(
                        'Disease Risk Score',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 14),
                      RiskGauge(score: score, tone: tone),
                      const SizedBox(height: 10),
                      Text(
                        tone == StatusTone.normal
                            ? 'Live readings are within healthy water-quality bands.'
                            : 'One or more readings need attention.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Latest water quality',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    MetricTile(
                      title: 'Temperature',
                      value: reading.temperature.toStringAsFixed(1),
                      unit: 'C',
                      normal:
                          reading.temperature >= 24 &&
                          reading.temperature <= 32,
                    ),
                    const SizedBox(height: 10),
                    MetricTile(
                      title: 'pH level',
                      value: reading.ph.toStringAsFixed(2),
                      unit: '',
                      normal: reading.ph >= 6.5 && reading.ph <= 8.5,
                    ),
                    const SizedBox(height: 10),
                    MetricTile(
                      title: 'Dissolved oxygen',
                      value: reading.dissolvedOxygen.toStringAsFixed(1),
                      unit: 'mg/L',
                      normal: reading.dissolvedOxygen >= 5,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Updated ${formatTimestamp(reading.timestamp)}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error});
  final Object? error;
  @override
  Widget build(BuildContext context) => EmptyState(
    title: 'Unable to load pond data',
    body: error is ApiException && (error as ApiException).statusCode == 404
        ? 'No readings are available for this device yet.'
        : 'Check the API connection and try again.',
  );
}
