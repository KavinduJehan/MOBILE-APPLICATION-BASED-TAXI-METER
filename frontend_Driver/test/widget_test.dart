import 'package:provider/provider.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ridex_driver/app.dart';
import 'package:ridex_driver/providers/auth_provider.dart';

void main() {
  testWidgets('shows the RideX splash screen', (WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AuthProvider(),
        child: const RideXDriverApp(),
      ),
    );
    // Allow the splash's delay to elapse so timers are not left pending.
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));

    expect(find.text('RideX'), findsOneWidget);
  });
}
