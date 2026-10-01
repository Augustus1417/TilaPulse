import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:client/models/reading.dart';
import 'package:client/models/risk_prediction.dart';
import 'package:client/core/constants.dart';
import 'package:client/services/api_service.dart';
import 'package:client/state/device_state.dart';
import 'package:client/widgets/design_system.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, this.onOpenRisk});
  final VoidCallback? onOpenRisk;
  @override
  State<HomePage> createState() => HomePageState();
}

class HomePageState extends State<HomePage> {
  Future<(Reading, RiskPrediction)>? _future;
  String? _deviceId;

  void refresh() => _refresh();

  void _refresh() {
    setState(() {
      _deviceId = null;
      _sync(context.read<DeviceState>().selected?.deviceId);
    });
  }

  void _sync(String? id) {
    if (id != null && id != _deviceId) {
      _deviceId = id;
      _future = Future.wait([
        apiService.fetchLatest(id),
        apiService.getLatestRisk(id),
      ]).then((values) => (values[0] as Reading, values[1] as RiskPrediction));
    }
  }

  void _openRisk() {
    widget.onOpenRisk?.call();
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
        body: 'Open Settings to connect a device and start receiving readings.',
      );
    }
    return FutureBuilder<(Reading, RiskPrediction)>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          if (snapshot.error is ApiException &&
              (snapshot.error as ApiException).statusCode == 404) {
            return _NoRiskAssessmentState(onOpenRisk: _openRisk);
          }
          return _ErrorState(error: snapshot.error);
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
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
            _refresh();
            await _future;
          },
          child: ListView(
            children: [
              PageHeader(title: state.selected!.name, onRefresh: _refresh),
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
    ? 'No stored risk assessment is available yet. Run one from the Risk page.'
        : 'Check the API connection and try again.',
  );
}

class _NoRiskAssessmentState extends StatelessWidget {
  const _NoRiskAssessmentState({required this.onOpenRisk});
  final VoidCallback onOpenRisk;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.insights_outlined, size: 48, color: brandTeal),
          const SizedBox(height: 16),
          Text(
            'No risk assessment yet',
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Open the Risk page to run the first assessment for this device.',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: onOpenRisk,
            icon: const Icon(Icons.stacked_line_chart),
            label: const Text('Open Risk'),
          ),
        ],
      ),
    ),
  );
}
