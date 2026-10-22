import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:supabase/supabase.dart';

import '../config/app_config.dart';
import '../rules/scoring_rules.dart';
import '../utils/enum_lookups.dart';

/// A deposit as it is submitted to the backend.
class DepositRequest {
  final String unitId;
  final String blockId;
  final String binId;
  final String inviteCode;
  final double weightKg;
  final double confidence;
  final String? sessionNonce;
  final DateTime timestamp;
  final String snapshotPath;

  const DepositRequest({
    required this.unitId,
    required this.blockId,
    required this.binId,
    required this.inviteCode,
    required this.weightKg,
    required this.confidence,
    this.sessionNonce,
    required this.timestamp,
    this.snapshotPath = '',
  });

  Map<String, dynamic> toJson() => {
        'unit_id': unitId,
        'block_id': blockId,
        'bin_id': binId,
        'invite_code': inviteCode,
        'weight_kg': weightKg,
        'confidence': confidence,
        'session_nonce': sessionNonce,
        'timestamp': timestamp.toIso8601String(),
        'snapshot_path': snapshotPath,
      };
}

/// The backend's answer to a deposit.
class DepositResult {
  final bool accepted;

  /// Points awarded by the backend, or -1 when the backend has no opinion
  /// (offline mode) and the local rules engine decides.
  final int awardedPoints;

  final ScoreBreakdown breakdown;
  final List<RuleFinding> findings;

  /// Verdict text straight from the backend, e.g. "Approved".
  final String? verdict;

  /// True when the backend already wrote the deposit and ledger rows, so the
  /// app must not write them again.
  final bool persisted;

  final int rewardLatencyMs;
  final String source;

  const DepositResult({
    required this.accepted,
    required this.awardedPoints,
    required this.breakdown,
    required this.findings,
    required this.persisted,
    required this.rewardLatencyMs,
    required this.source,
    this.verdict,
  });
}

/// Boundary between the app and the real backend.
///
/// The UI depends on this interface only, so swapping the local simulation
/// for the n8n pipeline is a configuration change, not a code change.
abstract class DepositApi {
  /// Submits a deposit and returns the points outcome.
  Future<DepositResult> submitDeposit(DepositRequest request);

  /// Notifies the resident's Telegram channel. Failures are non-fatal.
  Future<bool> notifyResident({
    required String unitId,
    required String message,
  });
}

/// Offline implementation used for the hackathon demo.
class LocalSimulatedDepositApi implements DepositApi {
  const LocalSimulatedDepositApi();

  @override
  Future<DepositResult> submitDeposit(DepositRequest request) async {
    // Simulate the round trip: load cell settling + vision model latency.
    await Future<void>.delayed(const Duration(milliseconds: 1400));
    return const DepositResult(
      accepted: true,
      awardedPoints: -1,
      breakdown: ScoreBreakdown.empty,
      findings: [],
      persisted: false,
      rewardLatencyMs: 1400,
      source: 'local-sim',
    );
  }

  @override
  Future<bool> notifyResident({
    required String unitId,
    required String message,
  }) async {
    return false;
  }
}

/// Supabase implementation: the scoring decision comes from Postgres.
///
/// The `rpc_submit_deposit` function applies the anti-gaming policy in the
/// database, so a tampered client cannot award itself points. The function
/// writes the deposit, the ledger entry and the resident's balance itself,
/// which is why [DepositResult.persisted] is true.
class SupabaseDepositApi implements DepositApi {
  SupabaseDepositApi({required SupabaseClient client, http.Client? httpClient})
      : _client = client,
        _http = httpClient ?? http.Client();

  final SupabaseClient _client;
  final http.Client _http;

  @override
  Future<DepositResult> submitDeposit(DepositRequest request) async {
    final stopwatch = Stopwatch()..start();
    try {
      final residentId = await _residentIdFor(request.inviteCode);
      final binId = await _binIdFor(request.binId);
      if (residentId == null || binId == null) {
        stopwatch.stop();
        return DepositResult(
          accepted: false,
          awardedPoints: 0,
          breakdown: ScoreBreakdown.empty,
          findings: const [
            RuleFinding(
              violation: RuleViolation.unknownResident,
              detail: 'This unit is not registered in the community database.',
            ),
          ],
          persisted: false,
          rewardLatencyMs: stopwatch.elapsedMilliseconds,
          source: 'supabase',
        );
      }

      final tier = ScoringRules.defaultRules.tierFor(request.confidence);
      final response = await _client.rpc(
        AppConfig.submitDepositRpc,
        params: {
          'p_resident_id': residentId,
          'p_bin_id': binId,
          'p_weight_kg': request.weightKg,
          'p_confidence': request.confidence,
          'p_session_nonce': request.sessionNonce,
          'p_tier': tier.name,
          'p_image_path': request.snapshotPath,
        },
      );
      stopwatch.stop();

      final body = _asMap(response);
      final success = body['success'] as bool? ?? true;
      final awarded = (body['points_awarded'] as num?)?.toInt() ?? 0;
      final verdict = body['verdict'] as String?;
      final rawViolations = (body['violations'] as List<dynamic>? ?? [])
          .map((v) => v.toString())
          .toList();

      final findings = rawViolations
          .map((code) => RuleFinding(
                violation: serverViolationToRule(code),
                detail: serverViolationMessage(code),
              ))
          .toList();

      final contaminated =
          tier == CleanlinessTier.contaminated ||
          (verdict?.toLowerCase().contains('contamination') ?? false);

      final breakdown = ScoreBreakdown(
        weightKg: request.weightKg,
        tier: contaminated ? CleanlinessTier.contaminated : tier,
        confidence: request.confidence,
        cleanlinessMultiplier:
            ScoringRules.defaultRules.multiplierFor(tier),
        basePoints: (request.weightKg * 100).round(),
        qualityBonus: 0,
        streakBonus: 0,
        cappedPoints: 0,
        totalPoints: awarded,
        findings: findings,
        pointsWithheld: awarded == 0,
      );

      return DepositResult(
        accepted: success && awarded > 0,
        awardedPoints: awarded,
        breakdown: breakdown,
        findings: findings,
        verdict: verdict,
        persisted: true,
        rewardLatencyMs: stopwatch.elapsedMilliseconds,
        source: 'supabase',
      );
    } catch (error) {
      stopwatch.stop();
      // Never let a backend hiccup break a live demo: fall back to the local
      // rules engine, which always has an opinion.
      return DepositResult(
        accepted: true,
        awardedPoints: -1,
        breakdown: ScoreBreakdown.empty,
        findings: const [],
        persisted: false,
        rewardLatencyMs: stopwatch.elapsedMilliseconds,
        source: 'supabase-fallback',
      );
    }
  }

  @override
  Future<bool> notifyResident({
    required String unitId,
    required String message,
  }) async {
    if (!AppConfig.hasTelegram) return false;
    try {
      final response = await _http
          .post(
            Uri.parse(
                'https://api.telegram.org/bot${AppConfig.telegramBotToken}/sendMessage'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'chat_id': AppConfig.telegramChatId,
              'text': '[Unit $unitId] $message',
            }),
          )
          .timeout(const Duration(seconds: 8));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Map<String, dynamic> _asMap(dynamic response) {
    if (response is Map<String, dynamic>) return response;
    if (response is List && response.isNotEmpty) {
      final first = response.first;
      if (first is Map<String, dynamic>) return first;
    }
    return const {};
  }

  Future<String?> _residentIdFor(String inviteCode) async {
    if (inviteCode.isEmpty) return null;
    final result = await _client
        .from('residents')
        .select('id')
        .eq('invite_code', inviteCode)
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
}

/// n8n implementation: POST to the webhook, receive the scoring decision.
///
/// Expected webhook response shape:
/// ```json
/// { "accepted": true, "points": 72, "confidence": 0.98,
///   "violations": [], "opens_dispute": false, "latency_ms": 1180 }
/// ```
class N8nDepositApi implements DepositApi {
  N8nDepositApi({
    required this.webhookUrl,
    http.Client? client,
  }) : _client = client ?? http.Client();

  final String webhookUrl;
  final http.Client _client;

  @override
  Future<DepositResult> submitDeposit(DepositRequest request) async {
    final stopwatch = Stopwatch()..start();
    try {
      final response = await _client
          .post(
            Uri.parse(webhookUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(request.toJson()),
          )
          .timeout(const Duration(seconds: 12));

      if (response.statusCode >= 400) {
        throw Exception('n8n webhook returned ${response.statusCode}');
      }

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      stopwatch.stop();

      final violations = <RuleFinding>[];
      for (final raw in (body['violations'] as List<dynamic>? ?? [])) {
        final name = raw.toString();
        final violation = RuleViolation.values.firstWhere(
          (v) => v.name == name,
          orElse: () => RuleViolation.serverPolicy,
        );
        violations.add(RuleFinding(
          violation: violation,
          detail: ruleViolationMessages[violation] ?? name,
        ));
      }

      final confidence =
          (body['confidence'] as num?)?.toDouble() ?? request.confidence;
      final tier = ScoringRules.defaultRules.tierFor(confidence);
      final points = (body['points'] as num?)?.toInt() ?? 0;

      return DepositResult(
        accepted: body['accepted'] as bool? ?? true,
        awardedPoints: points,
        breakdown: ScoreBreakdown(
          weightKg: request.weightKg,
          tier: tier,
          confidence: confidence,
          cleanlinessMultiplier: ScoringRules.defaultRules.multiplierFor(tier),
          basePoints: (request.weightKg * 100).round(),
          qualityBonus: 0,
          streakBonus: 0,
          cappedPoints: 0,
          totalPoints: points,
          findings: violations,
          pointsWithheld: points == 0,
        ),
        findings: violations,
        verdict: body['verdict'] as String?,
        persisted: false,
        rewardLatencyMs:
            (body['latency_ms'] as num?)?.toInt() ?? stopwatch.elapsedMilliseconds,
        source: 'n8n',
      );
    } catch (_) {
      stopwatch.stop();
      return DepositResult(
        accepted: true,
        awardedPoints: -1,
        breakdown: ScoreBreakdown.empty,
        findings: const [],
        persisted: false,
        rewardLatencyMs: stopwatch.elapsedMilliseconds,
        source: 'n8n-fallback',
      );
    }
  }

  @override
  Future<bool> notifyResident({
    required String unitId,
    required String message,
  }) async {
    if (!AppConfig.hasTelegram) return false;
    try {
      final response = await _client
          .post(
            Uri.parse(
                'https://api.telegram.org/bot${AppConfig.telegramBotToken}/sendMessage'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'chat_id': AppConfig.telegramChatId,
              'text': '[Unit $unitId] $message',
            }),
          )
          .timeout(const Duration(seconds: 8));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}

/// Picks the right backend for this build.
DepositApi buildDepositApi() {
  if (AppConfig.hasRemoteBackend) {
    return N8nDepositApi(webhookUrl: AppConfig.n8nWebhookUrl);
  }
  if (AppConfig.hasSupabase) {
    return SupabaseDepositApi(
      client: SupabaseClient(AppConfig.supabaseUrl, AppConfig.supabaseAnonKey),
    );
  }
  return const LocalSimulatedDepositApi();
}
