import 'package:agriloop_mobile/features/operator/operator_dashboard_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_doubles.dart';

import 'package:agriloop_mobile/core/services/local_agri_repository.dart';
import 'package:agriloop_mobile/providers/app_state_provider.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> pumpOperator(WidgetTester tester) async {
    final router = GoRouter(
      initialLocation: '/operator',
      routes: [
        GoRoute(
          path: '/operator',
          builder: (context, state) => const OperatorDashboardScreen(),
        ),
        GoRoute(
          path: '/home',
          builder: (context, state) => const Scaffold(body: Text('HOME')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          agriStateProvider.overrideWith(
            (ref) => AgriStateNotifier(
              api: FakeDepositApi(),
              repository: LocalAgriRepository(),
            ),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('operator sees the fleet, disputes and compost tabs',
      (WidgetTester tester) async {
    await pumpOperator(tester);

    expect(find.text('Bins (3)'), findsOneWidget);
    expect(find.text('Disputes (1)'), findsOneWidget);
    expect(find.text('Compost log'), findsOneWidget);
  });

  testWidgets('impact tab reports the pilot uplift', (WidgetTester tester) async {
    await pumpOperator(tester);

    await tester.drag(find.byType(TabBar), const Offset(-400, 0));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Impact'));
    await tester.pumpAndSettle();

    expect(find.text('Baseline week vs. rewards week'), findsOneWidget);
    expect(find.text('kg diverted per participant per week'), findsOneWidget);

    await tester.drag(find.byType(ListView).last, const Offset(0, -400));
    await tester.pumpAndSettle();

    expect(find.text('Value to Sime Darby Property'), findsOneWidget);
  });
}
