import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:client/widgets/risk_gauge.dart';

void main() {
  testWidgets('risk gauge fits common widths and scores', (tester) async {
    for (final width in [320.0, 390.0, 600.0]) {
      for (final score in [0, 35, 100]) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: width,
                  child: RiskGauge(score: score),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(tester.binding.hasScheduledFrame, isFalse);
      }
    }
  });
}
