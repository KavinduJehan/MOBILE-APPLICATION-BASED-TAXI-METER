import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ridex_driver/widgets/app_widgets.dart';

class _Screen extends StatelessWidget {
  const _Screen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: tabBackButton(context),
        title: const Text('Screen'),
      ),
    );
  }
}

void main() {
  testWidgets('as a tab: shows one back arrow that returns to Home', (
    tester,
  ) async {
    var wentHome = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: HomeTabScope(goHome: () => wentHome++, child: const _Screen()),
      ),
    );

    expect(find.byType(BackButton), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    expect(wentHome, 1);
  });

  testWidgets('as a pushed route: one automatic back arrow that pops', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const _Screen()),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.byType(BackButton), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('Screen'), findsNothing);
    expect(find.text('open'), findsOneWidget);
  });

  testWidgets('root screen outside the tabs: no back arrow', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: _Screen()));
    expect(find.byType(BackButton), findsNothing);
  });
}
