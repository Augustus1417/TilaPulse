import 'package:flutter_test/flutter_test.dart';

import 'package:tilapulse/app_shell.dart';

void main() {
  testWidgets('Tilapulse shell renders', (WidgetTester tester) async {
    await tester.pumpWidget(const TilapulseApp());
    await tester.pump();

    expect(find.text('Tilapulse'), findsWidgets);
    expect(find.text('Green Valley Pond'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
  });
}
