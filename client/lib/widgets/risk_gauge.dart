import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:client/widgets/design_system.dart';

const riskLowThresholdPercent = 30;
const riskHighThresholdPercent = 60;

class RiskGauge extends StatelessWidget {
  const RiskGauge({
    super.key,
    this.score,
    this.lastAssessed,
    this.showLegend = false,
  });

  final int? score;
  final String? lastAssessed;
  final bool showLegend;

  @override
  Widget build(BuildContext context) {
    final value = score?.clamp(0, 100);
    final tone = value == null
        ? null
        : value < riskLowThresholdPercent
        ? StatusTone.normal
        : value < riskHighThresholdPercent
        ? StatusTone.warning
        : StatusTone.critical;
    final label = tone == null
        ? 'No assessment yet'
        : tone == StatusTone.normal
        ? 'Low Risk'
        : tone == StatusTone.warning
        ? 'Moderate Risk'
        : 'High Risk';

    return Semantics(
      label: value == null
          ? 'No risk assessment yet'
          : 'Risk score $value percent, ${label.toLowerCase()}',
      child: Column(
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final width = math.min(constraints.maxWidth, 360.0);
              return SizedBox(
                width: width,
                height: width * .55,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: value == null ? 0 : value / 100),
                  duration: const Duration(milliseconds: 850),
                  curve: Curves.easeOutCubic,
                  builder: (context, progress, _) => CustomPaint(
                    painter: _RiskGaugePainter(
                      progress: progress,
                      score: value,
                      muted: value == null,
                    ),
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: _GaugeValue(score: value),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          LayoutBuilder(
            builder: (context, constraints) {
              final width = math.min(constraints.maxWidth, 360.0);
              return SizedBox(
                width: width,
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _GaugeEndLabel('0'),
                    _GaugeEndLabel('100'),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          StatusPill(label: label, tone: tone ?? StatusTone.info),
          const SizedBox(height: 6),
          Text(
            'Estimated disease risk for this pond',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          if (lastAssessed != null) ...[
            const SizedBox(height: 4),
            Text(lastAssessed!, style: Theme.of(context).textTheme.bodyMedium),
          ],
          if (showLegend) ...[
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 12,
              runSpacing: 6,
              children: const [
                _LegendItem('Low 0–30%', StatusTone.normal),
                _LegendItem('Moderate 30–60%', StatusTone.warning),
                _LegendItem('High 60–100%', StatusTone.critical),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _GaugeEndLabel extends StatelessWidget {
  const _GaugeEndLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 12),
  );
}

class _GaugeValue extends StatelessWidget {
  const _GaugeValue({required this.score});
  final int? score;

  @override
  Widget build(BuildContext context) => RichText(
    text: TextSpan(
      text: score == null ? '--' : '$score',
      style: Theme.of(context).textTheme.displaySmall?.copyWith(
        fontSize: 44,
        fontWeight: FontWeight.w800,
        color: score == null ? onSurfaceVariant : onSurface,
      ),
      children: score == null
          ? null
          : [
              TextSpan(
                text: '%',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: onSurfaceVariant,
                ),
              ),
            ],
    ),
  );
}

class _LegendItem extends StatelessWidget {
  const _LegendItem(this.label, this.tone);
  final String label;
  final StatusTone tone;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 9,
        height: 9,
        decoration: BoxDecoration(color: tone.color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 4),
      Text(label, style: Theme.of(context).textTheme.bodyMedium),
    ],
  );
}

class _RiskGaugePainter extends CustomPainter {
  _RiskGaugePainter({
    required this.progress,
    required this.score,
    required this.muted,
  });

  final double progress;
  final int? score;
  final bool muted;

  @override
  void paint(Canvas canvas, Size size) {
    final strokeWidth = size.width * .07;
    final center = Offset(size.width / 2, size.height - strokeWidth / 2);
    final radius = math.min(
      size.width / 2 - strokeWidth / 2,
      size.height - strokeWidth / 2,
    );
    final rect = Rect.fromCircle(center: center, radius: radius);
    final colors = [
      farmGreen,
      const Color(0xFFF39A00),
      const Color(0xFFC62828),
    ];
    final boundaries = [0.0, .3, .6, 1.0];
    final gap = math.min(.035, strokeWidth / radius / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    for (var i = 0; i < colors.length; i++) {
      final start = math.pi + math.pi * boundaries[i] + gap;
      final sweep =
          math.pi * (boundaries[i + 1] - boundaries[i]) - gap * 2;
      paint.color = muted ? outlineVariant.withValues(alpha: .35) : colors[i];
      canvas.drawArc(rect, start, sweep, false, paint);
    }

    if (score != null) {
      final angle = math.pi + math.pi * progress;
      final marker = Offset(
        center.dx + radius * math.cos(angle),
        center.dy + radius * math.sin(angle),
      );
      canvas
        ..drawCircle(marker, strokeWidth * .42, Paint()..color = onSurface)
        ..drawCircle(marker, strokeWidth * .25, Paint()..color = Colors.white);
    }
  }

  @override
  bool shouldRepaint(covariant _RiskGaugePainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.score != score ||
      oldDelegate.muted != muted;
}
