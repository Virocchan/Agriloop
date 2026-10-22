import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/all_models.dart';
import '../../providers/app_state_provider.dart';
import 'qr_pass_sheet.dart';

class RewardsTab extends ConsumerStatefulWidget {
  const RewardsTab({super.key});

  @override
  ConsumerState<RewardsTab> createState() => _RewardsTabState();
}

class _RewardsTabState extends ConsumerState<RewardsTab>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showRedeemDialog(VoucherItem item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF16221C),
        title: Text(item.title, style: const TextStyle(fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${item.costPts} points will be deducted from your account. Your balance is ${ref.read(agriStateProvider).profile.points} points.',
              style: const TextStyle(fontSize: 13, color: AppTheme.textMuted),
            ),
            const SizedBox(height: 10),
            Text('Terms: ${item.terms}',
                style: const TextStyle(fontSize: 11, color: AppTheme.textSubtle)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              final success =
                  ref.read(agriStateProvider.notifier).redeemVoucher(item);
              if (success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content: Text('Redeemed ${item.title}! Check "My Vouchers".')),
                );
                _tabController.animateTo(1);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Insufficient points to redeem voucher.')),
                );
              }
            },
            child: const Text('Confirm redeem'),
          ),
        ],
      ),
    );
  }

  void _showVoucherPass(ActiveVoucher voucher) {
    final expired = voucher.isExpired;
    QrPassSheet.show(
      context,
      title: voucher.merchant,
      subtitle: voucher.title,
      token: voucher.token,
      accent: expired ? AppTheme.accentCoral : AppTheme.primaryGlow,
      footerNote: expired
          ? 'This voucher expired on ${Fmt.date(voucher.expiresAt)}.'
          : 'Valid until ${Fmt.date(voucher.expiresAt)} · present at the checkout.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(agriStateProvider);
    final activeVouchers =
        state.myVouchers.where((v) => v.status == VoucherStatus.active).length;

    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Text('YOUR POINTS BALANCE',
                      style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        Fmt.points(state.profile.points),
                        style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            color: Colors.white),
                      ),
                      const SizedBox(width: 6),
                      const Text('pts',
                          style: TextStyle(
                              fontSize: 16,
                              color: AppTheme.accentLime,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const Text('1,000 pts = RM 5.00 voucher funded by community merchants',
                      style:
                          TextStyle(fontSize: 11, color: AppTheme.textSubtle)),
                  const SizedBox(height: 14),
                  TabBar(
                    controller: _tabController,
                    indicatorColor: AppTheme.primaryGlow,
                    labelColor: AppTheme.primaryGlow,
                    unselectedLabelColor: AppTheme.textMuted,
                    tabs: [
                      const Tab(text: 'Catalogue'),
                      Tab(text: 'My Vouchers ($activeVouchers)'),
                      const Tab(text: 'Ledger'),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            // ---- Catalogue ------------------------------------------------
            ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: state.catalog.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, idx) {
                final item = state.catalog[idx];
                final canAfford = state.profile.points >= item.costPts;

                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Colors.black26,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(
                            child: Text(item.icon, style: const TextStyle(fontSize: 22)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item.title,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold, fontSize: 13)),
                              Text(
                                '${item.merchant} · Valid ${item.expiryDays}d',
                                style: const TextStyle(
                                    fontSize: 11, color: AppTheme.textMuted),
                              ),
                              const SizedBox(height: 2),
                              Text('🪙 ${item.costPts} pts',
                                  style: const TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFFFBBF24),
                                      fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                canAfford ? const Color(0xFF16A34A) : Colors.white12,
                            padding:
                                const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          ),
                          onPressed:
                              canAfford ? () => _showRedeemDialog(item) : null,
                          child: Text(canAfford ? 'Redeem' : 'Need pts',
                              style: const TextStyle(fontSize: 11)),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),

            // ---- My vouchers ----------------------------------------------
            ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: state.myVouchers.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, idx) {
                final v = state.myVouchers[idx];
                final expired = v.isExpired;
                final used = v.status == VoucherStatus.used;
                final inactive = expired || used;

                return Opacity(
                  opacity: inactive ? 0.55 : 1,
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(v.merchant,
                                      style: const TextStyle(
                                          fontSize: 13, fontWeight: FontWeight.bold)),
                                  Text(v.title,
                                      style: const TextStyle(
                                          fontSize: 11, color: Color(0xFF86EFAC))),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 7, vertical: 3),
                                decoration: BoxDecoration(
                                  color: (used
                                          ? AppTheme.textSubtle
                                          : expired
                                              ? AppTheme.accentCoral
                                              : AppTheme.primaryGlow)
                                      .withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  used
                                      ? 'USED'
                                      : expired
                                          ? 'EXPIRED'
                                          : '${Fmt.daysUntil(v.expiresAt)}d left',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: used
                                        ? AppTheme.textMuted
                                        : expired
                                            ? AppTheme.accentCoral
                                            : AppTheme.primaryGlow,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            used
                                ? 'Redeemed ${v.usedAt == null ? '' : Fmt.dateTime(v.usedAt!)}'
                                : 'Expires ${Fmt.date(v.expiresAt)}',
                            style: const TextStyle(
                                fontSize: 10, color: AppTheme.textSubtle),
                          ),
                          const SizedBox(height: 10),
                          Align(
                            alignment: Alignment.centerRight,
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(
                                  color: inactive
                                      ? AppTheme.borderSubtle
                                      : AppTheme.primaryGlow,
                                ),
                              ),
                              onPressed:
                                  inactive ? null : () => _showVoucherPass(v),
                              child: Text(
                                inactive ? 'Void' : 'Show QR pass',
                                style: TextStyle(
                                    fontSize: 11,
                                    color:
                                        inactive ? AppTheme.textSubtle : Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),

            // ---- Points ledger ---------------------------------------------
            state.ledger.isEmpty
                ? const Center(
                    child: Text('No points activity yet.',
                        style: TextStyle(color: AppTheme.textMuted)),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: state.ledger.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, idx) {
                      final entry = state.ledger[idx];
                      final positive = entry.delta >= 0;
                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.black26,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              positive
                                  ? Icons.arrow_downward
                                  : Icons.arrow_upward,
                              size: 15,
                              color: positive
                                  ? AppTheme.primaryGlow
                                  : AppTheme.accentAmber,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(entry.reason,
                                      style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${Fmt.dateTime(entry.timestamp)}${entry.refId == null ? '' : ' · ${entry.refId}'}',
                                    style: const TextStyle(
                                        fontSize: 9, color: AppTheme.textSubtle),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              '${positive ? '+' : ''}${entry.delta}',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                fontFamily: 'monospace',
                                color: positive
                                    ? AppTheme.primaryGlow
                                    : AppTheme.accentAmber,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ],
        ),
      ),
    );
  }
}
