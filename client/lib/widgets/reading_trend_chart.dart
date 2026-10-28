import 'dart:math' as math;

import 'package:client/models/reading_series.dart';
import 'package:client/widgets/design_system.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

enum ReadingTrendParameter { temperature, ph, dissolvedOxygen }

class ReadingTrendChart extends StatefulWidget {
  const ReadingTrendChart({
    super.key,
    required this.series,
    required this.parameter,
    required this.range,
    required this.onParameterChanged,
    required this.onRangeChanged,
  });

  final ReadingSeries series;
  final ReadingTrendParameter parameter;
  final String range;
  final ValueChanged<ReadingTrendParameter> onParameterChanged;
  final ValueChanged<String> onRangeChanged;

  @override
  State<ReadingTrendChart> createState() => _ReadingTrendChartState();
}

class _ReadingTrendChartState extends State<ReadingTrendChart> {
  String get _key => switch (widget.parameter) {
    ReadingTrendParameter.temperature => 'temperature',
    ReadingTrendParameter.ph => 'ph',
    ReadingTrendParameter.dissolvedOxygen => 'dissolved_oxygen',
  };

  String get _label => switch (widget.parameter) {
    ReadingTrendParameter.temperature => 'Temperature',
    ReadingTrendParameter.ph => 'pH',
    ReadingTrendParameter.dissolvedOxygen => 'Dissolved oxygen',
  };

  String get _unit => switch (widget.parameter) {
    ReadingTrendParameter.temperature => '°C',
    ReadingTrendParameter.ph => '',
    ReadingTrendParameter.dissolvedOxygen => 'mg/L',
  };

  ReadingSeriesThreshold get _threshold => widget.series.thresholds[_key]!;

  StatusTone _tone(ReadingSeriesMetric metric) {
    final threshold = _threshold;
    final low = metric.minimum < threshold.minimum;
    final high =
        threshold.maximum != null && metric.maximum > threshold.maximum!;
    if (!low && !high) return StatusTone.normal;
    return low ? StatusTone.warning : StatusTone.critical;
  }

  bool _isFlagged(ReadingSeriesMetric metric) {
    final threshold = _threshold;
    if (widget.parameter == ReadingTrendParameter.dissolvedOxygen) {
      return metric.minimum < threshold.minimum;
    }
    return metric.minimum < threshold.minimum ||
        (threshold.maximum != null && metric.maximum > threshold.maximum!);
  }

  String _headline() {
    final points = widget.series.points;
    if (points.isEmpty) return 'No readings in this period.';
    final flagged = points
        .where((point) => _isFlagged(point.metrics[_key]!))
        .length;
    if (flagged == 0) return '$_label stayed in the healthy range.';
    final duration = flagged * widget.series.bucketSeconds;
    final value = duration % 3600 == 0
        ? '${duration ~/ 3600} hour${duration ~/ 3600 == 1 ? '' : 's'}'
        : '${(duration / 60).round()} minutes';
    final direction = widget.parameter == ReadingTrendParameter.dissolvedOxygen
        ? 'below'
        : 'outside';
    return '$_label was $direction the healthy range for about $value in the last ${_rangeLabel(widget.range)}.';
  }

  String _rangeLabel(String range) => switch (range) {
    '1h' => 'hour',
    '24h' => '24 hours',
    '7d' => '7 days',
    _ => '30 days',
  };

  List<List<ReadingSeriesPoint>> _runs() {
    final points = widget.series.points;
    final runs = <List<ReadingSeriesPoint>>[];
    for (final point in points) {
      if (runs.isEmpty ||
          point.time.difference(runs.last.last.time).inSeconds >
              widget.series.bucketSeconds * 1.5) {
        runs.add([point]);
      } else {
        runs.last.add(point);
      }
    }
    return runs;
  }

  String _timeLabel(double value) {
    final local = DateTime.fromMillisecondsSinceEpoch(
      value.toInt(),
      isUtc: true,
    ).toLocal();
    if (widget.range == '7d') return '${_weekday(local.weekday)} ${local.day}';
    if (widget.range == '30d') return '${_month(local.month)} ${local.day}';
    return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  int _tickSeconds() => switch (widget.range) {
    '1h' => 15 * 60,
    '24h' => 6 * 60 * 60,
    '7d' => 24 * 60 * 60,
    _ => 5 * 24 * 60 * 60,
  };

  String? _sparseDataMessage() {
    final points = widget.series.points;
    if (points.length < 2) return null;
    final duration = points.last.time.difference(points.first.time);
    final window = widget.series.to.difference(widget.series.from);
    if (duration.inMilliseconds >= window.inMilliseconds ~/ 10 &&
        points.length >= 5) {
      return null;
    }
    if (duration.inMinutes < 1) return 'Only a few seconds of data so far.';
    if (duration.inHours < 1) {
      return 'Only ${duration.inMinutes} minutes of data so far.';
    }
    final hours = duration.inMinutes / 60;
    final formatted = hours == hours.roundToDouble()
        ? '${hours.round()} hour${hours == 1 ? '' : 's'}'
        : '${hours.toStringAsFixed(1)} hours';
    return 'Only $formatted of data so far.';
  }

  String _weekday(int day) =>
      const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][day - 1];

  String _month(int month) => const [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ][month - 1];

  double _niceInterval(double span) {
    final rough = span / 4;
    final magnitude = math.pow(10, (math.log(rough) / math.ln10).floor());
    final normalized = rough / magnitude;
    final nice = normalized <= 1
        ? 1
        : normalized <= 2
        ? 2
        : normalized <= 5
        ? 5
        : 10;
    return (nice * magnitude).toDouble();
  }

  String _healthyLabel(ReadingSeriesThreshold threshold) {
    final decimals = widget.parameter == ReadingTrendParameter.ph ? 1 : 0;
    final minimum = threshold.minimum.toStringAsFixed(decimals);
    final maximum = threshold.maximum?.toStringAsFixed(decimals);
    final unit = _unit.isEmpty ? '' : ' $_unit';
    if (maximum == null) return 'Healthy: $minimum$unit and above';
    return 'Healthy: $minimum–$maximum$unit';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (widget.series.points.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: surfaceContainerLow,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: outlineVariant.withValues(alpha: .4)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Text(_headline(), style: theme.textTheme.bodyMedium),
                const SizedBox(height: 12),
                _selectors(),
              ],
            ),
          ),
        ),
      );
    }
    final runs = _runs();
    final threshold = _threshold;
    final allMetrics = widget.series.points.map(
      (point) => point.metrics[_key]!,
    );
    final values = [
      ...allMetrics.expand((metric) => [metric.minimum, metric.maximum]),
      threshold.minimum,
      if (threshold.maximum != null) threshold.maximum!,
    ];
    final minValue = values.reduce(math.min);
    final maxValue = values.reduce(math.max);
    final padding = math.max((maxValue - minValue) * .12, .5);
    final rawMinY = math.max(0, minValue - padding).toDouble();
    final rawMaxY = (maxValue + padding).toDouble();
    final yInterval = _niceInterval(rawMaxY - rawMinY);
    final minY = (rawMinY / yInterval).floor() * yInterval;
    final maxY = (rawMaxY / yInterval).ceil() * yInterval;
    final minX = widget.series.from.millisecondsSinceEpoch.toDouble();
    final rangeMilliseconds =
        widget.series.to.millisecondsSinceEpoch -
        widget.series.from.millisecondsSinceEpoch;
    final maxX =
        widget.series.to.millisecondsSinceEpoch.toDouble() +
        rangeMilliseconds * .03;
    final xInterval = rangeMilliseconds / 4;
    final latestTone = _tone(widget.series.points.last.metrics[_key]!);
    final healthyUpper = threshold.maximum ?? maxY;
    final healthyMiddle = (threshold.minimum + healthyUpper) / 2;
    final healthyTop = ((1 - ((healthyMiddle - minY) / (maxY - minY))) * 180)
        .clamp(8, 170)
        .toDouble();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: outlineVariant.withValues(alpha: .4)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              StatusPill(
                label: latestTone == StatusTone.normal
                    ? 'Normal'
                    : latestTone == StatusTone.warning
                    ? 'Low'
                    : 'High',
                tone: latestTone,
              ),
              const SizedBox(height: 6),
              Text(
                _headline(),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 10),
              _selectors(),
              const SizedBox(height: 12),
              SizedBox(
                height: 240,
                child: Stack(
                  children: [
                    LineChart(
                      LineChartData(
                        minX: minX,
                        maxX: maxX,
                        minY: minY,
                        maxY: maxY,
                        borderData: FlBorderData(show: false),
                        clipData: const FlClipData.none(),
                        gridData: FlGridData(
                          drawVerticalLine: false,
                          horizontalInterval: yInterval,
                        ),
                        rangeAnnotations: RangeAnnotations(
                          horizontalRangeAnnotations: [
                            HorizontalRangeAnnotation(
                              y1: threshold.minimum,
                              y2: threshold.maximum ?? maxY,
                              color: StatusTone.normal.color.withValues(
                                alpha: theme.brightness == Brightness.dark
                                    ? .24
                                    : .16,
                              ),
                            ),
                          ],
                        ),
                        titlesData: FlTitlesData(
                          rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              interval: yInterval,
                              reservedSize: 42,
                              getTitlesWidget: (value, meta) => Text(
                                value.toStringAsFixed(
                                  widget.parameter == ReadingTrendParameter.ph
                                      ? 1
                                      : 0,
                                ),
                                style: theme.textTheme.bodySmall,
                              ),
                            ),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 26,
                              interval: xInterval,
                              getTitlesWidget: (value, meta) {
                                if (value == meta.min || value == meta.max) {
                                  return const SizedBox.shrink();
                                }
                                final tick = _tickSeconds() * 1000;
                                final rounded = (value / tick).round() * tick;
                                if ((value - rounded).abs() > tick * .5) {
                                  return const SizedBox.shrink();
                                }
                                return Text(
                                  _timeLabel(rounded.toDouble()),
                                  maxLines: 1,
                                  softWrap: false,
                                  style: theme.textTheme.bodySmall,
                                );
                              },
                            ),
                          ),
                        ),
                        lineTouchData: LineTouchData(
                          touchTooltipData: LineTouchTooltipData(
                            getTooltipItems: (spots) => spots
                                .where((spot) => spot.barIndex % 3 == 2)
                                .map((spot) {
                                  final point = widget.series.points.firstWhere(
                                    (item) =>
                                        item.time.millisecondsSinceEpoch ==
                                        spot.x.toInt(),
                                  );
                                  final metric = point.metrics[_key]!;
                                  final tone = _tone(metric);
                                  return LineTooltipItem(
                                    '${_timeLabel(spot.x)}\n'
                                    '${metric.average.toStringAsFixed(2)} $_unit\n'
                                    '${metric.minimum.toStringAsFixed(2)}–'
                                    '${metric.maximum.toStringAsFixed(2)} $_unit\n'
                                    '${tone == StatusTone.normal
                                        ? 'Normal'
                                        : tone == StatusTone.warning
                                        ? 'Low'
                                        : 'High'}',
                                    TextStyle(
                                      color: tone.color,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  );
                                })
                                .toList(),
                          ),
                        ),
                        lineBarsData: [
                          for (final run in runs) ...[
                            _line(
                              run,
                              (point) => point.metrics[_key]!.minimum,
                              Colors.transparent,
                            ),
                            _line(
                              run,
                              (point) => point.metrics[_key]!.maximum,
                              Colors.transparent,
                            ),
                            _line(
                              run,
                              (point) => point.metrics[_key]!.average,
                              theme.colorScheme.primary,
                              dots: FlDotData(
                                show: true,
                                getDotPainter: (spot, percent, bar, index) {
                                  final point = run[index];
                                  return FlDotCirclePainter(
                                    radius:
                                        _isFlagged(point.metrics[_key]!) ||
                                            run.length == 1
                                        ? 4
                                        : 0,
                                    color: _isFlagged(point.metrics[_key]!)
                                        ? StatusTone.critical.color
                                        : theme.colorScheme.primary,
                                    strokeColor: Colors.white,
                                    strokeWidth: 1.5,
                                  );
                                },
                              ),
                            ),
                          ],
                        ],
                        betweenBarsData: [
                          for (var index = 0; index < runs.length; index++)
                            BetweenBarsData(
                              fromIndex: index * 3,
                              toIndex: index * 3 + 1,
                              color: theme.colorScheme.primary.withValues(
                                alpha: .10,
                              ),
                            ),
                        ],
                      ),
                    ),
                    Positioned(
                      left: 48,
                      top: healthyTop,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: StatusTone.normal.background.withValues(
                            alpha: theme.brightness == Brightness.dark
                                ? .90
                                : .92,
                          ),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 3,
                          ),
                          child: Text(
                            _healthyLabel(threshold),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: StatusTone.normal.color,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (_sparseDataMessage() case final message?)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(message, style: theme.textTheme.bodySmall),
                ),
              if (widget.series.points.length == 1)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    '${widget.series.points.single.metrics[_key]!.average.toStringAsFixed(2)} $_unit',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _selectors() => Column(
    children: [
      LayoutBuilder(
        builder: (context, constraints) => SizedBox(
          width: double.infinity,
          child: SegmentedButton<ReadingTrendParameter>(
            segments: [
              ButtonSegment(
                value: ReadingTrendParameter.temperature,
                label: SizedBox(
                  width: constraints.maxWidth / 3 - 10,
                  child: const Text(
                    'Temp',
                    maxLines: 1,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              ButtonSegment(
                value: ReadingTrendParameter.ph,
                label: SizedBox(
                  width: constraints.maxWidth / 3 - 10,
                  child: const Text(
                    'pH',
                    maxLines: 1,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              ButtonSegment(
                value: ReadingTrendParameter.dissolvedOxygen,
                label: SizedBox(
                  width: constraints.maxWidth / 3 - 10,
                  child: const Text(
                    'Oxygen',
                    maxLines: 1,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
            selected: {widget.parameter},
            onSelectionChanged: (value) =>
                widget.onParameterChanged(value.first),
            showSelectedIcon: false,
            style: const ButtonStyle(
              visualDensity: VisualDensity(horizontal: -3, vertical: -2),
              minimumSize: WidgetStatePropertyAll(Size.fromHeight(40)),
              padding: WidgetStatePropertyAll(
                EdgeInsets.symmetric(horizontal: 4),
              ),
            ),
          ),
        ),
      ),
      const SizedBox(height: 8),
      LayoutBuilder(
        builder: (context, constraints) => SizedBox(
          width: double.infinity,
          child: SegmentedButton<String>(
            segments: [
              for (final segment in const [
                ('1h', '1 hour'),
                ('24h', '24 hours'),
                ('7d', '7 days'),
                ('30d', '30 days'),
              ])
                ButtonSegment(
                  value: segment.$1,
                  label: SizedBox(
                    width: constraints.maxWidth / 4 - 10,
                    child: Text(
                      segment.$2,
                      maxLines: 1,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
            selected: {widget.range},
            onSelectionChanged: (value) => widget.onRangeChanged(value.first),
            showSelectedIcon: false,
            style: const ButtonStyle(
              visualDensity: VisualDensity(horizontal: -3, vertical: -2),
              minimumSize: WidgetStatePropertyAll(Size.fromHeight(40)),
              padding: WidgetStatePropertyAll(
                EdgeInsets.symmetric(horizontal: 4),
              ),
            ),
          ),
        ),
      ),
    ],
  );

  LineChartBarData _line(
    List<ReadingSeriesPoint> run,
    double Function(ReadingSeriesPoint) value,
    Color color, {
    FlDotData? dots,
  }) => LineChartBarData(
    spots: [
      for (final point in run)
        FlSpot(point.time.millisecondsSinceEpoch.toDouble(), value(point)),
    ],
    isCurved: false,
    color: color,
    barWidth: color == Colors.transparent ? 0 : 2.5,
    dotData: dots ?? const FlDotData(show: false),
    showingIndicators: const [],
  );
}
