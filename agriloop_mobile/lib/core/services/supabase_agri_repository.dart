import 'package:supabase/supabase.dart';

import '../../models/all_models.dart';
import '../rules/scoring_rules.dart';
import '../utils/enum_lookups.dart';
import 'agri_repository.dart';

/// Postgres-backed implementation of [AgriRepository].
///
/// Every write lands in a real table, so the operator dashboard, the
/// leaderboard and the pilot metrics are all queryable in SQL. The
/// anti-gaming policy is additionally enforced by the `submit_deposit()`
/// function, so a tampered client cannot award itself points.
class SupabaseAgriRepository implements AgriRepository {
  SupabaseAgriRepository({required SupabaseClient client})
      : _client = client;

  final SupabaseClient _client;

  /// Bin uuid → bin code, so rows can be mapped back to the app's model.
  final Map<String, String> _binCodes = {};

  @override
  String get name => 'supabase';

  @override
  bool get isSnapshotBackend => false;

  @override
  Future<void> saveSnapshot(RepositorySnapshot snapshot) async {
    // The Postgres backend writes row by row; there is no whole-world blob.
    if (snapshot.profile != null) await saveProfile(snapshot.profile!);
  }

  SupabaseClient get client => _client;

  // -------------------------------------------------------------------
  // Read
  // -------------------------------------------------------------------

  @override
  Future<RepositorySnapshot?> load() async {
    try {
      final r = await Future.wait([
        _client.from('blocks').select('id, code, name, township_id').order('code', ascending: true),
        _client.from('units').select('id, unit_number, invite_code, block_id').order('unit_number', ascending: true),
        // The earliest registered resident is the demo account the app signs
        // in as. A production build would resolve this from Supabase Auth.
        _client.from('residents').select('*').order('created_at', ascending: true),
        _client.from('bins').select('*').order('code', ascending: true),
        _client.from('deposits').select('*').order('created_at', ascending: false),
        _client.from('point_ledger').select('*').order('created_at', ascending: false),
        _client.from('voucher_catalogue').select('*').eq('active', true).order('code', ascending: true),
        _client.from('vouchers').select('*').order('issued_at', ascending: false),
        _client.from('redemptions').select('*').order('created_at', ascending: false),
        _client.from('disputes').select('*').order('created_at', ascending: false),
        _client.from('rejected_attempts').select('*').order('created_at', ascending: false),
        _client.from('notifications').select('*').order('created_at', ascending: false),
        _client.from('operator_tasks').select('*').order('created_at', ascending: false),
        _client.from('bokashi_batches').select('*').order('sealed_date', ascending: false),
        _client.from('compost_applications').select('*').order('created_at', ascending: false),
        _client.from('community_targets').select('*').eq('id', true),
        _client.from('townships').select('*'),
      ]);

      final blocks = _rows(r[0]);
      final units = _rows(r[1]);
      final residents = _rows(r[2]);
      final binRows = _rows(r[3]);
      final depositRows = _rows(r[4]);
      final ledgerRows = _rows(r[5]);
      final catalogueRows = _rows(r[6]);
      final voucherRows = _rows(r[7]);
      final redemptionRows = _rows(r[8]);
      final disputeRows = _rows(r[9]);
      final rejectedRows = _rows(r[10]);
      final notificationRows = _rows(r[11]);
      final taskRows = _rows(r[12]);
      final batchRows = _rows(r[13]);
      final compostRows = _rows(r[14]);
      final targetRows = _rows(r[15]);
      final townshipRows = _rows(r[16]);

      if (residents.isEmpty) return null;

      final blockById = {for (final b in blocks) b['id'] as String: b};
      final unitById = {for (final u in units) u['id'] as String: u};
      for (final b in binRows) {
        _binCodes[b['id'] as String] = b['code'] as String;
      }

      // --- profile ------------------------------------------------------
      final resident = residents.first;
      final residentUnit = unitById[resident['unit_id'] as String?];
      final residentBlock = residentUnit == null
          ? null
          : blockById[residentUnit['block_id'] as String?];

      final profile = UserProfile(
        nickname: resident['nickname'] as String,
        township: (townshipRows.isNotEmpty
                ? townshipRows.first['name'] as String
                : 'City of Elmina (Elmina Valley)'),
        block: (residentBlock?['code'] as String?) ?? 'Block A',
        unit: (residentUnit?['unit_number'] as String?) ?? '12-03',
        inviteCode: resident['invite_code'] as String,
        points: resident['points_balance'] as int,
        streakWeeks: resident['streak_weeks'] as int,
        totalKgDiverted:
            double.parse((resident['total_kg_diverted'] as num).toString()),
        co2AvoidedFactor:
            double.parse((resident['co2_factor'] as num).toString()),
        verified: resident['verified'] as bool,
        registeredAt: resident['registered_at'] == null
            ? null
            : DateTime.parse(resident['registered_at'] as String),
        residentPassToken: (resident['resident_pass_token'] as String?) ?? '',
      );

      // --- deposits -----------------------------------------------------
      final deposits = <DepositRecord>[];
      for (final row in depositRows) {
        final unit = unitById[row['unit_id'] as String?];
        final block = unit == null ? null : blockById[unit['block_id'] as String?];
        deposits.add(DepositRecord(
          id: (row['external_id'] as String?) ?? row['id'] as String,
          timestamp: DateTime.parse(row['created_at'] as String),
          binId: _binCode(row['bin_id'] as String?),
          unitId: (unit?['unit_number'] as String?) ?? '',
          blockId: (block?['code'] as String?) ?? '',
          weightKg: double.parse((row['weight_kg'] as num).toString()),
          pointsEarned: row['points_awarded'] as int,
          isClean: row['is_clean'] as bool,
          imagePath: (row['image_path'] as String?) ?? '',
          verdict: (row['verdict'] as String?) ?? '',
          sessionNonce: row['session_nonce'] as String?,
          confidence: double.parse((row['confidence'] as num).toString()),
          tier: cleanlinessTierByName(row['tier'] as String?),
          basePoints: row['base_points'] as int? ?? 0,
          qualityBonus: row['quality_bonus'] as int? ?? 0,
          streakBonus: row['streak_bonus'] as int? ?? 0,
          cleanlinessMultiplier: double.parse(
              (row['cleanliness_multiplier'] as num?)?.toString() ?? '1'),
          rewardLatencyMs: row['reward_latency_ms'] as int? ?? 0,
          violations: (row['violations'] as List<dynamic>? ?? [])
              .map((v) => ruleViolationByName(v.toString()))
              .whereType<RuleViolation>()
              .toList(),
          phase: (row['phase'] as String?) ?? 'rewarded',
        ));
      }

      // --- vouchers -----------------------------------------------------
      final vouchers = <ActiveVoucher>[];
      for (final row in voucherRows) {
        vouchers.add(ActiveVoucher(
          id: (row['external_id'] as String?) ?? row['id'] as String,
          merchant: row['merchant'] as String,
          merchantCode: row['merchant_code'] as String,
          title: row['title'] as String,
          token: row['token'] as String,
          valueRm: double.parse((row['value_rm'] as num).toString()),
          issuedAt: DateTime.parse(row['issued_at'] as String),
          expiresAt: DateTime.parse(row['expires_at'] as String),
          status: voucherStatusByName(row['status'] as String?),
          usedAt: row['used_at'] == null
              ? null
              : DateTime.parse(row['used_at'] as String),
        ));
      }

      // --- disputes -----------------------------------------------------
      final disputes = <DisputeCase>[];
      for (final row in disputeRows) {
        final unit = unitById[row['unit_id'] as String?];
        disputes.add(DisputeCase(
          id: (row['external_id'] as String?) ?? row['id'] as String,
          depositId: row['deposit_id'] as String? ?? '',
          unitId: (unit?['unit_number'] as String?) ?? '',
          binId: _binCode(row['bin_id'] as String?),
          reason: row['reason'] as String,
          imagePath: (row['image_path'] as String?) ?? '',
          weightKg: double.parse((row['weight_kg'] as num?)?.toString() ?? '0'),
          confidence: double.parse((row['confidence'] as num?)?.toString() ?? '0'),
          withheldPoints: row['withheld_points'] as int? ?? 0,
          status: disputeStatusByName(row['status'] as String?),
          resolutionNote: row['resolution_note'] as String?,
          createdAt: DateTime.parse(row['created_at'] as String),
          resolvedAt: row['resolved_at'] == null
              ? null
              : DateTime.parse(row['resolved_at'] as String),
        ));
      }

      // --- ledger -------------------------------------------------------
      final ledger = <PointsLedgerEntry>[];
      for (final row in ledgerRows) {
        ledger.add(PointsLedgerEntry(
          id: (row['external_id'] as String?) ?? row['id'] as String,
          delta: row['delta'] as int,
          reason: row['reason'] as String,
          refId: row['ref_id'] as String?,
          balanceAfter: row['balance_after'] as int,
          timestamp: DateTime.parse(row['created_at'] as String),
        ));
      }

      // --- rejected attempts ----------------------------------------------
      final rejected = <RejectedAttempt>[];
      for (final row in rejectedRows) {
        final unit = unitById[row['unit_id'] as String?];
        rejected.add(RejectedAttempt(
          id: (row['external_id'] as String?) ?? row['id'] as String,
          binId: _binCode(row['bin_id'] as String?),
          unitId: (unit?['unit_number'] as String?) ?? '',
          reason: row['reason'] as String,
          weightKg: double.parse((row['weight_kg'] as num?)?.toString() ?? '0'),
          timestamp: DateTime.parse(row['created_at'] as String),
        ));
      }

      // --- notifications ------------------------------------------------
      final notifications = <NotificationItem>[];
      for (final row in notificationRows) {
        notifications.add(NotificationItem(
          id: (row['external_id'] as String?) ?? row['id'] as String,
          title: row['title'] as String,
          message: (row['message'] as String?) ?? '',
          type: (row['type'] as String?) ?? 'system',
          time: DateTime.parse(row['created_at'] as String),
          isUnread: !(row['is_read'] as bool? ?? false),
        ));
      }

      // --- redemptions --------------------------------------------------
      final redemptions = <RedemptionRecord>[];
      for (final row in redemptionRows) {
        final unit = unitById[row['unit_id'] as String?];
        redemptions.add(RedemptionRecord(
          id: (row['external_id'] as String?) ?? row['id'] as String,
          voucherId: row['voucher_id'] as String? ?? '',
          merchant: row['merchant_code'] as String,
          merchantCode: row['merchant_code'] as String,
          valueRm: double.parse((row['value_rm'] as num).toString()),
          unitId: (unit?['unit_number'] as String?) ?? '',
          token: row['token'] as String,
          timestamp: DateTime.parse(row['created_at'] as String),
        ));
      }

      // --- compost ------------------------------------------------------
      final compost = <CompostApplication>[];
      for (final row in compostRows) {
        compost.add(CompostApplication(
          id: (row['external_id'] as String?) ?? row['id'] as String,
          kg: double.parse((row['kg'] as num).toString()),
          location: row['location'] as String,
          batchId: row['batch_id'] as String?,
          note: (row['note'] as String?) ?? '',
          timestamp: DateTime.parse(row['created_at'] as String),
        ));
      }

      // --- tasks --------------------------------------------------------
      final tasks = <OperatorTask>[];
      for (final row in taskRows) {
        tasks.add(OperatorTask(
          id: (row['external_id'] as String?) ?? row['id'] as String,
          binId: _binCode(row['bin_id'] as String?),
          title: row['title'] as String,
          description: (row['description'] as String?) ?? '',
          priority: (row['priority'] as String?) ?? 'medium',
          isCompleted: row['is_completed'] as bool? ?? false,
          source: (row['source'] as String?) ?? 'system',
          createdAt: DateTime.parse(row['created_at'] as String),
        ));
      }

      // --- batches ------------------------------------------------------
      final batches = <BokashiBatch>[];
      for (final row in batchRows) {
        batches.add(BokashiBatch(
          id: (row['external_id'] as String?) ?? row['id'] as String,
          binSource: row['bin_source'] as String,
          sealedDate: DateTime.parse(row['sealed_date'] as String),
          readyDate: DateTime.parse(row['ready_date'] as String),
          dayCurrent: row['day_current'] as int? ?? 0,
          dayTotal: row['day_total'] as int? ?? 14,
          status: (row['status'] as String?) ?? 'Fermenting (Anaerobic)',
        ));
      }

      // --- bins ---------------------------------------------------------
      final bins = <SmartBin>[];
      for (final row in binRows) {
        bins.add(SmartBin(
          id: row['code'] as String,
          name: row['name'] as String,
          location: row['location'] as String,
          status: row['status'] as String,
          weightG: row['weight_g'] as int,
          fillPct: row['fill_pct'] as int,
          tempC: double.parse((row['temp_c'] as num).toString()),
          humidityPct: row['humidity_pct'] as int,
          rssi: row['rssi'] as int,
          lockState: (row['lock_state'] as String?) ?? 'locked',
          lastSeen: row['last_seen'] == null
              ? null
              : DateTime.parse(row['last_seen'] as String),
        ));
      }

      // --- catalogue ----------------------------------------------------
      final catalog = <VoucherItem>[];
      for (final row in catalogueRows) {
        catalog.add(VoucherItem(
          id: row['code'] as String,
          merchant: row['merchant'] as String,
          merchantCode: row['merchant_code'] as String,
          title: row['title'] as String,
          terms: (row['terms'] as String?) ?? '',
          costPts: row['cost_points'] as int,
          expiryDays: row['expiry_days'] as int? ?? 30,
          icon: (row['icon'] as String?) ?? '🎟️',
          valueRm: double.parse((row['value_rm'] as num).toString()),
        ));
      }

      final targetRow = targetRows.isEmpty ? null : targetRows.first;

      return RepositorySnapshot(
        profile: profile,
        catalog: catalog,
        bins: bins,
        deposits: deposits,
        myVouchers: vouchers,
        tasks: tasks,
        batches: batches,
        notifications: notifications,
        disputes: disputes,
        ledger: ledger,
        rejectedAttempts: rejected,
        redemptions: redemptions,
        compostApplications: compost,
        communityCompostCurrentKg:
            double.parse((targetRow?['current_kg'] as num?)?.toString() ?? '0'),
        communityCompostTargetKg:
            double.parse((targetRow?['target_kg'] as num?)?.toString() ?? '100'),
        onboarded: true,
      );
    } catch (_) {
      // Never let a backend problem stop the app from opening.
      return null;
    }
  }

  // -------------------------------------------------------------------
  // Write
  // -------------------------------------------------------------------

  @override
  Future<void> saveProfile(UserProfile profile) async {
    await _client.from('residents').upsert({
      'invite_code': profile.inviteCode,
      'nickname': profile.nickname,
      'resident_pass_token': profile.residentPassToken,
      'points_balance': profile.points,
      'streak_weeks': profile.streakWeeks,
      'total_kg_diverted': profile.totalKgDiverted,
      'co2_factor': profile.co2AvoidedFactor,
      'verified': profile.verified,
      'registered_at':
          (profile.registeredAt ?? DateTime.now()).toIso8601String(),
    }, onConflict: 'invite_code');
  }

  @override
  Future<void> saveBin(SmartBin bin) async {
    await _client.from('bins').upsert({
      'code': bin.id,
      'name': bin.name,
      'location': bin.location,
      'status': bin.status,
      'weight_g': bin.weightG,
      'fill_pct': bin.fillPct,
      'temp_c': bin.tempC,
      'humidity_pct': bin.humidityPct,
      'rssi': bin.rssi,
      'lock_state': bin.lockState,
      'last_seen': (bin.lastSeen ?? DateTime.now()).toIso8601String(),
    }, onConflict: 'code');
  }

  @override
  Future<void> appendDeposit(DepositRecord deposit) async {
    await _client.from('deposits').insert({
      'external_id': deposit.id,
      'unit_id': await _unitIdFor(deposit.unitId),
      'weight_kg': deposit.weightKg,
      'points_awarded': deposit.pointsEarned,
      'is_clean': deposit.isClean,
      'tier': deposit.tier.name,
      'confidence': deposit.confidence,
      'base_points': deposit.basePoints,
      'quality_bonus': deposit.qualityBonus,
      'streak_bonus': deposit.streakBonus,
      'cleanliness_multiplier': deposit.cleanlinessMultiplier,
      'reward_latency_ms': deposit.rewardLatencyMs,
      'session_nonce': deposit.sessionNonce,
      'phase': deposit.phase,
      'image_path': deposit.imagePath,
      'verdict': deposit.verdict,
      'violations': deposit.violations.map((v) => v.name).toList(),
      'created_at': deposit.timestamp.toIso8601String(),
    });
  }

  @override
  Future<void> appendLedgerEntry(PointsLedgerEntry entry) async {
    await _client.from('point_ledger').insert({
      'external_id': entry.id,
      'delta': entry.delta,
      'reason': entry.reason,
      'ref_id': entry.refId,
      'balance_after': entry.balanceAfter,
      'created_at': entry.timestamp.toIso8601String(),
    });
  }

  @override
  Future<void> upsertVoucher(ActiveVoucher voucher) async {
    await _client.from('vouchers').upsert({
      'external_id': voucher.id,
      'merchant': voucher.merchant,
      'merchant_code': voucher.merchantCode,
      'title': voucher.title,
      'value_rm': voucher.valueRm,
      'token': voucher.token,
      'status': voucher.status.name,
      'issued_at': voucher.issuedAt.toIso8601String(),
      'expires_at': voucher.expiresAt.toIso8601String(),
      'used_at': voucher.usedAt?.toIso8601String(),
    }, onConflict: 'token');
  }

  @override
  Future<void> appendRedemption(RedemptionRecord record) async {
    await _client.from('redemptions').insert({
      'external_id': record.id,
      'merchant_code': record.merchantCode,
      'value_rm': record.valueRm,
      'unit_id': await _unitIdFor(record.unitId),
      'token': record.token,
      'created_at': record.timestamp.toIso8601String(),
    });
  }

  @override
  Future<void> upsertDispute(DisputeCase dispute) async {
    await _client.from('disputes').upsert({
      'external_id': dispute.id,
      'reason': dispute.reason,
      'image_path': dispute.imagePath,
      'weight_kg': dispute.weightKg,
      'confidence': dispute.confidence,
      'withheld_points': dispute.withheldPoints,
      'status': dispute.status.name,
      'resolution_note': dispute.resolutionNote,
      'created_at': dispute.createdAt.toIso8601String(),
      'resolved_at': dispute.resolvedAt?.toIso8601String(),
    }, onConflict: 'external_id');
  }

  @override
  Future<void> appendRejectedAttempt({
    required String binId,
    required String unitId,
    required String reason,
    required double weightKg,
  }) async {
    await _client.from('rejected_attempts').insert({
      'bin_id': await _binIdFor(binId),
      'unit_id': await _unitIdFor(unitId),
      'reason': reason,
      'weight_kg': weightKg,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  @override
  Future<void> appendNotification(NotificationItem notification) async {
    await _client.from('notifications').insert({
      'external_id': notification.id,
      'title': notification.title,
      'message': notification.message,
      'type': notification.type,
      'is_read': !notification.isUnread,
      'created_at': notification.time.toIso8601String(),
    });
  }

  @override
  Future<void> markNotificationRead(String id) async {
    await _client
        .from('notifications')
        .update({'is_read': true})
        .eq('external_id', id);
  }

  @override
  Future<void> appendTask(OperatorTask task) async {
    await _client.from('operator_tasks').insert({
      'external_id': task.id,
      'bin_id': await _binIdFor(task.binId),
      'title': task.title,
      'description': task.description,
      'priority': task.priority,
      'source': task.source,
      'created_at': task.createdAt.toIso8601String(),
    });
  }

  @override
  Future<void> completeTask(String id) async {
    await _client
        .from('operator_tasks')
        .update({'is_completed': true})
        .eq('external_id', id);
  }

  @override
  Future<void> appendCompostApplication(CompostApplication application) async {
    await _client.from('compost_applications').insert({
      'external_id': application.id,
      'kg': application.kg,
      'location': application.location,
      'note': application.note,
      'created_at': application.timestamp.toIso8601String(),
    });
  }

  @override
  Future<void> appendBatch(BokashiBatch batch) async {
    await _client.from('bokashi_batches').insert({
      'external_id': batch.id,
      'bin_id': await _binIdFor(batch.binSource.replaceFirst('Bin ', '')),
      'bin_source': batch.binSource,
      'sealed_date': batch.sealedDate.toIso8601String(),
      'ready_date': batch.readyDate.toIso8601String(),
      'day_current': batch.dayCurrent,
      'day_total': batch.dayTotal,
      'status': batch.status,
    });
  }

  @override
  Future<void> clear() async {
    for (final table in const [
      'notifications',
      'operator_tasks',
      'compost_applications',
      'bokashi_batches',
      'redemptions',
      'vouchers',
      'rejected_attempts',
      'disputes',
      'point_ledger',
      'deposits',
    ]) {
      await _client.from(table).delete().neq(
            'id',
            '00000000-0000-0000-0000-000000000000',
          );
    }
  }

  // -------------------------------------------------------------------
  // Helpers
  // -------------------------------------------------------------------

  List<Map<String, dynamic>> _rows(List<dynamic> data) => data
      .cast<Map<String, dynamic>>()
      .map((e) => Map<String, dynamic>.from(e))
      .toList();

  Future<String?> _unitIdFor(String unitNumber) async {
    if (unitNumber.isEmpty) return null;
    final result = await _client
        .from('units')
        .select('id')
        .eq('unit_number', unitNumber)
        .limit(1);
    if (result.isEmpty) return null;
    return result.first['id'] as String;
  }

  Future<String?> _binIdFor(String code) async {
    if (code.isEmpty) return null;
    final result =
        await _client.from('bins').select('id').eq('code', code).limit(1);
    if (result.isEmpty) return null;
    return result.first['id'] as String;
  }

  String _binCode(String? id) {
    if (id == null || id.isEmpty) return '';
    return _binCodes[id] ?? id;
  }
}
