import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../view_models/benchmark_view_model.dart';

class DeviceLibraryDialog extends StatefulWidget {
  const DeviceLibraryDialog({super.key});

  static Future<void> show(BuildContext context) async {
    final vm = Provider.of<BenchmarkViewModel>(context, listen: false);
    await showDialog<void>(
      context: context,
      builder: (ctx) => ChangeNotifierProvider<BenchmarkViewModel>.value(
        value: vm,
        child: const DeviceLibraryDialog(),
      ),
    );
  }

  @override
  State<DeviceLibraryDialog> createState() => _DeviceLibraryDialogState();
}

class _DeviceLibraryDialogState extends State<DeviceLibraryDialog>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final benchVm = context.watch<BenchmarkViewModel>();

    final discovered = benchVm.discoveredNodes.where((n) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return n.ip.toLowerCase().contains(q) ||
          n.hostname.toLowerCase().contains(q);
    }).toList();

    // Group historical unique targets
    final Map<String, int> historicalTargets = {};
    for (final run in benchVm.historicalRuns) {
      historicalTargets[run.targetHost] = run.port;
    }
    final historyList = historicalTargets.entries.where((e) {
      if (_searchQuery.isEmpty) return true;
      return e.key.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    return Dialog(
      backgroundColor: AppTheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: AppTheme.border),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 600),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  const Icon(Icons.devices, color: AppTheme.primaryLight, size: 22),
                  const SizedBox(width: 10),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'DEVICE & TARGET LIBRARY',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.6,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'Select discovered network nodes or historical targets for benchmarking',
                        style: TextStyle(fontSize: 11, color: Colors.white54),
                      ),
                    ],
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Search bar and Subnet Scan action
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 34,
                      child: TextField(
                        controller: _searchController,
                        style: const TextStyle(fontSize: 12),
                        decoration: InputDecoration(
                          hintText: 'Search IP, hostname...',
                          hintStyle:
                              const TextStyle(fontSize: 11, color: Colors.white30),
                          prefixIcon: const Icon(Icons.search, size: 14),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 12),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _searchQuery = '');
                                  },
                                )
                              : null,
                          contentPadding: EdgeInsets.zero,
                        ),
                        onChanged: (val) =>
                            setState(() => _searchQuery = val.trim()),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6)),
                    ),
                    onPressed: benchVm.isScanningSubnet
                        ? null
                        : () => benchVm.triggerSubnetScan(),
                    icon: benchVm.isScanningSubnet
                        ? const SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.radar, size: 14),
                    label: Text(
                      benchVm.isScanningSubnet ? 'Scanning...' : 'Scan Subnet',
                      style: const TextStyle(
                          fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Tabs
              TabBar(
                controller: _tabController,
                indicatorColor: AppTheme.primaryLight,
                labelColor: AppTheme.primaryLight,
                unselectedLabelColor: Colors.white60,
                labelStyle:
                    const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                tabs: [
                  Tab(text: 'DISCOVERED NODES (${discovered.length})'),
                  Tab(text: 'HISTORICAL TARGETS (${historyList.length})'),
                ],
              ),
              const SizedBox(height: 8),

              // Tab contents
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // Discovered Nodes
                    discovered.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.wifi_tethering_off,
                                    size: 40, color: Colors.white24),
                                const SizedBox(height: 8),
                                const Text(
                                  'No discovered nodes found',
                                  style: TextStyle(
                                      fontSize: 12, color: Colors.white60),
                                ),
                                const SizedBox(height: 4),
                                TextButton.icon(
                                  onPressed: () => benchVm.triggerSubnetScan(),
                                  icon: const Icon(Icons.radar, size: 14),
                                  label: const Text('Start Subnet Scan',
                                      style: TextStyle(fontSize: 11)),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            itemCount: discovered.length,
                            separatorBuilder: (context, index) =>
                                const Divider(height: 1, color: AppTheme.border),
                            itemBuilder: (ctx, idx) {
                              final node = discovered[idx];
                              return ListTile(
                                dense: true,
                                visualDensity: VisualDensity.compact,
                                leading: const Icon(Icons.dns_outlined,
                                    color: AppTheme.primaryLight, size: 20),
                                title: Text(
                                  node.displayName,
                                  style: const TextStyle(
                                      fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                                subtitle: Text(
                                  'Port: ${node.port} • Type: ${node.discoveryType}${node.latencyMs != null ? " • Latency: ${node.latencyMs}ms" : ""}',
                                  style: const TextStyle(
                                      fontSize: 10.5, color: Colors.white54),
                                ),
                                trailing: FilledButton.tonal(
                                  style: FilledButton.styleFrom(
                                    visualDensity: VisualDensity.compact,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 4),
                                  ),
                                  onPressed: () {
                                    benchVm.selectDiscoveredNode(node);
                                    Navigator.of(context).pop();
                                  },
                                  child: const Text('Use Target',
                                      style: TextStyle(fontSize: 11)),
                                ),
                              );
                            },
                          ),

                    // Historical Targets
                    historyList.isEmpty
                        ? const Center(
                            child: Text(
                              'No historical targets recorded yet',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.white60),
                            ),
                          )
                        : ListView.separated(
                            itemCount: historyList.length,
                            separatorBuilder: (context, index) =>
                                const Divider(height: 1, color: AppTheme.border),
                            itemBuilder: (ctx, idx) {
                              final entry = historyList[idx];
                              return ListTile(
                                dense: true,
                                visualDensity: VisualDensity.compact,
                                leading: const Icon(Icons.history,
                                    color: Colors.white60, size: 20),
                                title: Text(
                                  '${entry.key}:${entry.value}',
                                  style: AppTheme.monoStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold),
                                ),
                                trailing: FilledButton.tonal(
                                  style: FilledButton.styleFrom(
                                    visualDensity: VisualDensity.compact,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 4),
                                  ),
                                  onPressed: () {
                                    benchVm.setTargetHost(entry.key);
                                    benchVm.setPort(entry.value);
                                    Navigator.of(context).pop();
                                  },
                                  child: const Text('Use Target',
                                      style: TextStyle(fontSize: 11)),
                                ),
                              );
                            },
                          ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
