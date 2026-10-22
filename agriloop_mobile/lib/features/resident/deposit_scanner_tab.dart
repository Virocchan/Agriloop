import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/rules/scoring_rules.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/app_state_provider.dart';

enum DepositFlowState { scan, unlocking, settling, result }

/// Demo scenarios that exercise a specific rule of the anti-gaming engine.
enum DepositScenario {
  clean,
  contaminated,
  tooLight,
  duplicate,
  cooldown,
  dailyCap,
}

extension DepositScenarioX on DepositScenario {
  String get label {
    switch (this) {
      case DepositScenario.clean:
        return 'Clean deposit';
      case DepositScenario.contaminated:
        return 'Contaminated';
      case DepositScenario.tooLight:
        return 'Too light';
      case DepositScenario.duplicate:
        return 'Duplicate scan';
      case DepositScenario.cooldown:
        return 'Cooldown';
      case DepositScenario.dailyCap:
        return 'Daily cap';
    }
  }

  String get detail {
    switch (this) {
      case DepositScenario.clean:
        return 'Food waste only · full points';
      case DepositScenario.contaminated:
        return 'Plastic detected · points withheld';
      case DepositScenario.tooLight:
        return 'Below 50 g minimum';
      case DepositScenario.duplicate:
        return 'Same session nonce replayed';
      case DepositScenario.cooldown:
        return 'Second scan within 10 minutes';
      case DepositScenario.dailyCap:
        return 'Daily 500 pt cap reached';
    }
  }

  IconData get icon {
    switch (this) {
      case DepositScenario.clean:
        return Icons.eco;
      case DepositScenario.contaminated:
        return Icons.warning_amber_rounded;
      case DepositScenario.tooLight:
        return Icons.scale_outlined;
      case DepositScenario.duplicate:
        return Icons.copy_all_outlined;
      case DepositScenario.cooldown:
        return Icons.timer_outlined;
      case DepositScenario.dailyCap:
        return Icons.trending_flat;
    }
  }

  Color get color {
    switch (this) {
      case DepositScenario.clean:
        return const Color(0xFF22C55E);
      case DepositScenario.contaminated:
        return const Color(0xFFEF4444);
      case DepositScenario.tooLight:
        return const Color(0xFFF59E0B);
      case DepositScenario.duplicate:
        return const Color(0xFF06B6D4);
      case DepositScenario.cooldown:
        return const Color(0xFFA3E635);
      case DepositScenario.dailyCap:
        return const Color(0xFFFBBF24);
    }
  }

  /// Confidence reported by the ESP32-CAM vision check.
  double get confidence {
    switch (this) {
      case DepositScenario.clean:
        return 0.97;
      case DepositScenario.contaminated:
        return 0.41;
      case DepositScenario.tooLight:
        return 0.95;
      case DepositScenario.duplicate:
        return 0.96;
      case DepositScenario.cooldown:
        return 0.94;
      case DepositScenario.dailyCap:
        return 0.98;
    }
  }
}

class DepositScannerTab extends ConsumerStatefulWidget {
  const DepositScannerTab({super.key});

  @override
  ConsumerState<DepositScannerTab> createState() => _DepositScannerTabState();
}

class _DepositScannerTabState extends ConsumerState<DepositScannerTab> {
  DepositFlowState _flowState = DepositFlowState.scan;
  DepositScenario _scenario = DepositScenario.clean;
  double _weightKg = 0.65;
  String _binId = 'A01';
  String _sessionNonce = '';
  int _countdownSeconds = 30;
  Timer? _timer;
  DepositOutcome? _outcome;

  late final MobileScannerController _cameraController;
  bool _hasScanned = false;

  @override
  void initState() {
    super.initState();
    _cameraController = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
      torchEnabled: false,
    );
    _sessionNonce = _mintNonce();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _cameraController.dispose();
    super.dispose();
  }

  String _mintNonce() {
    final rnd = Random();
    final hex = rnd.nextInt(0xFFFF).toRadixString(16).padLeft(4, '0').toUpperCase();
    return 'NR-$hex-${DateTime.now().millisecondsSinceEpoch % 100000}';
  }

  // -------------------------------------------------------------------
  // Scanning
  // -------------------------------------------------------------------

  void _onBarcodeScanned(BarcodeCapture capture) {
    if (_hasScanned) return;
    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;
    final raw = barcodes.first.rawValue;
    if (raw == null || raw.isEmpty) return;

    final parsed = _parseBinPayload(raw);
    if (parsed == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ That QR is not an AgriLoop bin code.'),
        ),
      );
      return;
    }

    _hasScanned = true;
    setState(() {
      _binId = parsed.binId;
      _sessionNonce = parsed.nonce;
    });
    _startUnlockSequence();
  }

  /// Accepts both the AgriLoop bin payload and the legacy prototype format.
  ({String binId, String nonce})? _parseBinPayload(String raw) {
    final parts = raw.split('-');
    if (parts.length >= 3 && parts.first == 'AGR' && parts[1] == 'BIN') {
      return (binId: parts[2], nonce: parts.length > 3 ? parts[3] : _mintNonce());
    }
    if (parts.first == 'BIN' && parts.contains('SMART')) {
      final index = parts.indexOf('BIN');
      if (parts.length > index + 1) {
        return (binId: parts[index + 1], nonce: _mintNonce());
      }
    }
    return null;
  }

  // -------------------------------------------------------------------
  // Flow
  // -------------------------------------------------------------------

  void _startUnlockSequence() {
    setState(() {
      _outcome = null;
      _flowState = DepositFlowState.unlocking;
      _countdownSeconds = 30;
    });

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdownSeconds > 1) {
        setState(() => _countdownSeconds--);
      } else {
        _timer?.cancel();
        _onLidTimeout();
      }
    });
  }

  void _onLidTimeout() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Deposit session timed out. Bin relocked.')),
    );
    setState(() {
      _hasScanned = false;
      _flowState = DepositFlowState.scan;
    });
  }

  Future<void> _closeLidAndRecord() async {
    _timer?.cancel();
    setState(() => _flowState = DepositFlowState.settling);

    final scenario = _scenario;
    final weight = scenario == DepositScenario.tooLight ? 0.03 : _weightKg;

    // The demo scenarios inject a deterministic rule context so the
    // anti-gaming rules can be shown on demand, even on a clean install.
    final contextOverride = _contextOverrideFor(scenario);

    final outcome = await ref.read(agriStateProvider.notifier).submitDeposit(
          binId: _binId,
          weightKg: weight,
          confidence: scenario.confidence,
          sessionNonce: _sessionNonce,
          contextOverride: contextOverride,
        );

    if (!mounted) return;
    setState(() {
      _outcome = outcome;
      _flowState = DepositFlowState.result;
    });
  }

  ScoringContext? _contextOverrideFor(DepositScenario scenario) {
    final now = DateTime.now();
    switch (scenario) {
      case DepositScenario.duplicate:
        return ScoringContext(
          usedSessionNonces: {_sessionNonce},
          lastDepositAtBin: now.subtract(const Duration(hours: 2)),
        );
      case DepositScenario.cooldown:
        return ScoringContext(
          lastDepositAtBin: now.subtract(const Duration(minutes: 3)),
        );
      case DepositScenario.dailyCap:
        return const ScoringContext(pointsEarnedToday: 500);
      default:
        return null;
    }
  }

  void _resetToScanner() {
    setState(() {
      _hasScanned = false;
      _flowState = DepositFlowState.scan;
      _outcome = null;
      _sessionNonce = _mintNonce();
    });
  }

  @override
  Widget build(BuildContext context) {
    switch (_flowState) {
      case DepositFlowState.scan:
        return _buildScanView();
      case DepositFlowState.unlocking:
        return _buildUnlockingView();
      case DepositFlowState.settling:
        return _buildSettlingView();
      case DepositFlowState.result:
        return _buildResultView();
    }
  }

  // -------------------------------------------------------------------
  // 1. Scan view
  // -------------------------------------------------------------------

  Widget _buildScanView() {
    final state = ref.watch(agriStateProvider);
    final bin = state.bins.firstWhere(
      (b) => b.id == _binId,
      orElse: () => state.bins.first,
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Scan Bin QR Code',
                      overflow: TextOverflow.ellipsis,
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Align camera with the rotating QR on the Bin TFT screen',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF22C55E).withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.videocam, size: 12, color: Color(0xFF22C55E)),
                    SizedBox(width: 4),
                    Text('LIVE CAM',
                        style: TextStyle(
                            fontSize: 10,
                            color: Color(0xFF22C55E),
                            fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Bin selector
          SizedBox(
            height: 34,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: state.bins.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, idx) {
                final b = state.bins[idx];
                final selected = b.id == _binId;
                return GestureDetector(
                  onTap: () => setState(() => _binId = b.id),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: selected
                          ? const Color(0xFF22C55E).withValues(alpha: 0.16)
                          : const Color(0xFF16221C),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: selected
                            ? const Color(0xFF22C55E)
                            : const Color(0xFF25392E),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: b.acceptsDeposits
                                ? const Color(0xFF22C55E)
                                : const Color(0xFFEF4444),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${b.id} · ${b.fillPct}%',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: selected ? Colors.white : AppTheme.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),

          // Camera viewfinder
          Container(
            height: 220,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF25392E)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  MobileScanner(
                    controller: _cameraController,
                    fit: BoxFit.cover,
                    onDetect: _onBarcodeScanned,
                    errorBuilder: (context, error, child) {
                      return Container(
                        color: const Color(0xFF0F1813),
                        padding: const EdgeInsets.all(16),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.videocam_off_outlined,
                                  size: 36, color: Color(0xFFEF4444)),
                              const SizedBox(height: 8),
                              const Text(
                                'Camera Access Required',
                                style:
                                    TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                error.errorDetails?.message ??
                                    'Allow camera access, or use the simulation triggers below.',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    fontSize: 10, color: AppTheme.textMuted),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  Container(
                    width: 130,
                    height: 130,
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFF22C55E), width: 2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          iconSize: 18,
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.black.withValues(alpha: 0.6),
                            padding: const EdgeInsets.all(6),
                          ),
                          icon: const Icon(Icons.flash_on, color: Colors.white),
                          onPressed: () => _cameraController.toggleTorch(),
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          iconSize: 18,
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.black.withValues(alpha: 0.6),
                            padding: const EdgeInsets.all(6),
                          ),
                          icon: const Icon(Icons.cameraswitch, color: Colors.white),
                          onPressed: () => _cameraController.switchCamera(),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    bottom: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.qr_code_scanner,
                              size: 12, color: Color(0xFFA3E635)),
                          const SizedBox(width: 5),
                          Text(
                            'Bin ${bin.id} · ${bin.location}',
                            style: const TextStyle(
                                fontSize: 10,
                                color: Color(0xFFA3E635),
                                fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Simulation triggers
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF16221C),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF25392E)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Simulation triggers — each one exercises a rule:',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textMuted),
                      ),
                    ),
                    Text(_scenario.label,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: _scenario.color)),
                  ],
                ),
                const SizedBox(height: 10),
                GridView.count(
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 1.0,
                  children: DepositScenario.values.map((s) {
                    final selected = s == _scenario;
                    return GestureDetector(
                      onTap: () => setState(() {
                        _scenario = s;
                        if (s == DepositScenario.tooLight) {
                          _weightKg = 0.03;
                        } else if (_weightKg < 0.05) {
                          _weightKg = 0.65;
                        }
                      }),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: selected
                              ? s.color.withValues(alpha: 0.14)
                              : Colors.black26,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: selected ? s.color : const Color(0xFF25392E),
                            width: selected ? 1.5 : 1,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(s.icon, size: 18, color: s.color),
                            const SizedBox(height: 4),
                            Text(
                              s.label,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  fontSize: 10, fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              s.detail,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 8, color: AppTheme.textSubtle),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text('Load cell weight',
                        style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                    const Spacer(),
                    Text(
                      '${_weightKg.toStringAsFixed(2)} kg',
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF22C55E)),
                    ),
                  ],
                ),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: const Color(0xFF22C55E),
                    inactiveTrackColor: Colors.white10,
                    thumbColor: const Color(0xFF22C55E),
                    overlayColor: const Color(0xFF22C55E).withValues(alpha: 0.15),
                    trackHeight: 3,
                  ),
                  child: Slider(
                    value: _weightKg.clamp(0.02, 2.0),
                    min: 0.02,
                    max: 2.0,
                    divisions: 198,
                    onChanged: (v) => setState(() {
                      _weightKg = v;
                      if (v >= 0.05 && _scenario == DepositScenario.tooLight) {
                        _scenario = DepositScenario.clean;
                      }
                    }),
                  ),
                ),
                const SizedBox(height: 4),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _startUnlockSequence,
                    icon: const Icon(Icons.lock_open, size: 18),
                    label: const Text('Simulate unlock & deposit'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Accepted items checklist
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('📋 What goes into the Bokashi bin?',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('✅ Accepted',
                                style: TextStyle(
                                    color: Color(0xFF22C55E),
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            ...[
                              'Fruit & veg peels',
                              'Cooked leftovers & rice',
                              'Coffee & tea bags',
                              'Meat, fish, soft bones',
                              'Bread crusts & eggshells',
                            ].map((item) => Text('• $item',
                                style: const TextStyle(
                                    fontSize: 10, color: AppTheme.textMuted))),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('❌ Prohibited',
                                style: TextStyle(
                                    color: Color(0xFFEF4444),
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            ...[
                              'Plastic bags & wrap',
                              'Takeout cutlery & cups',
                              'Large hard bones',
                              'Excess soup / liquids',
                              'Metal, glass, foil',
                            ].map((item) => Text('• $item',
                                style: const TextStyle(
                                    fontSize: 10, color: AppTheme.textMuted))),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------
  // 2. Unlocking & countdown
  // -------------------------------------------------------------------

  Widget _buildUnlockingView() {
    final bin = ref.watch(agriStateProvider).bins
        .firstWhere((b) => b.id == _binId, orElse: () => ref.read(agriStateProvider).bins.first);

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: const BoxDecoration(
              gradient:
                  LinearGradient(colors: [Color(0xFF22C55E), Color(0xFF15803D)]),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.lock_open, size: 40, color: Colors.white),
          ),
          const SizedBox(height: 16),
          Text(
            'Bin ${bin.id} solenoid unlatched!',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            'Session $_sessionNonce · ${bin.location}',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
          ),
          const SizedBox(height: 6),
          const Text(
            'Open the lid, deposit food waste firmly, and close it tightly.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
          ),
          const SizedBox(height: 24),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF16221C),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFF59E0B), width: 3),
                  ),
                  child: Center(
                    child: Text(
                      '$_countdownSeconds',
                      style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Auto-relock countdown',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 13)),
                      SizedBox(height: 2),
                      Text('The scale settles automatically on reed switch closure.',
                          style:
                              TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.scale, size: 16, color: AppTheme.accentLime),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Expected load: ${_scenario == DepositScenario.tooLight ? 0.03 : _weightKg.toStringAsFixed(2)} kg',
                    style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                  ),
                ),
                Text(
                  'Session $_sessionNonce',
                  style: const TextStyle(
                      fontSize: 10, fontFamily: 'monospace',
                      color: AppTheme.accentLime),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _closeLidAndRecord,
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('Close lid & record deposit'),
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------
  // 3. Settling
  // -------------------------------------------------------------------

  Widget _buildSettlingView() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Color(0xFF22C55E)),
            SizedBox(height: 20),
            Text(
              'Settling load cell & running AI check',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'Stabilising the HX711 reading (std dev < 5 g) and verifying the ESP32-CAM snapshot against the food-only policy…',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
            ),
            SizedBox(height: 16),
            Text(
              'Validating: min weight · daily cap · cooldown · duplicate nonce · weight sanity',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 10, color: AppTheme.textSubtle),
            ),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------------
  // 4. Result
  // -------------------------------------------------------------------

  Widget _buildResultView() {
    final outcome = _outcome;
    if (outcome == null) return const SizedBox.shrink();

    final breakdown = outcome.breakdown;
    final blocked = outcome.findings.isNotEmpty &&
        outcome.findings.any((f) => f.blocksPoints);
    final contaminated = breakdown.tier == CleanlinessTier.contaminated;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                contaminated
                    ? '⚠️'
                    : (outcome.pointsAwarded > 0 ? '🎉' : 'ℹ️'),
                style: const TextStyle(fontSize: 28),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      contaminated
                          ? 'Contamination detected'
                          : (outcome.pointsAwarded > 0
                              ? 'Clean deposit verified!'
                              : 'Deposit recorded'),
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w800),
                    ),
                    Text(
                      'Bin $_binId · $_sessionNonce',
                      style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Weight delta
          Container(
            padding: const EdgeInsets.all(16),
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  (contaminated
                          ? const Color(0xFFEF4444)
                          : const Color(0xFF22C55E))
                      .withValues(alpha: 0.15),
                  const Color(0xFF143627).withValues(alpha: 0.4),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: (contaminated
                        ? const Color(0xFFEF4444)
                        : const Color(0xFF22C55E))
                    .withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              children: [
                const Text('NET ORGANIC WASTE DIVERTED',
                    style: TextStyle(
                        fontSize: 10,
                        letterSpacing: 0.5,
                        color: AppTheme.textMuted)),
                const SizedBox(height: 4),
                Text(
                  '+${breakdown.weightKg.toStringAsFixed(2)} kg',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: contaminated
                        ? const Color(0xFFEF4444)
                        : const Color(0xFF22C55E),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Confidence ${(breakdown.confidence * 100).round()}% · ${cleanlinessTierLabels[breakdown.tier]}',
                  style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Points breakdown from the rules engine
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Scoring breakdown',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 13)),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF16221C),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          outcome.source,
                          style: const TextStyle(
                              fontSize: 9,
                              fontFamily: 'monospace',
                              color: AppTheme.textMuted),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _breakdownRow('Base · 100 pts/kg × ${breakdown.weightKg.toStringAsFixed(2)} kg',
                      breakdown.basePoints),
                  _breakdownRow(
                      'Cleanliness multiplier × ${breakdown.cleanlinessMultiplier.toStringAsFixed(1)}',
                      (breakdown.basePoints * breakdown.cleanlinessMultiplier).round()),
                  _breakdownRow('Quality bonus', breakdown.qualityBonus),
                  _breakdownRow('Streak bonus', breakdown.streakBonus),
                  if (breakdown.cappedPoints > 0)
                    _breakdownRow('Clipped by daily cap',
                        -breakdown.cappedPoints, isNegative: true),
                  const Divider(color: Colors.white10, height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('POINTS AWARDED',
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textMuted)),
                      Text(
                        '+${outcome.pointsAwarded} pts',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: outcome.pointsAwarded > 0
                              ? const Color(0xFFFBBF24)
                              : AppTheme.textSubtle,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Deposit-to-reward latency',
                          style: TextStyle(
                              fontSize: 10, color: AppTheme.textSubtle)),
                      Text(
                        '${outcome.rewardLatencyMs} ms',
                        style: const TextStyle(
                            fontSize: 10,
                            fontFamily: 'monospace',
                            color: AppTheme.textMuted),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          if (outcome.findings.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: (blocked
                        ? const Color(0xFFEF4444)
                        : const Color(0xFFF59E0B))
                    .withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: (blocked
                          ? const Color(0xFFEF4444)
                          : const Color(0xFFF59E0B))
                      .withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        blocked ? Icons.block : Icons.info_outline,
                        size: 15,
                        color: blocked
                            ? const Color(0xFFFCA5A5)
                            : const Color(0xFFFBBF24),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        blocked
                            ? 'Deposit blocked by policy'
                            : 'Applied with adjustments',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: blocked
                              ? const Color(0xFFFCA5A5)
                              : const Color(0xFFFBBF24),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...outcome.findings.map((f) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('• ',
                                style: TextStyle(
                                    fontSize: 11, color: AppTheme.textMuted)),
                            Expanded(
                              child: Text(
                                f.detail,
                                style: const TextStyle(
                                    fontSize: 11, color: AppTheme.textMuted),
                              ),
                            ),
                          ],
                        ),
                      )),
                ],
              ),
            ),
          ],

          const SizedBox(height: 14),

          // Snapshot
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('ESP32-CAM snapshot',
                          style:
                              TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: (contaminated
                                  ? const Color(0xFFEF4444)
                                  : const Color(0xFFA3E635))
                              .withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${(breakdown.confidence * 100).round()}% confidence',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: contaminated
                                ? const Color(0xFFEF4444)
                                : const Color(0xFFA3E635),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.asset(
                      contaminated
                          ? 'assets/images/deposit_contaminated.jpg'
                          : 'assets/images/deposit_clean.jpg',
                      width: double.infinity,
                      height: 170,
                      fit: BoxFit.cover,
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (contaminated || outcome.pointsAwarded == 0) ...[
            const SizedBox(height: 14),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFFEF4444)),
              ),
              onPressed: () => _requestDispute(outcome),
              icon: const Icon(Icons.gavel, size: 16),
              label: const Text('Request operator dispute review'),
            ),
          ],

          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _resetToScanner,
              child: const Text('Return to scanner'),
            ),
          ),
        ],
      ),
    );
  }

  void _requestDispute(DepositOutcome outcome) {
    final record = outcome.record;
    if (record == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This deposit was blocked before recording.')),
      );
      return;
    }
    ref
        .read(agriStateProvider.notifier)
        .openDispute(record.id, 'Resident disputes the contamination flag.');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Dispute dispatched to the operator queue.')),
    );
  }

  Widget _breakdownRow(String label, int value, {bool isNegative = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
            ),
          ),
          Text(
            isNegative ? '$value' : '+$value',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              fontFamily: 'monospace',
              color: isNegative
                  ? const Color(0xFFFCA5A5)
                  : (value == 0
                      ? AppTheme.textSubtle
                      : const Color(0xFFA3E635)),
            ),
          ),
        ],
      ),
    );
  }
}
