import 'package:agriloop_mobile/core/services/local_agri_repository.dart';
import 'package:agriloop_mobile/main.dart';
import 'package:agriloop_mobile/providers/app_state_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'test_doubles.dart';

/// Builds the app against the local snapshot backend and a stubbed API, so
/// tests never touch the network.
Widget buildTestApp({Widget? child}) {
  return ProviderScope(
    overrides: [
      agriStateProvider.overrideWith(
        (ref) => AgriStateNotifier(
          api: FakeDepositApi(),
          repository: LocalAgriRepository(),
        ),
      ),
    ],
    child: child ?? const AgriLoopApp(),
  );
}
