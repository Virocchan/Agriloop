import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../providers/app_state_provider.dart';
import 'qr_pass_sheet.dart';

class ProfileTab extends ConsumerWidget {
  const ProfileTab({super.key});

  void _showReportProblemDialog(BuildContext context, WidgetRef ref) {
    String selectedBin = 'A01';
    String category = 'Bin full / overflowing';
    final notesController = TextEditingController();
    final bins = ref.read(agriStateProvider).bins;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          backgroundColor: const Color(0xFF16221C),
          title: const Text('🚨 Report a problem with bin',
              style: TextStyle(fontSize: 16)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Reports dispatch directly to the on-site operator queue.',
                    style:
                        TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                const SizedBox(height: 12),
                const Text('Bin location:',
                    style:
                        TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                DropdownButton<String>(
                  value: selectedBin,
                  isExpanded: true,
                  dropdownColor: const Color(0xFF16221C),
                  items: bins
                      .map((b) => DropdownMenuItem(
                          value: b.id, child: Text('Bin ${b.id} · ${b.location}')))
                      .toList(),
                  onChanged: (val) => setState(() => selectedBin = val!),
                ),
                const SizedBox(height: 8),
                const Text('Category:',
                    style:
                        TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                DropdownButton<String>(
                  value: category,
                  isExpanded: true,
                  dropdownColor: const Color(0xFF16221C),
                  items: const [
                    DropdownMenuItem(
                        value: 'Bin full / overflowing',
                        child: Text('Bin full / overflowing')),
                    DropdownMenuItem(
                        value: 'Odor / bran depleted',
                        child: Text('Odor / bran depleted')),
                    DropdownMenuItem(
                        value: 'Lid latch solenoid jammed',
                        child: Text('Lid latch solenoid jammed')),
                    DropdownMenuItem(
                        value: 'Screen / QR offline',
                        child: Text('Screen / QR offline')),
                  ],
                  onChanged: (val) => setState(() => category = val!),
                ),
                const SizedBox(height: 8),
                const Text('Notes / description:',
                    style:
                        TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                TextField(
                  controller: notesController,
                  maxLines: 2,
                  style: const TextStyle(fontSize: 12),
                  decoration: const InputDecoration(
                    hintText: 'Additional details for the maintenance crew...',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
            ),
            ElevatedButton(
              onPressed: () {
                ref.read(agriStateProvider.notifier).reportProblem(
                      selectedBin,
                      category,
                      notesController.text,
                    );
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content:
                          Text('Ticket submitted to the operator task queue.')),
                );
              },
              child: const Text('Submit ticket'),
            ),
          ],
        ),
      ),
    );
  }

  void _showBokashiGuide(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF16221C),
        title: const Text('📗 Bokashi composting 101',
            style: TextStyle(fontSize: 16)),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('How it works:',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: AppTheme.accentLime)),
              SizedBox(height: 4),
              Text(
                'Bokashi uses beneficial anaerobic microorganisms (EM-1) to pickle and ferment organic food scraps without foul odour or greenhouse methane emissions.',
                style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
              ),
              SizedBox(height: 10),
              Text('Golden rules:',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: AppTheme.accentLime)),
              SizedBox(height: 4),
              Text(
                '1. Press food scraps down firmly to expel air pockets.\n2. Ensure the airtight bin lid snaps securely.\n3. The operator drains Bokashi tea every 3-5 days for landscaping, and the fermented solids are buried after 14 days.\n4. The output is used for ornamental landscaping only — not edible crops.',
                style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Got it!'),
          ),
        ],
      ),
    );
  }

  void _showDepositHistory(BuildContext context, WidgetRef ref) {
    final deposits = ref.read(agriStateProvider).deposits;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF16221C),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        builder: (ctx, controller) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('📜 Deposit history & points ledger',
                  style:
                      TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.separated(
                  controller: controller,
                  itemCount: deposits.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, idx) {
                    final d = deposits[idx];
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.black26,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: Image.asset(
                              d.imagePath,
                              width: 48,
                              height: 48,
                              fit: BoxFit.cover,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Bin ${d.binId} · ${d.weightKg.toStringAsFixed(2)} kg',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13),
                                    ),
                                    Text(
                                      d.pointsEarned > 0
                                          ? '+${d.pointsEarned} pts'
                                          : '0 pts',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                        color: d.pointsEarned > 0
                                            ? const Color(0xFFFBBF24)
                                            : AppTheme.textSubtle,
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  d.verdict,
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: d.isClean
                                          ? const Color(0xFF86EFAC)
                                          : const Color(0xFFFCA5A5)),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${Fmt.dateTime(d.timestamp)} · ${(d.confidence * 100).round()}% confidence${d.violations.isEmpty ? '' : ' · ${d.violations.length} flag(s)'}',
                                  style: const TextStyle(
                                      fontSize: 10, color: AppTheme.textSubtle),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditIdentity(BuildContext context, WidgetRef ref) {
    final profile = ref.read(agriStateProvider).profile;
    final nicknameController = TextEditingController(text: profile.nickname);
    final unitController = TextEditingController(text: profile.unit);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF16221C),
        title: const Text('Edit unit details',
            style: TextStyle(fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nicknameController,
              decoration: const InputDecoration(labelText: 'Nickname'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: unitController,
              decoration: const InputDecoration(labelText: 'Unit number'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () {
              ref.read(agriStateProvider.notifier).updateProfile(
                    nickname: nicknameController.text.trim(),
                    township: profile.township,
                    block: profile.block,
                    unit: unitController.text.trim(),
                  );
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmReset(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF16221C),
        title: const Text('Reset demo data?', style: TextStyle(fontSize: 16)),
        content: const Text(
          'This clears the locally stored pilot history, points balance and vouchers, then reseeds the demo world.',
          style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentCoral),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(agriStateProvider.notifier).resetDemoData();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Demo data reset to the seed state.')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(agriStateProvider).profile;
    final state = ref.watch(agriStateProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Profile header
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                          colors: [Color(0xFF22C55E), Color(0xFF15803D)]),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        profile.nickname.substring(0, 2).toUpperCase(),
                        style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(profile.nickname,
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold)),
                        Text('${profile.township} · ${profile.unit}',
                            style: const TextStyle(
                                fontSize: 12, color: AppTheme.textMuted)),
                        Row(
                          children: [
                            Icon(
                              profile.verified
                                  ? Icons.verified
                                  : Icons.error_outline,
                              size: 12,
                              color: profile.verified
                                  ? AppTheme.accentLime
                                  : AppTheme.accentCoral,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                'Invite ${profile.inviteCode} · ${profile.verified ? 'verified' : 'pending'}',
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 11, color: AppTheme.accentLime),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Edit details',
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    onPressed: () => _showEditIdentity(context, ref),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Resident pass
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('🪪 Resident unit pass',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14)),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.accentLime.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text('SIGNED',
                            style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.accentLime)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Ties every deposit to ${profile.block} · Unit ${profile.unit}. Show it at the bin terminal.',
                    style: const TextStyle(
                        fontSize: 11, color: AppTheme.textMuted),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => QrPassSheet.show(
                        context,
                        title: 'Resident unit pass',
                        subtitle: '${profile.block} · Unit ${profile.unit}',
                        token: profile.residentPassToken,
                        tokenLabel: 'PASS',
                        footerNote:
                            'Signature verified by the bin terminal before the lid unlocks.',
                      ),
                      icon: const Icon(Icons.qr_code_2, size: 18),
                      label: const Text('Show my unit pass'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Menu options
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Text('📜', style: TextStyle(fontSize: 20)),
                  title: const Text('Deposit history & points ledger',
                      style:
                          TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  subtitle: const Text('Review past deposits, weights & points earned',
                      style:
                          TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                  trailing: const Icon(Icons.chevron_right, size: 18),
                  onTap: () => _showDepositHistory(context, ref),
                ),
                const Divider(color: Colors.white10, height: 1),
                ListTile(
                  leading: const Text('📗', style: TextStyle(fontSize: 20)),
                  title: const Text('Bokashi composting guide 101',
                      style:
                          TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  subtitle: const Text('Airtight fermentation tips & accepted materials',
                      style:
                          TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                  trailing: const Icon(Icons.chevron_right, size: 18),
                  onTap: () => _showBokashiGuide(context),
                ),
                const Divider(color: Colors.white10, height: 1),
                ListTile(
                  leading: const Text('🚨', style: TextStyle(fontSize: 20)),
                  title: const Text('Report a problem with smart bin',
                      style:
                          TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  subtitle: const Text('Bin full, smelly, latch jammed, or offline',
                      style:
                          TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                  trailing: const Icon(Icons.chevron_right, size: 18),
                  onTap: () => _showReportProblemDialog(context, ref),
                ),
                const Divider(color: Colors.white10, height: 1),
                ListTile(
                  leading: const Text('♻️', style: TextStyle(fontSize: 20)),
                  title: const Text('Reset demo data',
                      style:
                          TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  subtitle: const Text('Clear the local pilot snapshot and reseed',
                      style:
                          TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                  trailing: const Icon(Icons.chevron_right, size: 18),
                  onTap: () => _confirmReset(context, ref),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Impact summary
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Your impact',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.accentLime)),
                const SizedBox(height: 10),
                _kv('Total diverted',
                    '${profile.totalKgDiverted.toStringAsFixed(1)} kg'),
                _kv('CO₂e avoided',
                    '${profile.co2AvoidedKg.toStringAsFixed(1)} kg'),
                _kv('Week streak', '${profile.streakWeeks} weeks'),
                _kv('Points balance', Fmt.points(profile.points)),
                _kv('Open disputes', '${state.openDisputeCount}'),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Privacy note
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text(
              '🔒 Privacy assurance: AgriLoop stores only your unit ID and chosen nickname. No personal phone numbers or identification card numbers are published on community leaderboards.',
              style: TextStyle(fontSize: 11, color: AppTheme.textSubtle),
            ),
          ),
        ],
      ),
    );
  }

  Widget _kv(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
          Text(value,
              style: const TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
        ],
      ),
    );
  }
}
