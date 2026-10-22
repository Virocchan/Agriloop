import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/all_models.dart';
import '../../providers/app_state_provider.dart';
import 'dispute_queue_tab.dart';
import 'impact_tab.dart';

class OperatorDashboardScreen extends ConsumerStatefulWidget {
  const OperatorDashboardScreen({super.key});

  @override
  ConsumerState<OperatorDashboardScreen> createState() =>
      _OperatorDashboardScreenState();
}

class _OperatorDashboardScreenState extends ConsumerState<OperatorDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _compostKgController = TextEditingController(text: '25');
  final _compostNoteController = TextEditingController();
  String _compostLocation = 'Central Community Planter #3';
  String? _compostBatchId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _compostKgController.dispose();
    _compostNoteController.dispose();
    super.dispose();
  }

  void _remoteUnlockBin(String binId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF16221C),
        title: Text('Remote unlock bin $binId?'),
        content: const Text(
          'Sends an encrypted MQTT command to the ESP32 DevKit over TLS. The solenoid latch unlatches and auto-relocks in 60 seconds.',
          style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentCoral),
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Text('Bin $binId solenoid unlatched remotely via MQTT.')),
              );
            },
            child: const Text('Confirm unlock'),
          ),
        ],
      ),
    );
  }

  void _submitCompostLog() {
    final kg = double.tryParse(_compostKgController.text) ?? 20.0;
    ref.read(agriStateProvider.notifier).addCompostLog(
          kg,
          _compostLocation,
          batchId: _compostBatchId,
          note: _compostNoteController.text.trim(),
        );
    _compostNoteController.clear();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content:
            Text('Logged $kg kg returned to $_compostLocation! Resident meters updated.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(agriStateProvider);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('🛠️ Operator control hub',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            Text('Sime Darby Elmina cluster · ${state.bins.length} bins online',
                style: const TextStyle(fontSize: 10, color: AppTheme.accentLime)),
          ],
        ),
        actions: [
          TextButton.icon(
            icon: const Text('🏡'),
            label:
                const Text('Resident mode', style: TextStyle(color: AppTheme.primaryGlow, fontSize: 11)),
            onPressed: () {
              ref.read(agriStateProvider.notifier).switchRole(UserRole.resident);
              context.go('/home');
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primaryGlow,
          labelColor: AppTheme.primaryGlow,
          unselectedLabelColor: AppTheme.textMuted,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: [
            Tab(text: 'Bins (${state.bins.length})'),
            Tab(text: 'Tasks (${state.tasks.length})'),
            Tab(text: 'Batches (${state.batches.length})'),
            Tab(text: 'Disputes (${state.openDisputeCount})'),
            const Tab(text: 'Compost log'),
            const Tab(text: 'Impact'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // ---- TAB 1: Bins fleet ---------------------------------------
          ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: state.bins.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, idx) {
              final bin = state.bins[idx];
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(bin.name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold, fontSize: 13)),
                              Text(bin.location,
                                  style: const TextStyle(
                                      fontSize: 10, color: AppTheme.textMuted)),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: (bin.isOnline
                                      ? AppTheme.primaryGlow
                                      : AppTheme.accentCoral)
                                  .withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              bin.isOnline ? '● ONLINE (MQTT)' : '● OFFLINE',
                              style: TextStyle(
                                fontSize: 9,
                                color: bin.isOnline
                                    ? AppTheme.primaryGlow
                                    : AppTheme.accentCoral,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.black26,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildMetricCol(
                                'WEIGHT', '${bin.weightKg.toStringAsFixed(2)} kg'),
                            _buildMetricCol('FILL', '${bin.fillPct}%'),
                            _buildMetricCol('TEMP', '${bin.tempC}°C'),
                            _buildMetricCol('LOCK', bin.lockState.toUpperCase(),
                                isGreen: true),
                          ],
                        ),
                      ),
                      if (bin.fillPct >= 85) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppTheme.accentAmber.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: AppTheme.accentAmber
                                    .withValues(alpha: 0.3)),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.warning_amber_rounded,
                                  size: 14, color: Color(0xFFFBBF24)),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Bucket near capacity — new deposits will be refused until the bucket is swapped.',
                                  style: TextStyle(
                                      fontSize: 10, color: Color(0xFFFDE68A)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFF25392E)),
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            ),
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content: Text(
                                        'Pinged bin ${bin.id}: RSSI ${bin.rssi} dBm, Wi-Fi OK')),
                              );
                            },
                            child: const Text('Ping ESP32',
                                style: TextStyle(fontSize: 11, color: Colors.white)),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFF25392E)),
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            ),
                            onPressed: () {
                              ref
                                  .read(agriStateProvider.notifier)
                                  .sealBatch(bin.id);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content: Text(
                                        'Sealed a new Bokashi batch from bin ${bin.id}.')),
                              );
                            },
                            child: const Text('Seal bucket',
                                style: TextStyle(fontSize: 11, color: Colors.white)),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  AppTheme.accentCoral.withValues(alpha: 0.2),
                              side: const BorderSide(color: AppTheme.accentCoral),
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            ),
                            onPressed: () => _remoteUnlockBin(bin.id),
                            child: const Text('Unlock lid',
                                style:
                                    TextStyle(fontSize: 11, color: Color(0xFFFCA5A5))),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          // ---- TAB 2: Tasks --------------------------------------------
          ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: state.tasks.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, idx) {
              final task = state.tasks[idx];
              return Card(
                child: ListTile(
                  title: Text('${task.title} [Bin ${task.binId}]',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 13)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(task.description,
                          style: const TextStyle(
                              fontSize: 11, color: AppTheme.textMuted)),
                      const SizedBox(height: 2),
                      Text(
                        'Priority ${task.priority} · source ${task.source} · ${Fmt.relative(task.createdAt)}',
                        style: const TextStyle(
                            fontSize: 9, color: AppTheme.textSubtle),
                      ),
                    ],
                  ),
                  trailing: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                    ),
                    onPressed: () {
                      ref
                          .read(agriStateProvider.notifier)
                          .completeTask(task.id);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Task "${task.title}" completed.')),
                      );
                    },
                    child: const Text('Done', style: TextStyle(fontSize: 11)),
                  ),
                ),
              );
            },
          ),

          // ---- TAB 3: Bokashi batches -----------------------------------
          ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: state.batches.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, idx) {
              final b = state.batches[idx];
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('${b.id} (${b.binSource})',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 13)),
                          Text('Day ${b.dayCurrent} of ${b.dayTotal}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.accentLime,
                                  fontSize: 11)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: b.progress,
                          backgroundColor: Colors.white10,
                          color: const Color(0xFF10B981),
                          minHeight: 6,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Sealed: ${Fmt.date(b.sealedDate)}',
                              style: const TextStyle(
                                  fontSize: 10, color: AppTheme.textSubtle)),
                          Text('Status: ${b.status}',
                              style: const TextStyle(
                                  fontSize: 10, color: Color(0xFF86EFAC))),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          // ---- TAB 4: Disputes ------------------------------------------
          const DisputeQueueTab(),

          // ---- TAB 5: Compost log ----------------------------------------
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Log compost return to community park',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 14)),
                        const SizedBox(height: 4),
                        const Text(
                          'Published logs immediately increment resident community impact meters and send celebration alerts.',
                          style: TextStyle(
                              fontSize: 11, color: AppTheme.textMuted),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _compostKgController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Compost weight returned (kg)',
                          ),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: _compostLocation,
                          decoration: const InputDecoration(
                              labelText: 'Destination planter / garden'),
                          dropdownColor: const Color(0xFF16221C),
                          items: const [
                            DropdownMenuItem(
                                value: 'Central Community Planter #3',
                                child: Text('Central Community Planter #3')),
                            DropdownMenuItem(
                                value: 'Elmina Valley North Herbal Garden',
                                child: Text('Elmina Valley North Herbal Garden')),
                            DropdownMenuItem(
                                value: 'Block B Landscaped Fruit Trees',
                                child: Text('Block B Landscaped Fruit Trees')),
                          ],
                          onChanged: (val) =>
                              setState(() => _compostLocation = val!),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String?>(
                          initialValue: _compostBatchId,
                          decoration: const InputDecoration(
                              labelText: 'Source batch (optional)'),
                          dropdownColor: const Color(0xFF16221C),
                          items: [
                            const DropdownMenuItem<String?>(
                                value: null, child: Text('Unassigned')),
                            ...state.batches.map((b) => DropdownMenuItem<String?>(
                                  value: b.id,
                                  child: Text('${b.id} · ${b.status}'),
                                )),
                          ],
                          onChanged: (val) =>
                              setState(() => _compostBatchId = val),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _compostNoteController,
                          style: const TextStyle(fontSize: 12),
                          decoration: const InputDecoration(
                            labelText: 'Note (e.g. cure complete, buried at 20 cm)',
                          ),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _submitCompostLog,
                            icon: const Icon(Icons.park, size: 18),
                            label: const Text(
                                'Publish compost milestone to residents'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Compost return history',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 14)),
                            Text(
                              '${state.communityCompostCurrentKg.toStringAsFixed(0)} kg total',
                              style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.accentLime),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        if (state.compostApplications.isEmpty)
                          const Text('No compost returned yet.',
                              style: TextStyle(
                                  fontSize: 11, color: AppTheme.textMuted))
                        else
                          ...state.compostApplications.map((c) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Row(
                                  children: [
                                    const Icon(Icons.park,
                                        size: 14, color: Color(0xFF10B981)),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '${c.kg.toStringAsFixed(0)} kg → ${c.location}',
                                            style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600),
                                          ),
                                          if (c.note.isNotEmpty)
                                            Text(c.note,
                                                style: const TextStyle(
                                                    fontSize: 10,
                                                    color: AppTheme.textMuted)),
                                          Text(
                                            '${Fmt.date(c.timestamp)}${c.batchId == null ? '' : ' · ${c.batchId}'}',
                                            style: const TextStyle(
                                                fontSize: 9,
                                                color: AppTheme.textSubtle),
                                          ),
                                        ],
                                      ),
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

          // ---- TAB 6: Impact --------------------------------------------
          const ImpactTab(),
        ],
      ),
    );
  }

  Widget _buildMetricCol(String label, String val, {bool isGreen = false}) {
    return Column(
      children: [
        Text(label,
            style: const TextStyle(fontSize: 9, color: AppTheme.textMuted)),
        const SizedBox(height: 2),
        Text(
          val,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            fontFamily: 'monospace',
            color: isGreen ? AppTheme.primaryGlow : Colors.white,
          ),
        ),
      ],
    );
  }
}
