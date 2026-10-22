import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/app_state_provider.dart';
import '../../models/all_models.dart';
import 'home_tab.dart';
import 'deposit_scanner_tab.dart';
import 'rewards_tab.dart';
import 'community_tab.dart';
import 'profile_tab.dart';
import 'inbox_screen.dart';

class ResidentShell extends ConsumerStatefulWidget {
  const ResidentShell({super.key});

  @override
  ConsumerState<ResidentShell> createState() => _ResidentShellState();
}

class _ResidentShellState extends ConsumerState<ResidentShell> {
  int _currentIndex = 0;

  void _goToRole(UserRole role) {
    ref.read(agriStateProvider.notifier).switchRole(role);
    switch (role) {
      case UserRole.resident:
        context.go('/home');
      case UserRole.merchant:
        context.go('/merchant');
      case UserRole.operator:
        context.go('/operator');
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(agriStateProvider);

    final pages = [
      HomeTab(onNavigateToDeposit: () => setState(() => _currentIndex = 1)),
      const DepositScannerTab(),
      const RewardsTab(),
      const CommunityTab(),
      const ProfileTab(),
    ];

    final unreadCount = state.unreadCount;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Row(
          children: [
            Container(
              width: 40,
              height: 34,
              padding: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                color: const Color(0xFF16221C),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF274D39)),
              ),
              child: const Image(
                image: AssetImage('assets/images/agriloop_mark.png'),
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Flexible(
                        child: Text(
                          'AgriLoop',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: const Color(0xFF16A34A).withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Sime Darby',
                          style: TextStyle(
                            fontSize: 9,
                            color: Color(0xFFA3E635),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '${state.profile.township.split('(').first.trim()} · ${state.profile.unit}',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF94A39B)),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          // Role Switcher Menu Action
          PopupMenuButton<UserRole>(
            tooltip: 'Switch App Role',
            icon: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF16221C),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF25392E)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('🏡', style: TextStyle(fontSize: 14)),
                  SizedBox(width: 4),
                  Icon(Icons.arrow_drop_down, size: 16, color: Color(0xFF22C55E)),
                ],
              ),
            ),
            onSelected: (role) {
              _goToRole(role);
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: UserRole.resident,
                child: Row(
                  children: [
                    Text('🏡 '),
                    SizedBox(width: 8),
                    Text('Resident Mode (Current)'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: UserRole.merchant,
                child: Row(
                  children: [
                    Text('🛍️ '),
                    SizedBox(width: 8),
                    Text('Merchant Mode (Cashier Scanner)'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: UserRole.operator,
                child: Row(
                  children: [
                    Text('🛠️ '),
                    SizedBox(width: 8),
                    Text('Operator Mode (Fleet & Compost)'),
                  ],
                ),
              ),
            ],
          ),
          // Notification Bell
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined, color: Colors.white),
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const InboxScreen()),
                  );
                  if (!mounted) return;
                  ref.read(agriStateProvider.notifier).markAllNotificationsRead();
                },
              ),
              if (unreadCount > 0)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Color(0xFFEF4444),
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                    child: Text(
                      '$unreadCount',
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        selectedItemColor: const Color(0xFF22C55E),
        unselectedItemColor: const Color(0xFF64746D),
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF22C55E), Color(0xFF15803D)],
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.qr_code_scanner, color: Colors.white, size: 20),
            ),
            label: 'Deposit',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.card_giftcard_outlined),
            activeIcon: Icon(Icons.card_giftcard),
            label: 'Rewards',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.people_outline),
            activeIcon: Icon(Icons.people),
            label: 'Community',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
