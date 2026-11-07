import 'dart:async';
import 'package:flutter/material.dart';
import '../../data/repositories/benchmark_repository.dart';
import '../../data/services/iperf/iperf_binary_service.dart';
import '../../domain/models/benchmark_config.dart';
import '../../domain/models/benchmark_preset.dart';
import '../../domain/models/benchmark_result.dart';
import '../../domain/models/discovered_node.dart';
import '../../domain/models/live_sample.dart';
import '../../domain/models/network_adapter.dart';
import '../../domain/models/network_validator.dart';

class BenchmarkViewModel extends ChangeNotifier {
  BenchmarkViewModel({required this.repository}) {
    _init();
  }

  final BenchmarkRepository repository;

  // Active Configuration & Preset
  BenchmarkConfig _config = const BenchmarkConfig();
  BenchmarkPreset? _selectedPreset = BenchmarkPreset.defaultPresets.first;

  // Execution State
  bool _isRunning = false;
  bool _isDemoMode = false;
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
        _discoveredNodes = nodes;
        notifyListeners();
      });

      final savedBinaryPath = repository.dbService.getSetting('custom_binary_path');
      if (savedBinaryPath != null && savedBinaryPath.isNotEmpty) {
        await updateCustomBinaryPath(savedBinaryPath);
      }

      if (!repository.binaryInfo.isAvailable) {
        _isDemoMode = true;
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
    _isDemoMode = enabled;
    _config = _config.copyWith(isDemoMode: enabled);
    notifyListeners();
  }

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
      forceDemo: _isDemoMode,
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
