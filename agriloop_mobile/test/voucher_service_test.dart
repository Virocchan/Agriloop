import 'package:agriloop_mobile/core/services/voucher_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const service = VoucherService();

  test('mints a token whose signature verifies', () {
    final token = service.mintVoucherToken(
      merchantCode: 'JG',
      valueRm: 5,
      sequence: 101,
    );

    expect(token, startsWith('AGR-JG-5-101-'));
    expect(service.hasValidSignature(token), isTrue);
    expect(service.merchantCodeOf(token), 'JG');
  });

  test('rejects a tampered token', () {
    final token = service.mintVoucherToken(
      merchantCode: 'JG',
      valueRm: 5,
      sequence: 101,
    );
    final tampered = token.replaceFirst('AGR-JG-5-101-', 'AGR-JG-50-101-');

    expect(service.hasValidSignature(tampered), isFalse);
  });

  test('rejects a forged signature', () {
    const forged = 'AGR-JG-5-101-DEADBEEF';

    expect(service.hasValidSignature(forged), isFalse);
  });

  test('rejects a malformed token', () {
    expect(service.hasValidSignature('not-a-token'), isFalse);
    expect(service.recomputeSignature('AGR-JG'), isNull);
  });

  test('mints and verifies a resident pass', () {
    final token = service.mintResidentToken(
      inviteCode: 'ELM-9921',
      sequence: 1001,
    );

    expect(token, startsWith('AGR-RES-ELM9921-1001-'));
    expect(service.hasValidSignature(token), isTrue);
    expect(service.merchantCodeOf(token), isNull);
  });

  test('different merchants produce different signatures', () {
    final jaya = service.mintVoucherToken(
        merchantCode: 'JG', valueRm: 5, sequence: 101);
    final zus = service.mintVoucherToken(
        merchantCode: 'ZU', valueRm: 5, sequence: 101);

    expect(jaya, isNot(zus));
    expect(service.hasValidSignature(jaya), isTrue);
    expect(service.hasValidSignature(zus), isTrue);
  });
}
