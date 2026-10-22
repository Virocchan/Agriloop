import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../providers/app_state_provider.dart';
import '../../models/all_models.dart';

class CommunityTab extends ConsumerWidget {
  const CommunityTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(agriStateProvider);
    final standings = state.blockStandings;
    final metrics = state.pilotMetrics;
    final myBlock = state.profile.block;
    final myStanding = standings.where((s) => s.name == myBlock).firstOrNull;
    final myRank = standings.indexWhere((s) => s.name == myBlock) + 1;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Community impact hub',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const Text(
            'Elmina Valley block challenge · live from the deposit ledger',
            style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
          ),
          const SizedBox(height: 16),

          // Block leaderboard
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('🏆 Block leaderboard',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14)),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.accentAmber.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text('Ends in 8 days',
                            style: TextStyle(
                                fontSize: 10,
                                color: Color(0xFFFBBF24),
                                fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (standings.isEmpty)
                    const Text('No deposits recorded yet this cycle.',
                        style:
                            TextStyle(fontSize: 12, color: AppTheme.textMuted))
                  else
                    ...standings.map((blk) {
                      final isUser = blk.name == myBlock;
                      final color = switch (blk.participants) {
                        0 => AppTheme.textSubtle,
                        1 => const Color(0xFF94A3B8),
                        2 => const Color(0xFFD97706),
                        _ => const Color(0xFFF59E0B),
                      };
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isUser
                              ? AppTheme.primaryGlow.withValues(alpha: 0.08)
                              : Colors.black26,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isUser
                                ? AppTheme.primaryGlow
                                : Colors.transparent,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Text(
                                  '#${standings.indexOf(blk) + 1}',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: color),
                                ),
                                const SizedBox(width: 10),
                                Text(blk.name,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12)),
                                const SizedBox(width: 8),
                                Text('${blk.participants} units',
                                    style: const TextStyle(
                                        fontSize: 9,
                                        color: AppTheme.textSubtle)),
                              ],
                            ),
                            Text(
                              '${blk.kgDiverted.toStringAsFixed(1)} kg',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: Color(0xFFA3E635)),
                            ),
                          ],
                        ),
                      );
                    }),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Resident standing
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF193827), Color(0xFF13241B)],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF274D39)),
            ),
            child: Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryGlow.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    children: [
                      Text(
                        myRank == 0 ? '—' : '#$myRank',
                        style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: Colors.white),
                      ),
                      Text('in $myBlock',
                          style: const TextStyle(
                              fontSize: 10, color: Color(0xFFA3E635))),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "You've diverted ${state.profile.totalKgDiverted.toStringAsFixed(1)} kg in total!",
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        myStanding == null
                            ? 'Make your first deposit to join the block challenge.'
                            : 'Your block has diverted ${myStanding.kgDiverted.toStringAsFixed(1)} kg from ${myStanding.participants} units.',
                        style: const TextStyle(
                            fontSize: 11, color: AppTheme.textMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // The closed loop: waste -> bin -> compost -> park
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('♻️ Your waste → our park',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 4),
                  const Text(
                    'Every kilogram you divert is weighed at the bin, fermented in a Bokashi bucket, then returned to the township planters.',
                    style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                  ),
                  const SizedBox(height: 14),
                  _loopStep(
                    '1',
                    'Smart bin',
                    '${metrics.totalKg.toStringAsFixed(1)} kg diverted by ${metrics.participants} units in the pilot',
                    AppTheme.primaryGlow,
                  ),
                  _loopArrow(),
                  _loopStep(
                    '2',
                    'Bokashi fermentation',
                    '${state.batches.length} active batches · ${state.batches.where((b) => b.isReady).length} ready for soil incorporation',
                    const Color(0xFFA3E635),
                  ),
                  _loopArrow(),
                  _loopStep(
                    '3',
                    'Back to the township',
                    '${state.communityCompostCurrentKg.toStringAsFixed(0)} kg of pre-compost returned to planters',
                    const Color(0xFF10B981),
                  ),
                  if (state.compostApplications.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Text('Recent returns',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textMuted)),
                    const SizedBox(height: 6),
                    ...state.compostApplications.take(3).map((c) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            children: [
                              const Icon(Icons.park,
                                  size: 13, color: Color(0xFF10B981)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '${c.kg.toStringAsFixed(0)} kg → ${c.location}',
                                  style: const TextStyle(
                                      fontSize: 11, color: AppTheme.textMuted),
                                ),
                              ),
                              Text(
                                Fmt.relative(c.timestamp),
                                style: const TextStyle(
                                    fontSize: 9, color: AppTheme.textSubtle),
                              ),
                            ],
                          ),
                        )),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Weekly challenges
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('🎯 Weekly challenges',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 12),
                  _challengeRow(
                    '🔥',
                    '3-day composter',
                    'Deposit on 3 distinct days this week',
                    '+50 pts',
                    _challengeProgress(state),
                  ),
                  const Divider(color: Colors.white10, height: 20),
                  _challengeRow(
                    '✨',
                    'Zero contamination hero',
                    'Achieve 5 consecutive clean deposits verified by AI',
                    '+80 pts',
                    _cleanStreakProgress(state),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  double _challengeProgress(AgriState state) {
    final days = state.deposits
        .where((d) =>
            d.unitId == state.profile.unit &&
            d.timestamp.isAfter(DateTime.now().subtract(const Duration(days: 7))))
        .map((d) => DateTime(d.timestamp.year, d.timestamp.month, d.timestamp.day))
        .toSet();
    return (days.length / 3).clamp(0.0, 1.0);
  }

  double _cleanStreakProgress(AgriState state) {
    final mine = state.deposits
        .where((d) => d.unitId == state.profile.unit)
        .toList()
      ..sort((DepositRecord a, DepositRecord b) =>
          b.timestamp.compareTo(a.timestamp));
    var streak = 0;
    for (final d in mine) {
      if (d.isClean) {
        streak++;
      } else {
        break;
      }
    }
    return (streak / 5).clamp(0.0, 1.0);
  }

  Widget _loopStep(String number, String title, String body, Color color) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            shape: BoxShape.circle,
            border: Border.all(color: color.withValues(alpha: 0.4)),
          ),
          child: Center(
            child: Text(number,
                style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w800, color: color)),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700)),
              Text(body,
                  style: const TextStyle(
                      fontSize: 10, color: AppTheme.textMuted)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _loopArrow() {
    return const Padding(
      padding: EdgeInsets.only(left: 12, top: 6, bottom: 6),
      child: Icon(Icons.arrow_downward, size: 14, color: AppTheme.textSubtle),
    );
  }

  Widget _challengeRow(
    String emoji,
    String title,
    String body,
    String reward,
    double progress,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(emoji, style: const TextStyle(fontSize: 22)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 12)),
                  Text(reward,
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFFBBF24))),
                ],
              ),
              Text(body,
                  style: const TextStyle(
                      fontSize: 10, color: AppTheme.textMuted)),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: Colors.white10,
                  color: AppTheme.primaryGlow,
                  minHeight: 6,
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  '${(progress * 100).round()}% complete',
                  style: const TextStyle(fontSize: 9, color: AppTheme.textSubtle),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
