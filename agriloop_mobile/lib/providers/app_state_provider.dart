import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/app_config.dart';
import '../core/rules/scoring_rules.dart';
import '../core/services/agri_repository.dart';
import '../core/services/deposit_api.dart';
import '../core/services/voucher_service.dart';
import '../models/all_models.dart';

/// Result of a deposit submission, ready for the UI to render.
class DepositOutcome {
  final bool accepted;
  final int pointsAwarded;
  final ScoreBreakdown breakdown;
  final List<RuleFinding> findings;
  final int rewardLatencyMs;
  final String source;
  final DepositRecord? record;
  final DisputeCase? dispute;

  const DepositOutcome({
    required this.accepted,
    required this.pointsAwarded,
    required this.breakdown,
    required this.findings,
    required this.rewardLatencyMs,
    required this.source,
    this.record,
    this.dispute,
  });

  String get headline {
    if (!accepted) {
      return findings.isEmpty
          ? 'Deposit refused'
          : (findings.first.detail);
    }
    if (pointsAwarded == 0) {
      return 'Deposit recorded — no points awarded';
    }
    return '+$pointsAwarded Green Points';
  }
}

/// Result of a merchant-side voucher redemption attempt.
class RedemptionResult {
  final RedemptionOutcome outcome;
  final ActiveVoucher? voucher;
  final RedemptionRecord? record;

  const RedemptionResult({required this.outcome, this.voucher, this.record});

  bool get success => outcome == RedemptionOutcome.success;
}

class AgriState {
  final UserRole activeRole;
  final UserProfile profile;
  final List<SmartBin> bins;
  final List<DepositRecord> deposits;
  final List<VoucherItem> catalog;
  final List<ActiveVoucher> myVouchers;
  final List<OperatorTask> tasks;
  final List<BokashiBatch> batches;
  final List<NotificationItem> notifications;
  final List<DisputeCase> disputes;
  final List<PointsLedgerEntry> ledger;
  final List<RejectedAttempt> rejectedAttempts;
  final List<RedemptionRecord> redemptions;
  final List<CompostApplication> compostApplications;
  final double communityCompostCurrentKg;
  final double communityCompostTargetKg;
  final bool onboarded;
  final bool bootstrapped;
  final DateTime? savedAt;

  const AgriState({
    required this.activeRole,
    required this.profile,
    required this.bins,
    required this.deposits,
    required this.catalog,
    required this.myVouchers,
    required this.tasks,
    required this.batches,
    required this.notifications,
    required this.communityCompostCurrentKg,
    required this.communityCompostTargetKg,
    this.disputes = const [],
    this.ledger = const [],
    this.rejectedAttempts = const [],
    this.redemptions = const [],
    this.compostApplications = const [],
    this.onboarded = false,
    this.bootstrapped = false,
    this.savedAt,
  });

  AgriState copyWith({
    UserRole? activeRole,
    UserProfile? profile,
    List<SmartBin>? bins,
    List<DepositRecord>? deposits,
    List<VoucherItem>? catalog,
    List<ActiveVoucher>? myVouchers,
    List<OperatorTask>? tasks,
    List<BokashiBatch>? batches,
    List<NotificationItem>? notifications,
    List<DisputeCase>? disputes,
    List<PointsLedgerEntry>? ledger,
    List<RejectedAttempt>? rejectedAttempts,
    List<RedemptionRecord>? redemptions,
    List<CompostApplication>? compostApplications,
    double? communityCompostCurrentKg,
    double? communityCompostTargetKg,
    bool? onboarded,
    bool? bootstrapped,
    DateTime? savedAt,
  }) {
    return AgriState(
      activeRole: activeRole ?? this.activeRole,
      profile: profile ?? this.profile,
      bins: bins ?? this.bins,
      deposits: deposits ?? this.deposits,
      catalog: catalog ?? this.catalog,
      myVouchers: myVouchers ?? this.myVouchers,
      tasks: tasks ?? this.tasks,
      batches: batches ?? this.batches,
      notifications: notifications ?? this.notifications,
      disputes: disputes ?? this.disputes,
      ledger: ledger ?? this.ledger,
      rejectedAttempts: rejectedAttempts ?? this.rejectedAttempts,
      redemptions: redemptions ?? this.redemptions,
      compostApplications: compostApplications ?? this.compostApplications,
      communityCompostCurrentKg:
          communityCompostCurrentKg ?? this.communityCompostCurrentKg,
      communityCompostTargetKg:
          communityCompostTargetKg ?? this.communityCompostTargetKg,
      onboarded: onboarded ?? this.onboarded,
      bootstrapped: bootstrapped ?? this.bootstrapped,
      savedAt: savedAt ?? this.savedAt,
    );
  }

  int get unreadCount => notifications.where((n) => n.isUnread).length;

  int get openDisputeCount =>
      disputes.where((d) => d.status == DisputeStatus.open).length;

  /// Block standings derived from real deposit history, not hardcoded.
  List<BlockStanding> get blockStandings {
    final map = <String, _BlockAccumulator>{};
    for (final deposit in deposits) {
      if (deposit.rejected) continue;
      final key = deposit.blockId.isEmpty ? 'Block A' : deposit.blockId;
      final acc = map.putIfAbsent(key, () => _BlockAccumulator(key));
      acc.kg += deposit.weightKg;
      acc.deposits += 1;
      acc.units.add('${deposit.unitId}#${deposit.blockId}');
      if (!deposit.isClean) acc.contaminated += 1;
    }
    final standings = map.values
        .map((a) => BlockStanding(
              name: a.name,
              kgDiverted: a.kg,
              participants: a.units.length,
              deposits: a.deposits,
              contaminated: a.contaminated,
            ))
        .toList()
      ..sort((a, b) => b.kgDiverted.compareTo(a.kgDiverted));
    return standings;
  }

  /// Pilot metrics computed from the deposit history.
  PilotMetrics get pilotMetrics {
    final byPhaseKg = <String, double>{};
    final byPhaseUnits = <String, Set<String>>{};
    final byPhaseDeposits = <String, int>{};
    final participants = <String>{};
    var totalKg = 0.0;
    var contaminated = 0;
    var latencySum = 0;
    var latencyCount = 0;

    for (final deposit in deposits) {
      if (deposit.rejected) continue;
      totalKg += deposit.weightKg;
      participants.add('${deposit.unitId}#${deposit.blockId}');
      byPhaseKg[deposit.phase] = (byPhaseKg[deposit.phase] ?? 0) + deposit.weightKg;
      byPhaseDeposits[deposit.phase] = (byPhaseDeposits[deposit.phase] ?? 0) + 1;
      byPhaseUnits
          .putIfAbsent(deposit.phase, () => <String>{})
          .add('${deposit.unitId}#${deposit.blockId}');
      if (!deposit.isClean) contaminated += 1;
      if (deposit.rewardLatencyMs > 0) {
        latencySum += deposit.rewardLatencyMs;
        latencyCount += 1;
      }
    }

    final depositCount = byPhaseDeposits.values.fold<int>(0, (a, b) => a + b);
    const weeks = 2.0;
    final perParticipant = participants.isEmpty ? 0.0 : totalKg / participants.length;

    final baselineUnits = byPhaseUnits['baseline']?.length ?? 0;
    final rewardedUnits = byPhaseUnits['rewarded']?.length ?? 0;
    final baselineKg = byPhaseKg['baseline'] ?? 0;
    final rewardedKg = byPhaseKg['rewarded'] ?? 0;

    return PilotMetrics(
      deposits: depositCount,
      totalKg: totalKg,
      participants: participants.length,
      kgPerParticipantPerWeek: perParticipant / weeks,
      contaminationRate: depositCount == 0 ? 0 : contaminated / depositCount,
      weekTwoRetention: baselineUnits == 0 ? 0 : rewardedUnits / baselineUnits,
      avgRewardLatencyMs: latencyCount == 0 ? 0 : latencySum ~/ latencyCount,
      rejectedAttempts: rejectedAttempts.length,
      baselineKgPerParticipant:
          baselineUnits == 0 ? 0 : baselineKg / baselineUnits,
      rewardedKgPerParticipant:
          rewardedUnits == 0 ? 0 : rewardedKg / rewardedUnits,
    );
  }
}

class _BlockAccumulator {
  _BlockAccumulator(this.name);
  final String name;
  double kg = 0;
  int deposits = 0;
  int contaminated = 0;
  final Set<String> units = {};
}

/// Invite codes issued by the township management office.
const List<String> validInviteCodes = [
  'ELM-9921',
  'ELM-4417',
  'ELM-7788',
  'ELM-2056',
];

class AgriStateNotifier extends StateNotifier<AgriState> {
  AgriStateNotifier({
    DepositApi? api,
    AgriRepository? repository,
    VoucherService? voucherService,
    ScoringEngine? engine,
  })  : _api = api ?? buildDepositApi(),
        _repository = repository ?? buildRepository(),
        _voucherService = voucherService ?? const VoucherService(),
        _engine = engine ?? const ScoringEngine(),
        super(_seedState()) {
    unawaited(init());
  }

  final DepositApi _api;
  final AgriRepository _repository;
  final VoucherService _voucherService;
  final ScoringEngine _engine;

  Future<void>? _initFuture;
  Timer? _saveTimer;
  int _sequence = 2000;
  int _voucherSequence = 3000;

  @override
  void dispose() {
    _saveTimer?.cancel();
    super.dispose();
  }

  /// Idempotent bootstrap: restores the persisted snapshot or seeds a fresh
  /// demo world.
  Future<void> init() => _initFuture ??= _bootstrap();

  Future<void> _bootstrap() async {
    RepositorySnapshot? snapshot;
    try {
      snapshot = await _repository.load();
    } catch (_) {
      snapshot = null;
    }

    if (snapshot != null && !snapshot.isEmpty) {
      try {
        state = _stateFromSnapshot(snapshot).copyWith(bootstrapped: true);
        return;
      } catch (_) {
        // Corrupt snapshot — fall through to a fresh seed.
      }
    }

    state = state.copyWith(bootstrapped: true);
    _scheduleSave();
  }

  // ---------------------------------------------------------------------
  // Role + identity
  // ---------------------------------------------------------------------

  void switchRole(UserRole role) {
    state = state.copyWith(activeRole: role);
    _scheduleSave();
  }

  /// Registers (or re-registers) the resident and issues a signed unit pass.
  void registerResident({
    required String nickname,
    required String township,
    required String block,
    required String unit,
    required String inviteCode,
  }) {
    final token = _voucherService.mintResidentToken(
      inviteCode: inviteCode,
      sequence: ++_sequence,
    );
    final profile = state.profile.copyWith(
      nickname: nickname,
      township: township,
      block: block,
      unit: unit,
      inviteCode: inviteCode,
      verified: true,
      registeredAt: DateTime.now(),
      residentPassToken: token,
    );

    state = state.copyWith(
      profile: profile,
      onboarded: true,
    );

    final notification = _addNotification(
      title: 'Welcome to AgriLoop, $nickname',
      message:
          'Your unit $unit pass in $block is active. Deposit at any smart bin to start earning Green Points.',
      type: 'system',
    );
    _persist((repo) => repo.saveProfile(profile));
    _persist((repo) => repo.appendNotification(notification));
    _scheduleSave();
  }

  void updateProfile({
    required String nickname,
    required String township,
    required String block,
    required String unit,
  }) {
    state = state.copyWith(
      profile: state.profile.copyWith(
        nickname: nickname,
        township: township,
        block: block,
        unit: unit,
      ),
    );
    _scheduleSave();
  }

  // ---------------------------------------------------------------------
  // Deposits
  // ---------------------------------------------------------------------

  /// Submits a deposit through the rules engine and the backend boundary.
  Future<DepositOutcome> submitDeposit({
    required String binId,
    required double weightKg,
    required double confidence,
    String? sessionNonce,
    String? imagePath,
    bool overrideClean = false,
    ScoringContext? contextOverride,
  }) async {
    final now = DateTime.now();
    final bin = state.bins.firstWhere(
      (b) => b.id == binId,
      orElse: () => state.bins.first,
    );

    final context = contextOverride ?? _scoringContextFor(bin, now);

    final verdict = _engine.evaluate(
      weightKg: weightKg,
      confidence: confidence,
      now: now,
      context: context,
      sessionNonce: sessionNonce,
    );

    // Round trip through the backend boundary. When Postgres is connected the
    // database is the referee: it applies the anti-gaming policy and returns
    // the authoritative points. Offline, the local engine decides and the
    // local snapshot is written instead.
    DepositResult? apiResult;
    try {
      apiResult = await _api.submitDeposit(DepositRequest(
        unitId: state.profile.unit,
        blockId: state.profile.block,
        binId: bin.id,
        inviteCode: state.profile.inviteCode,
        weightKg: weightKg,
        confidence: confidence,
        sessionNonce: sessionNonce,
        timestamp: now,
        snapshotPath: imagePath ?? '',
      ));
    } catch (_) {
      apiResult = null;
    }

    final latency = apiResult?.rewardLatencyMs ?? 0;
    final source = apiResult?.source ?? 'local';

    // The server may overrule the local engine (or vice versa) — whichever
    // is stricter wins, so a deposit can never score more points than the
    // policy allows.
    final serverFindings = apiResult?.findings ?? const <RuleFinding>[];
    final serverBlocked =
        apiResult != null && apiResult.awardedPoints == 0 && serverFindings.isNotEmpty;
    final findings = serverFindings.isNotEmpty ? serverFindings : verdict.findings;
    final blocked = !verdict.accepted || serverBlocked;

    if (blocked) {
      final reason = findings.isEmpty
          ? 'Deposit refused by policy.'
          : findings.first.detail;
      _addRejectedAttempt(bin.id, reason, weightKg);
      _addNotification(
        title: '⚠️ Deposit not counted',
        message: '$reason Nothing was deducted and no points were awarded.',
        type: 'alert',
      );
      _persist((repo) => repo.appendRejectedAttempt(
            binId: bin.id,
            unitId: state.profile.unit,
            reason: reason,
            weightKg: weightKg,
          ));
      _scheduleSave();
      return DepositOutcome(
        accepted: false,
        pointsAwarded: 0,
        breakdown: verdict.breakdown,
        findings: findings,
        rewardLatencyMs: latency,
        source: source,
      );
    }

    // A server that has already scored the deposit is authoritative; the
    // local engine is the fallback when there is no backend.
    final serverPoints = apiResult?.awardedPoints ?? -1;
    final awarded = serverPoints >= 0 ? serverPoints : verdict.awardedPoints;
    final persisted = apiResult?.persisted ?? false;
    final recordId = 'DEP-${now.millisecondsSinceEpoch.toString().substring(8)}';
    final snapshot = imagePath ??
        (verdict.breakdown.tier == CleanlinessTier.clean
            ? 'assets/images/deposit_clean.jpg'
            : 'assets/images/deposit_contaminated.jpg');

    final record = DepositRecord(
      id: recordId,
      timestamp: now,
      binId: bin.id,
      unitId: state.profile.unit,
      blockId: state.profile.block,
      weightKg: weightKg,
      pointsEarned: awarded,
      isClean: overrideClean || verdict.breakdown.tier == CleanlinessTier.clean,
      imagePath: snapshot,
      verdict: apiResult?.verdict ?? _verdictText(verdict),
      sessionNonce: sessionNonce,
      confidence: confidence,
      tier: verdict.breakdown.tier,
      basePoints: verdict.breakdown.basePoints,
      qualityBonus: verdict.breakdown.qualityBonus,
      streakBonus: verdict.breakdown.streakBonus,
      cleanlinessMultiplier: verdict.breakdown.cleanlinessMultiplier,
      rewardLatencyMs: latency,
      violations: findings.map((f) => f.violation).toList(),
    );

    // --- Bin telemetry update -------------------------------------------
    final updatedBins = state.bins.map((b) {
      if (b.id != bin.id) return b;
      final newWeight = b.weightG + (weightKg * 1000).round();
      const capacity = 20000;
      final fill = ((newWeight / capacity) * 100).round().clamp(0, 100);
      return SmartBin(
        id: b.id,
        name: b.name,
        location: b.location,
        status: fill >= 90 ? 'full' : 'available',
        weightG: newWeight,
        fillPct: fill,
        tempC: b.tempC,
        humidityPct: b.humidityPct,
        rssi: b.rssi,
        lockState: 'locked',
        lastSeen: now,
      );
    }).toList();

    // --- Resident totals -------------------------------------------------
    var profile = state.profile;
    if (awarded > 0) {
      profile = profile.copyWith(
        points: profile.points + awarded,
        totalKgDiverted:
            double.parse((profile.totalKgDiverted + weightKg).toStringAsFixed(2)),
        streakWeeks: _nextStreak(now),
      );
    } else if (verdict.breakdown.tier != CleanlinessTier.contaminated) {
      // Contamination still counts as diverted volume for the township.
      profile = profile.copyWith(
        totalKgDiverted:
            double.parse((profile.totalKgDiverted + weightKg).toStringAsFixed(2)),
      );
    }

    final ledger = [...state.ledger];
    if (awarded != 0) {
      ledger.insert(
        0,
        PointsLedgerEntry(
          id: 'L-${now.millisecondsSinceEpoch}',
          delta: awarded,
          reason: 'Deposit ${weightKg.toStringAsFixed(2)} kg at Bin ${bin.id}',
          refId: recordId,
          balanceAfter: profile.points,
          timestamp: now,
        ),
      );
    }

    // --- Dispute auto-open on contamination --------------------------------
    DisputeCase? dispute;
    final disputes = [...state.disputes];
    if (verdict.opensDispute) {
      dispute = DisputeCase(
        id: 'DSP-${now.millisecondsSinceEpoch.toString().substring(8)}',
        depositId: recordId,
        unitId: state.profile.unit,
        binId: bin.id,
        reason: verdict.findings.isEmpty
            ? 'Vision model flagged non-food items in the deposit.'
            : verdict.findings.first.detail,
        imagePath: snapshot,
        weightKg: weightKg,
        confidence: confidence,
        withheldPoints: verdict.breakdown.basePoints,
        createdAt: now,
      );
      disputes.insert(0, dispute);
    }

    state = state.copyWith(
      deposits: [record, ...state.deposits],
      bins: updatedBins,
      profile: profile,
      ledger: ledger,
      disputes: disputes,
    );

    final notification = _addNotification(
      title: awarded > 0
          ? '+$awarded Green Points'
          : (verdict.opensDispute
              ? '⚠️ Contamination flagged'
              : 'ℹ️ Deposit recorded'),
      message: awarded > 0
          ? '${weightKg.toStringAsFixed(2)} kg diverted at Bin ${bin.id}. Reward delivered in ${latency}ms.'
          : (verdict.opensDispute
              ? 'Non-food items detected at Bin ${bin.id}. Points withheld — an operator will review your deposit.'
              : '${weightKg.toStringAsFixed(2)} kg diverted at Bin ${bin.id}. ${findings.isEmpty ? '' : findings.first.detail}'),
      type: awarded > 0 ? 'deposit' : 'alert',
    );

    // --- Persist to the backend -------------------------------------------
    // When the database already wrote the deposit, the ledger entry and the
    // balance, only the rows it does not own are written here.
    final updatedBin = updatedBins.firstWhere((b) => b.id == bin.id);
    if (!persisted) {
      _persist((repo) => repo.appendDeposit(record));
      if (awarded != 0) {
        _persist((repo) => repo.appendLedgerEntry(ledger.first));
      }
      _persist((repo) => repo.saveProfile(profile));
    }
    _persist((repo) => repo.saveBin(updatedBin));
    if (dispute != null) {
      final opened = dispute;
      _persist((repo) => repo.upsertDispute(opened));
    }
    _persist((repo) => repo.appendNotification(notification));

    // Notify the resident over the configured channel (Telegram in production).
    unawaited(_api.notifyResident(
      unitId: state.profile.unit,
      message: awarded > 0
          ? '+$awarded Green Points · ${weightKg.toStringAsFixed(2)} kg diverted at ${bin.id}'
          : 'Deposit recorded · ${findings.isEmpty ? 'no points' : findings.first.detail}',
    ));

    _scheduleSave();

    return DepositOutcome(
      accepted: true,
      pointsAwarded: awarded,
      breakdown: verdict.breakdown,
      findings: findings,
      rewardLatencyMs: latency,
      source: source,
      record: record,
      dispute: dispute,
    );
  }

  String _verdictText(RuleVerdict verdict) {
    if (verdict.findings.isNotEmpty) {
      return verdict.findings.map((f) => f.detail).join(' ');
    }
    switch (verdict.breakdown.tier) {
      case CleanlinessTier.clean:
        return 'Clean organic waste and Bokashi bran verified.';
      case CleanlinessTier.suspect:
        return 'Partially clean — some non-food items suspected.';
      case CleanlinessTier.contaminated:
        return 'Flagged: non-food items detected, points withheld.';
    }
  }

  ScoringContext _scoringContextFor(SmartBin bin, DateTime now) {
    final unit = state.profile.unit;
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayDeposits = state.deposits.where((d) =>
        !d.rejected &&
        d.unitId == unit &&
        d.timestamp.isAfter(todayStart));

    final mineAtBin = state.deposits.where((d) =>
        !d.rejected && d.unitId == unit && d.binId == bin.id).toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    final last = mineAtBin.isEmpty ? null : mineAtBin.first;

    // Every nonce this unit has already redeemed at this bin.
    final usedNonces = mineAtBin
        .map((d) => d.sessionNonce)
        .whereType<String>()
        .where((n) => n.isNotEmpty)
        .toSet();

    return ScoringContext(
      pointsEarnedToday:
          todayDeposits.fold<int>(0, (sum, d) => sum + d.pointsEarned),
      depositsToday: todayDeposits.length,
      lastDepositAtBin: last?.timestamp,
      usedSessionNonces: usedNonces,
      binFillPct: bin.fillPct,
      binAcceptingDeposits: bin.acceptsDeposits,
      binOnline: bin.isOnline,
      streakWeeks: state.profile.streakWeeks,
    );
  }

  int _nextStreak(DateTime now) {
    final weekAgo = now.subtract(const Duration(days: 7));
    final recent = state.deposits.any(
      (d) => !d.rejected && d.isClean && d.timestamp.isAfter(weekAgo),
    );
    if (!recent) return state.profile.streakWeeks + 1;
    return state.profile.streakWeeks;
  }

  // ---------------------------------------------------------------------
  // Vouchers
  // ---------------------------------------------------------------------

  /// Redeems a catalogue item for a signed, time-limited voucher.
  bool redeemVoucher(VoucherItem item) {
    if (state.profile.points < item.costPts) return false;

    final now = DateTime.now();
    final sequence = ++_voucherSequence;
    final token = _voucherService.mintVoucherToken(
      merchantCode: item.merchantCode,
      valueRm: item.valueRm,
      sequence: sequence,
    );

    final voucher = ActiveVoucher(
      id: 'VOUCH-$sequence',
      merchant: item.merchant,
      merchantCode: item.merchantCode,
      title: item.title,
      token: token,
      valueRm: item.valueRm,
      issuedAt: now,
      expiresAt: now.add(Duration(days: item.expiryDays)),
    );

    final profile = state.profile.copyWith(points: state.profile.points - item.costPts);

    final ledger = [
      PointsLedgerEntry(
        id: 'L-${now.millisecondsSinceEpoch}',
        delta: -item.costPts,
        reason: 'Redeemed ${item.title}',
        refId: voucher.id,
        balanceAfter: profile.points,
        timestamp: now,
      ),
      ...state.ledger,
    ];

    state = state.copyWith(
      profile: profile,
      myVouchers: [voucher, ...state.myVouchers],
      ledger: ledger,
    );

    final notification = _addNotification(
      title: '${item.title} issued',
      message:
          'Your voucher is active for ${item.expiryDays} days. Show the QR pass at the checkout.',
      type: 'rewards',
    );
    _persist((repo) => repo.upsertVoucher(voucher));
    _persist((repo) => repo.appendLedgerEntry(ledger.first));
    _persist((repo) => repo.saveProfile(profile));
    _persist((repo) => repo.appendNotification(notification));
    _scheduleSave();
    return true;
  }

  /// Merchant-side redemption. Validates signature, expiry, reuse and
  /// merchant match before applying the discount.
  RedemptionResult redeemVoucherToken({
    required String token,
    required String merchantCode,
  }) {
    final trimmed = token.trim();

    final known = state.myVouchers.where((v) => v.token == trimmed).toList();
    if (known.isEmpty) {
      return const RedemptionResult(outcome: RedemptionOutcome.unknownToken);
    }

    final voucher = known.first;

    if (!_voucherService.hasValidSignature(trimmed)) {
      return RedemptionResult(
        outcome: RedemptionOutcome.invalidSignature,
        voucher: voucher,
      );
    }

    if (voucher.merchantCode != merchantCode) {
      return RedemptionResult(
        outcome: RedemptionOutcome.wrongMerchant,
        voucher: voucher,
      );
    }

    if (voucher.status == VoucherStatus.used) {
      return RedemptionResult(
        outcome: RedemptionOutcome.alreadyUsed,
        voucher: voucher,
      );
    }

    if (DateTime.now().isAfter(voucher.expiresAt)) {
      return RedemptionResult(
        outcome: RedemptionOutcome.expired,
        voucher: voucher,
      );
    }

    final now = DateTime.now();
    final updated = state.myVouchers
        .map((v) => v.id == voucher.id
            ? v.copyWith(
                status: VoucherStatus.used,
                usedAt: now,
                usedBy: state.profile.unit,
              )
            : v)
        .toList();

    final record = RedemptionRecord(
      id: 'RDM-${now.millisecondsSinceEpoch.toString().substring(8)}',
      voucherId: voucher.id,
      merchant: voucher.merchant,
      merchantCode: voucher.merchantCode,
      valueRm: voucher.valueRm,
      unitId: state.profile.unit,
      token: trimmed,
      timestamp: now,
    );

    state = state.copyWith(
      myVouchers: updated,
      redemptions: [record, ...state.redemptions],
    );

    final notification = _addNotification(
      title: '${voucher.title} redeemed',
      message:
          'Discount applied at ${voucher.merchant}. ${voucher.token} is now void.',
      type: 'rewards',
    );
    final spent = updated.firstWhere((v) => v.id == voucher.id);
    _persist((repo) => repo.upsertVoucher(spent));
    _persist((repo) => repo.appendRedemption(record));
    _persist((repo) => repo.appendNotification(notification));
    _scheduleSave();

    return RedemptionResult(
      outcome: RedemptionOutcome.success,
      voucher: voucher,
      record: record,
    );
  }

  // ---------------------------------------------------------------------
  // Disputes
  // ---------------------------------------------------------------------

  /// Opens a resident-initiated dispute for a flagged deposit.
  void openDispute(String depositId, String reason) {
    final deposit = state.deposits.where((d) => d.id == depositId).firstOrNull;
    if (deposit == null) return;

    final now = DateTime.now();
    final dispute = DisputeCase(
      id: 'DSP-${now.millisecondsSinceEpoch.toString().substring(8)}',
      depositId: depositId,
      unitId: deposit.unitId.isEmpty ? state.profile.unit : deposit.unitId,
      binId: deposit.binId,
      reason: reason,
      imagePath: deposit.imagePath,
      weightKg: deposit.weightKg,
      confidence: deposit.confidence,
      withheldPoints: deposit.pointsEarned,
      createdAt: now,
    );

    state = state.copyWith(disputes: [dispute, ...state.disputes]);
    final notification = _addNotification(
      title: 'Dispute submitted',
      message:
          'Your review request for deposit $depositId is queued for the operator. The withheld points are on hold until it is resolved.',
      type: 'alert',
    );
    _persist((repo) => repo.upsertDispute(dispute));
    _persist((repo) => repo.appendNotification(notification));
    _scheduleSave();
  }

  /// Operator decision on a dispute.
  ///
  /// Upholding the dispute restores the withheld points to the resident.
  void resolveDispute(String disputeId, {required bool uphold, String note = ''}) {
    final dispute = state.disputes.where((d) => d.id == disputeId).firstOrNull;
    if (dispute == null) return;

    final now = DateTime.now();
    final resolved = dispute.copyWith(
      status: uphold ? DisputeStatus.upheld : DisputeStatus.rejected,
      resolutionNote: note.isEmpty
          ? (uphold
              ? 'Operator upheld the resident dispute — points restored.'
              : 'Operator upheld the contamination flag — points remain withheld.')
          : note,
      resolvedAt: now,
    );

    final disputes =
        state.disputes.map((d) => d.id == disputeId ? resolved : d).toList();

    var profile = state.profile;
    var ledger = state.ledger;

    if (uphold && dispute.withheldPoints > 0 &&
        dispute.unitId == state.profile.unit) {
      profile = profile.copyWith(points: profile.points + dispute.withheldPoints);
      ledger = [
        PointsLedgerEntry(
          id: 'L-${now.millisecondsSinceEpoch}',
          delta: dispute.withheldPoints,
          reason: 'Dispute upheld for deposit ${dispute.depositId}',
          refId: dispute.id,
          balanceAfter: profile.points,
          timestamp: now,
        ),
        ...ledger,
      ];
    }

    state = state.copyWith(disputes: disputes, profile: profile, ledger: ledger);

    final notification = _addNotification(
      title: uphold ? '✅ Dispute upheld' : '❌ Dispute rejected',
      message: uphold
          ? 'Your flagged deposit was reviewed and the ${dispute.withheldPoints} Green Points have been restored to your balance.'
          : 'Your flagged deposit was reviewed. The contamination flag stands and no points were awarded.',
      type: uphold ? 'rewards' : 'alert',
    );
    _persist((repo) => repo.upsertDispute(resolved));
    if (ledger.length > state.ledger.length) {
      _persist((repo) => repo.appendLedgerEntry(ledger.first));
    }
    _persist((repo) => repo.saveProfile(profile));
    _persist((repo) => repo.appendNotification(notification));
    _scheduleSave();
  }

  // ---------------------------------------------------------------------
  // Operator actions
  // ---------------------------------------------------------------------

  void completeTask(String taskId) {
    state = state.copyWith(
      tasks: state.tasks.where((t) => t.id != taskId).toList(),
    );
    _persist((repo) => repo.completeTask(taskId));
    _scheduleSave();
  }

  /// Logs compost returned to a township planter and closes the loop.
  void addCompostLog(double kg, String location, {String? batchId, String note = ''}) {
    final now = DateTime.now();
    final application = CompostApplication(
      id: 'CMP-${now.millisecondsSinceEpoch.toString().substring(8)}',
      kg: kg,
      location: location,
      batchId: batchId,
      note: note,
      timestamp: now,
    );

    state = state.copyWith(
      communityCompostCurrentKg: state.communityCompostCurrentKg + kg,
      compostApplications: [application, ...state.compostApplications],
    );

    final notification = _addNotification(
      title: '🌸 Community milestone!',
      message:
          '${kg.toStringAsFixed(0)} kg of fermented Bokashi pre-compost was returned to $location.',
      type: 'deposit',
    );
    _persist((repo) => repo.appendCompostApplication(application));
    _persist((repo) => repo.appendNotification(notification));
    _scheduleSave();
  }

  /// Seals the current bucket into a new fermentation batch.
  void sealBatch(String binId) {
    final now = DateTime.now();
    final index = state.batches.length + 1;
    final batch = BokashiBatch(
      id: 'Batch B-${index.toString().padLeft(2, '0')}',
      binSource: 'Bin $binId',
      sealedDate: now,
      readyDate: now.add(const Duration(days: 14)),
      dayCurrent: 0,
      status: 'Fermenting (Anaerobic)',
    );
    state = state.copyWith(batches: [batch, ...state.batches]);
    final notification = _addNotification(
      title: 'Bokashi batch sealed',
      message:
          '${batch.id} from Bin $binId is fermenting. Ready for garden soil incorporation in 14 days.',
      type: 'system',
    );
    _persist((repo) => repo.appendBatch(batch));
    _persist((repo) => repo.appendNotification(notification));
    _scheduleSave();
  }

  void reportProblem(String binId, String category, String notes) {
    final now = DateTime.now();
    final task = OperatorTask(
      id: 'T-${now.millisecondsSinceEpoch.toString().substring(8)}',
      binId: binId,
      title: 'Resident report: $category',
      description: notes.isEmpty
          ? 'Reported by a resident via the in-app channel.'
          : notes,
      priority: 'high',
      source: 'resident',
      createdAt: now,
    );

    state = state.copyWith(tasks: [task, ...state.tasks]);
    _persist((repo) => repo.appendTask(task));
    _scheduleSave();
  }

  // ---------------------------------------------------------------------
  // Notifications
  // ---------------------------------------------------------------------

  void markNotificationRead(String id) {
    state = state.copyWith(
      notifications: state.notifications
          .map((n) => n.id == id ? n.copyWith(isUnread: false) : n)
          .toList(),
    );
    _persist((repo) => repo.markNotificationRead(id));
    _scheduleSave();
  }

  void markAllNotificationsRead() {
    final unread = state.notifications.where((n) => n.isUnread).toList();
    state = state.copyWith(
      notifications:
          state.notifications.map((n) => n.copyWith(isUnread: false)).toList(),
    );
    for (final notification in unread) {
      _persist((repo) => repo.markNotificationRead(notification.id));
    }
    _scheduleSave();
  }

  NotificationItem _addNotification({
    required String title,
    required String message,
    required String type,
  }) {
    final now = DateTime.now();
    final item = NotificationItem(
      id: 'N-${now.millisecondsSinceEpoch}',
      title: title,
      message: message,
      type: type,
      time: now,
    );
    state = state.copyWith(notifications: [item, ...state.notifications]);
    return item;
  }

  void _addRejectedAttempt(String binId, String reason, double weightKg) {
    final now = DateTime.now();
    final attempt = RejectedAttempt(
      id: 'RA-${now.millisecondsSinceEpoch.toString().substring(8)}',
      binId: binId,
      unitId: state.profile.unit,
      reason: reason,
      weightKg: weightKg,
      timestamp: now,
    );
    state = state.copyWith(rejectedAttempts: [attempt, ...state.rejectedAttempts]);
  }

  // ---------------------------------------------------------------------
  // Persistence
  // ---------------------------------------------------------------------

  /// Debounced whole-world save. Only meaningful for snapshot backends —
  /// the Postgres backend writes row by row through [_persist].
  void _scheduleSave() {
    if (!_repository.isSnapshotBackend) return;
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 400), () {
      unawaited(_repository.saveSnapshot(_snapshotFromState()));
    });
  }

  /// Writes a single entity to the backend. Failures are swallowed so a
  /// backend problem can never break the demo.
  void _persist(Future<void> Function(AgriRepository repo) action) {
    unawaited(
      Future<void>.sync(() => action(_repository)).catchError((_) {}),
    );
  }

  /// Wipes local data and reseeds the demo world.
  Future<void> resetDemoData() async {
    await _repository.clear();
    _sequence = 2000;
    _voucherSequence = 3000;
    state = _seedState().copyWith(bootstrapped: true);
    _scheduleSave();
  }

  /// The current world as a repository snapshot.
  RepositorySnapshot _snapshotFromState() {
    final s = state;
    return RepositorySnapshot(
      profile: s.profile,
      catalog: s.catalog,
      bins: s.bins,
      deposits: s.deposits,
      myVouchers: s.myVouchers,
      tasks: s.tasks,
      batches: s.batches,
      notifications: s.notifications,
      disputes: s.disputes,
      ledger: s.ledger,
      rejectedAttempts: s.rejectedAttempts,
      redemptions: s.redemptions,
      compostApplications: s.compostApplications,
      communityCompostCurrentKg: s.communityCompostCurrentKg,
      communityCompostTargetKg: s.communityCompostTargetKg,
      onboarded: s.onboarded,
      activeRole: s.activeRole.name,
    );
  }

  /// Rebuilds the app state from a repository snapshot.
  AgriState _stateFromSnapshot(RepositorySnapshot snapshot) {
    final profile = snapshot.profile ?? state.profile;
    return AgriState(
      activeRole: UserRole.values.firstWhere(
        (r) => r.name == snapshot.activeRole,
        orElse: () => UserRole.resident,
      ),
      profile: profile,
      bins: snapshot.bins.isEmpty ? state.bins : snapshot.bins,
      deposits: snapshot.deposits,
      catalog: snapshot.catalog.isEmpty ? state.catalog : snapshot.catalog,
      myVouchers: snapshot.myVouchers,
      tasks: snapshot.tasks,
      batches: snapshot.batches,
      notifications: snapshot.notifications,
      disputes: snapshot.disputes,
      ledger: snapshot.ledger,
      rejectedAttempts: snapshot.rejectedAttempts,
      redemptions: snapshot.redemptions,
      compostApplications: snapshot.compostApplications,
      communityCompostCurrentKg: snapshot.communityCompostCurrentKg,
      communityCompostTargetKg: snapshot.communityCompostTargetKg,
      onboarded: snapshot.onboarded,
      bootstrapped: true,
    );
  }

  // ---------------------------------------------------------------------
  // Seed world
  // ---------------------------------------------------------------------

  static AgriState _seedState() {
    final now = DateTime.now();
    final rng = Random(42);

    const units = [
      ('12-03', 'Block A', 'A01'),
      ('08-02', 'Block A', 'A01'),
      ('15-11', 'Block A', 'B02'),
      ('04-01', 'Block B', 'B02'),
      ('09-07', 'Block B', 'A01'),
      ('02-05', 'Block C', 'C03'),
      ('11-04', 'Block C', 'C03'),
      ('06-12', 'Block C', 'A01'),
    ];

    // Week 1 = baseline (no Green Points), week 2 = rewards live.
    final deposits = <DepositRecord>[];
    var depositIndex = 0;

    for (var day = 13; day >= 0; day--) {
      final date = now.subtract(Duration(days: day));
      final phase = day >= 7 ? 'baseline' : 'rewarded';
      // Baseline week: lower participation and smaller loads.
      final dayCount = phase == 'baseline' ? 2 : 4;

      for (var i = 0; i < dayCount; i++) {
        final unit = units[(day * 3 + i * 5) % units.length];
        // The demo unit keeps a two-day gap so the 10-minute cooldown and the
        // daily caps are clear the moment the app is opened.
        if (unit.$1 == '12-03' && day < 2) continue;
        final weight = 0.25 + rng.nextDouble() * (phase == 'baseline' ? 0.5 : 1.1);
        final contaminated = phase == 'rewarded' && (day * 7 + i) % 11 == 0;
        final confidence = contaminated ? 0.42 + rng.nextDouble() * 0.15 : 0.88 + rng.nextDouble() * 0.1;
        final base = (weight * 100).round();
        final awarded = contaminated
            ? 0
            : phase == 'baseline'
                ? 0
                : base + (base * 0.2).round();
        final timestamp = DateTime(
          date.year,
          date.month,
          date.day,
          7 + (i * 3),
          (day * 13) % 60,
        );

        deposits.add(DepositRecord(
          id: 'DEP-S${(depositIndex++).toString().padLeft(4, '0')}',
          timestamp: timestamp,
          binId: unit.$3,
          unitId: unit.$1,
          blockId: unit.$2,
          weightKg: double.parse(weight.toStringAsFixed(2)),
          pointsEarned: awarded,
          isClean: !contaminated,
          imagePath: contaminated
              ? 'assets/images/deposit_contaminated.jpg'
              : 'assets/images/deposit_clean.jpg',
          verdict: contaminated
              ? 'Flagged: non-food items detected, points withheld.'
              : 'Clean organic waste and Bokashi bran verified.',
          sessionNonce: 'S${depositIndex.toString().padLeft(5, '0')}',
          confidence: double.parse(confidence.toStringAsFixed(2)),
          tier: contaminated
              ? CleanlinessTier.contaminated
              : CleanlinessTier.clean,
          basePoints: base,
          qualityBonus: awarded > 0 ? (base * 0.1).round() : 0,
          streakBonus: awarded > 0 ? (base * 0.1).round() : 0,
          cleanlinessMultiplier: contaminated ? 0 : 1,
          rewardLatencyMs: 900 + rng.nextInt(1400),
          phase: phase,
        ));
      }
    }

    deposits.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    final profile = UserProfile(
      nickname: 'Norah Lee',
      township: 'City of Elmina (Elmina Valley)',
      block: 'Block A',
      unit: '12-03',
      inviteCode: 'ELM-9921',
      points: 1450,
      streakWeeks: 4,
      totalKgDiverted: 18.4,
      verified: true,
      registeredAt: now.subtract(const Duration(days: 20)),
      residentPassToken: const VoucherService().mintResidentToken(
        inviteCode: 'ELM-9921',
        sequence: 1001,
      ),
    );

    const catalog = [
      VoucherItem(
        id: 'cat-jg-5',
        merchant: 'Jaya Grocer',
        merchantCode: 'JG',
        icon: '🛒',
        title: 'RM 5.00 Grocery Voucher',
        costPts: 1000,
        terms: 'Valid on fresh produce & grocery items across Sime Darby townships.',
        expiryDays: 30,
        valueRm: 5,
      ),
      VoucherItem(
        id: 'cat-zus-5',
        merchant: 'Zus Coffee',
        merchantCode: 'ZU',
        icon: '☕',
        title: 'RM 5.00 Handcrafted Beverage',
        costPts: 900,
        terms: 'Applicable in Zus Coffee app or in-store scan at the Elmina lakeside kiosk.',
        expiryDays: 14,
        valueRm: 5,
      ),
      VoucherItem(
        id: 'cat-tea-5',
        merchant: 'Tealive',
        merchantCode: 'TE',
        icon: '🧋',
        title: 'RM 5.00 Tea Voucher',
        costPts: 900,
        terms: 'Valid for handcrafted beverage or eco-reusable cup refills.',
        expiryDays: 21,
        valueRm: 5,
      ),
      VoucherItem(
        id: 'cat-vg-10',
        merchant: 'Village Grocer',
        merchantCode: 'VG',
        icon: '🥬',
        title: 'RM 10.00 Organic Produce Pass',
        costPts: 1900,
        terms: 'Valid with minimum spend RM 30 in the organic section.',
        expiryDays: 45,
        valueRm: 10,
      ),
    ];

    final issuedAt = now.subtract(const Duration(days: 2));
    final myVouchers = [
      ActiveVoucher(
        id: 'VOUCH-101',
        merchant: 'Jaya Grocer',
        merchantCode: 'JG',
        title: 'RM 5.00 Grocery Voucher',
        token: const VoucherService().mintVoucherToken(
          merchantCode: 'JG',
          valueRm: 5,
          sequence: 101,
        ),
        valueRm: 5,
        issuedAt: issuedAt,
        expiresAt: now.add(const Duration(days: 28)),
      ),
    ];

    final tasks = [
      OperatorTask(
        id: 'T-101',
        binId: 'B02',
        title: 'Swap 20L bucket & seal',
        description: 'Bucket reaches 84% fill level. Transfer to the curing bay.',
        priority: 'high',
      ),
      OperatorTask(
        id: 'T-102',
        binId: 'A01',
        title: 'Refill Bokashi microbial bran',
        description: 'Top up the hopper dispenser with fresh EM-1 bran specks.',
        priority: 'medium',
      ),
      OperatorTask(
        id: 'T-103',
        binId: 'C03',
        title: 'Drain the Bokashi tea tap',
        description:
            'Harvest concentrated liquid microbial feed for community planters.',
        priority: 'low',
      ),
    ];

    final batches = [
      BokashiBatch(
        id: 'Batch B-03',
        binSource: 'Bin A01',
        sealedDate: now.subtract(const Duration(days: 8)),
        readyDate: now.add(const Duration(days: 6)),
        dayCurrent: 8,
        status: 'Fermenting (Anaerobic)',
      ),
      BokashiBatch(
        id: 'Batch B-02',
        binSource: 'Bin B02',
        sealedDate: now.subtract(const Duration(days: 14)),
        readyDate: now,
        dayCurrent: 14,
        status: 'Ready for garden soil incorporation',
      ),
    ];

    final notifications = [
      NotificationItem(
        id: 'N-01',
        title: 'Deposit successful (+79 pts)',
        message:
            '0.72 kg organic waste diverted at Bin A01. Thank you for enriching Elmina soil!',
        type: 'deposit',
        time: now.subtract(const Duration(hours: 18)),
      ),
      NotificationItem(
        id: 'N-02',
        title: 'RM 5.00 Jaya Grocer voucher issued',
        message:
            'Your voucher is active and ready to be scanned at the cashier checkout.',
        type: 'rewards',
        time: now.subtract(const Duration(days: 2)),
      ),
    ];

    // One open dispute so the operator queue is populated on first launch.
    final seedContaminated = deposits.firstWhere(
      (d) => !d.isClean,
      orElse: () => deposits.first,
    );
    final disputes = [
      DisputeCase(
        id: 'DSP-9001',
        depositId: seedContaminated.id,
        unitId: seedContaminated.unitId,
        binId: seedContaminated.binId,
        reason: 'Vision model detected a plastic bag and takeout cutlery in the deposit.',
        imagePath: seedContaminated.imagePath,
        weightKg: seedContaminated.weightKg,
        confidence: seedContaminated.confidence,
        withheldPoints: seedContaminated.basePoints,
        createdAt: seedContaminated.timestamp,
      ),
    ];

    final compostApplications = [
      CompostApplication(
        id: 'CMP-8801',
        kg: 25,
        location: 'Central Community Planter #3',
        batchId: 'Batch B-02',
        note: 'Pre-compost buried, 2 week cure complete.',
        timestamp: now.subtract(const Duration(days: 3)),
      ),
      CompostApplication(
        id: 'CMP-8794',
        kg: 18,
        location: 'Elmina Valley North Herbal Garden',
        batchId: 'Batch B-01',
        timestamp: now.subtract(const Duration(days: 11)),
      ),
    ];

    return AgriState(
      activeRole: UserRole.resident,
      profile: profile,
      bins: const [
        SmartBin(
          id: 'A01',
          name: 'Bin A01 · Ground Foyer',
          location: 'Elmina Green Central',
          status: 'available',
          weightG: 8420,
          fillPct: 42,
          tempC: 31.2,
          humidityPct: 64,
          rssi: -61,
          lockState: 'locked',
        ),
        SmartBin(
          id: 'B02',
          name: 'Bin B02 · Central Park Walkway',
          location: 'Central Park West',
          status: 'available',
          weightG: 16800,
          fillPct: 84,
          tempC: 32.5,
          humidityPct: 68,
          rssi: -69,
          lockState: 'locked',
        ),
        SmartBin(
          id: 'C03',
          name: 'Bin C03 · Clubhouse Deck',
          location: 'Clubhouse & Nursery',
          status: 'available',
          weightG: 6200,
          fillPct: 31,
          tempC: 29.8,
          humidityPct: 61,
          rssi: -58,
          lockState: 'locked',
        ),
      ],
      deposits: deposits,
      catalog: catalog,
      myVouchers: myVouchers,
      tasks: tasks,
      batches: batches,
      notifications: notifications,
      disputes: disputes,
      ledger: [
        PointsLedgerEntry(
          id: 'L-900',
          delta: 79,
          reason: 'Deposit 0.72 kg at Bin A01',
          refId: 'DEP-8841',
          balanceAfter: 1450,
          timestamp: now.subtract(const Duration(hours: 18)),
        ),
        PointsLedgerEntry(
          id: 'L-880',
          delta: -1000,
          reason: 'Redeemed RM 5.00 Grocery Voucher',
          refId: 'VOUCH-101',
          balanceAfter: 1371,
          timestamp: now.subtract(const Duration(days: 2)),
        ),
      ],
      rejectedAttempts: [
        RejectedAttempt(
          id: 'RA-7701',
          binId: 'B02',
          unitId: '09-07',
          reason: 'Cooldown active on this bin — one deposit per 10 minutes.',
          weightKg: 0.42,
          timestamp: now.subtract(const Duration(days: 1, hours: 2)),
        ),
      ],
      redemptions: const [],
      compostApplications: compostApplications,
      communityCompostCurrentKg: 62.0,
      communityCompostTargetKg: 100.0,
      onboarded: AppConfig.seedDemoHistory,
      bootstrapped: false,
    );
  }
}

final agriStateProvider =
    StateNotifierProvider<AgriStateNotifier, AgriState>((ref) {
  return AgriStateNotifier();
});

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
