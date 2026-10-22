import 'package:supabase/supabase.dart';

import '../config/app_config.dart';
import '../../models/all_models.dart';
import 'local_agri_repository.dart';
import 'supabase_agri_repository.dart';

/// A hydrated slice of the world, used to rebuild the app state on boot.
class RepositorySnapshot {
  final UserProfile? profile;
  final List<VoucherItem> catalog;
  final List<SmartBin> bins;
  final List<DepositRecord> deposits;
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
  final String activeRole;

  const RepositorySnapshot({
    this.activeRole = 'resident',
    this.profile,
    this.catalog = const [],
    this.bins = const [],
    this.deposits = const [],
    this.myVouchers = const [],
    this.tasks = const [],
    this.batches = const [],
    this.notifications = const [],
    this.disputes = const [],
    this.ledger = const [],
    this.rejectedAttempts = const [],
    this.redemptions = const [],
    this.compostApplications = const [],
    this.communityCompostCurrentKg = 62.0,
    this.communityCompostTargetKg = 100.0,
    this.onboarded = false,
  });

  bool get isEmpty =>
      profile == null && bins.isEmpty && deposits.isEmpty && myVouchers.isEmpty;

  RepositorySnapshot copyWith({
    UserProfile? profile,
    List<VoucherItem>? catalog,
    List<SmartBin>? bins,
    List<DepositRecord>? deposits,
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
    String? activeRole,
  }) {
    return RepositorySnapshot(
      profile: profile ?? this.profile,
      catalog: catalog ?? this.catalog,
      bins: bins ?? this.bins,
      deposits: deposits ?? this.deposits,
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
      activeRole: activeRole ?? this.activeRole,
    );
  }

  Map<String, dynamic> toJson() => {
        'profile': profile?.toJson(),
        'catalog': catalog.map((c) => c.toJson()).toList(),
        'bins': bins.map((b) => b.toJson()).toList(),
        'deposits': deposits.map((d) => d.toJson()).toList(),
        'myVouchers': myVouchers.map((v) => v.toJson()).toList(),
        'tasks': tasks.map((t) => t.toJson()).toList(),
        'batches': batches.map((b) => b.toJson()).toList(),
        'notifications': notifications.map((n) => n.toJson()).toList(),
        'disputes': disputes.map((d) => d.toJson()).toList(),
        'ledger': ledger.map((e) => e.toJson()).toList(),
        'rejectedAttempts':
            rejectedAttempts.map((a) => a.toJson()).toList(),
        'redemptions': redemptions.map((r) => r.toJson()).toList(),
        'compostApplications':
            compostApplications.map((c) => c.toJson()).toList(),
        'communityCompostCurrentKg': communityCompostCurrentKg,
        'communityCompostTargetKg': communityCompostTargetKg,
        'onboarded': onboarded,
        'activeRole': activeRole,
      };
}

/// Storage boundary for the app's state.
///
/// The demo runs against a local snapshot; point the app at Supabase and the
/// same operations are executed against Postgres instead. The UI never knows
/// which one is in use.
abstract class AgriRepository {
  /// Human-readable name of the backing store, shown in the operator UI.
  String get name;

  /// True when the backend stores the whole world in one document (the local
  /// snapshot) rather than as individual rows.
  bool get isSnapshotBackend;

  /// Restores the world at boot. Returns null when there is nothing stored.
  Future<RepositorySnapshot?> load();

  /// Persists the whole world in one go. Only used by snapshot backends.
  Future<void> saveSnapshot(RepositorySnapshot snapshot);

  Future<void> saveProfile(UserProfile profile);
  Future<void> saveBin(SmartBin bin);
  Future<void> appendDeposit(DepositRecord deposit);
  Future<void> appendLedgerEntry(PointsLedgerEntry entry);
  Future<void> upsertVoucher(ActiveVoucher voucher);
  Future<void> appendRedemption(RedemptionRecord record);
  Future<void> upsertDispute(DisputeCase dispute);
  Future<void> appendRejectedAttempt({
    required String binId,
    required String unitId,
    required String reason,
    required double weightKg,
  });
  Future<void> appendNotification(NotificationItem notification);
  Future<void> markNotificationRead(String id);
  Future<void> appendTask(OperatorTask task);
  Future<void> completeTask(String id);
  Future<void> appendCompostApplication(CompostApplication application);
  Future<void> appendBatch(BokashiBatch batch);

  /// Clears every stored record (used by "Reset demo data").
  Future<void> clear();
}

/// Builds the repository the app should use for this build.
///
/// With no Supabase credentials the app runs entirely on the local snapshot,
/// so the live demo never depends on a network.
AgriRepository buildRepository() {
  if (AppConfig.hasSupabase) {
    return SupabaseAgriRepository(
      client: SupabaseClient(
        AppConfig.supabaseUrl,
        AppConfig.supabaseAnonKey,
      ),
    );
  }
  return LocalAgriRepository();
}
