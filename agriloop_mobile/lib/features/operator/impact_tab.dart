import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../providers/app_state_provider.dart';

/// Pilot analytics — the numbers behind the headline claim:
/// "does reward feedback increase clean food-waste diversion?".
class ImpactTab extends ConsumerWidget {
  const ImpactTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(agriStateProvider);
    final metrics = state.pilotMetrics;
    final deposits = state.deposits.where((d) => !d.rejected).toList();

    // Daily diverted kg, split by pilot phase.
    final daily = <DateTime, double>{};
    final dailyClean = <DateTime, double>{};
    for (final d in deposits) {
      final day = DateTime(d.timestamp.year, d.timestamp.month, d.timestamp.day);
      daily[day] = (daily[day] ?? 0) + d.weightKg;
      if (d.isClean) {
        dailyClean[day] = (dailyClean[day] ?? 0) + d.weightKg;
      }
    }
    final days = daily.keys.toList()..sort();

    final totalSpots = <FlSpot>[];
    final cleanSpots = <FlSpot>[];
    for (var i = 0; i < days.length; i++) {
      totalSpots.add(FlSpot(i.toDouble(), daily[days[i]]!));
      cleanSpots.add(FlSpot(i.toDouble(), dailyClean[days[i]] ?? 0));
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: _metricCard(
                '${metrics.kgPerParticipantPerWeek.toStringAsFixed(2)} kg',
                'kg diverted per participant per week',
                AppTheme.primaryGlow,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _metricCard(
                '${(metrics.contaminationRate * 100).toStringAsFixed(1)}%',
                'contamination rate',
                metrics.contaminationRate > 0.15
                    ? AppTheme.accentCoral
                    : AppTheme.accentLime,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _metricCard(
                '${(metrics.weekTwoRetention * 100).round()}%',
                'week-2 retention',
                AppTheme.accentCyan,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _metricCard(
                '${metrics.avgRewardLatencyMs} ms',
                'deposit-to-reward latency',
                AppTheme.accentAmber,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Baseline vs rewarded comparison
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF16221C),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF25392E)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Baseline week vs. rewards week',
                  style:
                      TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 4),
              const Text(
                'Per-participant diversion before Green Points were switched on, and after.',
                style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _bar(
                      'Baseline',
                      metrics.baselineKgPerParticipant,
                      AppTheme.textSubtle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _bar(
                      'Rewards live',
                      metrics.rewardedKgPerParticipant,
                      AppTheme.primaryGlow,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: (metrics.upliftPct > 0
                          ? AppTheme.primaryGlow
                          : AppTheme.accentAmber)
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.insights, size: 16, color: AppTheme.accentLime),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        metrics.upliftPct > 0
                            ? 'Reward feedback lifted diversion by ${metrics.upliftPct.toStringAsFixed(0)}% (${metrics.baselineKgPerParticipant.toStringAsFixed(2)} → ${metrics.rewardedKgPerParticipant.toStringAsFixed(2)} kg per participant).'
                            : 'Not enough rewarded-week data yet to call the uplift.',
                        style: const TextStyle(
                            fontSize: 11, color: AppTheme.textMuted),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Daily diversion chart
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF16221C),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF25392E)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Daily diversion (kg)',
                  style:
                      TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 4),
              const Text('Filled = clean volume, outline = total collected.',
                  style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
              const SizedBox(height: 20),
              SizedBox(
                height: 180,
                child: totalSpots.isEmpty
                    ? const Center(
                        child: Text('No data yet',
                            style:
                                TextStyle(color: AppTheme.textSubtle)))
                    : LineChart(
                        LineChartData(
                          gridData: FlGridData(
                            show: true,
                            drawVerticalLine: false,
                            getDrawingHorizontalLine: (value) => FlLine(
                              color: Colors.white.withValues(alpha: 0.06),
                              strokeWidth: 1,
                            ),
                          ),
                          borderData: FlBorderData(show: false),
                          titlesData: FlTitlesData(
                            leftTitles: const AxisTitles(
                              sideTitles:
                                  SideTitles(showTitles: true, reservedSize: 34),
                            ),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                interval: 1,
                                reservedSize: 28,
                                getTitlesWidget: (value, meta) {
                                  final i = value.toInt();
                                  if (i < 0 || i >= days.length) {
                                    return const SizedBox.shrink();
                                  }
                                  final d = days[i];
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: Text(
                                      '${d.day}/${d.month}',
                                      style: const TextStyle(
                                          fontSize: 8,
                                          color: AppTheme.textSubtle),
                                    ),
                                  );
                                },
                              ),
                            ),
                            topTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false)),
                            rightTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false)),
                          ),
                          lineBarsData: [
                            LineChartBarData(
                              spots: totalSpots,
                              isCurved: true,
                              barWidth: 2,
                              color: AppTheme.accentAmber,
                              dotData: const FlDotData(show: false),
                              belowBarData: BarAreaData(
                                show: true,
                                color:
                                    AppTheme.accentAmber.withValues(alpha: 0.08),
                              ),
                            ),
                            LineChartBarData(
                              spots: cleanSpots,
                              isCurved: true,
                              barWidth: 2,
                              color: AppTheme.primaryGlow,
                              dotData: const FlDotData(show: false),
                              belowBarData: BarAreaData(
                                show: true,
                                color:
                                    AppTheme.primaryGlow.withValues(alpha: 0.12),
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Township value
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF183325), Color(0xFF0F241A)],
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF274D39)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Value to Sime Darby Property',
                  style:
                      TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 10),
              _valueRow(
                'Waste diverted from landfill',
                '${metrics.totalKg.toStringAsFixed(1)} kg',
              ),
              _valueRow(
                'CO₂e avoided (2.5 kg/kg)',
                '${(metrics.totalKg * 2.5).toStringAsFixed(1)} kg',
              ),
              _valueRow(
                'Pre-compost returned to planters',
                '${state.communityCompostCurrentKg.toStringAsFixed(0)} kg',
              ),
              _valueRow(
                'Purchased fertiliser displaced',
                '≈ RM ${(state.communityCompostCurrentKg * 1.8).toStringAsFixed(0)}',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _metricCard(String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF16221C),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF25392E)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value,
              style: TextStyle(
                  fontSize: 22, fontWeight: FontWeight.w800, color: color)),
          const SizedBox(height: 4),
          Text(label,
              style: const TextStyle(fontSize: 10, color: AppTheme.textMuted)),
        ],
      ),
    );
  }

  Widget _bar(String label, double value, Color color) {
    const max = 5.0;
    final pct = (value / max).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct,
            minHeight: 10,
            backgroundColor: Colors.white10,
            color: color,
          ),
        ),
        const SizedBox(height: 6),
        Text('${value.toStringAsFixed(2)} kg / participant',
            style: const TextStyle(
                fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white)),
      ],
    );
  }

  Widget _valueRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
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
