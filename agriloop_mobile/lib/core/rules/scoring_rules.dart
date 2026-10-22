// AgriLoop Scoring & Anti-Gaming Rules Engine.
//
// This is the single source of truth for how many Green Points a deposit is
// worth and which deposits are rejected. The UI never recomputes points — it
// renders the `ScoreBreakdown` produced here.

/// Reasons a deposit can be flagged, blocked or down-weighted.
enum RuleViolation {
  belowMinWeight,
  dailyPointsCapReached,
  cooldownActive,
  duplicateScan,
  implausibleWeight,
  dailyDepositLimitReached,
  binFull,
  binOffline,
  /// The database enforced a rule the client does not model locally. The
  /// server's own code is carried through in the finding detail.
  serverPolicy,
  /// The unit is not registered in the community database.
  unknownResident,
  /// The deposit was rejected for contamination.
  contaminationDetected,
}

/// Human-readable explanation for each violation, used verbatim in the UI.
const Map<RuleViolation, String> ruleViolationMessages = {
  RuleViolation.belowMinWeight:
      'Below the 50 g minimum deposit weight — no points awarded.',
  RuleViolation.dailyPointsCapReached:
      'Daily points cap reached — deposit counted for diversion but earns no points.',
  RuleViolation.cooldownActive:
      'Cooldown active on this bin — one deposit per 10 minutes.',
  RuleViolation.duplicateScan:
      'Duplicate scan — this bin session nonce was already redeemed.',
  RuleViolation.implausibleWeight:
      'Weight jump looks implausible — points withheld pending operator audit.',
  RuleViolation.dailyDepositLimitReached:
      'Daily deposit limit reached for this unit.',
  RuleViolation.binFull:
      'Bin is full — the operator has been notified to swap the bucket.',
  RuleViolation.binOffline:
      'Bin is offline — no deposit session can be opened.',
};

/// How confident the vision model is that a deposit is clean organic waste.
enum CleanlinessTier { clean, suspect, contaminated }

const Map<CleanlinessTier, String> cleanlinessTierLabels = {
  CleanlinessTier.clean: 'Clean organic',
  CleanlinessTier.suspect: 'Suspect — needs review',
  CleanlinessTier.contaminated: 'Contaminated',
};

/// A rule was broken but the deposit is still recorded (weight still counts
/// towards diversion, points are withheld or reduced).
class RuleFinding {
  final RuleViolation violation;
  final String detail;
  final bool blocksPoints;

  const RuleFinding({
    required this.violation,
    required this.detail,
    this.blocksPoints = true,
  });
}

/// Full, auditable explanation of a points award.
class ScoreBreakdown {
  final double weightKg;
  final CleanlinessTier tier;
  final double confidence;
  final double cleanlinessMultiplier;
  final int basePoints;
  final int qualityBonus;
  final int streakBonus;
  final int cappedPoints;
  final int totalPoints;
  final List<RuleFinding> findings;
  final bool pointsWithheld;

  const ScoreBreakdown({
    required this.weightKg,
    required this.tier,
    required this.confidence,
    required this.cleanlinessMultiplier,
    required this.basePoints,
    required this.qualityBonus,
    required this.streakBonus,
    required this.cappedPoints,
    required this.totalPoints,
    this.findings = const [],
    this.pointsWithheld = false,
  });

  static const empty = ScoreBreakdown(
    weightKg: 0,
    tier: CleanlinessTier.contaminated,
    confidence: 0,
    cleanlinessMultiplier: 0,
    basePoints: 0,
    qualityBonus: 0,
    streakBonus: 0,
    cappedPoints: 0,
    totalPoints: 0,
    pointsWithheld: true,
  );
}

/// Tunable policy constants. Kept in one place so the pitch deck and the code
/// quote the same numbers.
class ScoringRules {
  const ScoringRules({
    this.pointsPerKg = 100,
    this.minWeightKg = 0.05,
    this.maxPlausibleDepositKg = 4.0,
    this.dailyPointsCap = 500,
    this.maxDepositsPerDay = 6,
    this.cooldownMinutes = 10,
    this.duplicateWindowMinutes = 2,
    this.cleanConfidenceThreshold = 0.85,
    this.suspectConfidenceThreshold = 0.60,
    this.streakBonusPct = 0.10,
    this.maxStreakBonusPoints = 100,
    this.suddenJumpKg = 1.5,
    this.suddenJumpFillPct = 20,
  });

  final int pointsPerKg;
  final double minWeightKg;
  final double maxPlausibleDepositKg;
  final int dailyPointsCap;
  final int maxDepositsPerDay;
  final int cooldownMinutes;
  final int duplicateWindowMinutes;
  final double cleanConfidenceThreshold;
  final double suspectConfidenceThreshold;
  final double streakBonusPct;
  final int maxStreakBonusPoints;
  final double suddenJumpKg;
  final int suddenJumpFillPct;

  static const defaultRules = ScoringRules();

  CleanlinessTier tierFor(double confidence) {
    if (confidence >= cleanConfidenceThreshold) return CleanlinessTier.clean;
    if (confidence >= suspectConfidenceThreshold) return CleanlinessTier.suspect;
    return CleanlinessTier.contaminated;
  }

  double multiplierFor(CleanlinessTier tier) {
    switch (tier) {
      case CleanlinessTier.clean:
        return 1.0;
      case CleanlinessTier.suspect:
        return 0.5;
      case CleanlinessTier.contaminated:
        return 0.0;
    }
  }
}

/// Everything the engine needs to know about the current world state.
class ScoringContext {
  /// Points already earned by this unit today.
  final int pointsEarnedToday;

  /// Number of deposits this unit already made today.
  final int depositsToday;

  /// Time of the previous deposit at this bin (null if none).
  final DateTime? lastDepositAtBin;

  /// Every session nonce this unit has already redeemed at this bin.
  /// Replaying any of them is a duplicate scan.
  final Set<String> usedSessionNonces;

  /// Time the current session nonce was issued.
  final DateTime? sessionIssuedAt;

  /// Current fill percentage of the target bin.
  final int binFillPct;

  /// Whether the bin is currently accepting deposits.
  final bool binAcceptingDeposits;

  /// Whether the bin is reachable.
  final bool binOnline;

  /// Current streak of consecutive clean weeks.
  final int streakWeeks;

  const ScoringContext({
    this.pointsEarnedToday = 0,
    this.depositsToday = 0,
    this.lastDepositAtBin,
    this.usedSessionNonces = const {},
    this.sessionIssuedAt,
    this.binFillPct = 0,
    this.binAcceptingDeposits = true,
    this.binOnline = true,
    this.streakWeeks = 0,
  });
}

/// Result of evaluating a deposit against the rules engine.
class RuleVerdict {
  final bool accepted;
  final int awardedPoints;
  final ScoreBreakdown breakdown;
  final List<RuleFinding> findings;
  final bool opensDispute;

  const RuleVerdict({
    required this.accepted,
    required this.awardedPoints,
    required this.breakdown,
    required this.findings,
    this.opensDispute = false,
  });

  bool get hasFindings => findings.isNotEmpty;
}

/// Evaluates deposits against the anti-gaming policy and computes the award.
class ScoringEngine {
  const ScoringEngine([this.rules = ScoringRules.defaultRules]);

  final ScoringRules rules;

  RuleVerdict evaluate({
    required double weightKg,
    required double confidence,
    required DateTime now,
    required ScoringContext context,
    String? sessionNonce,
  }) {
    final findings = <RuleFinding>[];

    // --- Hard blocks: the bin cannot accept a deposit at all -------------
    if (!context.binOnline) {
      findings.add(const RuleFinding(
        violation: RuleViolation.binOffline,
        detail: 'Bin heartbeat lost — session refused.',
      ));
      return _reject(weightKg, confidence, findings);
    }
    if (!context.binAcceptingDeposits) {
      findings.add(const RuleFinding(
        violation: RuleViolation.binFull,
        detail: 'Bucket at capacity — operator swap required.',
      ));
      return _reject(weightKg, confidence, findings);
    }

    // --- Duplicate session nonce ----------------------------------------
    // A nonce may only be redeemed once at a bin; replaying an older nonce
    // is just as much a replay as replaying the most recent one.
    if (sessionNonce != null &&
        sessionNonce.isNotEmpty &&
        context.usedSessionNonces.contains(sessionNonce)) {
      findings.add(RuleFinding(
        violation: RuleViolation.duplicateScan,
        detail: 'Session nonce $sessionNonce already redeemed.',
      ));
      return _reject(weightKg, confidence, findings);
    }

    // --- Cooldown between deposits at the same bin -----------------------
    if (context.lastDepositAtBin != null) {
      final elapsed = now.difference(context.lastDepositAtBin!).inMinutes;
      if (elapsed < rules.cooldownMinutes) {
        final remaining = rules.cooldownMinutes - elapsed;
        findings.add(RuleFinding(
          violation: RuleViolation.cooldownActive,
          detail: 'Wait $remaining more minute${remaining == 1 ? '' : 's'} before depositing at this bin again.',
        ));
        return _reject(weightKg, confidence, findings);
      }
    }

    // --- Daily deposit count ---------------------------------------------
    if (context.depositsToday >= rules.maxDepositsPerDay) {
      findings.add(RuleFinding(
        violation: RuleViolation.dailyDepositLimitReached,
        detail: 'Maximum ${rules.maxDepositsPerDay} deposits per day reached.',
      ));
      return _reject(weightKg, confidence, findings);
    }

    // --- Weight sanity ----------------------------------------------------
    if (weightKg > rules.maxPlausibleDepositKg) {
      findings.add(RuleFinding(
        violation: RuleViolation.implausibleWeight,
        detail:
            'Single deposit of ${weightKg.toStringAsFixed(2)} kg exceeds the ${rules.maxPlausibleDepositKg.toStringAsFixed(1)} kg plausibility ceiling.',
      ));
      return _reject(weightKg, confidence, findings);
    }

    // A sudden large jump on a nearly-empty bin suggests water, stones or a
    // foreign object rather than food waste.
    if (weightKg > rules.suddenJumpKg && context.binFillPct < rules.suddenJumpFillPct) {
      findings.add(RuleFinding(
        violation: RuleViolation.implausibleWeight,
        detail:
            'Bin was only ${context.binFillPct}% full — a ${weightKg.toStringAsFixed(2)} kg jump suggests water or non-food weight.',
      ));
    }

    // --- Below minimum weight ---------------------------------------------
    if (weightKg < rules.minWeightKg) {
      findings.add(RuleFinding(
        violation: RuleViolation.belowMinWeight,
        detail: 'Minimum deposit weight is ${(rules.minWeightKg * 1000).round()} g.',
      ));
    }

    // --- Points computation ------------------------------------------------
    final tier = rules.tierFor(confidence);
    final multiplier = rules.multiplierFor(tier);
    final basePoints = (weightKg * rules.pointsPerKg).round();
    final adjusted = (basePoints * multiplier).round();

    final isBlocked = findings.any((f) => f.blocksPoints);
    final qualityBonus = (tier == CleanlinessTier.clean && !isBlocked)
        ? (adjusted * rules.streakBonusPct).round()
        : 0;
    final streakBonus = (tier == CleanlinessTier.clean && !isBlocked)
        ? (adjusted * rules.streakBonusPct).round().clamp(0, rules.maxStreakBonusPoints)
        : 0;

    var total = adjusted + qualityBonus + streakBonus;

    // Daily cap — the excess is clipped, not voided silently.
    var cappedPoints = 0;
    final remainingCap = rules.dailyPointsCap - context.pointsEarnedToday;
    if (total > remainingCap) {
      cappedPoints = total - remainingCap;
      total = remainingCap.clamp(0, rules.dailyPointsCap);
      if (cappedPoints > 0) {
        findings.add(RuleFinding(
          violation: RuleViolation.dailyPointsCapReached,
          detail:
              'Daily cap of ${rules.dailyPointsCap} pts reached — $cappedPoints pts clipped for today.',
        ));
      }
    }

    final pointsWithheld = isBlocked || tier == CleanlinessTier.contaminated;

    final breakdown = ScoreBreakdown(
      weightKg: weightKg,
      tier: tier,
      confidence: confidence,
      cleanlinessMultiplier: multiplier,
      basePoints: basePoints,
      qualityBonus: qualityBonus,
      streakBonus: streakBonus,
      cappedPoints: cappedPoints,
      totalPoints: pointsWithheld ? 0 : total,
      findings: findings,
      pointsWithheld: pointsWithheld,
    );

    return RuleVerdict(
      accepted: true,
      awardedPoints: breakdown.totalPoints,
      breakdown: breakdown,
      findings: findings,
      opensDispute: tier == CleanlinessTier.contaminated,
    );
  }

  RuleVerdict _reject(
    double weightKg,
    double confidence,
    List<RuleFinding> findings,
  ) {
    final tier = rules.tierFor(confidence);
    return RuleVerdict(
      accepted: false,
      awardedPoints: 0,
      breakdown: ScoreBreakdown(
        weightKg: weightKg,
        tier: tier,
        confidence: confidence,
        cleanlinessMultiplier: 0,
        basePoints: 0,
        qualityBonus: 0,
        streakBonus: 0,
        cappedPoints: 0,
        totalPoints: 0,
        findings: findings,
        pointsWithheld: true,
      ),
      findings: findings,
    );
  }
}
