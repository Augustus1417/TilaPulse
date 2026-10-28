import 'package:client/models/reading_series.dart';
import 'package:client/widgets/reading_trend_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

ReadingSeries _series(List<int> offsets) {
  final start = DateTime.utc(2026, 10, 28, 8);
  return ReadingSeries(
    deviceId: 'pond-a',
    range: '1h',
    bucketSeconds: 60,
    from: start,
    to: start.add(const Duration(hours: 1)),
    points: [
      for (final offset in offsets)
        ReadingSeriesPoint(
          time: start.add(Duration(seconds: offset)),
          count: 1,
          metrics: const {
            'temperature': ReadingSeriesMetric(
              average: 28,
              minimum: 27.8,
              maximum: 28.2,
            ),
            'ph': ReadingSeriesMetric(average: 7.2, minimum: 7.1, maximum: 7.3),
            'dissolved_oxygen': ReadingSeriesMetric(
              average: 5.4,
              minimum: 5.2,
              maximum: 5.7,
            ),
          },
        ),
    ],
    thresholds: const {
      'temperature': ReadingSeriesThreshold(minimum: 24, maximum: 32),
      'ph': ReadingSeriesThreshold(minimum: 6.5, maximum: 8.5),
      'dissolved_oxygen': ReadingSeriesThreshold(minimum: 5, maximum: null),
    },
  );
}

Widget _chart(ReadingSeries series) => MaterialApp(
  home: Scaffold(
    body: ReadingTrendChart(
      series: series,
      parameter: ReadingTrendParameter.dissolvedOxygen,
      range: '1h',
      onParameterChanged: (_) {},
      onRangeChanged: (_) {},
    ),
  ),
);

void main() {
  testWidgets('renders continuous data', (tester) async {
    await tester.pumpWidget(_chart(_series([0, 60, 120, 180])));
    expect(find.text('Normal'), findsOneWidget);
    expect(find.text('Healthy: 5 mg/L and above'), findsOneWidget);
    expect(find.text('Only 3 minutes of data so far.'), findsOneWidget);
  });

  testWidgets('renders a gap without failing', (tester) async {
    await tester.pumpWidget(_chart(_series([0, 60, 180])));
    expect(find.byType(ReadingTrendChart), findsOneWidget);
  });

  testWidgets('renders a single bucket dot', (tester) async {
    await tester.pumpWidget(_chart(_series([120])));
    expect(find.text('Normal'), findsOneWidget);
    expect(find.text('5.40 mg/L'), findsOneWidget);
  });

  testWidgets('renders the empty state', (tester) async {
    await tester.pumpWidget(_chart(_series([])));
    expect(find.text('No readings in this period.'), findsOneWidget);
  });
}
