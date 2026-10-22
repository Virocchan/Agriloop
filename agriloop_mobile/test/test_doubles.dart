import 'package:agriloop_mobile/core/rules/scoring_rules.dart';
import 'package:agriloop_mobile/core/services/deposit_api.dart';

/// Backend stub with no latency, so the tests stay fast and never touch the
/// network.
class FakeDepositApi implements DepositApi {
  /// When set, the API reports this many points as the server's verdict.
  int? serverPoints;

  @override
  Future<DepositResult> submitDeposit(DepositRequest request) async {
    return DepositResult(
      accepted: true,
      awardedPoints: serverPoints ?? -1,
      breakdown: ScoreBreakdown.empty,
      findings: const [],
      persisted: false,
      rewardLatencyMs: 900,
      source: 'test',
    );
  }

  @override
  Future<bool> notifyResident({
    required String unitId,
    required String message,
  }) async {
    return true;
  }
}
