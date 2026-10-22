import 'package:agriloop_mobile/features/onboarding/onboarding_screen.dart';
import 'test_app.dart';
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

  testWidgets('app boots into the resident shell', (WidgetTester tester) async {
    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();

    expect(find.text('AgriLoop'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Deposit'), findsOneWidget);
    expect(find.text('Rewards'), findsOneWidget);
    expect(find.text('Community'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);
  });

  testWidgets('deposit tab exposes the rule scenarios',
      (WidgetTester tester) async {
    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Deposit'));
    await tester.pumpAndSettle();

    expect(find.text('Scan Bin QR Code'), findsOneWidget);
    expect(find.text('Cooldown'), findsOneWidget);
    expect(find.text('Duplicate scan'), findsOneWidget);
    expect(find.text('Daily cap'), findsOneWidget);
  });

  testWidgets('onboarding rejects an unknown invite code',
      (WidgetTester tester) async {
    final router = GoRouter(
      initialLocation: '/onboarding',
      routes: [
        GoRoute(
          path: '/onboarding',
          builder: (context, state) => const OnboardingScreen(),
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

    expect(find.text('Get started'), findsOneWidget);

    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();

    // The invite code is the second text field on the identity step.
    await tester.enterText(find.byType(TextField).at(1), 'BAD-CODE');
    await tester.tap(find.text('Verify invite code'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('not recognised'),
      findsOneWidget,
    );
  });

  testWidgets('onboarding issues a signed resident pass',
      (WidgetTester tester) async {
    final router = GoRouter(
      initialLocation: '/onboarding',
      routes: [
        GoRoute(
          path: '/onboarding',
          builder: (context, state) => const OnboardingScreen(),
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

    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Verify invite code'));
    await tester.pumpAndSettle();

    expect(find.text('Your unit pass is ready'), findsOneWidget);
    expect(find.textContaining('AGR-RES-ELM9921-'), findsOneWidget);
  });
}
