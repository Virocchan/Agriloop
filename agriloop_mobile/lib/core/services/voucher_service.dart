import 'dart:convert';

/// Result of attempting to redeem a voucher token at a merchant terminal.
enum RedemptionOutcome {
  success,
  unknownToken,
  invalidSignature,
  expired,
  alreadyUsed,
  wrongMerchant,
  notYetValid,
}

const Map<RedemptionOutcome, String> redemptionOutcomeMessages = {
  RedemptionOutcome.success: 'Voucher verified and applied.',
  RedemptionOutcome.unknownToken: 'Token not found — no such voucher was issued.',
  RedemptionOutcome.invalidSignature: 'Signature check failed — token may be forged.',
  RedemptionOutcome.expired: 'Voucher has expired.',
  RedemptionOutcome.alreadyUsed: 'Voucher has already been redeemed.',
  RedemptionOutcome.wrongMerchant: 'Voucher is not valid at this merchant.',
  RedemptionOutcome.notYetValid: 'Voucher is not active yet.',
};

/// Minted, signed voucher / resident-pass tokens.
///
/// Production should use HMAC-SHA256 from `package:crypto`. This build uses a
/// deterministic FNV-1a 64 signature so the demo runs with zero extra
/// dependencies; the shape of the token and the verification flow are
/// identical, so swapping the primitive is a one-file change.
class VoucherService {
  const VoucherService({this.secret = 'agriloop-demo-secret-sd-property'});

  final String secret;

  /// Signs a payload and returns a short uppercase hex signature.
  String sign(String payload) {
    return _fnv1a64Hex('$payload::$secret').substring(0, 8).toUpperCase();
  }

  /// Mints a voucher token.
  ///
  /// Format: `AGR-<MERCHANT>-<VALUE_RM>-<SEQ>-<SIGNATURE>`
  String mintVoucherToken({
    required String merchantCode,
    required double valueRm,
    required int sequence,
  }) {
    final code = _sanitize(merchantCode);
    final value = valueRm.toStringAsFixed(0);
    final payload = '$code|$value|$sequence';
    return 'AGR-$code-$value-$sequence-${sign(payload)}';
  }

  /// Mints a resident pass token tied to a unit.
  ///
  /// Format: `AGR-RES-<INVITE_CODE>-<SEQ>-<SIGNATURE>`
  String mintResidentToken({
    required String inviteCode,
    required int sequence,
  }) {
    final code = _sanitize(inviteCode);
    final payload = 'RES|$code|$sequence';
    return 'AGR-RES-$code-$sequence-${sign(payload)}';
  }

  /// Tokens are dash-delimited, so any dash inside a field is stripped.
  static String _sanitize(String value) =>
      value.toUpperCase().replaceAll('-', '').replaceAll(' ', '');

  /// Payload that a token's signature is computed over.
  ///
  /// Resident passes sign `RES|<invite>|<seq>`, vouchers sign
  /// `<merchant>|<value>|<seq>`.
  static String? signaturePayload(String token) {
    final parts = token.split('-');
    if (parts.length < 5 || parts[0] != 'AGR') return null;
    if (parts[1] == 'RES') return 'RES|${parts[2]}|${parts[3]}';
    return '${parts[1]}|${parts[2]}|${parts[3]}';
  }

  /// Recomputes the signature of a token from its own contents.
  ///
  /// Returns `null` when the token is malformed.
  String? recomputeSignature(String token) {
    final payload = VoucherService.signaturePayload(token);
    if (payload == null) return null;
    return sign(payload);
  }

  /// Verifies a token's structure and signature without needing the vault.
  bool hasValidSignature(String token) {
    final recomputed = recomputeSignature(token);
    if (recomputed == null) return false;
    return recomputed == token.split('-').last.toUpperCase();
  }

  /// Extracts the merchant code embedded in a voucher token, if any.
  String? merchantCodeOf(String token) {
    final parts = token.split('-');
    if (parts.length < 5 || parts[0] != 'AGR') return null;
    if (parts[1] == 'RES') return null;
    return parts[1];
  }

  /// Parses a signed token payload back into its parts.
  Map<String, dynamic>? decodeToken(String token) {
    final parts = token.split('-');
    if (parts.length < 5 || parts[0] != 'AGR') return null;
    return {
      'kind': parts[1],
      'value': parts[2],
      'sequence': parts[3],
      'signature': parts.sublist(4).join('-'),
    };
  }

  /// Encodes a payload for the demo persistence layer.
  String encode(Map<String, dynamic> json) => jsonEncode(json);

  /// FNV-1a 64-bit hash rendered as 16 hex characters.
  ///
  /// Uses [BigInt] so the result is bit-identical on the Dart VM and on the
  /// web (where native ints are doubles and would otherwise overflow).
  static String _fnv1a64Hex(String input) {
    final offsetBasis = BigInt.parse('cbf29ce484222325', radix: 16);
    final prime = BigInt.parse('100000001b3', radix: 16);
    final mask = BigInt.parse('FFFFFFFFFFFFFFFF', radix: 16);

    var hash = offsetBasis;
    for (final byte in utf8.encode(input)) {
      hash = (hash ^ BigInt.from(byte)) & mask;
      hash = (hash * prime) & mask;
    }
    return hash.toRadixString(16).padLeft(16, '0');
  }
}
