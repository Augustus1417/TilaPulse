import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:client/core/constants.dart';
import 'package:client/models/risk_prediction.dart';
import 'package:client/services/api_service.dart';
import 'package:client/state/device_state.dart';
import 'package:client/widgets/design_system.dart';

class RiskPage extends StatefulWidget {
  const RiskPage({super.key});
  @override
  State<RiskPage> createState() => _RiskPageState();
}

class _RiskPageState extends State<RiskPage> {
  Future<RiskPrediction>? _future;
  String? _deviceId;
  void _sync(String? id) {
    if (id != null && id != _deviceId) {
      _deviceId = id;
      _future = apiService.predict(id);
    }
  }

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
    return FutureBuilder<RiskPrediction>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.hasError)
          return const EmptyState(
            title: 'Risk is unavailable',
            body: 'A prediction needs at least one reading.',
          );
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        final prediction = snapshot.data!;
        final score = (prediction.riskScore * 100).round().clamp(0, 100);
        final tone = score < 30
            ? StatusTone.normal
            : score < 60
            ? StatusTone.warning
            : StatusTone.critical;
        final changePoint = prediction.bocpdProbability >= bocpdAlertThreshold;
        return ListView(
          children: [
            const PageHeader(title: 'Disease Risk'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SimpleCard(
                child: Column(
                  children: [
                    RiskGauge(score: score, tone: tone),
                    const SizedBox(height: 14),
                    Text(
                      'Current prediction for ${state.selected!.name}',
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
                    'What the score means',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 10),
                  SimpleCard(
                    child: Text(
                      score < 30
                          ? 'The model indicates low disease risk. Continue collecting readings so the prediction stays current.'
                          : score < 60
                          ? 'The model sees moderate risk. Review the latest water-quality readings and watch for a trend.'
                          : 'The model indicates high risk. Inspect water conditions promptly and take corrective action.',
                      style: Theme.of(context).textTheme.bodyLarge
                          ?.copyWith(height: 1.45),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Contributing signals',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 10),
                  SimpleCard(
                    child: Column(
                      children: [
                        _SignalRow(
                          label: 'LSTM risk probability',
                          value: prediction.lstmProbability,
                        ),
                        _SignalRow(
                          label: 'BOCPD change-point probability',
                          value: prediction.bocpdProbability,
                        ),
                        Text(
                          changePoint
                              ? 'A recent change-point signal is triggered. Look for a new shift in the readings.'
                              : 'No change-point signal is currently triggered.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  if (prediction.notice?.isNotEmpty == true)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        prediction.notice!,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SignalRow extends StatelessWidget {
  const _SignalRow({required this.label, required this.value});
  final String label;
  final double value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      children: [
        Expanded(child: Text(label)),
        Text(
          '${(value * 100).round()}%',
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ],
    ),
  );
}
