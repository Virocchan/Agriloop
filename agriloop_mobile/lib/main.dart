import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/theme/app_theme.dart';
import 'features/merchant/merchant_screen.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/operator/operator_dashboard_screen.dart';
import 'features/resident/resident_shell.dart';
import 'providers/app_state_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Restore the persisted demo state before the first frame so the app never
  // flashes stale data or loses progress mid-pitch.
  final container = ProviderContainer();
  await container.read(agriStateProvider.notifier).init();

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const AgriLoopApp(),
    ),
  );
}

class AgriLoopApp extends ConsumerWidget {
  const AgriLoopApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final onboarded = ref.watch(
      agriStateProvider.select((s) => s.onboarded),
    );

    final router = GoRouter(
      initialLocation: onboarded ? '/home' : '/onboarding',
      redirect: (context, state) {
        final isOnboarding = state.matchedLocation == '/onboarding';
        if (!onboarded && !isOnboarding) return '/onboarding';
        if (onboarded && isOnboarding) return '/home';
        return null;
      },
      routes: [
        GoRoute(
          path: '/onboarding',
          builder: (context, state) => const OnboardingScreen(),
        ),
        GoRoute(
          path: '/home',
          builder: (context, state) => const ResidentShell(),
        ),
        GoRoute(
          path: '/merchant',
          builder: (context, state) => const MerchantScreen(),
        ),
        GoRoute(
          path: '/operator',
          builder: (context, state) => const OperatorDashboardScreen(),
        ),
      ],
    );

    return MaterialApp.router(
      title: 'AgriLoop — Smart Community Composting',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      routerConfig: router,
      builder: (context, child) {
        return LayoutBuilder(
          builder: (context, constraints) {
            // If running on desktop / Chrome browser (> 500px), wrap in a sleek smartphone device frame
            if (constraints.maxWidth > 500) {
              final frameHeight = (constraints.maxHeight - 40).clamp(560.0, 900.0);
              return Scaffold(
                backgroundColor: const Color(0xFF090E0B),
                body: Container(
                  decoration: const BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment.center,
                      radius: 1.2,
                      colors: [Color(0xFF132219), Color(0xFF070B09)],
                    ),
                  ),
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Container(
                        width: 412,
                        height: frameHeight,
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          color: const Color(0xFF0D1511),
                          borderRadius: BorderRadius.circular(44),
                          border: Border.all(color: const Color(0xFF223127), width: 8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.85),
                              blurRadius: 50,
                              spreadRadius: 8,
                              offset: const Offset(0, 12),
                            ),
                            BoxShadow(
                              color: const Color(0xFF22C55E).withValues(alpha: 0.12),
                              blurRadius: 30,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: Stack(
                          children: [
                            Positioned.fill(child: child ?? const SizedBox.shrink()),
                            // Phone Speaker & Camera Notch (IgnorePointer so touches pass through)
                            IgnorePointer(
                              child: Align(
                                alignment: Alignment.topCenter,
                                child: Container(
                                  margin: const EdgeInsets.only(top: 8),
                                  width: 120,
                                  height: 22,
                                  decoration: BoxDecoration(
                                    color: Colors.black,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        width: 42,
                                        height: 4,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF262626),
                                          borderRadius: BorderRadius.circular(2),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration: const BoxDecoration(
                                          color: Color(0xFF1B2836),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }
            // On real mobile screens or narrow viewports, render standard full-screen mobile app
            return child ?? const SizedBox.shrink();
          },
        );
      },
    );
  }
}
