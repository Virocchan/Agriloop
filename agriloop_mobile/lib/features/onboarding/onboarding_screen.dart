import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/theme/app_theme.dart';
import '../../providers/app_state_provider.dart';

/// Resident registration flow.
///
/// Produces a signed unit pass (`AGR-RES-<invite>-<seq>-<sig>`) that identifies
/// the resident at the bin and is stored against their profile.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pageController = PageController();
  final _unitController = TextEditingController(text: '12-03');
  final _inviteController = TextEditingController(text: 'ELM-9921');
  final _nicknameController = TextEditingController(text: 'Norah Lee');

  int _page = 0;
  String _township = 'City of Elmina (Elmina Valley)';
  String _block = 'Block A';
  String? _inviteError;

  static const List<String> townships = [
    'City of Elmina (Elmina Valley)',
    'Sime Darby Homes, Bandar Bukit Jurai',
    'Sime Darby Vantage, Shah Alam',
  ];

  static const List<String> blocks = [
    'Block A',
    'Block B',
    'Block C',
    'Block D',
  ];

  @override
  void dispose() {
    _pageController.dispose();
    _unitController.dispose();
    _inviteController.dispose();
    _nicknameController.dispose();
    super.dispose();
  }

  void _next() {
    if (_page == 1) {
      final code = _inviteController.text.trim().toUpperCase();
      if (!validInviteCodes.contains(code)) {
        setState(() => _inviteError =
            'That invite code is not recognised. Try one of the codes issued by the township office.');
        return;
      }
      setState(() => _inviteError = null);
      // Issue the signed unit pass now so the next step can display it.
      ref.read(agriStateProvider.notifier).registerResident(
            nickname: _nicknameController.text.trim().isEmpty
                ? 'Resident'
                : _nicknameController.text.trim(),
            township: _township,
            block: _block,
            unit: _unitController.text.trim(),
            inviteCode: code,
          );
    }
    if (_page >= 2) return;
    _pageController.nextPage(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  void _back() {
    if (_page == 0) return;
    _pageController.previousPage(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  void _finish() {
    context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(agriStateProvider.select((s) => s.profile));

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 34,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
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
                  const Text(
                    'AgriLoop',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                  const Spacer(),
                  if (_page > 0)
                    TextButton(
                      onPressed: _back,
                      child: const Text('Back'),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: List.generate(3, (i) {
                  return Expanded(
                    child: Container(
                      height: 4,
                      margin: EdgeInsets.only(right: i == 2 ? 0 : 6),
                      decoration: BoxDecoration(
                        color: i <= _page
                            ? const Color(0xFF22C55E)
                            : const Color(0xFF25392E),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) => setState(() => _page = i),
                children: [
                  _welcomeStep(),
                  _identityStep(),
                  _passStep(profile.residentPassToken),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _page == 2 ? _finish : _next,
                  icon: Icon(_page == 2
                      ? Icons.rocket_launch_outlined
                      : Icons.arrow_forward),
                  label: Text(_page == 2
                      ? 'Start depositing'
                      : (_page == 1 ? 'Verify invite code' : 'Get started')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stepShell({
    required String eyebrow,
    required String title,
    required String subtitle,
    required List<Widget> children,
  }) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            eyebrow.toUpperCase(),
            style: const TextStyle(
              fontSize: 10,
              letterSpacing: 1,
              fontWeight: FontWeight.w700,
              color: AppTheme.accentLime,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 13, color: AppTheme.textMuted),
          ),
          const SizedBox(height: 22),
          ...children,
        ],
      ),
    );
  }

  Widget _welcomeStep() {
    return _stepShell(
      eyebrow: 'Step 1 of 3',
      title: 'Turn your food waste into township soil',
      subtitle:
          'Register your unit once. From then on, every kilogram you drop at a smart bin earns Green Points and becomes compost for the parks you live in.',
      children: [
        _featureRow(Icons.qr_code_scanner, 'Scan and deposit',
            'Your unit pass unlocks the bin lid for 30 seconds.'),
        _featureRow(Icons.auto_awesome, 'Earn Green Points',
            '100 pts per clean kilogram, with a streak bonus.'),
        _featureRow(Icons.park, 'Feed the township',
            'Compost goes back into the planters of your own estate.'),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF16221C),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF25392E)),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.lock_outline, size: 16, color: AppTheme.accentLime),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Privacy: AgriLoop stores only your unit ID and a chosen nickname. No phone numbers or ID card numbers are published on leaderboards.',
                  style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _identityStep() {
    return _stepShell(
      eyebrow: 'Step 2 of 3',
      title: 'Confirm your unit',
      subtitle:
          'Use the invite code from your township management notice. It links your deposits to the right block leaderboard.',
      children: [
        const Text('Township',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          initialValue: _township,
          dropdownColor: AppTheme.bgSurface,
          isExpanded: true,
          items: townships
              .map((t) => DropdownMenuItem(value: t, child: Text(t)))
              .toList(),
          onChanged: (v) => setState(() => _township = v!),
        ),
        const SizedBox(height: 14),
        const Text('Block', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          initialValue: _block,
          dropdownColor: AppTheme.bgSurface,
          isExpanded: true,
          items: blocks
              .map((b) => DropdownMenuItem(value: b, child: Text(b)))
              .toList(),
          onChanged: (v) => setState(() => _block = v!),
        ),
        const SizedBox(height: 14),
        const Text('Unit number', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        TextField(
          controller: _unitController,
          style: const TextStyle(fontSize: 14),
          decoration: const InputDecoration(hintText: 'e.g. 12-03'),
        ),
        const SizedBox(height: 14),
        const Text('Invite code', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        TextField(
          controller: _inviteController,
          textCapitalization: TextCapitalization.characters,
          style: const TextStyle(fontSize: 14, fontFamily: 'monospace'),
          decoration: InputDecoration(
            hintText: 'e.g. ELM-9921',
            errorText: _inviteError,
          ),
        ),
        const SizedBox(height: 14),
        const Text('Display nickname',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        TextField(
          controller: _nicknameController,
          style: const TextStyle(fontSize: 14),
          decoration: const InputDecoration(hintText: 'Shown on leaderboards'),
        ),
      ],
    );
  }

  Widget _passStep(String passToken) {
    final token = passToken.isEmpty
        ? 'AGR-RES-ELM-9921-1001-PENDING'
        : passToken;

    return _stepShell(
      eyebrow: 'Step 3 of 3',
      title: 'Your unit pass is ready',
      subtitle:
          'Show this QR at the bin terminal, or simply scan the bin QR in the app. Either way the deposit is attributed to your unit.',
      children: [
        Center(
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
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
        ),
        const SizedBox(height: 14),
        Center(
          child: Text(
            token,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 11,
              color: AppTheme.accentLime,
            ),
          ),
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF16221C),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF25392E)),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('What happens next',
                  style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.accentLime)),
              SizedBox(height: 8),
              Text(
                '1. Scan the bin QR and the lid unlocks for 30 seconds.\n'
                '2. Drop your food waste and close the lid.\n'
                '3. The load cell weighs it and the camera checks it.\n'
                '4. Your Green Points land in your balance instantly.',
                style: TextStyle(fontSize: 11, color: AppTheme.textMuted, height: 1.6),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _featureRow(IconData icon, String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFF22C55E).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: const Color(0xFF22C55E)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(body,
                    style: const TextStyle(
                        fontSize: 11, color: AppTheme.textMuted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
