/// Safe enum lookups for data that comes back from the database.
///
/// The database stores enums by name; unknown values must never crash the
/// app, so every lookup falls back to a sensible default.
library;

import '../rules/scoring_rules.dart';
import '../../models/all_models.dart';

/// Resolves a [RuleViolation] by its name, or null when unknown.
RuleViolation? ruleViolationByName(String? name) {
  if (name == null) return null;
  for (final v in RuleViolation.values) {
    if (v.name == name) return v;
  }
  return null;
}

/// Resolves a [CleanlinessTier] by its name.
CleanlinessTier cleanlinessTierByName(String? name) {
  for (final t in CleanlinessTier.values) {
    if (t.name == name) return t;
  }
  return CleanlinessTier.clean;
}

/// Resolves a [VoucherStatus] by its name.
VoucherStatus voucherStatusByName(String? name) {
  for (final s in VoucherStatus.values) {
    if (s.name == name) return s;
  }
  return VoucherStatus.active;
}

/// Resolves a [DisputeStatus] by its name.
DisputeStatus disputeStatusByName(String? name) {
  for (final s in DisputeStatus.values) {
    if (s.name == name) return s;
  }
  return DisputeStatus.open;
}

/// Maps a violation code returned by the Postgres `rpc_submit_deposit`
/// function onto the app's rule vocabulary.
RuleViolation serverViolationToRule(String code) {
  switch (code.toUpperCase()) {
    case 'COOLDOWN_VIOLATION':
      return RuleViolation.cooldownActive;
    case 'DUPLICATE_SESSION_NONCE':
    case 'DUPLICATE_NONCE':
      return RuleViolation.duplicateScan;
    case 'WEIGHT_BELOW_MINIMUM':
    case 'BELOW_MIN_WEIGHT':
      return RuleViolation.belowMinWeight;
    case 'DAILY_POINTS_CAP_VIOLATION':
    case 'DAILY_CAP_VIOLATION':
      return RuleViolation.dailyPointsCapReached;
    case 'DAILY_DEPOSIT_LIMIT_VIOLATION':
    case 'DAILY_DEPOSIT_LIMIT':
      return RuleViolation.dailyDepositLimitReached;
    case 'CONTAMINATION_DETECTED':
      return RuleViolation.contaminationDetected;
    case 'WEIGHT_EXCEEDS_MAXIMUM':
    case 'EXCESSIVE_WEIGHT':
    case 'IMPLAUSIBLE_WEIGHT':
      return RuleViolation.implausibleWeight;
    case 'BIN_FULL':
      return RuleViolation.binFull;
    case 'BIN_OFFLINE':
      return RuleViolation.binOffline;
    case 'UNKNOWN_UNIT':
    case 'UNKNOWN_RESIDENT':
      return RuleViolation.unknownResident;
    default:
      return RuleViolation.serverPolicy;
  }
}

/// A human-readable explanation for a violation code from the database.
String serverViolationMessage(String code) {
  switch (serverViolationToRule(code)) {
    case RuleViolation.cooldownActive:
      return 'Cooldown active on this bin — one deposit per 10 minutes.';
    case RuleViolation.duplicateScan:
      return 'Duplicate scan — this bin session nonce was already redeemed.';
    case RuleViolation.belowMinWeight:
      return 'Below the 50 g minimum deposit weight — no points awarded.';
    case RuleViolation.dailyPointsCapReached:
      return 'Daily points cap reached — deposit counted for diversion but earns no points.';
    case RuleViolation.dailyDepositLimitReached:
      return 'Daily deposit limit reached for this unit.';
    case RuleViolation.contaminationDetected:
      return 'Contamination detected — points withheld pending operator review.';
    case RuleViolation.implausibleWeight:
      return 'Weight jump looks implausible — points withheld pending operator audit.';
    case RuleViolation.binFull:
      return 'Bin is full — the operator has been notified to swap the bucket.';
    case RuleViolation.binOffline:
      return 'Bin is offline — no deposit session can be opened.';
    case RuleViolation.unknownResident:
      return 'This unit is not registered in the community database.';
    default:
      return 'Database policy rejected the deposit ($code).';
  }
}
