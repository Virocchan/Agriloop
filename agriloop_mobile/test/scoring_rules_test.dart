import 'package:agriloop_mobile/core/rules/scoring_rules.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const rules = ScoringRules.defaultRules;
  const engine = ScoringEngine(rules);

  final now = DateTime(2026, 3, 10, 9, 0);

  ScoringContext context({
    int pointsToday = 0,
    int depositsToday = 0,
    DateTime? lastAtBin,
    Set<String> usedNonces = const {},
    int fillPct = 50,
    bool accepting = true,
    bool online = true,
  }) {
    return ScoringContext(
      pointsEarnedToday: pointsToday,
      depositsToday: depositsToday,
      lastDepositAtBin: lastAtBin,
      usedSessionNonces: usedNonces,
      binFillPct: fillPct,
      binAcceptingDeposits: accepting,
      binOnline: online,
      streakWeeks: 3,
    );
  }

  group('clean deposits', () {
    test('awards base points plus quality and streak bonuses', () {
      final verdict = engine.evaluate(
        weightKg: 0.65,
        confidence: 0.97,
        now: now,
        context: context(),
      );

      expect(verdict.accepted, isTrue);
      expect(verdict.awardedPoints, 79);
      expect(verdict.breakdown.basePoints, 65);
      expect(verdict.breakdown.qualityBonus, 7);
      expect(verdict.breakdown.streakBonus, 7);
      expect(verdict.breakdown.totalPoints, 79);
      expect(verdict.findings, isEmpty);
    });

    test('scales linearly with weight', () {
      final one = engine.evaluate(
        weightKg: 1.0,
        confidence: 0.95,
        now: now,
        context: context(),
      );
      final two = engine.evaluate(
        weightKg: 2.0,
        confidence: 0.95,
        now: now,
        context: context(),
      );

      expect(two.awardedPoints, one.awardedPoints * 2);
    });
  });

  group('anti-gaming rules', () {
    test('rejects deposits below the minimum weight', () {
      final verdict = engine.evaluate(
        weightKg: 0.03,
        confidence: 0.95,
        now: now,
        context: context(),
      );

      expect(verdict.accepted, isTrue);
      expect(verdict.awardedPoints, 0);
      expect(verdict.breakdown.pointsWithheld, isTrue);
      expect(
        verdict.findings.map((f) => f.violation),
        contains(RuleViolation.belowMinWeight),
      );
    });

    test('blocks a second deposit during the cooldown window', () {
      final verdict = engine.evaluate(
        weightKg: 0.5,
        confidence: 0.95,
        now: now,
        context: context(lastAtBin: now.subtract(const Duration(minutes: 3))),
      );

      expect(verdict.accepted, isFalse);
      expect(verdict.awardedPoints, 0);
      expect(
        verdict.findings.map((f) => f.violation),
        contains(RuleViolation.cooldownActive),
      );
    });

    test('allows a deposit once the cooldown has elapsed', () {
      final verdict = engine.evaluate(
        weightKg: 0.5,
        confidence: 0.95,
        now: now,
        context: context(lastAtBin: now.subtract(const Duration(minutes: 11))),
      );

      expect(verdict.accepted, isTrue);
      expect(verdict.awardedPoints, greaterThan(0));
    });

    test('rejects a replayed session nonce', () {
      final verdict = engine.evaluate(
        weightKg: 0.5,
        confidence: 0.95,
        now: now,
        sessionNonce: 'NR-ABCD-1234',
        context: context(
          usedNonces: {'NR-ABCD-1234'},
          lastAtBin: now.subtract(const Duration(hours: 3)),
        ),
      );

      expect(verdict.accepted, isFalse);
      expect(
        verdict.findings.map((f) => f.violation),
        contains(RuleViolation.duplicateScan),
      );
    });

    test('rejects a replay of an older nonce at the same bin', () {
      // The nonce is not the most recent one, but it was already redeemed.
      final verdict = engine.evaluate(
        weightKg: 0.5,
        confidence: 0.95,
        now: now,
        sessionNonce: 'NR-OLD-1234',
        context: context(
          usedNonces: {'NR-NEW-9999', 'NR-OLD-1234'},
          lastAtBin: now.subtract(const Duration(hours: 3)),
        ),
      );

      expect(verdict.accepted, isFalse);
      expect(
        verdict.findings.map((f) => f.violation),
        contains(RuleViolation.duplicateScan),
      );
    });

    test('clips awards at the daily points cap', () {
      final verdict = engine.evaluate(
        weightKg: 2.0,
        confidence: 0.98,
        now: now,
        context: context(pointsToday: 480),
      );

      expect(verdict.accepted, isTrue);
      expect(verdict.awardedPoints, 20);
      expect(verdict.breakdown.cappedPoints, greaterThan(0));
      expect(
        verdict.findings.map((f) => f.violation),
        contains(RuleViolation.dailyPointsCapReached),
      );
    });

    test('rejects a deposit beyond the daily deposit limit', () {
      final verdict = engine.evaluate(
        weightKg: 0.5,
        confidence: 0.95,
        now: now,
        context: context(depositsToday: rules.maxDepositsPerDay),
      );

      expect(verdict.accepted, isFalse);
      expect(
        verdict.findings.map((f) => f.violation),
        contains(RuleViolation.dailyDepositLimitReached),
      );
    });

    test('rejects implausibly heavy single deposits', () {
      final verdict = engine.evaluate(
        weightKg: 9,
        confidence: 0.95,
        now: now,
        context: context(),
      );

      expect(verdict.accepted, isFalse);
      expect(
        verdict.findings.map((f) => f.violation),
        contains(RuleViolation.implausibleWeight),
      );
    });

    test('flags a sudden jump on a nearly empty bin', () {
      final verdict = engine.evaluate(
        weightKg: 3.2,
        confidence: 0.95,
        now: now,
        context: context(fillPct: 8),
      );

      expect(verdict.accepted, isTrue);
      expect(verdict.awardedPoints, 0);
      expect(
        verdict.findings.map((f) => f.violation),
        contains(RuleViolation.implausibleWeight),
      );
    });

    test('refuses a deposit at a full bin', () {
      final verdict = engine.evaluate(
        weightKg: 0.5,
        confidence: 0.95,
        now: now,
        context: context(accepting: false),
      );

      expect(verdict.accepted, isFalse);
      expect(
        verdict.findings.map((f) => f.violation),
        contains(RuleViolation.binFull),
      );
    });

    test('refuses a deposit at an offline bin', () {
      final verdict = engine.evaluate(
        weightKg: 0.5,
        confidence: 0.95,
        now: now,
        context: context(online: false),
      );

      expect(verdict.accepted, isFalse);
      expect(
        verdict.findings.map((f) => f.violation),
        contains(RuleViolation.binOffline),
      );
    });
  });

  group('cleanliness tiers', () {
    test('contaminated deposits score zero and open a dispute', () {
      final verdict = engine.evaluate(
        weightKg: 0.8,
        confidence: 0.41,
        now: now,
        context: context(),
      );

      expect(verdict.breakdown.tier, CleanlinessTier.contaminated);
      expect(verdict.awardedPoints, 0);
      expect(verdict.opensDispute, isTrue);
    });

    test('suspect deposits are halved', () {
      final verdict = engine.evaluate(
        weightKg: 1.0,
        confidence: 0.7,
        now: now,
        context: context(),
      );

      expect(verdict.breakdown.tier, CleanlinessTier.suspect);
      expect(verdict.breakdown.cleanlinessMultiplier, 0.5);
      expect(verdict.awardedPoints, 50);
    });
  });
}
