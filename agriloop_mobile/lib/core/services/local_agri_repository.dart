import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../models/all_models.dart';
import 'agri_repository.dart';

/// On-device implementation of [AgriRepository].
///
/// Keeps a single versioned JSON snapshot in shared preferences so the demo
/// survives a reload or a crash. This is the default when no Supabase
/// credentials are supplied.
class LocalAgriRepository implements AgriRepository {
  LocalAgriRepository({SharedPreferences? preferences})
      : _preferences = preferences;

  static const String _key = 'agriloop_state_v1';
  static const int schemaVersion = 1;

  SharedPreferences? _preferences;

  RepositorySnapshot? _cached;

  @override
  String get name => 'local';

  @override
  bool get isSnapshotBackend => true;

  Future<SharedPreferences> get _prefs async =>
      _preferences ??= await SharedPreferences.getInstance();

  @override
  Future<RepositorySnapshot?> load() async {
    if (_cached != null) return _cached;
    try {
      final prefs = await _prefs;
      final raw = prefs.getString(_key);
      if (raw == null || raw.isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      final version = decoded['schemaVersion'];
      if (version is! int || version > schemaVersion) return null;
      _cached = _snapshotFromJson(decoded);
      return _cached;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> saveSnapshot(RepositorySnapshot snapshot) => _persist(snapshot);

  @override
  Future<void> saveProfile(UserProfile profile) async {
    final snapshot = await load() ?? const RepositorySnapshot();
    await _persist(snapshot.copyWith(profile: profile));
  }

  @override
  Future<void> saveBin(SmartBin bin) async {
    final snapshot = await load() ?? const RepositorySnapshot();
    final bins = [...snapshot.bins];
    final index = bins.indexWhere((b) => b.id == bin.id);
    if (index >= 0) {
      bins[index] = bin;
    } else {
      bins.add(bin);
    }
    await _persist(snapshot.copyWith(bins: bins));
  }

  @override
  Future<void> appendDeposit(DepositRecord deposit) async {
    final snapshot = await load() ?? const RepositorySnapshot();
    await _persist(snapshot.copyWith(
      deposits: [deposit, ...snapshot.deposits],
    ));
  }

  @override
  Future<void> appendLedgerEntry(PointsLedgerEntry entry) async {
    final snapshot = await load() ?? const RepositorySnapshot();
    await _persist(snapshot.copyWith(ledger: [entry, ...snapshot.ledger]));
  }

  @override
  Future<void> upsertVoucher(ActiveVoucher voucher) async {
    final snapshot = await load() ?? const RepositorySnapshot();
    final vouchers = [...snapshot.myVouchers];
    final index = vouchers.indexWhere((v) => v.id == voucher.id);
    if (index >= 0) {
      vouchers[index] = voucher;
    } else {
      vouchers.insert(0, voucher);
    }
    await _persist(snapshot.copyWith(myVouchers: vouchers));
  }

  @override
  Future<void> appendRedemption(RedemptionRecord record) async {
    final snapshot = await load() ?? const RepositorySnapshot();
    await _persist(snapshot.copyWith(redemptions: [record, ...snapshot.redemptions]));
  }

  @override
  Future<void> upsertDispute(DisputeCase dispute) async {
    final snapshot = await load() ?? const RepositorySnapshot();
    final disputes = [...snapshot.disputes];
    final index = disputes.indexWhere((d) => d.id == dispute.id);
    if (index >= 0) {
      disputes[index] = dispute;
    } else {
      disputes.insert(0, dispute);
    }
    await _persist(snapshot.copyWith(disputes: disputes));
  }

  @override
  Future<void> appendRejectedAttempt({
    required String binId,
    required String unitId,
    required String reason,
    required double weightKg,
  }) async {
    final snapshot = await load() ?? const RepositorySnapshot();
    final attempt = RejectedAttempt(
      id: 'RA-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}',
      binId: binId,
      unitId: unitId,
      reason: reason,
      weightKg: weightKg,
      timestamp: DateTime.now(),
    );
    await _persist(snapshot.copyWith(
      rejectedAttempts: [attempt, ...snapshot.rejectedAttempts],
    ));
  }

  @override
  Future<void> appendNotification(NotificationItem notification) async {
    final snapshot = await load() ?? const RepositorySnapshot();
    await _persist(snapshot.copyWith(
      notifications: [notification, ...snapshot.notifications],
    ));
  }

  @override
  Future<void> markNotificationRead(String id) async {
    final snapshot = await load() ?? const RepositorySnapshot();
    await _persist(snapshot.copyWith(
      notifications: snapshot.notifications
          .map((n) => n.id == id ? n.copyWith(isUnread: false) : n)
          .toList(),
    ));
  }

  @override
  Future<void> appendTask(OperatorTask task) async {
    final snapshot = await load() ?? const RepositorySnapshot();
    await _persist(snapshot.copyWith(tasks: [task, ...snapshot.tasks]));
  }

  @override
  Future<void> completeTask(String id) async {
    final snapshot = await load() ?? const RepositorySnapshot();
    await _persist(snapshot.copyWith(
      tasks: snapshot.tasks.where((t) => t.id != id).toList(),
    ));
  }

  @override
  Future<void> appendCompostApplication(CompostApplication application) async {
    final snapshot = await load() ?? const RepositorySnapshot();
    await _persist(snapshot.copyWith(
      compostApplications: [
        application,
        ...snapshot.compostApplications,
      ],
      communityCompostCurrentKg:
          snapshot.communityCompostCurrentKg + application.kg,
    ));
  }

  @override
  Future<void> appendBatch(BokashiBatch batch) async {
    final snapshot = await load() ?? const RepositorySnapshot();
    await _persist(snapshot.copyWith(batches: [batch, ...snapshot.batches]));
  }

  @override
  Future<void> clear() async {
    _cached = null;
    try {
      final prefs = await _prefs;
      await prefs.remove(_key);
    } catch (_) {
      // Ignore — the in-memory cache is already cleared.
    }
  }

  Future<void> _persist(RepositorySnapshot snapshot) async {
    _cached = snapshot;
    try {
      final prefs = await _prefs;
      await prefs.setString(_key, jsonEncode({
        'schemaVersion': schemaVersion,
        ...snapshot.toJson(),
      }));
    } catch (_) {
      // Persistence must never break the demo.
    }
  }

  static RepositorySnapshot _snapshotFromJson(Map<String, dynamic> json) {
    List<T> parse<T>(String key, T Function(Map<String, dynamic>) build) {
      final raw = json[key] as List<dynamic>? ?? [];
      return raw
          .map((e) => build(Map<String, dynamic>.from(e as Map)))
          .toList();
    }

    return RepositorySnapshot(
      profile: json['profile'] == null
          ? null
          : UserProfile.fromJson(Map<String, dynamic>.from(json['profile'] as Map)),
      catalog: parse('catalog', VoucherItem.fromJson),
      bins: parse('bins', SmartBin.fromJson),
      deposits: parse('deposits', DepositRecord.fromJson),
      myVouchers: parse('myVouchers', ActiveVoucher.fromJson),
      tasks: parse('tasks', OperatorTask.fromJson),
      batches: parse('batches', BokashiBatch.fromJson),
      notifications: parse('notifications', NotificationItem.fromJson),
      disputes: parse('disputes', DisputeCase.fromJson),
      ledger: parse('ledger', PointsLedgerEntry.fromJson),
      rejectedAttempts: parse('rejectedAttempts', RejectedAttempt.fromJson),
      redemptions: parse('redemptions', RedemptionRecord.fromJson),
      compostApplications:
          parse('compostApplications', CompostApplication.fromJson),
      communityCompostCurrentKg:
          (json['communityCompostCurrentKg'] as num?)?.toDouble() ?? 62.0,
      communityCompostTargetKg:
          (json['communityCompostTargetKg'] as num?)?.toDouble() ?? 100.0,
      onboarded: json['onboarded'] as bool? ?? false,
      activeRole: json['activeRole'] as String? ?? 'resident',
    );
  }
}
