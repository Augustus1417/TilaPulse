import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:client/state/device_state.dart';

const brandTeal = Color(0xFF006666);
const waterBlue = Color(0xFF0099CC);
const farmGreen = Color(0xFF4D8B31);
const appSurface = Color(0xFFF7FAF9);
const surfaceContainer = Color(0xFFE6E9E8);
const surfaceContainerLow = Colors.white;
const onSurface = Color(0xFF181C1C);
const onSurfaceVariant = Color(0xFF3F4948);
const outlineVariant = Color(0xFFBEC9C8);

enum StatusTone { normal, warning, critical, info }

extension StatusToneX on StatusTone {
  Color get color => switch (this) {
    StatusTone.normal => farmGreen,
    StatusTone.warning => const Color(0xFFF39A00),
    StatusTone.critical => const Color(0xFFC62828),
    StatusTone.info => waterBlue,
  };
  Color get background => switch (this) {
    StatusTone.normal => const Color(0xFFEAF4E4),
    StatusTone.warning => const Color(0xFFFFF4D6),
    StatusTone.critical => const Color(0xFFFDE8E7),
    StatusTone.info => const Color(0xFFE6F5FB),
  };
}

class SimpleCard extends StatelessWidget {
  const SimpleCard({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: surfaceContainerLow,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: outlineVariant.withValues(alpha: .4)),
    ),
    padding: const EdgeInsets.all(16),
    child: child,
  );
}

class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.label, required this.tone});
  final String label;
  final StatusTone tone;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: tone.background,
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      label,
      style: Theme.of(context).textTheme.labelLarge
          ?.copyWith(color: tone.color, fontSize: 11),
    ),
  );
}

class RiskGauge extends StatelessWidget {
  const RiskGauge({super.key, required this.score, required this.tone});
  final int score;
  final StatusTone tone;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      SizedBox(
        height: 125,
        width: 150,
        child: CustomPaint(
          painter: _GaugePainter(score / 100, tone.color),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$score',
                  style: Theme.of(context).textTheme.displaySmall
                      ?.copyWith(fontSize: 48, fontWeight: FontWeight.w800),
                ),
                Text('%', style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
        ),
      ),
      StatusPill(
        label: score < 30
            ? 'Low Risk'
            : score < 60
            ? 'Moderate Risk'
            : 'High Risk',
        tone: tone,
      ),
    ],
  );
}

class _GaugePainter extends CustomPainter {
  _GaugePainter(this.progress, this.color);
  final double progress;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * .72);
    final rect = Rect.fromCircle(center: center, radius: size.width * .36);
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round
      ..color = outlineVariant.withValues(alpha: .3);
    final value = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round
      ..color = color;
    canvas.drawArc(rect, 3.14, -3.14, false, track);
    canvas.drawArc(rect, 3.14, -3.14 * progress.clamp(0, 1), false, value);
  }

  @override
  bool shouldRepaint(covariant _GaugePainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.title, required this.body});
  final String title;
  final String body;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.water_damage_outlined, size: 48, color: brandTeal),
          const SizedBox(height: 16),
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}

class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    required this.title,
    this.onRefresh,
    this.showSwitcher = true,
  });
  final String title;
  final VoidCallback? onRefresh;
  final bool showSwitcher;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.waves, size: 24, color: brandTeal),
            const SizedBox(width: 8),
            Text(
              'Tilapulse',
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(color: brandTeal),
            ),
            const Spacer(),
            if (onRefresh != null)
              IconButton(
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh',
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (showSwitcher) const DeviceSwitcher(),
        const SizedBox(height: 16),
        Text(title, style: Theme.of(context).textTheme.headlineLarge),
      ],
    ),
  );
}

class DeviceSwitcher extends StatelessWidget {
  const DeviceSwitcher({super.key});
  @override
  Widget build(BuildContext context) {
    final state = context.watch<DeviceState>();
    return DropdownButtonFormField<String>(
      initialValue: state.selected?.deviceId,
      decoration: const InputDecoration(
        labelText: 'Selected pond',
        prefixIcon: Icon(Icons.devices_other),
        border: OutlineInputBorder(),
      ),
      items: state.devices
          .map(
            (device) => DropdownMenuItem(
              value: device.deviceId,
              child: Text(device.name, overflow: TextOverflow.ellipsis),
            ),
          )
          .toList(),
      onChanged: (id) {
        if (id != null)
          state.select(
            state.devices.firstWhere((device) => device.deviceId == id),
          );
      },
    );
  }
}

class MetricTile extends StatelessWidget {
  const MetricTile({
    super.key,
    required this.title,
    required this.value,
    required this.unit,
    required this.normal,
  });
  final String title;
  final String value;
  final String unit;
  final bool normal;
  @override
  Widget build(BuildContext context) => SimpleCard(
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 8),
              Text(
                '$value $unit',
                style: Theme.of(context).textTheme.headlineMedium
                    ?.copyWith(fontSize: 27),
              ),
            ],
          ),
        ),
        StatusPill(
          label: normal ? 'Normal' : 'Warning',
          tone: normal ? StatusTone.normal : StatusTone.warning,
        ),
      ],
    ),
  );
}
