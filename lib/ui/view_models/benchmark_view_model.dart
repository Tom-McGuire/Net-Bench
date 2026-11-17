import 'dart:async';
import 'package:material_ui/material_ui.dart';
import '../../data/repositories/benchmark_repository.dart';
import '../../data/services/iperf/iperf_binary_service.dart';
import '../../domain/models/benchmark_config.dart';
import '../../domain/models/benchmark_preset.dart';
import '../../domain/models/benchmark_result.dart';
import '../../domain/models/discovered_node.dart';
import '../../domain/models/launch_adapter_config.dart';
import '../../domain/models/live_sample.dart';
import '../../domain/models/network_adapter.dart';
import '../../domain/models/network_validator.dart';

class BenchmarkViewModel extends ChangeNotifier {
  BenchmarkViewModel({
    required this.repository,
    this.initialAdapterConfig,
  }) {
    _init();
  }

  final BenchmarkRepository repository;
  final LaunchAdapterConfig? initialAdapterConfig;
  bool _startupAdapterApplied = false;

  // Active Configuration & Preset
  BenchmarkConfig _config = const BenchmarkConfig();
  BenchmarkPreset? _selectedPreset = BenchmarkPreset.defaultPresets.first;

  // Execution State
  bool _isRunning = false;
  bool _isDemoMode = false;
  bool _isDemoWalkthroughActive = false;
  LiveSample? _currentSample;
  final List<LiveSample> _liveSamples = [];
  StreamSubscription<LiveSample>? _sampleSub;
  BenchmarkResult? _lastCompletedResult;

  // Filter & Search State
  String _searchQuery = '';
  String _protocolFilter = 'ALL'; // 'ALL' | 'TCP' | 'UDP'
  List<BenchmarkResult> _historicalRuns = [];

  // Multi-Selection for Comparison
  final Set<String> _selectedComparisonIds = {};

  // Inspector Selection (Bottom Detail Panel)
  BenchmarkResult? _selectedInspectorRecord;
  int _inspectorTabIndex = 0; // 0: Summary, 1: CLI Preview, 2: Raw Logs

  // Discovery State
  bool _isScanningSubnet = false;
  List<DiscoveredNode> _discoveredNodes = [];
  StreamSubscription<List<DiscoveredNode>>? _nodesSub;

  // Network Adapters
  List<NetworkAdapter> _availableAdapters = const [
    NetworkAdapter(name: 'Auto / Default Route', ipAddress: '0.0.0.0'),
  ];
  List<NetworkAdapter> get availableAdapters =>
      List.unmodifiable(_availableAdapters);

  // Validation feedback
  String? _validationError;
  String? get validationError => _validationError;

  // Getters
  BenchmarkConfig get config => _config;
  BenchmarkPreset? get selectedPreset => _selectedPreset;
  bool get isRunning => _isRunning;
  bool get isDemoMode => _isDemoMode;
  bool get isDemoWalkthroughActive => _isDemoWalkthroughActive;
  IPerfBinaryInfo get binaryInfo => repository.binaryInfo;

  LiveSample? get currentSample => _currentSample;
  List<LiveSample> get liveSamples => List.unmodifiable(_liveSamples);
  BenchmarkResult? get lastCompletedResult => _lastCompletedResult;

  String get searchQuery => _searchQuery;
  String get protocolFilter => _protocolFilter;
  List<BenchmarkResult> get historicalRuns => _historicalRuns;

  Set<String> get selectedComparisonIds => _selectedComparisonIds;
  List<BenchmarkResult> get comparisonRuns => _historicalRuns
      .where((r) => _selectedComparisonIds.contains(r.id))
      .toList();

  BenchmarkResult? get selectedInspectorRecord =>
      _selectedInspectorRecord ?? _lastCompletedResult;
  int get inspectorTabIndex => _inspectorTabIndex;

  bool get isScanningSubnet => _isScanningSubnet;
  List<DiscoveredNode> get discoveredNodes => _discoveredNodes;

  // Live Metrics
  double get instantThroughputMbps => _currentSample?.throughputMbps ?? 0.0;
  double get peakThroughputMbps {
    if (_liveSamples.isEmpty) return 0.0;
    return _liveSamples
        .map((s) => s.throughputMbps)
        .reduce((a, b) => a > b ? a : b);
  }

  double get avgThroughputMbps {
    if (_liveSamples.isEmpty) return 0.0;
    final sum = _liveSamples.map((s) => s.throughputMbps).reduce((a, b) => a + b);
    return sum / _liveSamples.length;
  }

  int get totalRetransmits =>
      _liveSamples.fold(0, (sum, s) => sum + s.retransmits);
  double? get currentJitterMs => _currentSample?.jitterMs;
  double? get currentLossPercent => _currentSample?.lostPercent;
  double? get currentPingRttMs => _currentSample?.pingRttMs;

  Future<void> _init() async {
    try {
      await repository.init();
      _refreshHistoricalRuns();
      _discoveredNodes = repository.currentDiscoveredNodes;

      _nodesSub = repository.discoveredNodesStream.listen((nodes) {
        if (!_isDemoWalkthroughActive) {
          _discoveredNodes = nodes;
          notifyListeners();
        }
      });

      final savedBinaryPath = repository.dbService.getSetting('custom_binary_path');
      if (savedBinaryPath != null && savedBinaryPath.isNotEmpty) {
        await updateCustomBinaryPath(savedBinaryPath);
      }

      loadAdapters();
    } catch (_) {}
    notifyListeners();
  }

  Future<void> loadAdapters() async {
    final list = await repository.getNetworkAdapters();
    if (list.isNotEmpty) {
      _availableAdapters = [
        const NetworkAdapter(
          name: 'Auto / Default Route',
          ipAddress: '0.0.0.0',
        ),
        ...list.where((a) => a.ipAddress != '0.0.0.0'),
      ];
      if (!_startupAdapterApplied &&
          initialAdapterConfig != null &&
          initialAdapterConfig!.hasOverride) {
        _startupAdapterApplied = true;
        final matched = initialAdapterConfig!.matchAdapter(_availableAdapters);
        if (matched != null) {
          _config = _config.copyWith(bindAddress: matched.ipAddress);
        }
      }
      notifyListeners();
    }
  }

  bool _isDisposed = false;

  void setBindAddress(String? address) {
    if (address == null || address.isEmpty || address == '0.0.0.0') {
      _config = _config.copyWith(clearBindAddress: true);
    } else {
      _config = _config.copyWith(bindAddress: address.trim());
    }
    notifyListeners();
  }

  void setConfig(BenchmarkConfig newConfig) {
    _config = newConfig;
    _validationError = null;
    notifyListeners();
  }

  void selectPreset(BenchmarkPreset preset) {
    _selectedPreset = preset;
    _config = preset.config.copyWith(
      targetHost: _config.targetHost,
      port: _config.port,
      isDemoMode: _isDemoMode,
    );
    _validationError = null;
    notifyListeners();
  }

  void setTargetHost(String host) {
    _config = _config.copyWith(targetHost: host.trim());
    _validationError = null;
    notifyListeners();
  }

  void setPort(int port) {
    _config = _config.copyWith(port: port);
    _validationError = null;
    notifyListeners();
  }

  void setStreams(int streams) {
    _config = _config.copyWith(streams: streams);
    notifyListeners();
  }

  void setDuration(int seconds) {
    _config = _config.copyWith(durationSeconds: seconds);
    notifyListeners();
  }

  void setDirection(String direction) {
    _config = _config.copyWith(direction: direction);
    notifyListeners();
  }

  void setProtocol(String proto) {
    _config = _config.copyWith(protocol: proto);
    notifyListeners();
  }

  void setDemoMode(bool enabled) {
    if (!enabled && _isDemoWalkthroughActive) {
      endDemoWalkthrough();
      return;
    }
    _isDemoMode = enabled;
    _config = _config.copyWith(isDemoMode: enabled);
    notifyListeners();
  }

  /// Populates realistic in-memory benchmark telemetry and launches the
  /// interactive spotlight walkthrough without writing to SQLite or Shared DB.
  void startDemoWalkthrough() {
    if (_isRunning) return;

    _isDemoMode = true;
    _isDemoWalkthroughActive = true;
    _validationError = null;
    _searchQuery = '';
    _protocolFilter = 'ALL';
    _inspectorTabIndex = 0;
    _config = _config.copyWith(
      isDemoMode: true,
      targetHost: '192.168.1.10',
      port: 5201,
    );

    final demoSamples = <LiveSample>[
      const LiveSample(
        interval: 1,
        secondsElapsed: 1.0,
        throughputMbps: 915.4,
        perStreamMbps: {1: 229.1, 2: 228.5, 3: 229.0, 4: 228.8},
        retransmits: 0,
        pingRttMs: 4.2,
      ),
      const LiveSample(
        interval: 2,
        secondsElapsed: 2.0,
        throughputMbps: 932.8,
        perStreamMbps: {1: 233.5, 2: 232.9, 3: 233.1, 4: 233.3},
        retransmits: 0,
        pingRttMs: 4.6,
      ),
      const LiveSample(
        interval: 3,
        secondsElapsed: 3.0,
        throughputMbps: 948.1,
        perStreamMbps: {1: 237.2, 2: 236.8, 3: 237.0, 4: 237.1},
        retransmits: 1,
        pingRttMs: 5.4,
      ),
      const LiveSample(
        interval: 4,
        secondsElapsed: 4.0,
        throughputMbps: 956.3,
        perStreamMbps: {1: 239.1, 2: 238.9, 3: 239.2, 4: 239.1},
        retransmits: 0,
        pingRttMs: 5.9,
      ),
      const LiveSample(
        interval: 5,
        secondsElapsed: 5.0,
        throughputMbps: 941.0,
        perStreamMbps: {1: 235.4, 2: 235.1, 3: 235.3, 4: 235.2},
        retransmits: 0,
        pingRttMs: 4.9,
      ),
      const LiveSample(
        interval: 6,
        secondsElapsed: 6.0,
        throughputMbps: 964.2,
        perStreamMbps: {1: 241.2, 2: 240.8, 3: 241.1, 4: 241.1},
        retransmits: 0,
        pingRttMs: 6.8,
      ),
      const LiveSample(
        interval: 7,
        secondsElapsed: 7.0,
        throughputMbps: 949.5,
        perStreamMbps: {1: 237.5, 2: 237.3, 3: 237.4, 4: 237.3},
        retransmits: 1,
        pingRttMs: 5.6,
      ),
      const LiveSample(
        interval: 8,
        secondsElapsed: 8.0,
        throughputMbps: 936.7,
        perStreamMbps: {1: 234.2, 2: 234.1, 3: 234.3, 4: 234.1},
        retransmits: 0,
        pingRttMs: 4.8,
      ),
      const LiveSample(
        interval: 9,
        secondsElapsed: 9.0,
        throughputMbps: 928.9,
        perStreamMbps: {1: 232.3, 2: 232.2, 3: 232.1, 4: 232.3},
        retransmits: 0,
        pingRttMs: 4.5,
      ),
      const LiveSample(
        interval: 10,
        secondsElapsed: 10.0,
        throughputMbps: 945.1,
        perStreamMbps: {1: 236.4, 2: 236.2, 3: 236.3, 4: 236.2},
        retransmits: 0,
        pingRttMs: 4.5,
      ),
    ];

    _liveSamples
      ..clear()
      ..addAll(demoSamples);
    _currentSample = _liveSamples.last;

    final now = DateTime.now();
    final demoRun1 = BenchmarkResult(
      id: 'demo-run-1',
      timestamp: now.subtract(const Duration(minutes: 4)),
      profileName: '1G Full-Duplex',
      targetHost: '192.168.1.10',
      port: 5201,
      protocol: 'tcp',
      direction: 'bidirectional',
      streams: 4,
      durationSeconds: 10,
      avgThroughputMbps: 941.8,
      peakThroughputMbps: 964.2,
      minThroughputMbps: 892.0,
      totalBytes: 1177250000,
      retransmits: 2,
      baselinePingMs: 2.1,
      loadedPingMs: 4.5,
      bufferbloatDeltaMs: 2.4,
      samples: List.of(_liveSamples),
      rawJson:
          '{"start":{"connected":[{"socket":5,"local_host":"192.168.1.50","remote_host":"192.168.1.10","remote_port":5201}],"test_start":{"protocol":"TCP","num_streams":4,"blksize":131072,"duration":10}},"end":{"sum_sent":{"bytes":1177250000,"bits_per_second":941800000,"retransmits":2},"sum_received":{"bytes":1176500000,"bits_per_second":941200000}}}',
    );

    final demoRun2 = BenchmarkResult(
      id: 'demo-run-2',
      timestamp: now.subtract(const Duration(minutes: 12)),
      profileName: 'UDP Jitter Check',
      targetHost: '192.168.1.10',
      port: 5201,
      protocol: 'udp',
      direction: 'upload',
      streams: 1,
      durationSeconds: 10,
      avgThroughputMbps: 498.4,
      peakThroughputMbps: 500.0,
      minThroughputMbps: 495.1,
      totalBytes: 623000000,
      jitterMs: 0.28,
      lossPercent: 0.02,
      lostPackets: 8,
      totalPackets: 40000,
      rawJson:
          '{"start":{"connected":[{"socket":6,"local_host":"192.168.1.50","remote_host":"192.168.1.10","remote_port":5201}],"test_start":{"protocol":"UDP","num_streams":1,"duration":10}},"end":{"sum":{"bytes":623000000,"bits_per_second":498400000,"jitter_ms":0.28,"lost_packets":8,"packets":40000,"lost_percent":0.02}}}',
    );

    _historicalRuns = [demoRun1, demoRun2];
    _selectedComparisonIds
      ..clear()
      ..addAll(['demo-run-1', 'demo-run-2']);
    _lastCompletedResult = demoRun1;
    _selectedInspectorRecord = demoRun1;
    _discoveredNodes = [
      DiscoveredNode(
        ip: '192.168.1.10',
        hostname: 'iperf-core-01',
        port: 5201,
        discoveryType: 'peer_beacon',
        latencyMs: 2,
        lastSeen: now,
      ),
      DiscoveredNode(
        ip: '192.168.1.25',
        hostname: 'nas-bench-02',
        port: 5201,
        discoveryType: 'tcp_sweep',
        latencyMs: 3,
        lastSeen: now,
      ),
    ];

    notifyListeners();
  }

  void loadDemoWalkthroughData() => startDemoWalkthrough();

  /// Ends the interactive walkthrough, exits demo mode, and clears all
  /// in-memory demo telemetry before restoring persisted history.
  void endDemoWalkthrough() {
    _isDemoWalkthroughActive = false;
    _isDemoMode = false;
    _config = _config.copyWith(isDemoMode: false);
    _liveSamples.clear();
    _currentSample = null;
    _lastCompletedResult = null;
    _selectedComparisonIds.clear();
    _selectedInspectorRecord = null;
    _inspectorTabIndex = 0;
    _discoveredNodes = repository.currentDiscoveredNodes;
    _refreshHistoricalRuns();
  }

  void clearDemoWalkthroughData() => endDemoWalkthrough();

  Future<void> updateCustomBinaryPath(String path) async {
    repository.dbService.setSetting('custom_binary_path', path);
    await repository.checkBinary(customPath: path);
    if (repository.binaryInfo.isAvailable) {
      _isDemoMode = false;
    }
    notifyListeners();
  }

  // Execution
  void startBenchmark() {
    if (_isRunning) return;

    if (!NetworkValidator.isValidHost(_config.targetHost)) {
      _validationError = 'Invalid target host or IP address format.';
      notifyListeners();
      return;
    }

    if (!NetworkValidator.isValidPort(_config.port)) {
      _validationError = 'Port must be between 1 and 65535.';
      notifyListeners();
      return;
    }

    _validationError = null;
    _isRunning = true;
    _liveSamples.clear();
    _currentSample = null;
    notifyListeners();

    final stream = repository.runBenchmark(
      config: _config,
      forceDemo: _isDemoMode || !repository.binaryInfo.isAvailable,
      onComplete: (result) {
        _isRunning = false;
        _lastCompletedResult = result;
        _selectedInspectorRecord = result;
        _refreshHistoricalRuns();
        notifyListeners();
      },
    );

    _sampleSub = stream.listen(
      (sample) {
        _currentSample = sample;
        _liveSamples.add(sample);
        notifyListeners();
      },
      onError: (err) {
        _isRunning = false;
        notifyListeners();
      },
    );
  }

  void stopBenchmark() {
    if (!_isRunning) return;
    repository.cancelActiveBenchmark();
    _sampleSub?.cancel();
    _sampleSub = null;
    _isRunning = false;
    notifyListeners();
  }

  // Subnet Discovery
  Future<void> triggerSubnetScan() async {
    if (_isScanningSubnet) return;
    _isScanningSubnet = true;
    notifyListeners();

    try {
      final nodes = await repository.scanSubnet(port: _config.port);
      _discoveredNodes = nodes;
    } finally {
      _isScanningSubnet = false;
      notifyListeners();
    }
  }

  void selectDiscoveredNode(DiscoveredNode node) {
    _config = _config.copyWith(targetHost: node.ip, port: node.port);
    notifyListeners();
  }

  // Filters & Historical Runs
  void setSearchQuery(String query) {
    _searchQuery = query;
    _refreshHistoricalRuns();
  }

  void setProtocolFilter(String proto) {
    _protocolFilter = proto;
    _refreshHistoricalRuns();
  }

  void clearFilters() {
    _searchQuery = '';
    _protocolFilter = 'ALL';
    _refreshHistoricalRuns();
  }

  void _refreshHistoricalRuns() {
    _historicalRuns = repository.getHistoricalRuns(
      searchQuery: _searchQuery,
      protocol: _protocolFilter,
    );
    notifyListeners();
  }

  void selectInspectorRecord(BenchmarkResult? record) {
    _selectedInspectorRecord = record;
    notifyListeners();
  }

  void setInspectorTabIndex(int index) {
    _inspectorTabIndex = index;
    notifyListeners();
  }

  // Multi-Run Comparison
  void toggleComparisonSelection(String id) {
    if (_selectedComparisonIds.contains(id)) {
      _selectedComparisonIds.remove(id);
    } else {
      _selectedComparisonIds.add(id);
    }
    notifyListeners();
  }

  void clearComparisonSelection() {
    _selectedComparisonIds.clear();
    notifyListeners();
  }

  // Delete & Export
  void deleteHistoricalRun(String id) {
    repository.deleteRun(id);
    _selectedComparisonIds.remove(id);
    if (_selectedInspectorRecord?.id == id) {
      _selectedInspectorRecord = null;
    }
    _refreshHistoricalRuns();
  }

  void clearAllHistory() {
    repository.clearHistory();
    _selectedComparisonIds.clear();
    _selectedInspectorRecord = null;
    _refreshHistoricalRuns();
  }

  Future<String?> exportCsv(BenchmarkResult result) =>
      repository.exportCsv(result);

  Future<String?> exportJson(BenchmarkResult result) =>
      repository.exportJson(result);

  @override
  void notifyListeners() {
    if (_isDisposed) return;
    super.notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _sampleSub?.cancel();
    _nodesSub?.cancel();
    super.dispose();
  }
}
