import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/services/voucher_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/all_models.dart';
import '../../providers/app_state_provider.dart';

/// Cashier terminal for partner merchants.
///
/// Scans a resident's voucher pass, validates the signature, expiry and reuse
/// state, then marks the voucher as spent.
class MerchantScreen extends ConsumerStatefulWidget {
  const MerchantScreen({super.key});

  @override
  ConsumerState<MerchantScreen> createState() => _MerchantScreenState();
}

class _MerchantScreenState extends ConsumerState<MerchantScreen> {
  late final MobileScannerController _merchantCameraController;
  bool _isProcessing = false;
  final TextEditingController _manualTokenController = TextEditingController();

  /// Merchant code this terminal belongs to.
  static const String merchantCode = 'JG';
  static const String merchantName = 'Jaya Grocer';

  /// Pre-seeded ledger so the cashier sees movement on first open.
  final List<RedemptionRecord> _seedLedger = [
    RedemptionRecord(
      id: 'RDM-9001',
      voucherId: 'VOUCH-880',
      merchant: merchantName,
      merchantCode: merchantCode,
      valueRm: 5,
      unitId: '08-04',
      token: const VoucherService().mintVoucherToken(
        merchantCode: merchantCode,
        valueRm: 5,
        sequence: 880,
      ),
      timestamp: DateTime.now().subtract(const Duration(hours: 2)),
    ),
    RedemptionRecord(
      id: 'RDM-9002',
      voucherId: 'VOUCH-874',
      merchant: merchantName,
      merchantCode: merchantCode,
      valueRm: 10,
      unitId: '14-02',
      token: const VoucherService().mintVoucherToken(
        merchantCode: merchantCode,
        valueRm: 10,
        sequence: 874,
      ),
      timestamp: DateTime.now().subtract(const Duration(hours: 5)),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _merchantCameraController = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
    );
  }

  @override
  void dispose() {
    _merchantCameraController.dispose();
    _manualTokenController.dispose();
    super.dispose();
  }

  List<RedemptionRecord> get _ledger {
    final stored = ref.read(agriStateProvider).redemptions;
    return [...stored, ..._seedLedger]
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  double get _totalPayout =>
      _ledger.fold<double>(0, (sum, r) => sum + r.valueRm);

  void _processScannedVoucher(String rawToken) {
    if (_isProcessing) return;

    // Ignore anything that is not an AgriLoop voucher token — the demo
    // environment often has unrelated barcodes in front of the camera.
    final trimmed = rawToken.trim();
    if (!trimmed.startsWith('AGR-')) return;

    _isProcessing = true;

    final result = ref.read(agriStateProvider.notifier).redeemVoucherToken(
          token: trimmed,
          merchantCode: merchantCode,
        );

    _showResultDialog(result, trimmed);
  }

  void _showResultDialog(RedemptionResult result, String token) {
    final success = result.success;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF16221C),
        title: Row(
          children: [
            Icon(
              success ? Icons.check_circle : Icons.error_outline,
              color: success ? AppTheme.primaryGlow : AppTheme.accentCoral,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                success ? 'Voucher verified!' : 'Voucher rejected',
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              success
                  ? 'RM ${result.voucher!.valueRm.toStringAsFixed(2)} discount applied for unit ${_unitIdOf(result)}. The token is now void.'
                  : redemptionOutcomeMessages[result.outcome]!,
              style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
            ),
            const SizedBox(height: 10),
            Text(
              'TOKEN: $token',
              style: const TextStyle(
                  fontFamily: 'monospace', fontSize: 10, color: AppTheme.accentLime),
            ),
            if (result.voucher != null) ...[
              const SizedBox(height: 8),
              Text(
                'Issued ${Fmt.date(result.voucher!.issuedAt)} · expires ${Fmt.date(result.voucher!.expiresAt)}',
                style: const TextStyle(fontSize: 10, color: AppTheme.textSubtle),
              ),
            ],
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  success ? const Color(0xFF16A34A) : AppTheme.accentCoral,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _isProcessing = false;
            },
            child: Text(success ? 'Complete transaction' : 'Dismiss'),
          ),
        ],
      ),
    );
  }

  String _unitIdOf(RedemptionResult result) {
    return result.record?.unitId ?? ref.read(agriStateProvider).profile.unit;
  }

  void _simulateScan() {
    // Uses the resident's live active voucher when one exists, otherwise a
    // generated token so the cashier flow can always be demonstrated.
    final active = ref
        .read(agriStateProvider)
        .myVouchers
        .where((v) =>
            v.merchantCode == merchantCode &&
            v.status == VoucherStatus.active &&
            !v.isExpired)
        .toList();
    final token = active.isNotEmpty
        ? active.first.token
        : const VoucherService().mintVoucherToken(
            merchantCode: merchantCode, valueRm: 5, sequence: 900);
    _processScannedVoucher(token);
  }

  @override
  Widget build(BuildContext context) {
    final ledger = _ledger;

    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Jaya Grocer · cashier portal',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            Text('Authorised partner merchant · Elmina branch',
                style: TextStyle(fontSize: 10, color: AppTheme.accentLime)),
          ],
        ),
        actions: [
          TextButton.icon(
            icon: const Text('🏡'),
            label: const Text('Resident mode',
                style: TextStyle(color: AppTheme.primaryGlow, fontSize: 11)),
            onPressed: () {
              ref.read(agriStateProvider.notifier).switchRole(UserRole.resident);
              context.go('/home');
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Camera scanner
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Scan resident voucher QR',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 15)),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color:
                                AppTheme.primaryGlow.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text('CAMERA READY',
                              style: TextStyle(
                                  fontSize: 9,
                                  color: AppTheme.primaryGlow,
                                  fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Signature, expiry and reuse state are verified before the discount is applied.',
                      style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                    ),
                    const SizedBox(height: 14),

                    Container(
                      height: 190,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF25392E)),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            MobileScanner(
                              controller: _merchantCameraController,
                              fit: BoxFit.cover,
                              onDetect: (capture) {
                                final barcodes = capture.barcodes;
                                if (barcodes.isNotEmpty &&
                                    barcodes.first.rawValue != null) {
                                  _processScannedVoucher(
                                      barcodes.first.rawValue!);
                                }
                              },
                              errorBuilder: (ctx, err, child) => Container(
                                color: const Color(0xFF0F1813),
                                padding: const EdgeInsets.all(12),
                                child: Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.videocam_off,
                                          size: 36, color: Color(0xFFEF4444)),
                                      const SizedBox(height: 6),
                                      const Text('Camera access required',
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12)),
                                      Text(
                                        err.errorDetails?.message ??
                                            'Allow camera permission, or type the token below.',
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                            fontSize: 10,
                                            color: AppTheme.textMuted),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                border: Border.all(
                                    color: AppTheme.primaryGlow, width: 2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            Positioned(
                              top: 8,
                              right: 8,
                              child: IconButton(
                                iconSize: 18,
                                style: IconButton.styleFrom(
                                  backgroundColor:
                                      Colors.black.withValues(alpha: 0.6),
                                  padding: const EdgeInsets.all(6),
                                ),
                                icon: const Icon(Icons.cameraswitch, color: Colors.white),
                                onPressed: () =>
                                    _merchantCameraController.switchCamera(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _simulateScan,
                        icon: const Icon(Icons.qr_code, size: 18),
                        label: const Text('Simulate customer voucher scan'),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _manualTokenController,
                      style: const TextStyle(
                          fontSize: 11, fontFamily: 'monospace'),
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: 'Or type a token: AGR-JG-5-…',
                        hintStyle: const TextStyle(fontSize: 11),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.search, size: 18),
                          onPressed: () {
                            final token = _manualTokenController.text.trim();
                            if (token.isEmpty) return;
                            _manualTokenController.clear();
                            _processScannedVoucher(token);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Redemption ledger
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Today's redemptions",
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 14)),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color:
                                AppTheme.primaryGlow.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            'RM ${_totalPayout.toStringAsFixed(2)} total',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                                color: AppTheme.primaryGlow),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ...ledger.map((r) => Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.black26,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Unit ${r.unitId}',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12)),
                                  Text(
                                    '${Fmt.time(r.timestamp)} · ${r.token}',
                                    style: const TextStyle(
                                        fontSize: 10,
                                        color: AppTheme.textSubtle),
                                  ),
                                ],
                              ),
                              Text(
                                '-RM ${r.valueRm.toStringAsFixed(2)}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: AppTheme.primaryGlow,
                                    fontFamily: 'monospace'),
                              ),
                            ],
                          ),
                        )),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
