import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:net_bench/domain/models/benchmark_preset.dart';
import 'package:net_bench/domain/models/benchmark_result.dart';
import 'package:net_bench/domain/models/discovered_node.dart';
import 'package:net_bench/domain/models/network_adapter.dart';
import 'package:net_bench/ui/theme/app_theme.dart';
import 'package:net_bench/ui/view_models/benchmark_view_model.dart';
import 'package:net_bench/ui/view_models/server_view_model.dart';
import 'package:net_bench/ui/views/dialogs/device_library_dialog.dart';
import 'package:net_bench/ui/views/dialogs/installation_guide_dialog.dart';
import 'package:net_bench/ui/views/dialogs/settings_dialog.dart';
import 'package:net_bench/ui/views/widgets/chart/live_throughput_chart.dart';
import 'package:net_bench/ui/views/widgets/common/command_preview_card.dart';
import 'package:net_bench/ui/views/widgets/common/status_badge.dart';
import 'package:net_bench/ui/views/widgets/discovery/discovered_nodes_bar.dart';
import 'package:net_bench/ui/views/widgets/gauge/throughput_gauge_widget.dart';
import 'package:net_bench/ui/views/widgets/history/comparison_matrix_card.dart';
import 'package:net_bench/ui/views/widgets/history/history_data_table.dart';
import 'package:net_bench/ui/views/widgets/server/server_monitor_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _targetHostController = TextEditingController();
  final TextEditingController _portController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  static final DateFormat _dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tabController = TabController(length: 3, vsync: this);

    final vm = Provider.of<BenchmarkViewModel>(context, listen: false);
    _targetHostController.text = vm.config.targetHost;
    _portController.text = vm.config.port.toString();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tabController.dispose();
    _targetHostController.dispose();
    _portController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  /// Intercepts window exit to guarantee clean socket & process termination.
  @override
  Future<AppExitResponse> didRequestAppExit() async {
    final benchVm = Provider.of<BenchmarkViewModel>(context, listen: false);
    final serverVm = Provider.of<ServerViewModel>(context, listen: false);

    if (benchVm.isRunning) {
      benchVm.stopBenchmark();
    }
    if (serverVm.isRunning) {
      await serverVm.stopServer();
    }

    return AppExitResponse.exit;
  }

  void _openSettings(BenchmarkViewModel vm) {
    showDialog(
      context: context,
      builder: (_) => SettingsDialog(viewModel: vm),
    );
  }

  void _openInstallGuide(BenchmarkViewModel vm) {
    showDialog(
      context: context,
      builder: (_) => InstallationGuideDialog(viewModel: vm),
    );
  }

  void _openDeviceLibrary(BenchmarkViewModel vm) {
    DeviceLibraryDialog.show(context);
  }

  @override
  Widget build(BuildContext context) {
    final benchVm = context.watch<BenchmarkViewModel>();
    final serverVm = context.watch<ServerViewModel>();

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Tier 1: Top Control Bar
            _buildTopControlBar(benchVm, serverVm),
            const Divider(height: 1),

            // Tier 2: Global Alert / Status Banner (Conditional)
            _buildGlobalAlertBanner(benchVm),

            // Tier 3: Filter & Triage Toolbar
            _buildTriageToolbar(benchVm),
            const Divider(height: 1),

            // Tier 4: Primary Data Workspace (Expanded)
            Expanded(
              child: TabBarView(
                controller: _tabController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  // Tab 0: Live Benchmark Workspace
                  _buildLiveBenchmarkWorkspace(benchVm),
                  // Tab 1: Historical Runs & Comparison Table
                  _buildHistoryWorkspace(benchVm),
                  // Tab 2: Server Daemon Monitor
                  _buildServerWorkspace(serverVm, benchVm),
                ],
              ),
            ),

            const Divider(height: 1),

            // Tier 5: Collapsible Detail Inspector & Persistent Status Bar
            _buildDetailInspectorAndStatusBar(benchVm),
          ],
        ),
      ),
    );
  }

  // Tier 1: Top Control Bar (Standardized 52px 5-Zone Architecture)
  Widget _buildTopControlBar(
      BenchmarkViewModel benchVm, ServerViewModel serverVm) {
    final isServerActive = serverVm.isRunning;

    return Container(
      height: 52,
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E1E),
        border: Border(bottom: BorderSide(color: Color(0xFF2C2C2C), width: 1)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final availWidth =
              constraints.maxWidth.isFinite ? constraints.maxWidth : 1280.0;
          const minRequiredWidth = 2500.0;
          final contentWidth =
              availWidth > minRequiredWidth ? availWidth : minRequiredWidth;

          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              width: contentWidth - 32,
              height: 52,
              child: Row(
                children: [
                  // ==================== ZONE 1: BRANDING ====================
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppTheme.border),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Image.asset(
                      'assets/icons/app_icon.png',
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(Icons.speed,
                            color: AppTheme.primaryLight, size: 18),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'NET-BENCH',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'Local Network Benchmarker & iPerf3 Station',
                        style: TextStyle(fontSize: 10, color: Colors.white54),
                      ),
                    ],
                  ),
                  const SizedBox(width: 16),

                  // ==================== ZONE 2: INTERFACE & TARGET ====================
                  Container(
                    height: 32,
                    width: 190,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF252526),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFF3E3E42)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: () {
                          final current =
                              benchVm.config.bindAddress ?? '0.0.0.0';
                          final items = benchVm.availableAdapters.toList();
                          if (items.any((a) => a.ipAddress == current)) {
                            return current;
                          }
                          return '0.0.0.0';
                        }(),
                        isDense: true,
                        icon: const Icon(Icons.arrow_drop_down, size: 18),
                        dropdownColor: const Color(0xFF252526),
                        style:
                            const TextStyle(fontSize: 11, color: Colors.white70),
                        onChanged: benchVm.isRunning
                            ? null
                            : (val) => benchVm.setBindAddress(val),
                        items: () {
                          final items = benchVm.availableAdapters.toList();
                          if (benchVm.config.bindAddress != null &&
                              !items.any((a) =>
                                  a.ipAddress == benchVm.config.bindAddress)) {
                            items.add(NetworkAdapter(
                              name: 'Custom',
                              ipAddress: benchVm.config.bindAddress!,
                            ));
                          }
                          return items.map((adapter) {
                            return DropdownMenuItem<String>(
                              value: adapter.ipAddress,
                              child: Row(
                                children: [
                                  const Icon(Icons.settings_ethernet,
                                      size: 14, color: AppTheme.primaryLight),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      adapter.displayName,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          fontSize: 11, color: Colors.white),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList();
                        }(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.refresh, size: 16),
                    tooltip: 'Refresh Interfaces',
                    visualDensity: VisualDensity.compact,
                    onPressed:
                        benchVm.isRunning ? null : () => benchVm.loadAdapters(),
                  ),
                  const SizedBox(width: 10),

                  // Workspace Tab Switcher
                  Container(
                    height: 30,
                    decoration: BoxDecoration(
                      color: AppTheme.scaffoldBg,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: TabBar(
                      controller: _tabController,
                      isScrollable: true,
                      tabAlignment: TabAlignment.start,
                      indicatorSize: TabBarIndicatorSize.tab,
                      indicator: BoxDecoration(
                        color: AppTheme.primary,
                        borderRadius: BorderRadius.circular(5),
                      ),
                      dividerColor: Colors.transparent,
                      labelPadding:
                          const EdgeInsets.symmetric(horizontal: 10),
                      labelStyle: const TextStyle(
                          fontSize: 11, fontWeight: FontWeight.bold),
                      unselectedLabelColor: Colors.white60,
                      labelColor: Colors.white,
                      tabs: [
                        const Tab(text: 'LIVE BENCHMARK'),
                        Tab(text: 'HISTORY (${benchVm.historicalRuns.length})'),
                        Tab(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('SERVER DAEMON'),
                              if (isServerActive) ...[
                                const SizedBox(width: 6),
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: const BoxDecoration(
                                    color: AppTheme.success,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),

                  // ==================== ZONE 3: PRIMARY ACTIONS ====================
                  FilledButton.icon(
                    onPressed: () {
                      if (benchVm.isRunning) {
                        benchVm.stopBenchmark();
                      } else {
                        benchVm.startBenchmark();
                      }
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: benchVm.isRunning
                          ? const Color(0xFFEF4444) // Active Red
                          : const Color(0xFF10B981), // Idle Emerald Green (from ARP Scout)
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6)),
                    ),
                    icon: Icon(
                      benchVm.isRunning ? Icons.stop : Icons.play_arrow,
                      size: 17,
                    ),
                    label: Text(
                      benchVm.isRunning ? 'STOP' : 'START TEST',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Server Quick Pill
                  InkWell(
                    onTap: () => serverVm.toggleServer(),
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 7),
                      decoration: BoxDecoration(
                        color: isServerActive
                            ? AppTheme.success.withValues(alpha: 0.15)
                            : AppTheme.surfaceHighest,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isServerActive
                              ? AppTheme.success
                              : AppTheme.border,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isServerActive
                                ? Icons.radio_button_checked
                                : Icons.dns,
                            size: 13,
                            color: isServerActive
                                ? AppTheme.success
                                : Colors.white60,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            isServerActive
                                ? (serverVm.state.isSimulated
                                    ? 'SERVER: DEMO'
                                    : 'SERVER ON :${serverVm.port}')
                                : 'SERVER OFF',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                              color: isServerActive
                                  ? AppTheme.success
                                  : Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const Spacer(),

                  // ==================== ZONE 4: ECOSYSTEM & DEMO ====================
                  // Device Library
                  OutlinedButton.icon(
                    onPressed: () => _openDeviceLibrary(benchVm),
                    icon: const Icon(Icons.devices, size: 15),
                    label: const Text('Device Library',
                        style: TextStyle(fontSize: 11)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6)),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Load Demo
                  OutlinedButton.icon(
                    onPressed: benchVm.isRunning
                        ? null
                        : () => benchVm.setDemoMode(!benchVm.isDemoMode),
                    icon: const Icon(Icons.play_circle_outline, size: 15),
                    label: Text(
                      benchVm.isDemoMode ? 'Demo Active' : 'Load Demo',
                      style: TextStyle(
                        fontSize: 11,
                        color: benchVm.isDemoMode ? AppTheme.warning : null,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6)),
                      side: benchVm.isDemoMode
                          ? const BorderSide(color: AppTheme.warning)
                          : null,
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Binary or Demo Pill
                  StatusBadge(
                    label: benchVm.isDemoMode
                        ? 'DEMO'
                        : (benchVm.binaryInfo.isAvailable
                            ? 'IPERF3'
                            : 'NO BINARY'),
                    color: benchVm.isDemoMode
                        ? AppTheme.warning
                        : (benchVm.binaryInfo.isAvailable
                            ? AppTheme.success
                            : AppTheme.error),
                    icon: benchVm.isDemoMode
                        ? Icons.science
                        : (benchVm.binaryInfo.isAvailable
                            ? Icons.check
                            : Icons.error_outline),
                  ),
                  const SizedBox(width: 4),

                  // Help & Settings
                  IconButton(
                    icon: const Icon(Icons.help_outline, size: 16),
                    tooltip: 'iPerf3 Installation Guide & Help',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _openInstallGuide(benchVm),
                  ),
                  IconButton(
                    icon: const Icon(Icons.settings, size: 16),
                    tooltip: 'Settings',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _openSettings(benchVm),
                  ),
                  const SizedBox(width: 8),

                  // ==================== ZONE 5: CLEAR & EXPORT ====================
                  OutlinedButton.icon(
                    onPressed:
                        (benchVm.isRunning || benchVm.historicalRuns.isEmpty)
                            ? null
                            : () => benchVm.clearAllHistory(),
                    icon: const Icon(Icons.delete_sweep_outlined, size: 15),
                    label: const Text('Clear', style: TextStyle(fontSize: 11)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6)),
                    ),
                  ),
                  const SizedBox(width: 8),

                  PopupMenuButton<String>(
                    tooltip: 'Export',
                    enabled: benchVm.historicalRuns.isNotEmpty ||
                        benchVm.lastCompletedResult != null,
                    onSelected: (val) {
                      final target = benchVm.selectedInspectorRecord ??
                          benchVm.lastCompletedResult ??
                          (benchVm.historicalRuns.isNotEmpty
                              ? benchVm.historicalRuns.first
                              : null);
                      if (target == null) return;
                      if (val == 'csv') {
                        benchVm.exportCsv(target);
                      } else if (val == 'json') {
                        benchVm.exportJson(target);
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: 'csv',
                        child: Row(
                          children: [
                            Icon(Icons.table_chart_outlined, size: 15),
                            SizedBox(width: 8),
                            Text('Export CSV', style: TextStyle(fontSize: 11)),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'json',
                        child: Row(
                          children: [
                            Icon(Icons.code, size: 15),
                            SizedBox(width: 8),
                            Text('Export JSON', style: TextStyle(fontSize: 11)),
                          ],
                        ),
                      ),
                    ],
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 7),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFF2C2C2C)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.download, size: 15, color: Colors.white70),
                          SizedBox(width: 6),
                          Text('Export',
                              style: TextStyle(
                                  fontSize: 11, color: Colors.white70)),
                          Icon(Icons.arrow_drop_down,
                              size: 14, color: Colors.white70),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // Tier 2: Global Alert Banner (Conditional)
  Widget _buildGlobalAlertBanner(BenchmarkViewModel benchVm) {
    if (benchVm.isRunning) {
      return Container(
        height: 32,
        color: AppTheme.success.withValues(alpha: 0.15),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            const SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppTheme.success,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'BENCHMARK IN PROGRESS: Testing ${benchVm.config.targetHost} (${benchVm.config.protocol.toUpperCase()}) ...',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: AppTheme.success,
              ),
            ),
            const Spacer(),
            Text(
              'Instant: ${benchVm.instantThroughputMbps.toStringAsFixed(1)} Mbps | Elapsed: ${benchVm.currentSample?.secondsElapsed.toInt() ?? 0}s / ${benchVm.config.durationSeconds}s',
              style: AppTheme.monoStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    if (!benchVm.binaryInfo.isAvailable && !benchVm.isDemoMode) {
      return Container(
        height: 34,
        color: AppTheme.warning.withValues(alpha: 0.15),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              const Icon(Icons.warning_amber, size: 15, color: AppTheme.warning),
              const SizedBox(width: 8),
              const Text(
                'iPerf3 executable not detected on system PATH. Enable Demo Mode or configure custom binary.',
                style: TextStyle(fontSize: 11, color: Colors.white),
              ),
              const SizedBox(width: 16),
              TextButton(
                style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                onPressed: () => benchVm.setDemoMode(true),
                child: const Text('ENABLE DEMO MODE',
                    style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.warning)),
              ),
              const SizedBox(width: 8),
              TextButton(
                style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                onPressed: () => _openSettings(benchVm),
                child: const Text('CONFIGURE PATH',
                    style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryLight)),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                onPressed: () => _openInstallGuide(benchVm),
                icon: const Icon(Icons.download_for_offline,
                    size: 13, color: AppTheme.success),
                label: const Text('HOW TO INSTALL',
                    style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.success)),
              ),
            ],
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  // Tier 3: Filter & Triage Toolbar
  Widget _buildTriageToolbar(BenchmarkViewModel benchVm) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      color: AppTheme.surfaceHigh,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // Search Input
            SizedBox(
              width: 180,
              height: 32,
              child: TextField(
                controller: _searchController,
                style: const TextStyle(fontSize: 11),
                decoration: InputDecoration(
                  hintText: 'Search target / profile...',
                  hintStyle: const TextStyle(fontSize: 11, color: Colors.white24),
                  prefixIcon: const Icon(Icons.search, size: 14),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 12),
                          onPressed: () {
                            _searchController.clear();
                            benchVm.setSearchQuery('');
                          },
                        )
                      : null,
                ),
                onChanged: (val) => benchVm.setSearchQuery(val),
              ),
            ),
            const SizedBox(width: 12),

            // Protocol Filter Chips
            ...['ALL', 'TCP', 'UDP'].map((proto) {
              final isSelected = benchVm.protocolFilter == proto;
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  label: Text(proto),
                  selected: isSelected,
                  labelStyle: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.white : Colors.white60,
                  ),
                  selectedColor: AppTheme.primary,
                  backgroundColor: AppTheme.surfaceHighest,
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
                  visualDensity: VisualDensity.compact,
                  side: BorderSide(
                      color: isSelected ? AppTheme.primary : AppTheme.border),
                  onSelected: (_) => benchVm.setProtocolFilter(proto),
                ),
              );
            }),

            const SizedBox(width: 8),
            const SizedBox(
              height: 24,
              child: VerticalDivider(width: 1, indent: 4, endIndent: 4),
            ),
            const SizedBox(width: 8),

            // Preset Chips
            Row(
              children: BenchmarkPreset.defaultPresets.map((preset) {
                final isSelected = benchVm.selectedPreset?.id == preset.id;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ActionChip(
                    label: Text(preset.name),
                    labelStyle: TextStyle(
                      fontSize: 10.5,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? AppTheme.primaryLight : Colors.white70,
                    ),
                    backgroundColor: isSelected
                        ? AppTheme.primary.withValues(alpha: 0.2)
                        : AppTheme.surfaceHighest,
                    side: BorderSide(
                      color:
                          isSelected ? AppTheme.primary : AppTheme.border,
                    ),
                    visualDensity: VisualDensity.compact,
                    onPressed: () => benchVm.selectPreset(preset),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(width: 10),

            // Clear Filters
            if (benchVm.searchQuery.isNotEmpty || benchVm.protocolFilter != 'ALL')
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: TextButton.icon(
                  style:
                      TextButton.styleFrom(visualDensity: VisualDensity.compact),
                  onPressed: () {
                    _searchController.clear();
                    benchVm.clearFilters();
                  },
                  icon: const Icon(Icons.filter_alt_off, size: 12),
                  label: const Text('CLEAR FILTERS',
                      style: TextStyle(fontSize: 10, color: Colors.white70)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // Tier 4, Tab 0: Live Benchmark Workspace
  Widget _buildLiveBenchmarkWorkspace(BenchmarkViewModel benchVm) {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        children: [
          // Subnet Discovery Bar
          DiscoveredNodesBar(
            nodes: benchVm.discoveredNodes,
            isScanning: benchVm.isScanningSubnet,
            currentTargetHost: benchVm.config.targetHost,
            onScanTriggered: () => benchVm.triggerSubnetScan(),
            onNodeSelected: (DiscoveredNode node) {
              benchVm.selectDiscoveredNode(node);
              _targetHostController.text = node.ip;
              _portController.text = node.port.toString();
            },
          ),
          const SizedBox(height: 10),

          // Main Visual Grid: Left Configuration & Live Gauges, Right Live Graph
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left Column: Configuration Sidebar + Throughput Gauge
                SizedBox(
                  width: 340,
                  child: Column(
                    children: [
                      // Radial Gauge
                      ThroughputGaugeWidget(
                        currentSpeedMbps: benchVm.instantThroughputMbps,
                        peakSpeedMbps: benchVm.peakThroughputMbps,
                        avgSpeedMbps: benchVm.avgThroughputMbps,
                        isUdp: benchVm.config.isUdp,
                      ),
                      const SizedBox(height: 10),
                      // Target Configuration Card
                      Expanded(
                        child: _buildTargetConfigCard(benchVm),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),

                // Right Column: Live Area Graph + Real-Time Metric Tiles
                Expanded(
                  child: Column(
                    children: [
                      // Live Area Chart
                      Expanded(
                        child: LiveThroughputChart(
                          samples: benchVm.liveSamples,
                          isUdp: benchVm.config.isUdp,
                          isBufferbloat: benchVm.selectedPreset?.isBufferbloatPreset ?? false,
                        ),
                      ),
                      const SizedBox(height: 10),
                      // Real-time KPI Metric Tiles
                      _buildRealtimeKpiGrid(benchVm),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTargetConfigCard(BenchmarkViewModel benchVm) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.border),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.tune, size: 14, color: AppTheme.primaryLight),
                const SizedBox(width: 6),
                const Text(
                  'TEST CONFIG',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                    color: Colors.white70,
                  ),
                ),
                const Spacer(),
                Flexible(
                  child: Text(
                    benchVm.selectedPreset?.name ?? 'Custom',
                    style: const TextStyle(
                        fontSize: 10, color: AppTheme.primaryLight),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Host & Port Row
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _targetHostController,
                    enabled: !benchVm.isRunning,
                    style: AppTheme.monoStyle(fontSize: 11),
                    decoration: const InputDecoration(
                      labelText: 'TARGET HOST / IP',
                      labelStyle: TextStyle(fontSize: 10),
                    ),
                    onChanged: (val) => benchVm.setTargetHost(val),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _portController,
                    enabled: !benchVm.isRunning,
                    style: AppTheme.monoStyle(fontSize: 11),
                    decoration: const InputDecoration(
                      labelText: 'PORT',
                      labelStyle: TextStyle(fontSize: 10),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (val) {
                      final p = int.tryParse(val);
                      if (p != null) benchVm.setPort(p);
                    },
                  ),
                ),
              ],
            ),
            if (benchVm.validationError != null) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.error.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: AppTheme.error.withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, size: 14, color: AppTheme.error),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        benchVm.validationError!,
                        style: const TextStyle(fontSize: 10.5, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 10),
            // Protocol & Streams Row
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    key: ValueKey('proto_${benchVm.config.protocol}'),
                    isExpanded: true,
                    initialValue: benchVm.config.protocol,
                    decoration: const InputDecoration(
                      labelText: 'PROTOCOL',
                      labelStyle: TextStyle(fontSize: 10),
                    ),
                    dropdownColor: AppTheme.surfaceHigh,
                    style: AppTheme.monoStyle(fontSize: 11),
                    items: const [
                      DropdownMenuItem(value: 'tcp', child: Text('TCP')),
                      DropdownMenuItem(value: 'udp', child: Text('UDP')),
                    ],
                    onChanged: benchVm.isRunning
                        ? null
                        : (val) {
                            if (val != null) benchVm.setProtocol(val);
                          },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    key: ValueKey('streams_${benchVm.config.streams}'),
                    isExpanded: true,
                    initialValue: benchVm.config.streams,
                    decoration: const InputDecoration(
                      labelText: 'STREAMS (-P)',
                      labelStyle: TextStyle(fontSize: 10),
                    ),
                    dropdownColor: AppTheme.surfaceHigh,
                    style: AppTheme.monoStyle(fontSize: 11),
                    items: [1, 2, 4, 8, 16, 32]
                        .map((s) => DropdownMenuItem(
                            value: s, child: Text('$s P')))
                        .toList(),
                    onChanged: benchVm.isRunning
                        ? null
                        : (val) {
                            if (val != null) benchVm.setStreams(val);
                          },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Direction & Duration Row
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    key: ValueKey('direction_${benchVm.config.direction}'),
                    isExpanded: true,
                    initialValue: benchVm.config.direction,
                    decoration: const InputDecoration(
                      labelText: 'DIRECTION',
                      labelStyle: TextStyle(fontSize: 10),
                    ),
                    dropdownColor: AppTheme.surfaceHigh,
                    style: AppTheme.monoStyle(fontSize: 11),
                    items: const [
                      DropdownMenuItem(
                          value: 'upload', child: Text('Upload')),
                      DropdownMenuItem(
                          value: 'download', child: Text('Download')),
                      DropdownMenuItem(
                          value: 'bidirectional',
                          child: Text('Bidir')),
                    ],
                    onChanged: benchVm.isRunning
                        ? null
                        : (val) {
                            if (val != null) benchVm.setDirection(val);
                          },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    key: ValueKey('duration_${benchVm.config.durationSeconds}'),
                    isExpanded: true,
                    initialValue: benchVm.config.durationSeconds,
                    decoration: const InputDecoration(
                      labelText: 'DURATION',
                      labelStyle: TextStyle(fontSize: 10),
                    ),
                    dropdownColor: AppTheme.surfaceHigh,
                    style: AppTheme.monoStyle(fontSize: 11),
                    items: [5, 10, 15, 20, 30, 60]
                        .map((d) => DropdownMenuItem(
                            value: d, child: Text('${d}s')))
                        .toList(),
                    onChanged: benchVm.isRunning
                        ? null
                        : (val) {
                            if (val != null) benchVm.setDuration(val);
                          },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // CLI Preview
            CommandPreviewCard(
              command: benchVm.config.toCliCommandString(
                benchVm.binaryInfo.path ?? 'iperf3',
              ),
              title: 'Command Line',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRealtimeKpiGrid(BenchmarkViewModel benchVm) {
    return Row(
      children: [
        _kpiTile(
          label: 'AVG THROUGHPUT',
          value: benchVm.avgThroughputMbps >= 1000
              ? '${(benchVm.avgThroughputMbps / 1000).toStringAsFixed(2)} Gbps'
              : '${benchVm.avgThroughputMbps.toStringAsFixed(1)} Mbps',
          color: Colors.white,
          icon: Icons.speed,
        ),
        const SizedBox(width: 8),
        _kpiTile(
          label: 'PEAK SPEED',
          value: benchVm.peakThroughputMbps >= 1000
              ? '${(benchVm.peakThroughputMbps / 1000).toStringAsFixed(2)} Gbps'
              : '${benchVm.peakThroughputMbps.toStringAsFixed(1)} Mbps',
          color: AppTheme.success,
          icon: Icons.trending_up,
        ),
        const SizedBox(width: 8),
        _kpiTile(
          label: benchVm.config.isUdp ? 'JITTER / LOSS' : 'RETRANSMITS',
          value: benchVm.config.isUdp
              ? '${benchVm.currentJitterMs?.toStringAsFixed(2) ?? '-'} ms | ${benchVm.currentLossPercent?.toStringAsFixed(1) ?? '0'}%'
              : '${benchVm.totalRetransmits} pkts',
          color: benchVm.totalRetransmits > 10 ? AppTheme.warning : Colors.white70,
          icon: Icons.sync_problem,
        ),
        const SizedBox(width: 8),
        _kpiTile(
          label: 'BUFFERBLOAT RTT',
          value: benchVm.currentPingRttMs != null
              ? '${benchVm.currentPingRttMs!.toStringAsFixed(1)} ms'
              : 'Idle',
          color: AppTheme.primaryLight,
          icon: Icons.hourglass_bottom,
        ),
      ],
    );
  }

  Widget _kpiTile({
    required String label,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppTheme.border),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: color.withValues(alpha: 0.7)),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                      color: Colors.white38,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: AppTheme.monoStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Tier 4, Tab 1: Historical Runs Workspace
  Widget _buildHistoryWorkspace(BenchmarkViewModel benchVm) {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        children: [
          // Comparison Matrix Card (if 2+ checked)
          if (benchVm.comparisonRuns.length >= 2)
            ComparisonMatrixCard(
              runs: benchVm.comparisonRuns,
              onClearComparison: () => benchVm.clearComparisonSelection(),
            ),
          // Virtualized Data Table
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.border),
              ),
              child: HistoryDataTable(
                runs: benchVm.historicalRuns,
                selectedComparisonIds: benchVm.selectedComparisonIds,
                onToggleComparison: (String id) =>
                    benchVm.toggleComparisonSelection(id),
                selectedInspectorRecord: benchVm.selectedInspectorRecord,
                onSelectInspectorRecord: (BenchmarkResult run) =>
                    benchVm.selectInspectorRecord(run),
                onDeleteRun: (String id) => benchVm.deleteHistoricalRun(id),
                onExportCsv: (BenchmarkResult run) => benchVm.exportCsv(run),
                onExportJson: (BenchmarkResult run) => benchVm.exportJson(run),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Tier 4, Tab 2: Server Daemon Workspace
  Widget _buildServerWorkspace(
      ServerViewModel serverVm, BenchmarkViewModel benchVm) {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: ServerMonitorCard(
        serverVm: serverVm,
        binaryPath: benchVm.binaryInfo.path,
        isOlderThan3191: benchVm.binaryInfo.isOlderThan3191,
      ),
    );
  }

  // Tier 5: Collapsible Detail Inspector & Persistent Status Bar
  Widget _buildDetailInspectorAndStatusBar(BenchmarkViewModel benchVm) {
    final record = benchVm.selectedInspectorRecord;

    return Container(
      color: AppTheme.surfaceHigh,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Inspector Content (height ~200px)
          if (record != null)
            Container(
              height: 200,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                children: [
                  // Inspector Header Bar
                  Row(
                    children: [
                      StatusBadge(
                        label: record.protocol,
                        color: record.isUdp
                            ? AppTheme.warning
                            : AppTheme.primaryLight,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'RUN ID: #${record.id}',
                        style: AppTheme.monoStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _dateFormat.format(record.timestamp),
                        style: AppTheme.monoStyle(
                            fontSize: 10.5, color: Colors.white54),
                      ),
                      const Spacer(),
                      // Tab Buttons: Summary, CLI Preview, Raw Logs
                      _inspectorTabButton(benchVm, 0, 'SUMMARY'),
                      const SizedBox(width: 6),
                      _inspectorTabButton(benchVm, 1, 'CLI PREVIEW'),
                      const SizedBox(width: 6),
                      _inspectorTabButton(benchVm, 2, 'RAW LOGS'),
                      const SizedBox(width: 12),
                      // Export Actions
                      IconButton(
                        icon: const Icon(Icons.file_download, size: 14),
                        tooltip: 'Export CSV',
                        visualDensity: VisualDensity.compact,
                        onPressed: () => benchVm.exportCsv(record),
                      ),
                      IconButton(
                        icon: const Icon(Icons.code, size: 14),
                        tooltip: 'Export JSON',
                        visualDensity: VisualDensity.compact,
                        onPressed: () => benchVm.exportJson(record),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 14),
                        tooltip: 'Close Inspector',
                        visualDensity: VisualDensity.compact,
                        onPressed: () => benchVm.selectInspectorRecord(null),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Divider(height: 1),
                  const SizedBox(height: 8),
                  // Inspector Tab Body
                  Expanded(
                    child: _buildInspectorBody(record, benchVm.inspectorTabIndex),
                  ),
                ],
              ),
            ),

          const Divider(height: 1),

          // Persistent Status Bar
          Container(
            height: 24,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            color: AppTheme.surfaceHighest,
            child: Row(
              children: [
                Text(
                  '${benchVm.historicalRuns.length} runs stored',
                  style: AppTheme.monoStyle(fontSize: 10, color: Colors.white60),
                ),
                const SizedBox(width: 12),
                const Text('|', style: TextStyle(fontSize: 10, color: Colors.white24)),
                const SizedBox(width: 12),
                Text(
                  benchVm.isScanningSubnet
                      ? 'Subnet Discovery: Scanning...'
                      : 'Subnet Nodes: ${benchVm.discoveredNodes.length}',
                  style: AppTheme.monoStyle(fontSize: 10, color: Colors.white60),
                ),
                const Spacer(),
                Text(
                  benchVm.binaryInfo.isAvailable
                      ? 'Binary: ${benchVm.binaryInfo.path}'
                      : (benchVm.isDemoMode
                          ? 'Demo Mode Active'
                          : 'No iPerf3 binary'),
                  style: AppTheme.monoStyle(fontSize: 10, color: Colors.white54),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _inspectorTabButton(BenchmarkViewModel vm, int idx, String label) {
    final isSelected = vm.inspectorTabIndex == idx;
    return InkWell(
      onTap: () => vm.setInspectorTabIndex(idx),
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary : AppTheme.surfaceHighest,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : Colors.white60,
          ),
        ),
      ),
    );
  }

  Widget _buildInspectorBody(BenchmarkResult record, int tabIndex) {
    if (tabIndex == 1) {
      // CLI Preview
      return Center(
        child: CommandPreviewCard(
          command:
              'iperf3 -c ${record.targetHost} -p ${record.port} -t ${record.durationSeconds} -P ${record.streams} ${record.isUdp ? '-u' : ''}',
          title: 'Executed Command',
        ),
      );
    }

    if (tabIndex == 2) {
      // Raw Logs
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFF0F141C),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: AppTheme.border),
        ),
        child: SelectableText(
          record.rawJson.isNotEmpty
              ? record.rawJson
              : 'No raw logs recorded for this run.',
          style: AppTheme.monoStyle(fontSize: 10.5, color: const Color(0xFFC9D1D9)),
        ),
      );
    }

    // Default: Summary Tab
    return SingleChildScrollView(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _summaryRow('Target Host', '${record.targetHost}:${record.port}'),
                _summaryRow('Profile Name', record.profileName),
                _summaryRow('Protocol', '${record.protocol.toUpperCase()} (${record.streams} parallel streams)'),
                _summaryRow('Direction', record.direction),
              ],
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _summaryRow('Average Bitrate', '${record.avgThroughputMbps} Mbps'),
                _summaryRow('Peak Bitrate', '${record.peakThroughputMbps} Mbps'),
                _summaryRow('Min Bitrate', '${record.minThroughputMbps} Mbps'),
                _summaryRow('Total Transferred', '${(record.totalBytes / (1024 * 1024)).toStringAsFixed(1)} MBytes'),
              ],
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _summaryRow('Retransmissions', '${record.retransmits} pkts'),
                _summaryRow('Jitter', record.jitterMs != null ? '${record.jitterMs} ms' : 'N/A'),
                _summaryRow('Packet Loss', record.lossPercent != null ? '${record.lossPercent}%' : 'N/A'),
                _summaryRow('Bufferbloat Delta', record.bufferbloatDeltaMs != null ? '+${record.bufferbloatDeltaMs} ms' : 'N/A'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: const TextStyle(fontSize: 10.5, color: Colors.white38),
          ),
          Text(
            value,
            style: AppTheme.monoStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
