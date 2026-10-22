import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/all_models.dart';
import '../../providers/app_state_provider.dart';

/// Operator review queue for contamination disputes.
///
/// The vision model opens a case automatically; the operator upholds or
/// rejects it, and the resident is notified either way.
class DisputeQueueTab extends ConsumerWidget {
  const DisputeQueueTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final disputes = ref.watch(agriStateProvider).disputes;
    final open = disputes.where((d) => d.status == DisputeStatus.open).toList();
    final closed = disputes.where((d) => d.status != DisputeStatus.open).toList();

    if (disputes.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.verified_user, size: 40, color: Color(0xFF22C55E)),
            SizedBox(height: 12),
            Text('No disputes — every deposit passed the vision check.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: _summaryTile(
                '${open.length}',
                'Awaiting review',
                open.isEmpty ? AppTheme.primaryGlow : AppTheme.accentAmber,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _summaryTile(
                '${closed.length}',
                'Resolved',
                AppTheme.textMuted,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _summaryTile(
                '${ref.watch(agriStateProvider).rejectedAttempts.length}',
                'Blocked attempts',
                AppTheme.accentCoral,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (open.isNotEmpty) ...[
          const Text('OPEN CASES',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                  color: AppTheme.accentAmber)),
          const SizedBox(height: 8),
          ...open.map((d) => _caseCard(context, ref, d, isOpen: true)),
        ],
        if (closed.isNotEmpty) ...[
          const SizedBox(height: 12),
          const Text('RESOLVED',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                  color: AppTheme.textSubtle)),
          const SizedBox(height: 8),
          ...closed.map((d) => _caseCard(context, ref, d, isOpen: false)),
        ],
        const SizedBox(height: 16),
        const Text('BLOCKED DEPOSIT ATTEMPTS',
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
                color: AppTheme.textSubtle)),
        const SizedBox(height: 8),
        ...ref.watch(agriStateProvider).rejectedAttempts.map((a) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF16221C),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: AppTheme.accentCoral.withValues(alpha: 0.25)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.block, size: 15, color: AppTheme.accentCoral),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          a.reason,
                          style: const TextStyle(
                              fontSize: 11, color: AppTheme.textMuted),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Unit ${a.unitId} · Bin ${a.binId} · ${a.weightKg.toStringAsFixed(2)} kg · ${Fmt.relative(a.timestamp)}',
                          style: const TextStyle(
                              fontSize: 9, color: AppTheme.textSubtle),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )),
      ],
    );
  }

  Widget _summaryTile(String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF16221C),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF25392E)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value,
              style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w800, color: color)),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(fontSize: 9, color: AppTheme.textMuted)),
        ],
      ),
    );
  }

  Widget _caseCard(
    BuildContext context,
    WidgetRef ref,
    DisputeCase d, {
    required bool isOpen,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF16221C),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isOpen
              ? AppTheme.accentAmber.withValues(alpha: 0.4)
              : const Color(0xFF25392E),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                d.id,
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w800),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: (isOpen ? AppTheme.accentAmber : AppTheme.textSubtle)
                      .withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  d.status == DisputeStatus.open
                      ? 'OPEN'
                      : (d.status == DisputeStatus.upheld
                          ? 'UPHELD'
                          : 'REJECTED'),
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: isOpen
                        ? AppTheme.accentAmber
                        : (d.status == DisputeStatus.upheld
                            ? AppTheme.primaryGlow
                            : AppTheme.textMuted),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset(
                  d.imagePath,
                  width: 66,
                  height: 66,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      d.reason,
                      style: const TextStyle(
                          fontSize: 11, color: AppTheme.textMuted),
                    ),
                    const SizedBox(height: 6),
                    _meta('Unit', d.unitId),
                    _meta('Bin', d.binId),
                    _meta('Weight', '${d.weightKg.toStringAsFixed(2)} kg'),
                    _meta('AI confidence',
                        '${(d.confidence * 100).round()}%'),
                    _meta('Withheld', '${d.withheldPoints} pts'),
                    _meta('Raised', Fmt.relative(d.createdAt)),
                  ],
                ),
              ),
            ],
          ),
          if (d.resolutionNote != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                d.resolutionNote!,
                style: const TextStyle(fontSize: 10, color: AppTheme.textMuted),
              ),
            ),
          ],
          if (isOpen) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppTheme.accentCoral),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    onPressed: () => ref
                        .read(agriStateProvider.notifier)
                        .resolveDispute(d.id, uphold: false),
                    icon: const Icon(Icons.close, size: 15),
                    label: const Text('Reject flag',
                        style: TextStyle(fontSize: 11, color: Color(0xFFFCA5A5))),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF16A34A),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    onPressed: () => ref
                        .read(agriStateProvider.notifier)
                        .resolveDispute(d.id, uphold: true),
                    icon: const Icon(Icons.check, size: 15),
                    label: const Text('Uphold dispute',
                        style: TextStyle(fontSize: 11)),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _meta(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 9, color: AppTheme.textSubtle)),
          Text(value,
              style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textMuted)),
        ],
      ),
    );
  }
}
