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
  bool _assessing = false;
  String? _assessmentError;
  void _sync(String? id) {
    if (id != null && id != _deviceId) {
      _deviceId = id;
      _future = apiService.getLatestRisk(id);
      _assessmentError = null;
      _assessing = false;
    }
  }

  Future<void> _runAssessment() async {
    final deviceId = context.read<DeviceState>().selected?.deviceId;
    if (deviceId == null) return;
    setState(() {
      _assessing = true;
      _assessmentError = null;
    });
    try {
      final prediction = await apiService.assessRisk(deviceId);
      if (!mounted) return;
      setState(() {
        _future = Future.value(prediction);
        _assessing = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _assessing = false;
        _assessmentError = error is ApiException
            ? error.message
            : 'The risk assessment could not be completed.';
      });
    }
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
    return FutureBuilder<RiskPrediction>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _NoAssessmentState(
            onAssess: _runAssessment,
            assessing: _assessing,
            error: _assessmentError,
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
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
                    const SizedBox(height: 14),
                    Text(
                      'Stored label: ${prediction.riskLabel}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    if (_assessmentError != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        _assessmentError!,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: StatusTone.critical.color,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                    const SizedBox(height: 14),
                    FilledButton.icon(
                      onPressed: _assessing ? null : _runAssessment,
                      icon: _assessing
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.refresh),
                      label: Text(
                        _assessing ? 'Assessing...' : 'Assess Risk Now',
                      ),
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

class _NoAssessmentState extends StatelessWidget {
  const _NoAssessmentState({
    required this.onAssess,
    required this.assessing,
    this.error,
  });
  final VoidCallback onAssess;
  final bool assessing;
  final String? error;

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
            'Run an assessment to calculate the current disease risk.',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          if (error != null) ...[
            const SizedBox(height: 10),
            Text(
              error!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: StatusTone.critical.color,
              ),
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: assessing ? null : onAssess,
            icon: assessing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            label: Text(assessing ? 'Assessing...' : 'Assess Risk Now'),
          ),
        ],
      ),
    ),
  );
}
