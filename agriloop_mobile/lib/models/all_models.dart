// AgriLoop Data Models
//
// Every model that is persisted carries a `toJson` / `fromJson` pair so the
// demo snapshot in `PersistenceService` stays in sync with the domain.

import '../core/rules/scoring_rules.dart';

enum UserRole { resident, merchant, operator }

/// Lifecycle of a voucher once it has been issued to a resident.
enum VoucherStatus { active, used, expired, disputed }

/// Lifecycle of a contamination dispute raised by the vision model.
enum DisputeStatus { open, upheld, rejected }

/// A single point movement, kept for audit and for the resident ledger.
class PointsLedgerEntry {
  final String id;
  final int delta;
  final String reason;
  final String? refId;
  final int balanceAfter;
  final DateTime timestamp;

  const PointsLedgerEntry({
    required this.id,
    required this.delta,
    required this.reason,
    this.refId,
    required this.balanceAfter,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'delta': delta,
        'reason': reason,
        'refId': refId,
        'balanceAfter': balanceAfter,
        'timestamp': timestamp.toIso8601String(),
      };

  factory PointsLedgerEntry.fromJson(Map<String, dynamic> json) => PointsLedgerEntry(
        id: json['id'] as String,
        delta: json['delta'] as int,
        reason: json['reason'] as String,
        refId: json['refId'] as String?,
        balanceAfter: json['balanceAfter'] as int,
        timestamp: DateTime.parse(json['timestamp'] as String),
      );
}

/// A contamination case opened for operator review.
class DisputeCase {
  final String id;
  final String depositId;
  final String unitId;
  final String binId;
  final String reason;
  final String imagePath;
  final double weightKg;
  final double confidence;
  final int withheldPoints;
  final DisputeStatus status;
  final String? resolutionNote;
  final DateTime createdAt;
  final DateTime? resolvedAt;

  const DisputeCase({
    required this.id,
    required this.depositId,
    required this.unitId,
    required this.binId,
    required this.reason,
    required this.imagePath,
    required this.weightKg,
    required this.confidence,
    this.withheldPoints = 0,
    this.status = DisputeStatus.open,
    this.resolutionNote,
    required this.createdAt,
    this.resolvedAt,
  });

  DisputeCase copyWith({
    DisputeStatus? status,
    String? resolutionNote,
    DateTime? resolvedAt,
  }) {
    return DisputeCase(
      id: id,
      depositId: depositId,
      unitId: unitId,
      binId: binId,
      reason: reason,
      imagePath: imagePath,
      weightKg: weightKg,
      confidence: confidence,
      withheldPoints: withheldPoints,
      status: status ?? this.status,
      resolutionNote: resolutionNote ?? this.resolutionNote,
      createdAt: createdAt,
      resolvedAt: resolvedAt ?? this.resolvedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'depositId': depositId,
        'unitId': unitId,
        'binId': binId,
        'reason': reason,
        'imagePath': imagePath,
        'weightKg': weightKg,
        'confidence': confidence,
        'withheldPoints': withheldPoints,
        'status': status.name,
        'resolutionNote': resolutionNote,
        'createdAt': createdAt.toIso8601String(),
        'resolvedAt': resolvedAt?.toIso8601String(),
      };

  factory DisputeCase.fromJson(Map<String, dynamic> json) => DisputeCase(
        id: json['id'] as String,
        depositId: json['depositId'] as String,
        unitId: json['unitId'] as String,
        binId: json['binId'] as String,
        reason: json['reason'] as String,
        imagePath: json['imagePath'] as String,
        weightKg: (json['weightKg'] as num).toDouble(),
        confidence: (json['confidence'] as num).toDouble(),
        withheldPoints: json['withheldPoints'] as int? ?? 0,
        status: DisputeStatus.values.firstWhere(
          (s) => s.name == json['status'],
          orElse: () => DisputeStatus.open,
        ),
        resolutionNote: json['resolutionNote'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
        resolvedAt: json['resolvedAt'] == null
            ? null
            : DateTime.parse(json['resolvedAt'] as String),
      );
}

/// A deposit attempt that the rules engine refused. Kept so the operator can
/// show that gaming attempts are logged rather than silently dropped.
class RejectedAttempt {
  final String id;
  final String binId;
  final String unitId;
  final String reason;
  final double weightKg;
  final DateTime timestamp;

  const RejectedAttempt({
    required this.id,
    required this.binId,
    required this.unitId,
    required this.reason,
    required this.weightKg,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'binId': binId,
        'unitId': unitId,
        'reason': reason,
        'weightKg': weightKg,
        'timestamp': timestamp.toIso8601String(),
      };

  factory RejectedAttempt.fromJson(Map<String, dynamic> json) => RejectedAttempt(
        id: json['id'] as String,
        binId: json['binId'] as String,
        unitId: json['unitId'] as String,
        reason: json['reason'] as String,
        weightKg: (json['weightKg'] as num).toDouble(),
        timestamp: DateTime.parse(json['timestamp'] as String),
      );
}

/// A merchant redemption event.
class RedemptionRecord {
  final String id;
  final String voucherId;
  final String merchant;
  final String merchantCode;
  final double valueRm;
  final String unitId;
  final String token;
  final DateTime timestamp;

  const RedemptionRecord({
    required this.id,
    required this.voucherId,
    required this.merchant,
    required this.merchantCode,
    required this.valueRm,
    required this.unitId,
    required this.token,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'voucherId': voucherId,
        'merchant': merchant,
        'merchantCode': merchantCode,
        'valueRm': valueRm,
        'unitId': unitId,
        'token': token,
        'timestamp': timestamp.toIso8601String(),
      };

  factory RedemptionRecord.fromJson(Map<String, dynamic> json) => RedemptionRecord(
        id: json['id'] as String,
        voucherId: json['voucherId'] as String,
        merchant: json['merchant'] as String,
        merchantCode: json['merchantCode'] as String,
        valueRm: (json['valueRm'] as num).toDouble(),
        unitId: json['unitId'] as String,
        token: json['token'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String),
      );
}

/// Compost returned to a township planter — the closing of the loop.
class CompostApplication {
  final String id;
  final double kg;
  final String location;
  final String? batchId;
  final String note;
  final DateTime timestamp;

  const CompostApplication({
    required this.id,
    required this.kg,
    required this.location,
    this.batchId,
    this.note = '',
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'kg': kg,
        'location': location,
        'batchId': batchId,
        'note': note,
        'timestamp': timestamp.toIso8601String(),
      };

  factory CompostApplication.fromJson(Map<String, dynamic> json) => CompostApplication(
        id: json['id'] as String,
        kg: (json['kg'] as num).toDouble(),
        location: json['location'] as String,
        batchId: json['batchId'] as String?,
        note: json['note'] as String? ?? '',
        timestamp: DateTime.parse(json['timestamp'] as String),
      );
}

class UserProfile {
  final String nickname;
  final String township;
  final String block;
  final String unit;
  final String inviteCode;
  final int points;
  final int streakWeeks;
  final double totalKgDiverted;
  final double co2AvoidedFactor; // 2.5 kg CO2e per kg food waste (IPCC / EPA WARM)
  final bool verified;
  final DateTime? registeredAt;
  final String residentPassToken;

  const UserProfile({
    required this.nickname,
    required this.township,
    required this.block,
    required this.unit,
    required this.inviteCode,
    this.points = 1450,
    this.streakWeeks = 4,
    this.totalKgDiverted = 18.4,
    this.co2AvoidedFactor = 2.5,
    this.verified = true,
    this.registeredAt,
    this.residentPassToken = '',
  });

  double get co2AvoidedKg => totalKgDiverted * co2AvoidedFactor;
  double get estimatedRmValue => points / 200.0; // 1,000 pts = RM 5

  UserProfile copyWith({
    String? nickname,
    String? township,
    String? block,
    String? unit,
    String? inviteCode,
    int? points,
    int? streakWeeks,
    double? totalKgDiverted,
    bool? verified,
    DateTime? registeredAt,
    String? residentPassToken,
  }) {
    return UserProfile(
      nickname: nickname ?? this.nickname,
      township: township ?? this.township,
      block: block ?? this.block,
      unit: unit ?? this.unit,
      inviteCode: inviteCode ?? this.inviteCode,
      points: points ?? this.points,
      streakWeeks: streakWeeks ?? this.streakWeeks,
      totalKgDiverted: totalKgDiverted ?? this.totalKgDiverted,
      co2AvoidedFactor: co2AvoidedFactor,
      verified: verified ?? this.verified,
      registeredAt: registeredAt ?? this.registeredAt,
      residentPassToken: residentPassToken ?? this.residentPassToken,
    );
  }

  Map<String, dynamic> toJson() => {
        'nickname': nickname,
        'township': township,
        'block': block,
        'unit': unit,
        'inviteCode': inviteCode,
        'points': points,
        'streakWeeks': streakWeeks,
        'totalKgDiverted': totalKgDiverted,
        'co2AvoidedFactor': co2AvoidedFactor,
        'verified': verified,
        'registeredAt': registeredAt?.toIso8601String(),
        'residentPassToken': residentPassToken,
      };

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        nickname: json['nickname'] as String,
        township: json['township'] as String,
        block: json['block'] as String,
        unit: json['unit'] as String,
        inviteCode: json['inviteCode'] as String,
        points: json['points'] as int,
        streakWeeks: json['streakWeeks'] as int,
        totalKgDiverted: (json['totalKgDiverted'] as num).toDouble(),
        co2AvoidedFactor: (json['co2AvoidedFactor'] as num?)?.toDouble() ?? 2.5,
        verified: json['verified'] as bool? ?? true,
        registeredAt: json['registeredAt'] == null
            ? null
            : DateTime.parse(json['registeredAt'] as String),
        residentPassToken: json['residentPassToken'] as String? ?? '',
      );
}

class SmartBin {
  final String id;
  final String name;
  final String location;
  final String status; // 'available' | 'full' | 'offline'
  final int weightG;
  final int fillPct;
  final double tempC;
  final int humidityPct;
  final int rssi;
  final String lockState; // 'locked' | 'unlocked'
  final DateTime? lastSeen;

  const SmartBin({
    required this.id,
    required this.name,
    required this.location,
    required this.status,
    required this.weightG,
    required this.fillPct,
    required this.tempC,
    required this.humidityPct,
    required this.rssi,
    required this.lockState,
    this.lastSeen,
  });

  double get weightKg => weightG / 1000.0;
  bool get isOnline => status != 'offline';
  bool get acceptsDeposits => status == 'available';

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'location': location,
        'status': status,
        'weightG': weightG,
        'fillPct': fillPct,
        'tempC': tempC,
        'humidityPct': humidityPct,
        'rssi': rssi,
        'lockState': lockState,
        'lastSeen': lastSeen?.toIso8601String(),
      };

  factory SmartBin.fromJson(Map<String, dynamic> json) => SmartBin(
        id: json['id'] as String,
        name: json['name'] as String,
        location: json['location'] as String,
        status: json['status'] as String,
        weightG: json['weightG'] as int,
        fillPct: json['fillPct'] as int,
        tempC: (json['tempC'] as num).toDouble(),
        humidityPct: json['humidityPct'] as int,
        rssi: json['rssi'] as int,
        lockState: json['lockState'] as String,
        lastSeen: json['lastSeen'] == null
            ? null
            : DateTime.parse(json['lastSeen'] as String),
      );
}

class DepositRecord {
  final String id;
  final DateTime timestamp;
  final String binId;
  final String unitId;
  final String blockId;
  final double weightKg;
  final int pointsEarned;
  final bool isClean;
  final String imagePath;
  final String verdict;
  final String? sessionNonce;
  final double confidence;
  final CleanlinessTier tier;
  final int basePoints;
  final int qualityBonus;
  final int streakBonus;
  final double cleanlinessMultiplier;
  final int rewardLatencyMs;
  final List<RuleViolation> violations;
  final bool rejected;
  /// 'baseline' = pilot week without Green Points, 'rewarded' = pilot week
  /// with rewards live. Used to compute the behaviour-uplift metric.
  final String phase;

  DepositRecord({
    required this.id,
    required this.timestamp,
    required this.binId,
    required this.weightKg,
    required this.pointsEarned,
    required this.isClean,
    required this.imagePath,
    required this.verdict,
    this.unitId = '',
    this.blockId = '',
    this.sessionNonce,
    this.confidence = 0.98,
    this.tier = CleanlinessTier.clean,
    this.basePoints = 0,
    this.qualityBonus = 0,
    this.streakBonus = 0,
    this.cleanlinessMultiplier = 1.0,
    this.rewardLatencyMs = 0,
    this.violations = const [],
    this.rejected = false,
    this.phase = 'rewarded',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'timestamp': timestamp.toIso8601String(),
        'binId': binId,
        'unitId': unitId,
        'blockId': blockId,
        'weightKg': weightKg,
        'pointsEarned': pointsEarned,
        'isClean': isClean,
        'imagePath': imagePath,
        'verdict': verdict,
        'sessionNonce': sessionNonce,
        'confidence': confidence,
        'tier': tier.name,
        'basePoints': basePoints,
        'qualityBonus': qualityBonus,
        'streakBonus': streakBonus,
        'cleanlinessMultiplier': cleanlinessMultiplier,
        'rewardLatencyMs': rewardLatencyMs,
        'violations': violations.map((v) => v.name).toList(),
        'rejected': rejected,
        'phase': phase,
      };

  factory DepositRecord.fromJson(Map<String, dynamic> json) => DepositRecord(
        id: json['id'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String),
        binId: json['binId'] as String,
        unitId: json['unitId'] as String? ?? '',
        blockId: json['blockId'] as String? ?? '',
        weightKg: (json['weightKg'] as num).toDouble(),
        pointsEarned: json['pointsEarned'] as int,
        isClean: json['isClean'] as bool,
        imagePath: json['imagePath'] as String,
        verdict: json['verdict'] as String,
        sessionNonce: json['sessionNonce'] as String?,
        confidence: (json['confidence'] as num?)?.toDouble() ?? 0.98,
        tier: CleanlinessTier.values.firstWhere(
          (t) => t.name == json['tier'],
          orElse: () => CleanlinessTier.clean,
        ),
        basePoints: json['basePoints'] as int? ?? 0,
        qualityBonus: json['qualityBonus'] as int? ?? 0,
        streakBonus: json['streakBonus'] as int? ?? 0,
        cleanlinessMultiplier:
            (json['cleanlinessMultiplier'] as num?)?.toDouble() ?? 1.0,
        rewardLatencyMs: json['rewardLatencyMs'] as int? ?? 0,
        violations: (json['violations'] as List<dynamic>? ?? [])
            .map((v) => RuleViolation.values.firstWhere(
                  (r) => r.name == v.toString(),
                  orElse: () => RuleViolation.implausibleWeight,
                ))
            .toList(),
        rejected: json['rejected'] as bool? ?? false,
        phase: json['phase'] as String? ?? 'rewarded',
      );
}

class VoucherItem {
  final String id;
  final String merchant;
  final String merchantCode;
  final String title;
  final String terms;
  final int costPts;
  final int expiryDays;
  final String icon;
  final double valueRm;

  const VoucherItem({
    required this.id,
    required this.merchant,
    required this.merchantCode,
    required this.title,
    required this.terms,
    required this.costPts,
    required this.expiryDays,
    required this.icon,
    required this.valueRm,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'merchant': merchant,
        'merchantCode': merchantCode,
        'title': title,
        'terms': terms,
        'costPts': costPts,
        'expiryDays': expiryDays,
        'icon': icon,
        'valueRm': valueRm,
      };

  factory VoucherItem.fromJson(Map<String, dynamic> json) => VoucherItem(
        id: json['id'] as String,
        merchant: json['merchant'] as String,
        merchantCode: json['merchantCode'] as String,
        title: json['title'] as String,
        terms: json['terms'] as String,
        costPts: json['costPts'] as int,
        expiryDays: json['expiryDays'] as int,
        icon: json['icon'] as String,
        valueRm: (json['valueRm'] as num).toDouble(),
      );
}

class ActiveVoucher {
  final String id;
  final String merchant;
  final String merchantCode;
  final String title;
  final String token;
  final double valueRm;
  final DateTime issuedAt;
  final DateTime expiresAt;
  final VoucherStatus status;
  final DateTime? usedAt;
  final String? usedBy;

  const ActiveVoucher({
    required this.id,
    required this.merchant,
    required this.merchantCode,
    required this.title,
    required this.token,
    required this.valueRm,
    required this.issuedAt,
    required this.expiresAt,
    this.status = VoucherStatus.active,
    this.usedAt,
    this.usedBy,
  });

  bool get isUsed => status == VoucherStatus.used;
  bool get isExpired => DateTime.now().isAfter(expiresAt);

  ActiveVoucher copyWith({
    VoucherStatus? status,
    DateTime? usedAt,
    String? usedBy,
  }) {
    return ActiveVoucher(
      id: id,
      merchant: merchant,
      merchantCode: merchantCode,
      title: title,
      token: token,
      valueRm: valueRm,
      issuedAt: issuedAt,
      expiresAt: expiresAt,
      status: status ?? this.status,
      usedAt: usedAt ?? this.usedAt,
      usedBy: usedBy ?? this.usedBy,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'merchant': merchant,
        'merchantCode': merchantCode,
        'title': title,
        'token': token,
        'valueRm': valueRm,
        'issuedAt': issuedAt.toIso8601String(),
        'expiresAt': expiresAt.toIso8601String(),
        'status': status.name,
        'usedAt': usedAt?.toIso8601String(),
        'usedBy': usedBy,
      };

  factory ActiveVoucher.fromJson(Map<String, dynamic> json) => ActiveVoucher(
        id: json['id'] as String,
        merchant: json['merchant'] as String,
        merchantCode: json['merchantCode'] as String,
        title: json['title'] as String,
        token: json['token'] as String,
        valueRm: (json['valueRm'] as num).toDouble(),
        issuedAt: DateTime.parse(json['issuedAt'] as String),
        expiresAt: DateTime.parse(json['expiresAt'] as String),
        status: VoucherStatus.values.firstWhere(
          (s) => s.name == json['status'],
          orElse: () => VoucherStatus.active,
        ),
        usedAt: json['usedAt'] == null ? null : DateTime.parse(json['usedAt'] as String),
        usedBy: json['usedBy'] as String?,
      );
}

class BokashiBatch {
  final String id;
  final String binSource;
  final DateTime sealedDate;
  final DateTime readyDate;
  final int dayCurrent;
  final int dayTotal;
  final String status;

  BokashiBatch({
    required this.id,
    required this.binSource,
    required this.sealedDate,
    required this.readyDate,
    required this.dayCurrent,
    this.dayTotal = 14,
    required this.status,
  });

  double get progress => dayTotal == 0 ? 0 : (dayCurrent / dayTotal).clamp(0.0, 1.0);
  bool get isReady => dayCurrent >= dayTotal;

  Map<String, dynamic> toJson() => {
        'id': id,
        'binSource': binSource,
        'sealedDate': sealedDate.toIso8601String(),
        'readyDate': readyDate.toIso8601String(),
        'dayCurrent': dayCurrent,
        'dayTotal': dayTotal,
        'status': status,
      };

  factory BokashiBatch.fromJson(Map<String, dynamic> json) => BokashiBatch(
        id: json['id'] as String,
        binSource: json['binSource'] as String,
        sealedDate: DateTime.parse(json['sealedDate'] as String),
        readyDate: DateTime.parse(json['readyDate'] as String),
        dayCurrent: json['dayCurrent'] as int,
        dayTotal: json['dayTotal'] as int? ?? 14,
        status: json['status'] as String,
      );
}

class OperatorTask {
  final String id;
  final String binId;
  final String title;
  final String description;
  final String priority; // 'high' | 'medium' | 'low'
  final bool isCompleted;
  final DateTime createdAt;
  final String source;

  OperatorTask({
    required this.id,
    required this.binId,
    required this.title,
    required this.description,
    required this.priority,
    this.isCompleted = false,
    this.source = 'system',
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'binId': binId,
        'title': title,
        'description': description,
        'priority': priority,
        'isCompleted': isCompleted,
        'createdAt': createdAt.toIso8601String(),
        'source': source,
      };

  factory OperatorTask.fromJson(Map<String, dynamic> json) => OperatorTask(
        id: json['id'] as String,
        binId: json['binId'] as String,
        title: json['title'] as String,
        description: json['description'] as String,
        priority: json['priority'] as String,
        isCompleted: json['isCompleted'] as bool? ?? false,
        createdAt: DateTime.parse(json['createdAt'] as String),
        source: json['source'] as String? ?? 'system',
      );
}

class NotificationItem {
  final String id;
  final String title;
  final String message;
  final String type; // 'deposit' | 'alert' | 'rewards' | 'system'
  final DateTime time;
  final bool isUnread;

  NotificationItem({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.time,
    this.isUnread = true,
  });

  NotificationItem copyWith({bool? isUnread}) => NotificationItem(
        id: id,
        title: title,
        message: message,
        type: type,
        time: time,
        isUnread: isUnread ?? this.isUnread,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'message': message,
        'type': type,
        'time': time.toIso8601String(),
        'isUnread': isUnread,
      };

  factory NotificationItem.fromJson(Map<String, dynamic> json) => NotificationItem(
        id: json['id'] as String,
        title: json['title'] as String,
        message: json['message'] as String,
        type: json['type'] as String,
        time: DateTime.parse(json['time'] as String),
        isUnread: json['isUnread'] as bool? ?? true,
      );
}

/// Aggregate standing of one residential block in the community challenge.
class BlockStanding {
  final String name;
  final double kgDiverted;
  final int participants;
  final int deposits;
  final int contaminated;

  const BlockStanding({
    required this.name,
    required this.kgDiverted,
    required this.participants,
    required this.deposits,
    required this.contaminated,
  });

  double get contaminationRate => deposits == 0 ? 0 : contaminated / deposits;

  BlockStanding copyWith({
    double? kgDiverted,
    int? participants,
    int? deposits,
    int? contaminated,
  }) {
    return BlockStanding(
      name: name,
      kgDiverted: kgDiverted ?? this.kgDiverted,
      participants: participants ?? this.participants,
      deposits: deposits ?? this.deposits,
      contaminated: contaminated ?? this.contaminated,
    );
  }
}

/// Pilot metrics derived from the deposit history — the numbers the pitch
/// quotes when answering "does the reward actually change behaviour?".
class PilotMetrics {
  final int deposits;
  final double totalKg;
  final int participants;
  final double kgPerParticipantPerWeek;
  final double contaminationRate;
  final double weekTwoRetention;
  final int avgRewardLatencyMs;
  final int rejectedAttempts;
  final double baselineKgPerParticipant;
  final double rewardedKgPerParticipant;

  const PilotMetrics({
    this.deposits = 0,
    this.totalKg = 0,
    this.participants = 0,
    this.kgPerParticipantPerWeek = 0,
    this.contaminationRate = 0,
    this.weekTwoRetention = 0,
    this.avgRewardLatencyMs = 0,
    this.rejectedAttempts = 0,
    this.baselineKgPerParticipant = 0,
    this.rewardedKgPerParticipant = 0,
  });

  double get upliftPct {
    if (baselineKgPerParticipant <= 0) return 0;
    return ((rewardedKgPerParticipant - baselineKgPerParticipant) /
            baselineKgPerParticipant) *
        100;
  }
}
