import 'package:agriloop_mobile/core/rules/scoring_rules.dart';
import 'package:agriloop_mobile/core/services/local_agri_repository.dart';
import 'package:agriloop_mobile/core/services/voucher_service.dart';
import 'package:agriloop_mobile/models/all_models.dart';
import 'package:agriloop_mobile/providers/app_state_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_doubles.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  late AgriStateNotifier notifier;

  setUp(() async {
    // The tests run against the local snapshot backend so they never touch
    // the network.
    notifier = AgriStateNotifier(
      api: FakeDepositApi(),
      repository: LocalAgriRepository(),
    );
    await notifier.init();
  });

  tearDown(() {
    notifier.dispose();
  });

  group('deposit flow', () {
    test('a clean deposit awards points and updates the balance', () async {
      final before = notifier.state.profile.points;

      final outcome = await notifier.submitDeposit(
        binId: 'A01',
        weightKg: 0.65,
        confidence: 0.97,
        sessionNonce: 'NR-TEST-1',
      );

      expect(outcome.accepted, isTrue);
      expect(outcome.pointsAwarded, 79);
      expect(notifier.state.profile.points, before + 79);
      expect(notifier.state.deposits.first.pointsEarned, 79);
      expect(notifier.state.ledger.first.delta, 79);
    });

    test('a contaminated deposit scores zero and opens a dispute', () async {
      final openBefore = notifier.state.openDisputeCount;
      final outcome = await notifier.submitDeposit(
        binId: 'A01',
        weightKg: 0.8,
        confidence: 0.41,
        sessionNonce: 'NR-TEST-2',
      );

      expect(outcome.accepted, isTrue);
      expect(outcome.pointsAwarded, 0);
      expect(outcome.dispute, isNotNull);
      expect(notifier.state.openDisputeCount, openBefore + 1);
    });

    test('a blocked deposit is logged as a rejected attempt', () async {
      final before = notifier.state.rejectedAttempts.length;
      final depositsBefore = notifier.state.deposits.length;
      final outcome = await notifier.submitDeposit(
        binId: 'A01',
        weightKg: 0.5,
        confidence: 0.95,
        sessionNonce: 'NR-TEST-3',
        contextOverride: ScoringContext(
          lastDepositAtBin: DateTime.now().subtract(const Duration(minutes: 2)),
        ),
      );

      expect(outcome.accepted, isFalse);
      expect(notifier.state.rejectedAttempts.length, before + 1);
      expect(notifier.state.deposits.length, depositsBefore);
    });

    test('the deposit increases the bin fill level', () async {
      final before = notifier.state.bins.first.weightG;

      await notifier.submitDeposit(
        binId: 'A01',
        weightKg: 1.0,
        confidence: 0.97,
        sessionNonce: 'NR-TEST-4',
      );

      expect(notifier.state.bins.first.weightG, before + 1000);
    });
  });

  group('voucher lifecycle', () {
    test('redeeming deducts points and issues a signed token', () {
      final item = notifier.state.catalog.first;
      final before = notifier.state.profile.points;

      final ok = notifier.redeemVoucher(item);

      expect(ok, isTrue);
      expect(notifier.state.profile.points, before - item.costPts);
      expect(notifier.state.myVouchers.length, 2);
      expect(notifier.state.ledger.first.delta, -item.costPts);
    });

    test('redeeming is refused when the balance is too low', () {
      const expensive = VoucherItem(
        id: 'cat-test-expensive',
        merchant: 'Test Merchant',
        merchantCode: 'TM',
        title: 'RM 100.00 Test Voucher',
        terms: 'Test only.',
        costPts: 999999,
        expiryDays: 30,
        icon: '🧪',
        valueRm: 100,
      );
      expect(notifier.redeemVoucher(expensive), isFalse);
    });

    test('a valid token can be redeemed exactly once', () {
      final item = notifier.state.catalog.first;
      notifier.redeemVoucher(item);
      final voucher = notifier.state.myVouchers.first;

      final first = notifier.redeemVoucherToken(
        token: voucher.token,
        merchantCode: voucher.merchantCode,
      );
      expect(first.outcome, RedemptionOutcome.success);
      expect(notifier.state.myVouchers.first.status, VoucherStatus.used);

      final second = notifier.redeemVoucherToken(
        token: voucher.token,
        merchantCode: voucher.merchantCode,
      );
      expect(second.outcome, RedemptionOutcome.alreadyUsed);
    });

    test('an unknown token is rejected', () {
      final result = notifier.redeemVoucherToken(
        token: 'AGR-JG-5-999-DEADBEEF',
        merchantCode: 'JG',
      );

      expect(result.outcome, RedemptionOutcome.unknownToken);
    });

    test('a token issued for another merchant is rejected', () {
      final item = notifier.state.catalog.first;
      notifier.redeemVoucher(item);
      final voucher = notifier.state.myVouchers.first;

      final result = notifier.redeemVoucherToken(
        token: voucher.token,
        merchantCode: 'ZU',
      );

      expect(result.outcome, RedemptionOutcome.wrongMerchant);
    });
  });

  group('disputes', () {
    test('upholding a dispute restores the withheld points', () async {
      final openBefore = notifier.state.openDisputeCount;
      final outcome = await notifier.submitDeposit(
        binId: 'A01',
        weightKg: 0.8,
        confidence: 0.41,
        sessionNonce: 'NR-TEST-5',
      );
      final dispute = outcome.dispute!;
      final before = notifier.state.profile.points;

      notifier.resolveDispute(dispute.id, uphold: true);

      expect(notifier.state.profile.points, before + dispute.withheldPoints);
      expect(
        notifier.state.disputes.first.status,
        DisputeStatus.upheld,
      );
      expect(notifier.state.openDisputeCount, openBefore);
    });

    test('rejecting a dispute leaves the points withheld', () async {
      final outcome = await notifier.submitDeposit(
        binId: 'A01',
        weightKg: 0.8,
        confidence: 0.41,
        sessionNonce: 'NR-TEST-6',
      );
      final before = notifier.state.profile.points;

      notifier.resolveDispute(outcome.dispute!.id, uphold: false);

      expect(notifier.state.profile.points, before);
      expect(
        notifier.state.disputes.first.status,
        DisputeStatus.rejected,
      );
    });
  });

  group('registration', () {
    test('registering issues a resident pass and marks onboarding done', () {
      notifier.registerResident(
        nickname: 'Test Resident',
        township: 'City of Elmina (Elmina Valley)',
        block: 'Block B',
        unit: '09-09',
        inviteCode: 'ELM-4417',
      );

      expect(notifier.state.onboarded, isTrue);
      expect(notifier.state.profile.unit, '09-09');
      expect(notifier.state.profile.residentPassToken, startsWith('AGR-RES-ELM4417-'));
    });
  });

  group('derived metrics', () {
    test('block standings are derived from the deposit ledger', () async {
      await notifier.submitDeposit(
        binId: 'A01',
        weightKg: 0.5,
        confidence: 0.97,
        sessionNonce: 'NR-TEST-7',
      );

      final standings = notifier.state.blockStandings;
      expect(standings, isNotEmpty);
      expect(standings.first.kgDiverted, greaterThan(0));
    });

    test('pilot metrics report a baseline and a rewarded phase', () {
      final metrics = notifier.state.pilotMetrics;

      expect(metrics.participants, greaterThan(0));
      expect(metrics.baselineKgPerParticipant, greaterThan(0));
      expect(metrics.rewardedKgPerParticipant, greaterThan(0));
      expect(metrics.avgRewardLatencyMs, greaterThan(0));
    });
  });
}
