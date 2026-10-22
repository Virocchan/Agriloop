import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/theme/app_theme.dart';

/// Bottom sheet that shows a scannable QR pass.
///
/// Used for both the resident unit pass and voucher redemption passes.
class QrPassSheet extends StatelessWidget {
  const QrPassSheet({
    super.key,
    required this.title,
    required this.subtitle,
    required this.token,
    this.footerNote,
    this.accent = const Color(0xFF22C55E),
    this.tokenLabel = 'TOKEN',
  });

  final String title;
  final String subtitle;
  final String token;
  final String? footerNote;
  final Color accent;
  final String tokenLabel;

  static Future<void> show(
    BuildContext context, {
    required String title,
    required String subtitle,
    required String token,
    String? footerNote,
    Color accent = const Color(0xFF22C55E),
    String tokenLabel = 'TOKEN',
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF16221C),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => QrPassSheet(
        title: title,
        subtitle: subtitle,
        token: token,
        footerNote: footerNote,
        accent: accent,
        tokenLabel: tokenLabel,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFF25392E),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              title.toUpperCase(),
              style: const TextStyle(
                fontSize: 11,
                letterSpacing: 1,
                color: AppTheme.textMuted,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
              ),
              child: QrImageView(
                data: token,
                version: QrVersions.auto,
                size: 190,
                eyeStyle: const QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: Color(0xFF0D1511),
                ),
                dataModuleStyle: const QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: Color(0xFF0D1511),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: accent.withValues(alpha: 0.3)),
              ),
              child: Text(
                '$tokenLabel: $token',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11,
                  color: accent,
                ),
              ),
            ),
            if (footerNote != null) ...[
              const SizedBox(height: 12),
              Text(
                footerNote!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
